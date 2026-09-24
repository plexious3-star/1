"""Texture baking: UV unwrap + procedural hand-drawn detail overlays.

Textures are OVERLAYS: black (ink, shadow, hatching, veins) and white (gloss flecks)
with alpha. On a Roblox MeshPart the part's own Color shows through transparent
texels, so the palette still decides the hue: one texture set works for every
palette (crimson, pale, bruise …).

Every texel is traced back to its 3D point on the sculpt, so the detail follows the
anatomy: creases darken (SDF ambient occlusion), shadowed areas get hatched like the
reference's ink work, exposed bulges get gloss dashes, material borders get ink lines.
"""
import math

import numpy as np
import xatlas
from PIL import Image

from sculpt.sdf import fbm

LIGHT = np.array([-0.4, 0.8, -0.45]) / np.linalg.norm([-0.4, 0.8, -0.45])


def _n(v):
    v = np.asarray(v, float)
    return v / np.linalg.norm(v)


HATCH_A = _n((1.0, 0.35, 0.2))
HATCH_B = _n((-0.3, 1.0, 0.45))
GLOSS = _n((0.25, 1.0, -0.2))
STRIATE = _n((0.9, 0.15, 0.4))

SKIN = {"Skin", "SkinLight", "SkinDark", "SkinDeep", "skin"}
FLESH = {"Flesh", "FleshDark", "flesh"}
BONE = {"Bone", "BoneDark"}
HARD = {"Claw", "Teeth", "dark"}
UNTEXTURED = {"Eye", "Pupil", "Glow", "Spot", "eye", "VoidRim"}


def texture_size(verts, faces, density=210.0):
    a = verts[faces[:, 1]] - verts[faces[:, 0]]
    b = verts[faces[:, 2]] - verts[faces[:, 0]]
    area = 0.5 * np.linalg.norm(np.cross(a, b), axis=1).sum()
    side = math.sqrt(max(area, 1e-6)) * density
    return int(np.clip(2 ** round(math.log2(max(side, 1))), 128, 1024))


def unwrap(verts, faces, res):
    atlas = xatlas.Atlas()
    atlas.add_mesh(verts.astype(np.float32), faces.astype(np.uint32))
    pack = xatlas.PackOptions()
    pack.resolution = res
    pack.padding = 4
    pack.bilinear = True
    pack.bruteForce = False
    chart = xatlas.ChartOptions()
    atlas.generate(chart_options=chart, pack_options=pack)
    vmap, indices, uvs = atlas[0]
    return vmap.astype(int), indices.astype(int), uvs


def _rasterize_uv(indices, uvs, res):
    """All texels covered by the UV triangles → (px, py, tri, l0, l1, l2)."""
    P = uvs * res
    out = [[], [], [], [], [], []]
    for t, (a, b, c) in enumerate(indices):
        ax, ay = P[a]
        bx, by = P[b]
        cx, cy = P[c]
        x0, x1 = int(math.floor(min(ax, bx, cx))), int(math.ceil(max(ax, bx, cx)))
        y0, y1 = int(math.floor(min(ay, by, cy))), int(math.ceil(max(ay, by, cy)))
        x0, y0, x1, y1 = max(x0, 0), max(y0, 0), min(x1, res - 1), min(y1, res - 1)
        if x1 < x0 or y1 < y0:
            continue
        gx, gy = np.meshgrid(np.arange(x0, x1 + 1) + 0.5, np.arange(y0, y1 + 1) + 0.5)
        den = (by - cy) * (ax - cx) + (cx - bx) * (ay - cy)
        if abs(den) < 1e-12:
            continue
        l0 = ((by - cy) * (gx - cx) + (cx - bx) * (gy - cy)) / den
        l1 = ((cy - ay) * (gx - cx) + (ax - cx) * (gy - cy)) / den
        l2 = 1 - l0 - l1
        m = (l0 >= -0.02) & (l1 >= -0.02) & (l2 >= -0.02)
        if not m.any():
            continue
        out[0].append(gx[m].astype(int))
        out[1].append(gy[m].astype(int))
        out[2].append(np.full(m.sum(), t))
        out[3].append(l0[m])
        out[4].append(l1[m])
        out[5].append(l2[m])
    return [np.concatenate(o) for o in out]


