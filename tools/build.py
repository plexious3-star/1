"""Generate the Roblox build script and preview renders from creature_spec.

    python3 tools/build.py            # writes roblox/BuildRedCreature.lua + previews/*.png
"""
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(__file__))
import creature_spec as spec  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# Standard R6 joint rotation matrices (CFrame components R00..R22).
ROTS = {
    "root":  (-1, 0, 0, 0, 0, 1, 0, 1, 0),
    "right": (0, 0, 1, 0, 1, 0, -1, 0, 0),
    "left":  (0, 0, -1, 0, 1, 0, 1, 0, 0),
}


# --------------------------------------------------------------------------- math
def cf(pos=(0, 0, 0), rot=np.eye(3)):
    m = np.eye(4)
    m[:3, :3] = rot
    m[:3, 3] = pos
    return m


def angles(rx, ry, rz):
    """CFrame.Angles in degrees: R = Rx * Ry * Rz."""
    a, b, c = (math.radians(v) for v in (rx, ry, rz))
    rxm = np.array([[1, 0, 0], [0, math.cos(a), -math.sin(a)], [0, math.sin(a), math.cos(a)]])
    rym = np.array([[math.cos(b), 0, math.sin(b)], [0, 1, 0], [-math.sin(b), 0, math.cos(b)]])
    rzm = np.array([[math.cos(c), -math.sin(c), 0], [math.sin(c), math.cos(c), 0], [0, 0, 1]])
    return rxm @ rym @ rzm


def rest_pose():
    """World CFrames of every base part in the rest pose (HRP at y=3)."""
    world = {"HumanoidRootPart": cf((0, 3, 0))}
    for name, p0, p1, c0p, c1p, rot in spec.JOINTS:
        r = np.array(ROTS[rot], dtype=float).reshape(3, 3)
        world[p1] = world[p0] @ cf(c0p, r) @ np.linalg.inv(cf(c1p, r))
    parent, root_pos = spec.TAIL_ROOT
    prev_len = None
    for i, (length, _, rot) in enumerate(spec.TAIL):
        c0 = cf(root_pos if prev_len is None else (0, -prev_len / 2, 0), angles(*rot))
        c1 = cf((0, length / 2, 0))
        world[f"Tail{i+1}"] = world[parent] @ c0 @ np.linalg.inv(c1)
        parent, prev_len = f"Tail{i+1}", length
    return world


# --------------------------------------------------------------------------- render
def shade_color(name):
    rgb, mat = spec.PALETTE[name]
    return np.array(rgb, dtype=float) / 255.0, mat == "Neon"


def render(world, yaw_deg, pitch_deg=-8, ppu=70, size=(560, 640)):
    yaw, pitch = math.radians(yaw_deg), math.radians(pitch_deg)
    # camera looks along d; yaw 0 = looking at the creature's front
    d = np.array([math.sin(yaw) * math.cos(pitch), math.sin(pitch), math.cos(yaw) * math.cos(pitch)])
    right = np.cross(d, [0, 1, 0]); right /= np.linalg.norm(right)
    up = np.cross(right, d)
    w, h = size
    center = np.array([0, 2.9, -0.3])
    xs = (np.arange(w) - w / 2) / ppu
    ys = (h / 2 - np.arange(h)) / ppu
    gx, gy = np.meshgrid(xs, ys)
    origins = center + gx[..., None] * right + gy[..., None] * up - d * 50
    O = origins.reshape(-1, 3)
    depth = np.full(len(O), np.inf)
    col = np.ones((len(O), 3)) * np.array([0.93, 0.93, 0.95])
    ids = np.full(len(O), -1)
    light = np.array([-0.45, 0.75, -0.55]); light /= np.linalg.norm(light)
    for idx, p in enumerate(spec.PIECES):
        m = world[p["part"]] @ cf(p["pos"], angles(*p["rot"]))
        R, c = m[:3, :3], m[:3, 3]
        a = np.array(p["size"], dtype=float) / 2
        ol = ((O - c) @ R) / a
        dl = (R.T @ d) / a
        A = dl @ dl
        B = 2 * ol @ dl
        C = np.einsum("ij,ij->i", ol, ol) - 1
        disc = B * B - 4 * A * C
        hit = disc > 0
        t = np.full(len(O), np.inf)
        t[hit] = (-B[hit] - np.sqrt(disc[hit])) / (2 * A)
        closer = t < depth
        if not closer.any():
            continue
        pl = ol[closer] + t[closer, None] * dl
        n = (pl / a) @ R.T
        n /= np.linalg.norm(n, axis=1, keepdims=True)
        base, neon = shade_color(p["color"])
        if neon:
            shade = np.ones(len(n)) * 1.15
        else:
            lam = np.clip(n @ light, 0, 1)
            rim = np.clip(1 - np.abs(n @ -d), 0, 1) ** 3
            shade = 0.38 + 0.72 * lam - 0.25 * rim
        col[closer] = np.clip(base * shade[:, None], 0, 1)
        depth[closer] = t[closer]
        ids[closer] = idx
    img = (col.reshape(h, w, 3) * 255).astype(np.uint8)
    dep = depth.reshape(h, w)
    # ink lines at silhouette / depth breaks, like the reference's line art
    finite = np.where(np.isinf(dep), 1e3, dep)
    edge = np.zeros((h, w), bool)
    for dy, dx in ((0, 1), (1, 0)):
        diff = np.abs(finite - np.roll(np.roll(finite, dy, 0), dx, 1))
        edge |= diff > 0.35
    img[edge] = (img[edge] * 0.25).astype(np.uint8)
    return Image.fromarray(img)


