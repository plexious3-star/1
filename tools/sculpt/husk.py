"""CrimsonHusk — the reference creature, sculpted as organic meshes over an invisible R6 skeleton.

    python3 tools/sculpt/husk.py          # meshes → assets/meshes/CrimsonHusk/, previews → previews/mesh/

World space = the rig's rest pose at scale 1: feet on y=0, -Z is the creature's front,
+X its right. Every primitive belongs to one R6 bone; each bone is meshed on its own.
"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from sculpt.sdf import Sculpt, bezier_points, ellipsoid, rot_matrix, round_cone, sphere, tube  # noqa: E402

NAME = "CrimsonHusk"

MATERIALS = {
    #  name     RGB                Roblox material   neon
    "skin": ((168, 44, 50), "SmoothPlastic", False),
    "flesh": ((224, 204, 164), "SmoothPlastic", False),
    "void": ((10, 8, 8), "Slate", False),
    "eye": ((228, 226, 214), "Neon", True),
    "dark": ((22, 8, 10), "SmoothPlastic", False),
}

# Visible legs are LEG_EXTRA studs longer than the R6 leg: the assembler sets
# Humanoid.HipHeight = LEG_EXTRA (on R6 it is an offset added to the leg length).
LEG_EXTRA = 0.35

# R6 skeleton rest pose (bone centers, world). Joint C0/C1 follow from these.
BONES = {
    "HumanoidRootPart": (0, 3 + LEG_EXTRA, 0),
    "Torso": (0, 3 + LEG_EXTRA, 0),
    "Head": (0, 4.1 + LEG_EXTRA, -0.8),
    "Right Arm": (1.55, 3.05 + LEG_EXTRA, -0.2),
    "Left Arm": (-1.55, 3.05 + LEG_EXTRA, -0.2),
    "Right Leg": (0.48, 1.0 + LEG_EXTRA, 0.05),
    "Left Leg": (-0.48, 1.0 + LEG_EXTRA, 0.05),
    "Tail": (-0.2, 2.3 + LEG_EXTRA, 0.55),
}
# Motor6D layout (torso-local C0 position, C1 position, standard R6 rotation key)
JOINTS = [
    ("Neck", "Torso", "Head", (0, 0.6, -0.8), (0, -0.5, 0), "root"),
    ("Right Shoulder", "Torso", "Right Arm", (1.05, 0.55, -0.2), (-0.5, 0.5, 0), "right"),
    ("Left Shoulder", "Torso", "Left Arm", (-1.05, 0.55, -0.2), (0.5, 0.5, 0), "left"),
    ("Right Hip", "Torso", "Right Leg", (0.98, -1, 0.05), (0.5, 1, 0), "right"),
    ("Left Hip", "Torso", "Left Leg", (-0.98, -1, 0.05), (-0.5, 1, 0), "left"),
    ("TailJoint", "Torso", "Tail", (-0.2, -0.7, 0.55), (0, 0, 0), "none"),
]


def X(s, p):
    return (s * p[0], p[1], p[2])


def torso(S, T="Torso"):
    """Hunched torso: hump, neck wraps, layered front tissue, recessed chest void."""
    S.add(T, ellipsoid((0, 2.15, 0.1), (0.72, 0.45, 0.52)), "skin", 0.2)                   # pelvis
    S.add(T, ellipsoid((0, 2.6, 0.3), (0.62, 0.5, 0.38)), "skin", 0.25)                   # lower back
    S.add(T, ellipsoid((0, 2.6, -0.15), (0.6, 0.5, 0.45)), "skin", 0.25)                  # abdomen
    S.add(T, ellipsoid((0, 3.15, -0.12), (0.74, 0.7, 0.6), (-20, 0, 0)), "skin", 0.3)     # ribcage
    S.add(T, ellipsoid((0, 3.6, 0.25), (0.76, 0.72, 0.74), (-30, 0, 0)), "skin", 0.3)     # upper back hump
    S.add(T, ellipsoid((0.05, 3.98, 0.1), (0.62, 0.42, 0.56), (-35, 0, 4)), "skin", 0.25) # hump crest
    for s in (1, -1):
        S.add(T, ellipsoid(X(s, (0.42, 3.9, -0.4)), (0.44, 0.4, 0.5), (0, 0, s * 38)), "skin", 0.2)     # neck wrap (slopes into the shoulder)
        S.add(T, ellipsoid(X(s, (0.8, 3.42, -0.14)), (0.42, 0.48, 0.52), (0, 0, s * 24)), "skin", 0.22)  # shoulder
        S.add(T, ellipsoid(X(s, (0.6, 3.0, 0.15)), (0.32, 0.7, 0.48), (0, 0, s * 10)), "skin", 0.2)      # lats
    # layered tissue on the front: pecs, ribs, belly bands (raised 3D geometry)
    S.add(T, ellipsoid((0.45, 3.45, -0.6), (0.44, 0.38, 0.26), (-25, 0, -15)), "flesh", 0.12)
    S.add(T, ellipsoid((-0.42, 3.42, -0.58), (0.38, 0.34, 0.24), (-25, 0, 15)), "flesh", 0.12)
    for s in (1, -1):
        for j, y in enumerate((3.58, 3.38, 3.18, 2.98)):
            S.add(T, tube([X(s, (0.28, y, -0.74 + j * 0.02)), X(s, (0.6, y - 0.05, -0.62)), X(s, (0.83, y - 0.1, -0.36))],
                          [0.05, 0.045, 0.03]), "flesh", 0.05)
    for j, y in enumerate((2.72, 2.56, 2.4, 2.25)):
        w = 0.48 - j * 0.04
        S.add(T, tube([(-w, y, -0.5), (0, y - 0.02, -0.64 + j * 0.02), (w, y, -0.5)], [0.035, 0.045, 0.035]), "flesh", 0.05)
    S.paint(T, ellipsoid((0.08, 3.2, -0.72), (0.72, 0.58, 0.36)), "flesh")
    S.paint(T, ellipsoid((0, 2.45, -0.52), (0.55, 0.45, 0.36)), "flesh")
    S.paint(T, ellipsoid((0, 2.02, -0.36), (0.36, 0.26, 0.3)), "flesh")
    # the chest has been opened: a deep recessed void
    S.sub(T, ellipsoid((-0.08, 3.0, -0.92), (0.5, 0.72, 0.42), (0, 0, 6)), "void", 0.07)
    S.sub(T, ellipsoid((-0.05, 2.95, -0.58), (0.32, 0.52, 0.34)), "void", 0.05)
    S.sub(T, ellipsoid((0.0, 2.48, -0.72), (0.15, 0.3, 0.2), (0, 0, -4)), "void", 0.05)
    # creases between muscle masses
    for s in (1, -1):
        S.sub(T, tube([X(s, (0.64, 3.95, -0.52)), X(s, (0.72, 3.55, -0.6)), X(s, (0.78, 3.2, -0.52))], [0.03, 0.03, 0.02]), None, 0.03)
    S.sub(T, tube([(-0.55, 4.05, 0.62), (0.0, 4.25, 0.55), (0.45, 4.1, 0.62)], [0.035, 0.04, 0.03]), None, 0.03)
    S.sub(T, tube([(-0.7, 3.5, 0.78), (0, 3.62, 0.9), (0.6, 3.48, 0.8)], [0.03, 0.035, 0.03]), None, 0.03)
    S.noise(T, 0.014, 4.0)

def head(S, H="Head"):
    """Octopoid head: swept-back cranium, folds, one sunken pale eye, face tendrils."""
    S.add(H, ellipsoid((0, 3.85, -0.55), (0.38, 0.3, 0.36)), "skin", 0.2)                  # neck plug (hides the joint)
    S.add(H, ellipsoid((0, 4.45, -0.6), (0.62, 0.66, 0.74), (38, 0, 0)), "skin", 0.25)     # swept-back cranium
    S.add(H, ellipsoid((0.05, 4.75, -0.3), (0.5, 0.42, 0.55), (30, 0, 6)), "skin", 0.2)    # crown lobe
    S.add(H, ellipsoid((0, 3.98, -1.0), (0.46, 0.4, 0.42), (-25, 0, 0)), "skin", 0.2)      # face (turned down)
    S.add(H, ellipsoid((0, 3.76, -1.16), (0.34, 0.25, 0.28), (-35, 0, 0)), "skin", 0.15)   # compressed snout
    S.add(H, tube([(-0.48, 4.2, -0.96), (-0.05, 4.3, -1.2), (0.46, 4.22, -0.98)], [0.1, 0.12, 0.1]), "skin", 0.1)  # brow
    S.add(H, ellipsoid((-0.34, 4.26, -1.02), (0.2, 0.12, 0.16), (0, 0, 15)), "skin", 0.08)  # heavy lid over the eye
    for s in (1, -1):
        S.add(H, ellipsoid(X(s, (0.38, 3.95, -0.95)), (0.2, 0.25, 0.25)), "skin", 0.1)     # cheeks
        for j, (y0, z0) in enumerate(((4.28, -0.82), (4.08, -0.72))):
            S.add(H, tube([X(s, (0.44, y0, z0)), X(s, (0.52, y0 + 0.22, z0 + 0.35)), X(s, (0.4, y0 + 0.45, z0 + 0.7))],
                          [0.085, 0.08, 0.05]), "skin", 0.05)                                 # side folds
            S.sub(H, tube([X(s, (0.48, y0 - 0.1, z0 + 0.02)), X(s, (0.56, y0 + 0.12, z0 + 0.37)), X(s, (0.44, y0 + 0.35, z0 + 0.72))],
                          [0.04, 0.045, 0.03]), None, 0.03)                                   # deep creases
    for j, (y, z) in enumerate(((4.98, -0.5), (5.02, -0.25), (4.94, 0.0), (4.78, 0.22))):
        S.sub(H, tube([(-0.4, y - 0.2, z + 0.1), (0.02, y - 0.06, z + 0.14), (0.42, y - 0.2, z + 0.17)], [0.03, 0.036, 0.026]), None, 0.03)
    # the single pale eye, sunk into a dark socket on the left side of the face
    S.sub(H, sphere((-0.37, 4.1, -1.07), 0.11), "dark", 0.03)
    S.add(H, sphere((-0.38, 4.1, -1.08), 0.07), "eye", 0.0)
    S.sub(H, tube([(0.28, 4.12, -1.14), (0.42, 4.1, -1.04)], [0.02, 0.015]), "dark", 0.01)  # closed scar on the right
    # face tendrils hanging from under the snout
    rng = np.random.RandomState(4)
    roots = [(-0.36, 3.84, -1.08), (-0.22, 3.76, -1.18), (-0.08, 3.72, -1.24), (0.08, 3.72, -1.24), (0.22, 3.76, -1.18),
             (0.36, 3.84, -1.08), (-0.15, 3.8, -1.05), (0.15, 3.8, -1.05)]
    for i, r in enumerate(roots):
        L = 0.5 + 0.28 * (1 - abs(r[0]) / 0.36) + rng.uniform(-0.06, 0.06)
        sway = rng.uniform(-0.07, 0.07)
        curl = rng.uniform(-0.1, 0.06)
        pts = bezier_points(r, (r[0] * 1.15 + sway, r[1] - L * 0.55, r[2] - 0.1), (r[0] * 1.05 + sway * 2, r[1] - L, r[2] + curl), 7)
        S.add(H, tube(pts, np.linspace(0.062, 0.02, 7), k=0.02), "skin", 0.03)
    # dark speckles on the crown (paint only)
    Rc = rot_matrix(38, 0, 0)
    for _ in range(22):
        # a direction on the upper-front of the cranium, pushed to its surface
        d = np.array([rng.uniform(-0.55, 0.55), rng.uniform(0.55, 1.0), rng.uniform(-0.9, 0.1)])
        d /= np.linalg.norm(d)
        p = np.array((0, 4.45, -0.6)) + Rc @ (d * np.array((0.62, 0.66, 0.74)) * 1.02)
        S.paint(H, sphere(p, rng.uniform(0.06, 0.11)), "dark")
    S.noise(H, 0.012, 5.0)

def arm(S, A, s):
    """Heavy arm with an exposed tissue strip (no hand); s = +1 right, -1 left."""
    Sh, E, W, F = (1.08, 3.45, -0.15), (1.28, 2.7, -0.12), (1.3, 1.95, -0.4), (1.3, 1.68, -0.48)
    S.add(A, ellipsoid(X(s, (1.08, 3.48, -0.12)), (0.44, 0.42, 0.48)), "skin", 0.2)         # deltoid into the shoulder
    S.add(A, round_cone(X(s, Sh), X(s, E), 0.36, 0.27), "skin", 0.2)                        # upper arm
    S.add(A, ellipsoid(X(s, (1.22, 3.1, -0.3)), (0.27, 0.4, 0.23), (10, 0, 0)), "skin", 0.15)  # biceps
    S.add(A, ellipsoid(X(s, (1.27, 3.05, 0.04)), (0.25, 0.42, 0.23)), "skin", 0.15)            # triceps
    S.add(A, sphere(X(s, (1.3, 2.72, 0.02)), 0.17), "skin", 0.12)                              # elbow
    S.add(A, round_cone(X(s, E), X(s, W), 0.29, 0.23), "skin", 0.15)                        # forearm
    S.add(A, ellipsoid(X(s, (1.35, 2.45, -0.24)), (0.31, 0.43, 0.28), (20, 0, 0)), "skin", 0.15)  # forearm belly
    S.add(A, ellipsoid(X(s, (1.48, 2.5, -0.1)), (0.14, 0.38, 0.16), (15, 0, -5 * s)), "skin", 0.1)  # outer ridge
    S.paint(A, ellipsoid(X(s, (1.06, 2.35, -0.32)), (0.2, 0.52, 0.26), (20, 0, 0)), "flesh")
    for j in range(3):
        y = 2.62 - j * 0.24
        S.add(A, tube([X(s, (1.02, y, -0.42 + j * 0.05)), X(s, (1.06, y - 0.03, -0.24 + j * 0.05)),
                       X(s, (1.1, y - 0.05, -0.08 + j * 0.04))], [0.03, 0.035, 0.025]), "flesh", 0.04)
    S.noise(A, 0.012, 4.5)

def fist(S, A, s, noise=True):
    """Huge fist with curled fingers, thumb and nails."""
    F = (1.3, 1.68, -0.48)
    S.add(A, ellipsoid(X(s, F), (0.3, 0.28, 0.32)), "skin", 0.12)
    S.add(A, ellipsoid(X(s, (1.36, 1.82, -0.45)), (0.25, 0.2, 0.28)), "skin", 0.1)          # back of the hand
    for i, z in enumerate((-0.74, -0.6, -0.46, -0.32)):
        r = 0.09 - i * 0.006
        pts = [X(s, (1.42, 1.62, z)), X(s, (1.36, 1.44, z - 0.01)), X(s, (1.2, 1.4, z)), X(s, (1.1, 1.5, z + 0.01))]
        S.add(A, tube(pts, [r, r * 0.95, r * 0.9, r * 0.8], k=0.04), "skin", 0.05)
        S.add(A, ellipsoid(X(s, (1.07, 1.52, z + 0.01)), (0.04, 0.05, 0.05)), "dark", 0.0)  # nails
        S.sub(A, tube([X(s, (1.44, 1.66, z + 0.07)), X(s, (1.37, 1.42, z + 0.07))], [0.012, 0.012]), None, 0.02)
    S.add(A, tube([X(s, (1.17, 1.8, -0.7)), X(s, (1.1, 1.6, -0.8)), X(s, (1.18, 1.48, -0.76))], [0.1, 0.085, 0.07]), "skin", 0.05)
    if noise:
        S.noise(A, 0.012, 4.5)

def leg(S, Lb, s):
    """Long thick leg with exposed inner-thigh tissue (no foot)."""
    L = Lb
    Hp, K, An = (0.45, 2.12, 0.0), (0.5, 1.2, -0.18), (0.5, 0.28, 0.02)
    S.add(L, ellipsoid(X(s, (0.45, 2.2, 0.02)), (0.4, 0.36, 0.42)), "skin", 0.2)           # hip mass (into the pelvis)
    S.add(L, round_cone(X(s, Hp), X(s, K), 0.37, 0.22), "skin", 0.2)                         # thigh
    S.add(L, ellipsoid(X(s, (0.4, 1.72, -0.22)), (0.3, 0.52, 0.26), (15, 0, 0)), "skin", 0.15)  # quadriceps
    S.add(L, ellipsoid(X(s, (0.55, 1.75, 0.12)), (0.24, 0.48, 0.22)), "skin", 0.15)              # hamstring
    S.paint(L, ellipsoid(X(s, (0.27, 1.72, -0.24)), (0.26, 0.62, 0.3), (15, 0, 0)), "flesh")
    for j in range(3):
        y = 2.02 - j * 0.24
        S.add(L, tube([X(s, (0.16, y, -0.18)), X(s, (0.28, y - 0.04, -0.4)), X(s, (0.46, y - 0.06, -0.44))],
                      [0.028, 0.033, 0.024]), "flesh", 0.04)
    S.add(L, sphere(X(s, (0.5, 1.2, -0.2)), 0.19), "skin", 0.12)                            # knee
    S.add(L, round_cone(X(s, K), X(s, An), 0.21, 0.13), "skin", 0.15)                       # shin
    S.add(L, ellipsoid(X(s, (0.53, 0.84, 0.08)), (0.2, 0.36, 0.2)), "skin", 0.14)            # calf
    S.paint(L, ellipsoid(X(s, (0.36, 0.78, -0.05)), (0.12, 0.4, 0.18)), "flesh")
    S.noise(L, 0.012, 4.5)

def foot(S, Lb, s, noise=True):
    """Long splayed foot with separated toes and nails; flat sole on y=0."""
    L = Lb
    S.add(L, ellipsoid(X(s, (0.5, 0.14, 0.14)), (0.17, 0.14, 0.2)), "skin", 0.12)            # heel
    S.add(L, ellipsoid(X(s, (0.5, 0.13, -0.25)), (0.26, 0.12, 0.38)), "skin", 0.14)          # foot body
    for i, dx in enumerate((-0.19, -0.065, 0.065, 0.19)):
        base = (0.5 + dx, 0.11, -0.48)
        tip = (0.5 + dx * 1.7, 0.06, -0.95 - (0.06 if abs(dx) < 0.1 else 0))
        mid = ((base[0] + tip[0]) / 2, 0.1, (base[2] + tip[2]) / 2)
        S.add(L, tube([X(s, base), X(s, mid), X(s, tip)], [0.075, 0.06, 0.045]), "skin", 0.05)
        S.add(L, ellipsoid(X(s, (tip[0] + dx * 0.15, 0.05, tip[2] - 0.05)), (0.035, 0.03, 0.06)), "dark", 0.0)  # toenails
    S.sub(L, sphere(X(s, (0.5, -6.0, -0.2)), 6.0), None, 0.02)                              # flat sole on the ground
    if noise:
        S.noise(L, 0.012, 4.5)

def tail(S, Tl="Tail"):
    """Curved tail sweeping to the left, hooked claw tip."""
    pts = np.concatenate([bezier_points((-0.2, 2.3, 0.45), (-0.85, 1.7, 1.55), (-1.12, 0.62, 1.42), 10),
                          bezier_points((-1.12, 0.62, 1.42), (-1.2, 0.36, 1.25), (-1.3, 0.4, 1.02), 4)[1:]])
    S.add(Tl, tube(pts, np.linspace(0.26, 0.06, len(pts)), k=0.06), "skin", 0.1)
    S.add(Tl, tube([(-1.3, 0.4, 1.02), (-1.42, 0.5, 0.9), (-1.48, 0.7, 0.93)], [0.055, 0.035, 0.008]), "dark", 0.02)  # claw
    S.noise(Tl, 0.008, 5.0)

def build():
    S = Sculpt(NAME)
    # everything above the hips is authored at the classic R6 height and lifted onto the longer legs
    for bone in ("Torso", "Head", "Right Arm", "Left Arm", "Tail"):
        S.shift[bone] = (0, LEG_EXTRA, 0)
    torso(S)
    head(S)
    for s, bone in ((1, "Right Arm"), (-1, "Left Arm")):
        arm(S, bone, s)
        fist(S, bone, s, noise=False)
    for s, bone in ((1, "Right Leg"), (-1, "Left Leg")):
        leg(S, bone, s)
        foot(S, bone, s, noise=False)
    tail(S)
    return S

# voxel size per bone (smaller = more detail where it matters: face, hands, feet)
VOXEL = {"Head": 0.018, "Torso": 0.026, "Right Arm": 0.02, "Left Arm": 0.02, "Right Leg": 0.02, "Left Leg": 0.02, "Tail": 0.02}
MAX_TRIS = {"Head": 14000, "Torso": 14000, "Right Arm": 10000, "Left Arm": 10000, "Right Leg": 9000, "Left Leg": 9000, "Tail": 3500}