def _lines(p, direction, freq, width, warp=0.35, wfreq=3.0):
    s = p @ direction * freq + warp * fbm(p * wfreq)
    f = s - np.floor(s)
    return np.clip(1 - np.abs(f - 0.5) * 2 / max(width, 1e-4), 0, 1) ** 2


def _ambient_occlusion(sdf, p, n):
    """SDF occlusion measured relative to the surface point itself (no bias from mesh smoothing)."""
    d0 = sdf(p)
    occ = np.zeros(len(p))
    for i, h in enumerate((0.05, 0.11, 0.2)):
        d = sdf(p + n * h)
        occ += np.clip(h + d0 - d, 0, None) / h * (0.55 ** i)
    return np.clip(occ * 0.9, 0, 1)


def _strokes(p, direction, freq, width, density):
    """Sketchy ink strokes: parallel lines broken into short dashes, denser where `density` is high."""
    lines = _lines(p, direction, freq, width, warp=0.55, wfreq=2.5)
    breakup = fbm(p * 9.0 + direction * 3.0)
    return lines * (breakup < (density * 1.6 - 0.6))


def shade(role, p, n, border, sdf, seed=0, matfn=None):
    """Overlay RGBA (0..1) for texels at points p with normals n."""
    p = p + seed * 13.1
    occ = _ambient_occlusion(sdf, p - seed * 13.1, n) if sdf is not None else np.zeros(len(p))
    down = np.clip(-n[:, 1], 0, 1)
    lit = np.clip(n @ LIGHT, 0, 1)
    D = np.clip(occ * 1.2 + down * 0.3 + (1 - lit) * 0.15 + 0.12 * fbm(p * 2.2), 0, 1)
    dark = np.zeros(len(p))
    light = np.zeros(len(p))

    def add_dark(a):
        nonlocal dark
        dark = 1 - (1 - dark) * (1 - np.clip(a, 0, 1))

    def add_light(a):
        nonlocal light
        light = 1 - (1 - light) * (1 - np.clip(a, 0, 1))

    if role in SKIN:
        add_dark(0.28 * np.clip(D - 0.15, 0, 1))
        add_dark(0.75 * _strokes(p, HATCH_A, 12, 0.16, np.clip((D - 0.25) / 0.4, 0, 1)))
        add_dark(0.65 * _strokes(p, HATCH_B, 13, 0.14, np.clip((D - 0.65) / 0.3, 0, 1)))
        add_dark(0.1 * np.clip((fbm(p * 6) - 0.3) / 0.2, 0, 1))                # mottling
        ridge = 1 - np.abs(fbm(p * 3.2 + 5))
        add_dark(0.22 * np.clip((ridge - 0.945) / 0.035, 0, 1))                # veins
        add_dark(0.25 * (fbm(p * 40) > 0.7))                                    # pores
        exposed = (1 - occ) * np.clip(n @ LIGHT + 0.2, 0, 1)
        dash = _lines(p, GLOSS, 5, 0.15, warp=0.8, wfreq=2.0) * (fbm(p * 3.5 + 2) > 0.15)
        add_light(0.85 * dash * np.clip((exposed - 0.45) / 0.25, 0, 1))
    elif role in FLESH:
        add_dark(0.22 * np.clip(D - 0.1, 0, 1))
        add_dark(0.45 * _strokes(p, STRIATE, 20, 0.12, 0.55 + 0.45 * D))     # striated tissue
        add_dark(0.5 * _strokes(p, HATCH_A, 12, 0.14, np.clip((D - 0.5) / 0.35, 0, 1)))
        add_light(0.6 * _lines(p, GLOSS, 8, 0.1, warp=0.8) * (fbm(p * 4) > 0.3) * np.clip((1 - occ) * lit - 0.3, 0, 1) * 2)
    elif role in BONE:
        add_dark(0.4 * D)
        add_dark(0.16 * _lines(p, (0, 1, 0), 28, 0.25, warp=0.8, wfreq=4))  # grain
        crack = 1 - np.abs(fbm(p * 5.5 + 3))
        add_dark(0.55 * np.clip((crack - 0.93) / 0.05, 0, 1))
    elif role in HARD:
        add_dark(0.35 * D)
        add_light(0.7 * _lines(p, GLOSS, 9, 0.1, warp=0.3) * lit * (1 - occ))
    elif role == "Void":
        add_light(0.35 * (fbm(p * 9) > 0.55) * np.clip(n[:, 1], 0, 1))
    elif role == "Membrane":
        add_dark(0.3 * D)
        vein = 1 - np.abs(fbm(p * 2.5 + 7))
        add_dark(0.5 * np.clip((vein - 0.9) / 0.06, 0, 1))
    add_dark(0.9 * _border_ink(p, n, border, role, matfn))                     # ink along tissue borders
    alpha = np.clip(dark + light * (1 - dark), 0, 1)
    gray = np.where(alpha > 1e-4, light * (1 - dark) / np.maximum(alpha, 1e-4), 0)
    return gray, alpha


