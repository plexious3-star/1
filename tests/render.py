"""Render the MeshParts the framework placed (dumped by the mock) with the real library meshes.

Each dumped part names its library piece (MeshName); its OBJ geometry is scaled to the
part's Size and transformed by its solved world CFrame — i.e. exactly what Roblox would
show once the library is imported.
"""
import glob
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
from sculpt import raster  # noqa: E402

_LIB = None


def library():
    """name → (verts, normals, faces, extent, uv, texture) from the baked library OBJs."""
    global _LIB
    if _LIB is None:
        _LIB = {}
        sys.path.insert(0, os.path.join(ROOT, "tools"))
        from sculpt.library import read_objects
        lib_dir = os.path.join(ROOT, "assets", "meshes", "library")
        textures = {}
        for path in glob.glob(os.path.join(lib_dir, "*.obj")):
            for o in read_objects(path):
                tex = None
                if o.get("tex"):
                    if o["tex"] not in textures:
                        textures[o["tex"]] = np.asarray(Image.open(os.path.join(lib_dir, "textures", o["tex"])).convert("RGBA"), float) / 255
                    tex = textures[o["tex"]]
                V = o["v"]
                _LIB[o["name"]] = (V, o["n"], o["f"], V.max(0) - V.min(0), o["uv"] if len(o["uv"]) else None, tex)
    return _LIB


def to_pieces(parts):
    lib = library()
    out = []
    for p in parts:
        if p["s"] != "Mesh" or p.get("mesh") not in lib:
            continue
        V, N, F, ext, uv, tex = lib[p["mesh"]]
        x, y, z, *r = p["cf"]
        R = np.array(r, float).reshape(3, 3)
        k = np.array(p["sz"]) / np.maximum(ext, 1e-6)
        verts = (V * k) @ R.T + np.array([x, y, z])
        normals = (N / np.maximum(k, 1e-6)) @ R.T
        normals /= np.maximum(np.linalg.norm(normals, axis=1, keepdims=True), 1e-9)
        out.append(dict(verts=verts, faces=F, normals=normals, color=p["c"], neon=p["m"] == "Neon",
                        gloss=0.3, uv=uv, tex=tex))
    return out


def bounds(pieces):
    allv = np.concatenate([pc["verts"] for pc in pieces])
    return allv.min(0), allv.max(0)


def label(img, text):
    ImageDraw.Draw(img).text((8, 6), text, fill=(20, 20, 20))
    return img


def render_all(dumps, out_dir):
    os.makedirs(out_dir, exist_ok=True)
    pieces_by = {n: to_pieces(parts) for n, parts in dumps.items()}
    pieces_by = {n: p for n, p in pieces_by.items() if p}
    for name, pieces in pieces_by.items():
        lo, hi = bounds(pieces)
        span = max(hi[1] - lo[1], hi[0] - lo[0], hi[2] - lo[2]) + 0.8
        ppu = 600 / span
        center = (lo + hi) / 2
        views = [raster.render(pieces, yaw, size=(480, 680), center=center, ppu=ppu) for yaw in (28, 0, 90, 180)]
        sheet = Image.new("RGB", (480 * 4, 680), (255, 255, 255))
        for i, v in enumerate(views):
            sheet.paste(v, (480 * i, 0))
        label(sheet, name + "   (3/4, front, side, back)")
        sheet.save(os.path.join(out_dir, f"{name}.png"))
    bases = [n for n in pieces_by if "_" not in n and not n.startswith("Fuzz")]
    if bases:
        tallest = max(max(hi[1] - lo[1], (hi[0] - lo[0]) * 1.45, (hi[2] - lo[2]) * 1.2) for lo, hi in (bounds(pieces_by[n]) for n in bases)) + 1.2
        ppu = 560 / tallest
        tiles = []
        for n in bases:
            lo, hi = bounds(pieces_by[n])
            center = ((lo[0] + hi[0]) / 2, lo[1] - 0.4 + 300 / ppu, (lo[2] + hi[2]) / 2)
            tiles.append(label(raster.render(pieces_by[n], 28, size=(380, 600), center=center, ppu=ppu), n))
        lineup = Image.new("RGB", (380 * len(tiles), 600), (255, 255, 255))
        for i, t in enumerate(tiles):
            lineup.paste(t, (380 * i, 0))
        lineup.save(os.path.join(out_dir, "_lineup.png"))
    for base in bases:
        seq = [s for s in (base, base + "_Partial", base + "_Full") if s in pieces_by]
        if len(seq) < 2:
            continue
        spans = [bounds(pieces_by[n]) for n in seq]
        tallest = max(max(hi[1] - lo[1], (hi[0] - lo[0]) * 1.25, (hi[2] - lo[2]) * 1.1) for lo, hi in spans) + 1.2
        ppu = 560 / tallest
        tiles = []
        for n, (lo, hi) in zip(seq, spans):
            center = ((lo[0] + hi[0]) / 2, lo[1] - 0.4 + 300 / ppu, (lo[2] + hi[2]) / 2)
            tiles.append(label(raster.render(pieces_by[n], 28, size=(460, 600), center=center, ppu=ppu), n))
        strip = Image.new("RGB", (460 * len(tiles), 600), (255, 255, 255))
        for i, t in enumerate(tiles):
            strip.paste(t, (460 * i, 0))
        strip.save(os.path.join(out_dir, f"_forms_{base}.png"))
