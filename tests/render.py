"""Ray-traced previews of parts dumped by the mock (Ball / Block / Wedge / Cylinder).

Orthographic, Lambert-shaded with ink outlines. Good enough to judge silhouette,
proportions and placement; it is not a Roblox renderer.
"""
import math
import os

import numpy as np
from PIL import Image, ImageDraw

BG = np.array([0.93, 0.93, 0.95])


def _frame(p):
    x, y, z, *r = p["cf"]
    R = np.array(r, dtype=float).reshape(3, 3)
    return R, np.array([x, y, z], dtype=float)


def _hit_ball(ol, dl, a):
    ol, dl = ol / a, dl / a
    A = dl @ dl
    B = 2 * ol @ dl
    C = np.einsum("ij,ij->i", ol, ol) - 1
    disc = B * B - 4 * A * C
    t = np.full(len(ol), np.inf)
    ok = disc > 0
    t[ok] = (-B[ok] - np.sqrt(disc[ok])) / (2 * A)
    with np.errstate(invalid="ignore"):
        n = (ol + t[:, None] * dl) / a
    return t, n


def _hit_planes(ol, dl, planes):
    """Convex solid n·p <= d for every (n, d)."""
    N = len(ol)
    t_in = np.full(N, -np.inf)
    t_out = np.full(N, np.inf)
    n_in = np.zeros((N, 3))
    for n, d in planes:
        n = np.asarray(n, dtype=float)
        denom = dl @ n
        num = d - ol @ n
        with np.errstate(divide="ignore", invalid="ignore"):
            t = num / denom
        entering = denom < 0
        exiting = denom > 0
        parallel_out = (denom == 0) & (num < 0)
        upd = entering & (t > t_in)
        t_in = np.where(upd, t, t_in)
        n_in[upd] = n
        t_out = np.where(exiting, np.minimum(t_out, t), t_out)
        t_in = np.where(parallel_out, np.inf, t_in)
    hit = (t_in <= t_out) & np.isfinite(t_in)
    t = np.where(hit, t_in, np.inf)
    return t, n_in


def _hit_cylinder(ol, dl, a):
    # axis X, radius = min(half Y, half Z)
    r = min(a[1], a[2])
    A = dl[1] ** 2 + dl[2] ** 2
    B = 2 * (ol[:, 1] * dl[1] + ol[:, 2] * dl[2])
    C = ol[:, 1] ** 2 + ol[:, 2] ** 2 - r * r
    N = len(ol)
    t_in, t_out = np.full(N, -np.inf), np.full(N, np.inf)
    n_in = np.zeros((N, 3))
    if A > 1e-12:
        disc = B * B - 4 * A * C
        ok = disc > 0
        t0 = np.full(N, np.inf)
        t1 = np.full(N, -np.inf)
        t0[ok] = (-B[ok] - np.sqrt(disc[ok])) / (2 * A)
        t1[ok] = (-B[ok] + np.sqrt(disc[ok])) / (2 * A)
        t_in, t_out = t0, t1
        p = ol + t0[:, None] * dl
        n_in = np.stack([np.zeros(N), p[:, 1], p[:, 2]], 1)
        t_in = np.where(ok, t_in, np.inf)
    else:  # ray parallel to the axis: inside the tube or never
        t_in = np.where(C <= 0, -np.inf, np.inf)
    # slab interval for x
    with np.errstate(divide="ignore", invalid="ignore"):
        tx0 = (-a[0] - ol[:, 0]) / dl[0] if dl[0] != 0 else np.full(N, -np.inf)
        tx1 = (a[0] - ol[:, 0]) / dl[0] if dl[0] != 0 else np.full(N, np.inf)
    lo, hi = np.minimum(tx0, tx1), np.maximum(tx0, tx1)
    use_cap = lo > t_in
    t_enter = np.maximum(t_in, lo)
    t_exit = np.minimum(t_out, hi)
    hit = t_enter <= t_exit
    n = np.where(use_cap[:, None], np.array([-np.sign(dl[0]), 0, 0])[None, :], n_in)
    return np.where(hit, t_enter, np.inf), n


