"""Tiny z-buffer triangle rasterizer for inspecting sculpted meshes (smooth shading + ink lines).

pieces: list of dicts { verts (N,3) world, faces (M,3), normals (N,3), color (r,g,b 0..1), neon bool }
"""
import math

import numpy as np
from PIL import Image

BG = np.array([0.93, 0.93, 0.95])


def camera(yaw, pitch):
    y, p = math.radians(yaw), math.radians(pitch)
    d = np.array([math.sin(y) * math.cos(p), math.sin(p), math.cos(y) * math.cos(p)])
    right = np.cross(d, [0, 1, 0])
    right /= np.linalg.norm(right)
    up = np.cross(right, d)
    return d, right, up


def render(pieces, yaw=0.0, pitch=-6.0, size=(560, 680), center=(0, 2.4, 0), ppu=110.0, flat=False, silhouette=False):
    w, h = size
    d, right, up = camera(yaw, pitch)
    center = np.asarray(center, float)
    zbuf = np.full((h, w), np.inf)
    img = np.tile(BG, (h, w, 1))
    light = np.array([-0.5, 0.8, -0.45])
    light /= np.linalg.norm(light)
    fill = np.array([0.6, 0.1, 0.8])
    fill /= np.linalg.norm(fill)
    for piece in pieces:
        V, F, N = piece["verts"], piece["faces"], piece["normals"]
        rel = V - center
        sx = rel @ right * ppu + w / 2
        sy = h / 2 - rel @ up * ppu
        sz = rel @ d
        base = np.asarray(piece["color"], float)
        if silhouette:
            shade_v = np.zeros(len(V))
            col_v = np.tile([0.18, 0.18, 0.2], (len(V), 1))
        elif piece.get("neon"):
            col_v = np.tile(np.clip(base * 1.1, 0, 1), (len(V), 1))
        else:
            lam = np.clip(N @ light, 0, 1)
            lam2 = np.clip(N @ fill, 0, 1)
            rim = np.clip(1 - np.abs(N @ -d), 0, 1) ** 2.5
            spec = np.clip(N @ ((light - d) / np.linalg.norm(light - d)), 0, 1) ** 24 * piece.get("gloss", 0.25)
            shade = 0.46 + 0.6 * lam + 0.14 * lam2 - 0.16 * rim
            col_v = np.clip(base * shade[:, None] + spec[:, None], 0, 1)
            if flat:
                col_v = np.tile(np.clip(base, 0, 1), (len(V), 1))
        tex = None if silhouette or piece.get("neon") else piece.get("tex")
        if tex is not None:
            UV = piece["uv"]
            TH, TW = tex.shape[:2]
            shade_v = np.ones(len(V)) if flat else shade
            spec_v = np.zeros(len(V)) if flat else spec
        tx, ty, tz = sx[F], sy[F], sz[F]
        x0 = np.clip(np.floor(tx.min(1)).astype(int), 0, w - 1)
        x1 = np.clip(np.ceil(tx.max(1)).astype(int), 0, w - 1)
        y0 = np.clip(np.floor(ty.min(1)).astype(int), 0, h - 1)
        y1 = np.clip(np.ceil(ty.max(1)).astype(int), 0, h - 1)
        for i in range(len(F)):
            if x1[i] < x0[i] or y1[i] < y0[i]:
                continue
            xs = np.arange(x0[i], x1[i] + 1) + 0.5
            ys = np.arange(y0[i], y1[i] + 1) + 0.5
            gx, gy = np.meshgrid(xs, ys)
            ax, ay, bx, by, cx, cy = tx[i, 0], ty[i, 0], tx[i, 1], ty[i, 1], tx[i, 2], ty[i, 2]
            den = (by - cy) * (ax - cx) + (cx - bx) * (ay - cy)
            if abs(den) < 1e-9:
                continue
            l0 = ((by - cy) * (gx - cx) + (cx - bx) * (gy - cy)) / den
            l1 = ((cy - ay) * (gx - cx) + (ax - cx) * (gy - cy)) / den
            l2 = 1 - l0 - l1
            inside = (l0 >= -1e-4) & (l1 >= -1e-4) & (l2 >= -1e-4)
            if not inside.any():
                continue
            z = l0 * tz[i, 0] + l1 * tz[i, 1] + l2 * tz[i, 2]
            sub = zbuf[y0[i]:y1[i] + 1, x0[i]:x1[i] + 1]
            m = inside & (z < sub)
            if not m.any():
                continue
            sub[m] = z[m]
            if tex is not None:
                f = F[i]
                a0, a1, a2 = l0[m], l1[m], l2[m]
                u = a0 * UV[f[0], 0] + a1 * UV[f[1], 0] + a2 * UV[f[2], 0]
                v = a0 * UV[f[0], 1] + a1 * UV[f[1], 1] + a2 * UV[f[2], 1]
                tx_ = np.clip((u * TW).astype(int), 0, TW - 1)
                ty_ = np.clip(((1 - v) * TH).astype(int), 0, TH - 1)
                t = tex[ty_, tx_]
                alb = base[None, :] * (1 - t[:, 3:4]) + t[:, 0:3] * t[:, 3:4]
                sh = a0 * shade_v[f[0]] + a1 * shade_v[f[1]] + a2 * shade_v[f[2]]
                sp = a0 * spec_v[f[0]] + a1 * spec_v[f[1]] + a2 * spec_v[f[2]]
                img[y0[i]:y1[i] + 1, x0[i]:x1[i] + 1][m] = np.clip(alb * sh[:, None] + sp[:, None], 0, 1)
                continue
            c = col_v[F[i]]
            col = l0[..., None] * c[0] + l1[..., None] * c[1] + l2[..., None] * c[2]
            img[y0[i]:y1[i] + 1, x0[i]:x1[i] + 1][m] = col[m]
    # ink lines at depth discontinuities (the reference is line art)
    zb = np.where(np.isinf(zbuf), 1e3, zbuf)
    edge = np.zeros((h, w), bool)
    for dy, dx in ((0, 1), (1, 0), (1, 1)):
        edge |= np.abs(zb - np.roll(np.roll(zb, dy, 0), dx, 1)) > 0.12
    img[edge] *= 0.22
    return Image.fromarray((np.clip(img, 0, 1) * 255).astype(np.uint8))
