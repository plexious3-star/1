"""Signed-distance sculpting → organic meshes for Roblox MeshParts.

A Sculpt is an ordered list of operations evaluated over a voxel grid:

    add(prim, mat, k)     smooth union (k = blend radius): flesh, muscle, bone, tissue
    sub(prim, mat, k)     smooth subtraction: cavities, sockets, creases; the carved
                          surface takes `mat` (e.g. the black void inside the chest)
    paint(prim, mat)      material only (no geometry): exposed tissue regions
    noise(amp, freq)      organic surface irregularity

Each primitive belongs to a BONE (the R6 part it rides on). Every bone is meshed
separately (closed surfaces that overlap at the joints, so nothing opens up when the
rig animates), then split by material into pieces that share exact vertices.

Pipeline per bone: evaluate SDF on a grid → marching cubes → Taubin smoothing →
quadric decimation → smooth normals → material per face → OBJ per (bone, material).
"""
import math

import numpy as np
import fast_simplification
from scipy import sparse
from skimage import measure


# ---------------------------------------------------------------------------- math
def rot_matrix(rx=0.0, ry=0.0, rz=0.0):
    a, b, c = (math.radians(v) for v in (rx, ry, rz))
    X = np.array([[1, 0, 0], [0, math.cos(a), -math.sin(a)], [0, math.sin(a), math.cos(a)]])
    Y = np.array([[math.cos(b), 0, math.sin(b)], [0, 1, 0], [-math.sin(b), 0, math.cos(b)]])
    Z = np.array([[math.cos(c), -math.sin(c), 0], [math.sin(c), math.cos(c), 0], [0, 0, 1]])
    return X @ Y @ Z


def smin(a, b, k):
    if k <= 0:
        return np.minimum(a, b)
    h = np.maximum(k - np.abs(a - b), 0.0) / k
    return np.minimum(a, b) - h * h * k * 0.25


def smax(a, b, k):
    return -smin(-a, -b, k)


# ---------------------------------------------------------------------------- noise
_PERM = np.random.RandomState(1337).permutation(256)
_PERM = np.concatenate([_PERM, _PERM])
_GRAD = np.random.RandomState(7).uniform(-1, 1, 256)


def value_noise(p):
    """Smooth 3D value noise in [-1, 1]."""
    pi = np.floor(p).astype(np.int64)
    pf = p - pi
    u = pf * pf * (3 - 2 * pf)
    xi, yi, zi = pi[:, 0] & 255, pi[:, 1] & 255, pi[:, 2] & 255

    def h(dx, dy, dz):
        return _GRAD[_PERM[_PERM[(xi + dx) & 255] + ((yi + dy) & 255)] + ((zi + dz) & 255) & 255]

    x00 = h(0, 0, 0) + (h(1, 0, 0) - h(0, 0, 0)) * u[:, 0]
    x10 = h(0, 1, 0) + (h(1, 1, 0) - h(0, 1, 0)) * u[:, 0]
    x01 = h(0, 0, 1) + (h(1, 0, 1) - h(0, 0, 1)) * u[:, 0]
    x11 = h(0, 1, 1) + (h(1, 1, 1) - h(0, 1, 1)) * u[:, 0]
    y0 = x00 + (x10 - x00) * u[:, 1]
    y1 = x01 + (x11 - x01) * u[:, 1]
    return y0 + (y1 - y0) * u[:, 2]


def fbm(p, octaves=3):
    total, amp, freq = 0.0, 1.0, 1.0
    for _ in range(octaves):
        total = total + amp * value_noise(p * freq)
        amp *= 0.5
        freq *= 2.03
    return total / 1.75


# ---------------------------------------------------------------------------- primitives
class Prim:
    """A distance function plus a conservative bounding box."""

    def __init__(self, fn, lo, hi):
        self.fn, self.lo, self.hi = fn, np.asarray(lo, float), np.asarray(hi, float)

    def __call__(self, p):
        return self.fn(p)


def ellipsoid(c, r, rot=(0, 0, 0)):
    c, r = np.asarray(c, float), np.asarray(r, float)
    R = rot_matrix(*rot)

    def fn(p):
        q = (p - c) @ R
        k0 = np.linalg.norm(q / r, axis=1)
        k1 = np.linalg.norm(q / (r * r), axis=1)
        return k0 * (k0 - 1.0) / np.maximum(k1, 1e-9)

    m = r.max()
    return Prim(fn, c - m, c + m)


def sphere(c, r):
    c = np.asarray(c, float)
    return Prim(lambda p: np.linalg.norm(p - c, axis=1) - r, c - r, c + r)