def _border_ink(p, n, border, role, matfn, r=0.03):
    """Ink where the sculpt's true material boundary passes (smooth, not the triangle staircase)."""
    if matfn is None:
        return np.clip((border - 0.62) / 0.2, 0, 1)
    ink = np.zeros(len(p))
    near = np.nonzero(border > 0.01)[0]
    if len(near) == 0:
        return ink
    q, qn = p[near], n[near]
    up = np.where(np.abs(qn[:, 1:2]) < 0.9, np.array([[0, 1, 0]]), np.array([[1, 0, 0]]))
    t1 = np.cross(qn, up)
    t1 /= np.maximum(np.linalg.norm(t1, axis=1, keepdims=True), 1e-9)
    t2 = np.cross(qn, t1)
    m0 = matfn(q)
    hit = m0 != role
    for off in (t1 * r, -t1 * r, t2 * r, -t2 * r):
        hit |= matfn(q + off) != m0
    ink[near] = hit
    return ink


def _dilate(rgba, filled, iters=6):
    img = rgba.copy()
    mask = filled.copy()
    for _ in range(iters):
        acc = np.zeros_like(img)
        cnt = np.zeros(mask.shape)
        for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0)):
            m = np.roll(np.roll(mask, dy, 0), dx, 1)
            acc += np.roll(np.roll(img, dy, 0), dx, 1) * m[..., None]
            cnt += m
        grow = (~mask) & (cnt > 0)
        img[grow] = acc[grow] / cnt[grow][:, None]
        mask = mask | grow
    return img


def bake_piece(verts, normals, faces, border, role, sdf, seed=0, matfn=None):
    """→ (vmap, indices, uvs, image or None). Untextured roles still get UVs."""
    res = texture_size(verts, faces)
    used = np.unique(faces)
    remap = -np.ones(len(verts), dtype=int)
    remap[used] = np.arange(len(used))
    lv, ln, lf, lb = verts[used], normals[used], remap[faces], border[used]
    vmap, indices, uvs = unwrap(lv, lf, res)
    if role in UNTEXTURED:
        return used[vmap], indices, uvs, None
    px, py, tri, l0, l1, l2 = _rasterize_uv(indices, uvs, res)
    corners = vmap[indices[tri]]
    w = np.stack([l0, l1, l2], 1)[..., None]
    p = (lv[corners] * w).sum(1)
    n = (ln[corners] * w).sum(1)
    n /= np.maximum(np.linalg.norm(n, axis=1, keepdims=True), 1e-9)
    b = (lb[corners] * w[..., 0]).sum(1)
    gray, alpha = shade(role, p, n, b, sdf, seed, matfn)
    rgba = np.zeros((res, res, 4))
    rgba[py, px, 0:3] = gray[:, None]
    rgba[py, px, 3] = alpha
    filled = np.zeros((res, res), bool)
    filled[py, px] = True
    rgba = _dilate(rgba, filled)
    img = Image.fromarray((np.clip(rgba, 0, 1) * 255).astype(np.uint8), "RGBA").transpose(Image.FLIP_TOP_BOTTOM)
    return used[vmap], indices, uvs, img


def border_flags(faces, face_mat, n_verts):
    """1.0 on vertices shared by faces of different materials (where the ink line goes)."""
    names = {m: i for i, m in enumerate(sorted(set(face_mat)))}
    ids = np.array([names[m] for m in face_mat])
    lo = np.full(n_verts, 10 ** 6)
    hi = np.full(n_verts, -1)
    for k in range(3):
        np.minimum.at(lo, faces[:, k], ids)
        np.maximum.at(hi, faces[:, k], ids)
    return ((hi >= 0) & (lo != hi)).astype(float)