def render(parts, yaw=0.0, pitch=-8.0, ppu=55, size=(520, 620), center=None):
    yaw_r, pitch_r = math.radians(yaw), math.radians(pitch)
    d = np.array([math.sin(yaw_r) * math.cos(pitch_r), math.sin(pitch_r), math.cos(yaw_r) * math.cos(pitch_r)])
    right = np.cross(d, [0, 1, 0])
    right /= np.linalg.norm(right)
    up = np.cross(right, d)
    w, h = size
    center = np.array(center if center is not None else [0, 3, 0], dtype=float)
    xs = (np.arange(w) - w / 2) / ppu
    ys = (h / 2 - np.arange(h)) / ppu
    gx, gy = np.meshgrid(xs, ys)
    O = (center + gx[..., None] * right + gy[..., None] * up - d * 60).reshape(-1, 3)
    depth = np.full(len(O), np.inf)
    col = np.tile(BG, (len(O), 1))
    light = np.array([-0.45, 0.75, -0.55])
    light /= np.linalg.norm(light)
    for p in parts:
        R, c = _frame(p)
        a = np.array(p["sz"], dtype=float) / 2
        # cheap bounding-sphere cull
        rad = np.linalg.norm(a)
        rel = O - c
        along = rel @ d
        perp2 = np.einsum("ij,ij->i", rel, rel) - along ** 2
        cand = np.nonzero(perp2 < rad * rad)[0]
        if len(cand) == 0:
            continue
        ol = (O[cand] - c) @ R
        dl = R.T @ d
        s = p["s"]
        if s == "Ball":
            t, nl = _hit_ball(ol, dl, a)
            nl = nl / a
        elif s == "Wedge":
            hy, hz = a[1], a[2]
            wn = np.array([0, 1 / hy, -1 / hz])
            t, nl = _hit_planes(ol, dl, [((1, 0, 0), a[0]), ((-1, 0, 0), a[0]), ((0, -1, 0), a[1]),
                                         ((0, 0, 1), a[2]), (tuple(wn / np.linalg.norm(wn)), 0.0)])
        elif s == "Cylinder":
            t, nl = _hit_cylinder(ol, dl, a)
        else:
            t, nl = _hit_planes(ol, dl, [((1, 0, 0), a[0]), ((-1, 0, 0), a[0]), ((0, 1, 0), a[1]),
                                         ((0, -1, 0), a[1]), ((0, 0, 1), a[2]), ((0, 0, -1), a[2])])
        closer = (t < depth[cand]) & (t > 0)
        if not closer.any():
            continue
        idx = cand[closer]
        n = nl[closer] @ R.T
        n /= np.maximum(np.linalg.norm(n, axis=1, keepdims=True), 1e-9)
        n = np.where((n @ d)[:, None] > 0, -n, n)
        base = np.array(p["c"], dtype=float)
        if p["m"] == "Neon":
            shade = np.full(len(n), 1.15)
        else:
            lam = np.clip(n @ light, 0, 1)
            rim = np.clip(1 - np.abs(n @ -d), 0, 1) ** 3
            shade = 0.4 + 0.7 * lam - 0.22 * rim
        rgb = np.clip(base * shade[:, None], 0, 1)
        tr = p.get("t", 0)
        if tr > 0:
            rgb = rgb * (1 - tr) + col[idx] * tr
        col[idx] = rgb
        depth[idx] = t[closer]
    img = (col.reshape(h, w, 3) * 255).astype(np.uint8)
    dep = np.where(np.isinf(depth), 1e3, depth).reshape(h, w)
    edge = np.zeros((h, w), bool)
    for dy, dx in ((0, 1), (1, 0)):
        edge |= np.abs(dep - np.roll(np.roll(dep, dy, 0), dx, 1)) > 0.35
    img[edge] = (img[edge] * 0.25).astype(np.uint8)
    return Image.fromarray(img)


def _bounds(parts):
    pts = []
    for p in parts:
        _, c = _frame(p)
        pts.append(c)
    pts = np.array(pts)
    return pts.min(0), pts.max(0)


def _label(img, text):
    ImageDraw.Draw(img).text((8, 6), text, fill=(20, 20, 20))
    return img


def render_all(dumps, out_dir):
    os.makedirs(out_dir, exist_ok=True)
    for name, parts in dumps.items():
        lo, hi = _bounds(parts)
        center = [(lo[0] + hi[0]) / 2, (lo[1] + hi[1]) / 2 + 0.2, (lo[2] + hi[2]) / 2]
        span = max(hi[1] - lo[1], hi[0] - lo[0], hi[2] - lo[2]) + 2.5
        ppu = min(60, 560 / span)
        views = [render(parts, yaw, ppu=ppu, center=center) for yaw in (25, 0, 90, 180)]
        sheet = Image.new("RGB", (520 * 4, 620), (255, 255, 255))
        for i, v in enumerate(views):
            sheet.paste(v, (520 * i, 0))
        _label(sheet, name + "   (3/4, front, side, back)")
        sheet.save(os.path.join(out_dir, f"{name}.png"))
    # lineup of the presets at a common scale
    names = [n for n in dumps if "_" not in n and not n.startswith("Fuzz")]
    if names:
        tiles = []
        tallest = max(_bounds(dumps[n])[1][1] - _bounds(dumps[n])[0][1] for n in names) + 3
        ppu = min(38, 480 / tallest)
        for n in names:
            lo, hi = _bounds(dumps[n])
            ground = lo[1] - 0.6
            center = [(lo[0] + hi[0]) / 2, ground + 250 / ppu, (lo[2] + hi[2]) / 2]
            tiles.append(_label(render(dumps[n], 25, ppu=ppu, size=(360, 520), center=center), n))
        lineup = Image.new("RGB", (360 * len(tiles), 520), (255, 255, 255))
        for i, t in enumerate(tiles):
            lineup.paste(t, (360 * i, 0))
        lineup.save(os.path.join(out_dir, "_lineup.png"))
    forms = [n for n in dumps if n.endswith("_Partial")]
    for partial in forms:
        base = partial[: -len("_Partial")]
        seq = [base, partial, base + "_Full"]
        seq = [s for s in seq if s in dumps]
        tiles = []
        spans = [_bounds(dumps[n]) for n in seq]
        tallest = max(max(hi[1] - lo[1], (hi[0] - lo[0]) * 0.75) for lo, hi in spans) + 3
        ppu = min(40, 520 / tallest)
        for n, (lo, hi) in zip(seq, spans):
            center = [(lo[0] + hi[0]) / 2, lo[1] - 0.6 + 280 / ppu, (lo[2] + hi[2]) / 2]
            tiles.append(_label(render(dumps[n], 25, ppu=ppu, size=(420, 560), center=center), n))
        strip = Image.new("RGB", (420 * len(tiles), 560), (255, 255, 255))
        for i, t in enumerate(tiles):
            strip.paste(t, (420 * i, 0))
        strip.save(os.path.join(out_dir, f"_forms_{base}.png"))