def round_cone(a, b, ra, rb):
    """Capsule from a (radius ra) to b (radius rb) — the anatomical taper."""
    a, b = np.asarray(a, float), np.asarray(b, float)
    ba = b - a
    l2 = ba @ ba
    rr = ra - rb
    a2 = l2 - rr * rr
    il2 = 1.0 / l2

    def fn(p):
        pa = p - a
        y = pa @ ba
        z = y - l2
        w = pa * l2 - np.outer(y, ba)
        x2 = np.einsum("ij,ij->i", w, w)
        y2 = y * y * l2
        z2 = z * z * l2
        k = np.sign(rr) * rr * rr * x2
        d_end = np.sqrt(x2 + z2) * il2 - rb
        d_start = np.sqrt(x2 + y2) * il2 - ra
        d_mid = (np.sqrt(np.maximum(x2 * a2 * il2, 0)) + y * rr) * il2 - ra
        return np.where(np.sign(z) * a2 * z2 > k, d_end, np.where(np.sign(y) * a2 * y2 < k, d_start, d_mid))

    m = max(ra, rb)
    return Prim(fn, np.minimum(a, b) - m, np.maximum(a, b) + m)


def squashed(prim, center, scale, rot=(0, 0, 0)):
    """Non-uniformly scale a primitive around `center` (flattened limbs, fingers …)."""
    center, scale = np.asarray(center, float), np.asarray(scale, float)
    R = rot_matrix(*rot)

    def fn(p):
        q = ((p - center) @ R) / scale
        return prim(q @ R.T + center) * scale.min()

    ext = np.maximum(np.abs(prim.lo - center), np.abs(prim.hi - center)).max() * scale.max()
    return Prim(fn, center - ext, center + ext)


def tube(points, radii, k=0.05):
    """Smooth chain of round cones through points (horns, fingers, tails, tendrils)."""
    cones = [round_cone(points[i], points[i + 1], radii[i], radii[i + 1]) for i in range(len(points) - 1)]

    def fn(p):
        d = cones[0](p)
        for c in cones[1:]:
            d = smin(d, c(p), k)
        return d

    lo = np.min([c.lo for c in cones], axis=0)
    hi = np.max([c.hi for c in cones], axis=0)
    return Prim(fn, lo, hi)


def torus(c, R_major, r_minor, rot=(0, 0, 0)):
    c = np.asarray(c, float)
    R = rot_matrix(*rot)

    def fn(p):
        q = (p - c) @ R
        xz = np.sqrt(q[:, 0] ** 2 + q[:, 2] ** 2) - R_major
        return np.sqrt(xz * xz + q[:, 1] ** 2) - r_minor

    m = R_major + r_minor
    return Prim(fn, c - m, c + m)


def bezier_points(p0, p1, p2, n=8):
    """Points along a quadratic Bézier (for curved horns, tails, tendrils)."""
    p0, p1, p2 = (np.asarray(v, float) for v in (p0, p1, p2))
    t = np.linspace(0, 1, n)[:, None]
    return (1 - t) ** 2 * p0 + 2 * (1 - t) * t * p1 + t * t * p2


# ---------------------------------------------------------------------------- sculpt
class Sculpt:
    def __init__(self, name):
        self.name = name
        self.ops = {}  # bone -> list of ops
        self.shift = {}  # bone -> translation applied to everything sculpted for it

    def _op(self, bone, kind, prim, mat=None, k=0.0, **extra):
        self.ops.setdefault(bone, []).append(dict(kind=kind, prim=prim, mat=mat, k=k, **extra))

    def add(self, bone, prim, mat, k=0.12):
        self._op(bone, "add", prim, mat, k)

    def sub(self, bone, prim, mat=None, k=0.05):
        self._op(bone, "sub", prim, mat, k)

    def paint(self, bone, prim, mat, soft=0.0):
        self._op(bone, "paint", prim, mat, soft=soft)

    def noise(self, bone, amp=0.02, freq=3.0):
        self._op(bone, "noise", None, amp=amp, freq=freq)

    def bounds(self, bone):
        lo = np.full(3, np.inf)
        hi = np.full(3, -np.inf)
        for op in self.ops[bone]:
            if op["kind"] == "add":
                lo = np.minimum(lo, op["prim"].lo)
                hi = np.maximum(hi, op["prim"].hi)
        off = np.asarray(self.shift.get(bone, (0, 0, 0)), float)
        return lo + off, hi + off

    def evaluate(self, bone, p):
        p = p - np.asarray(self.shift.get(bone, (0, 0, 0)), float)
        d = np.full(len(p), np.inf)
        mat = np.full(len(p), "", dtype=object)
        for op in self.ops[bone]:
            kind = op["kind"]
            if kind == "noise":
                d = d + op["amp"] * fbm(p * op["freq"])
                continue
            di = op["prim"](p)
            if kind == "add":
                closer = di < d
                mat = np.where(closer, op["mat"], mat)
                d = smin(d, di, op["k"])
            elif kind == "sub":
                carved = -di > d
                if op["mat"] is not None:
                    mat = np.where(carved, op["mat"], mat)
                d = smax(d, -di, op["k"])
            elif kind == "paint":
                if op["soft"] > 0:  # ragged, organic border
                    di = di + op["soft"] * fbm(p * 6.0)
                mat = np.where(di < 0, op["mat"], mat)
        return d, mat