def previews():
    world = rest_pose()
    out = os.path.join(ROOT, "previews")
    os.makedirs(out, exist_ok=True)
    views = [("front", 0), ("three_quarter", 28), ("side", 90), ("back", 180), ("other_side", -90)]
    imgs = {}
    for name, yaw in views:
        im = render(world, yaw)
        im.save(os.path.join(out, f"{name}.png"))
        imgs[name] = im
    ref_path = os.path.join(ROOT, "reference", "reference.png")
    if os.path.exists(ref_path):
        ref = Image.open(ref_path).convert("RGBA")
        bg = Image.new("RGBA", ref.size, (237, 237, 242, 255))
        ref = Image.alpha_composite(bg, ref).convert("RGB")
        ref = ref.resize((int(ref.width * 640 / ref.height), 640))
        sheet = Image.new("RGB", (ref.width + 560 * 2, 640), (255, 255, 255))
        sheet.paste(ref, (0, 0))
        sheet.paste(imgs["three_quarter"], (ref.width, 0))
        sheet.paste(imgs["front"], (ref.width + 560, 0))
        ImageDraw.Draw(sheet).text((8, 8), "reference", fill=(0, 0, 0))
        sheet.save(os.path.join(out, "compare.png"))
    turn = Image.new("RGB", (560 * 4, 640), (255, 255, 255))
    for i, n in enumerate(["front", "side", "back", "other_side"]):
        turn.paste(imgs[n], (560 * i, 0))
    turn.save(os.path.join(out, "turnaround.png"))


# --------------------------------------------------------------------------- lua
def num(v):
    s = f"{v:.3f}".rstrip("0").rstrip(".")
    return "0" if s in ("-0", "") else s


def v3(t):
    return ", ".join(num(x) for x in t)


def lua_pieces():
    groups = {}
    for p in spec.PIECES:
        groups.setdefault(p["group"], []).append(p)
    lines = []
    for g, items in groups.items():
        lines.append(f"\t-- {g}")
        for p in items:
            lines.append(
                f'\t{{"{g}", "{p["name"]}", "{p["part"]}", {{{v3(p["pos"])}}}, '
                f'{{{v3(p["size"])}}}, {{{v3(p["rot"])}}}, "{p["color"]}"}},')
    return "\n".join(lines)


def lua_palette():
    return "\n".join(
        f'\t{name} = {{ Color3.fromRGB({v3(rgb)}), Enum.Material.{mat} }},'
        for name, (rgb, mat) in spec.PALETTE.items())


def lua_joints():
    return "\n".join(
        f'\t{{ "{n}", "{p0}", "{p1}", {{{v3(c0)}}}, {{{v3(c1)}}}, "{rot}" }},'
        for n, p0, p1, c0, c1, rot in spec.JOINTS)


def lua_tail():
    return "\n".join(f"\t{{ {num(l)}, {num(r)}, {{{v3(rot)}}} }}," for l, r, rot in spec.TAIL)


def write_lua():
    template = open(os.path.join(os.path.dirname(__file__), "template.lua")).read()
    parent, root_pos = spec.TAIL_ROOT
    lua = (template
           .replace("--@PALETTE@", lua_palette())
           .replace("--@JOINTS@", lua_joints())
           .replace("--@TAIL@", lua_tail())
           .replace("--@TAIL_ROOT@", f'"{parent}", {{{v3(root_pos)}}}')
           .replace("--@PIECES@", lua_pieces()))
    out = os.path.join(ROOT, "roblox", "BuildRedCreature.lua")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    open(out, "w").write(lua)
    return out


if __name__ == "__main__":
    if "--no-render" not in sys.argv:
        previews()
    print(write_lua())