# ---------------------------------------------------------------------------- meshing
def _taubin(verts, faces, iters=12, lam=0.5, mu=-0.53):
    n = len(verts)
    i = np.concatenate([faces[:, 0], faces[:, 1], faces[:, 2], faces[:, 1], faces[:, 2], faces[:, 0]])
    j = np.concatenate([faces[:, 1], faces[:, 2], faces[:, 0], faces[:, 0], faces[:, 1], faces[:, 2]])
    A = sparse.coo_matrix((np.ones(len(i)), (i, j)), shape=(n, n)).tocsr()
    A.data[:] = 1.0
    deg = np.asarray(A.sum(1)).ravel()
    deg[deg == 0] = 1
    Dinv = sparse.diags(1.0 / deg)
    L = Dinv @ A
    v = verts.copy()
    for _ in range(iters):
        v = v + lam * (L @ v - v)
        v = v + mu * (L @ v - v)
    return v


def vertex_normals(verts, faces):
    fn = np.cross(verts[faces[:, 1]] - verts[faces[:, 0]], verts[faces[:, 2]] - verts[faces[:, 0]])
    n = np.zeros_like(verts)
    for k in range(3):
        np.add.at(n, faces[:, k], fn)
    return n / np.maximum(np.linalg.norm(n, axis=1, keepdims=True), 1e-12)


def mesh_bone(sculpt, bone, voxel=0.03, max_tris=9000, smooth_iters=10):
    lo, hi = sculpt.bounds(bone)
    lo, hi = lo - 0.15, hi + 0.15
    shape = np.ceil((hi - lo) / voxel).astype(int) + 1
    xs = [lo[i] + np.arange(shape[i]) * voxel for i in range(3)]
    grid = np.stack(np.meshgrid(*xs, indexing="ij"), -1).reshape(-1, 3)
    d = np.empty(len(grid))
    chunk = 400_000
    for s in range(0, len(grid), chunk):
        d[s:s + chunk], _ = sculpt.evaluate(bone, grid[s:s + chunk])
    vol = d.reshape(shape)
    verts, faces, _, _ = measure.marching_cubes(vol, level=0.0, spacing=(voxel,) * 3)
    verts = verts + lo
    # skimage's winding already faces out of the solid (toward positive distance): keep it
    verts = _taubin(verts, faces, iters=smooth_iters)
    if len(faces) > max_tris:
        verts, faces = fast_simplification.simplify(verts.astype(np.float32), faces.astype(np.int32),
                                                    target_reduction=1 - max_tris / len(faces), agg=5)
        verts = verts.astype(float)
    _, mats = sculpt.evaluate(bone, verts)
    # face material = majority of its vertices (first vertex breaks ties)
    fm = mats[faces]
    face_mat = np.where(fm[:, 1] == fm[:, 2], fm[:, 1], fm[:, 0])
    face_mat = smooth_labels(faces, face_mat)
    return verts, faces, vertex_normals(verts, faces), face_mat


def smooth_labels(faces, labels, iters=3):
    """Majority filter over edge-adjacent faces: clean material borders, no speckle islands."""
    edges = {}
    for fi, (a, b, c) in enumerate(faces):
        for e in ((a, b), (b, c), (c, a)):
            edges.setdefault((min(e), max(e)), []).append(fi)
    nbrs = [[] for _ in range(len(faces))]
    for fs in edges.values():
        if len(fs) == 2:
            nbrs[fs[0]].append(fs[1])
            nbrs[fs[1]].append(fs[0])
    labels = labels.copy()
    for _ in range(iters):
        new = labels.copy()
        for fi, ns in enumerate(nbrs):
            if len(ns) == 3:
                a, b, c = labels[ns[0]], labels[ns[1]], labels[ns[2]]
                if a == b or a == c:
                    maj = a
                elif b == c:
                    maj = b
                else:
                    continue
                if maj != labels[fi] and (labels[fi] not in (a, b, c) or maj in (a, b) and maj in (b, c)):
                    new[fi] = maj
        labels = new
    return labels


# ---------------------------------------------------------------------------- export
def write_obj(path, name, verts, normals, faces, offset):
    """Write one piece, vertices relative to `offset` (the piece's pivot)."""
    used = np.unique(faces)
    remap = -np.ones(len(verts), dtype=int)
    remap[used] = np.arange(len(used))
    v = verts[used] - offset
    n = normals[used]
    f = remap[faces] + 1
    with open(path, "w") as fh:
        fh.write(f"# {name}\no {name}\n")
        fh.write("".join(f"v {a:.4f} {b:.4f} {c:.4f}\n" for a, b, c in v))
        fh.write("".join(f"vn {a:.4f} {b:.4f} {c:.4f}\n" for a, b, c in n))
        fh.write("".join(f"f {a}//{a} {b}//{b} {c}//{c}\n" for a, b, c in f))
    return v
