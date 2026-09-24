"""The Curse mesh library: every modular body part as a sculpted, organic mesh.

    python3 tools/sculpt/library.py [--fast] [--only Id,Id] [--no-render] [--budget 0.25]

Each component is sculpted in its OWN local space (see "spaces" below), baked to
meshes split by palette role, and described in a generated manifest
(src/shared/CurseBody/Meshes/Library.lua) with its pieces, sockets, joint layout and
variants. The CurseBody runtime clones these MeshParts, scales them by the body's mass
and welds them onto the invisible R6 skeleton.

Spaces (all: -Z = front, +X = the creature's right; sided parts are authored RIGHT and
mirrored to "_L" pieces at export):
    torso   origin = R6 Torso center (the torso box spans ±1, ±1, ±0.5)
    head    origin = R6 Head center, neck joint at (0, -0.5, 0)
    arm     origin = R6 arm center, shoulder pivot at (-0.5, 0.5, 0)
    hand    origin = wrist, fingers hang toward -Y, palm faces -X
    leg     origin = R6 leg center, hip at the top (y = +1), authored down to y = 1 - span
    foot    origin = ground point under the ankle
    surface origin = a point on the body, +Y out of the surface (horns, eyes, mouths, growths)
    body    origin = attach point, axes aligned with the torso (tails, wings, tendrils, spikes)
"""
import json
import math
import os
import sys
import time

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, os.path.dirname(HERE))
from sculpt import husk  # noqa: E402
from sculpt import texture  # noqa: E402
from sculpt.sdf import (Prim, Sculpt, bezier_points, ellipsoid, mesh_bone, rot_matrix, round_cone,  # noqa: E402
                        sphere, squashed, torus, tube)

ROLE = {"skin": "Skin", "flesh": "Flesh", "void": "Void", "eye": "Eye", "dark": "Claw"}

FRONT, BACK, RIGHT, UP, DOWN = (-90, 0, 0), (90, 0, 0), (0, 0, -90), (0, 0, 0), (180, 0, 0)


def X(s, p):
    return (s * p[0], p[1], p[2])


def triangle(a, b, c, thickness):
    """Thin membrane: distance to a triangle minus half-thickness."""
    a, b, c = (np.asarray(v, float) for v in (a, b, c))
    ba, cb, ac = b - a, c - b, a - c
    nor = np.cross(ba, ac)

    def fn(p):
        pa, pb, pc = p - a, p - b, p - c

        def seg(e, q):
            t = np.clip((q @ e) / (e @ e), 0, 1)
            d = np.outer(t, e) - q
            return np.einsum("ij,ij->i", d, d)

        s = (np.sign(pa @ np.cross(ba, nor)) + np.sign(pb @ np.cross(cb, nor)) + np.sign(pc @ np.cross(ac, nor)))
        edge = np.minimum(np.minimum(seg(ba, pa), seg(cb, pb)), seg(ac, pc))
        face = (pa @ nor) ** 2 / (nor @ nor)
        return np.sqrt(np.where(s < 2, edge, face)) - thickness

    pts = np.stack([a, b, c])
    return Prim(fn, pts.min(0) - thickness, pts.max(0) + thickness)


# ============================================================================ registry
COMPONENTS = {}


def component(cid, slot, grade, space, **meta):
    def deco(fn):
        COMPONENTS[cid] = dict(id=cid, slot=slot, grade=grade, space=space, fn=fn, **meta)
        return fn
    return deco


def sockets_from(**kw):
    """name = (pos, rot) → manifest socket dict."""
    return {k: dict(pos=list(v[0]), rot=list(v[1])) for k, v in kw.items()}


def pair(name, pos, rot):
    """Right socket + mirrored left socket."""
    r = (pos, rot)
    l = ((-pos[0], pos[1], pos[2]), (rot[0], -rot[1], -rot[2]))
    return {name + "R": r, name + "L": l}


# ============================================================================ torsos
def torso_sockets(front, back, width, top, chest_y=0.3, belly_y=-0.35, neck=(0, 1.0, 0.05), tail=(0, -0.8, 0.42),
                  hip_x=0.62):
    s = dict(
        Chest=((0, chest_y, -front), FRONT), Belly=((0, belly_y, -front * 0.9), FRONT),
        UpperBack=((0, 0.6, back), BACK), Back=((0, 0.15, back * 1.02), BACK), LowerBack=((0, -0.4, back * 0.9), BACK),
        TailRoot=(tail, BACK), Neck=(neck, UP),
    )
    s.update(pair("Chest", (0.32 * width, chest_y + 0.15, -front * 0.95), FRONT))
    s.update(pair("ChestLow", (0.45 * width, belly_y + 0.35, -front * 0.8), FRONT))
    s.update(pair("Back", (0.4 * width, 0.5, back * 0.92), BACK))
    s.update(pair("Flank", (0.68 * width, 0.1, 0.02), RIGHT))
    s.update(pair("Shoulder", (0.72 * width, top, 0.0), UP))
    s.update(pair("Hip", (hip_x, -0.85, 0.0), RIGHT))
    return sockets_from(**s)


def open_chest(S, T, center, radii):
    """Carve the torso open: a recessed black cavity with bone stubs at its rim."""
    c = np.asarray(center, float)
    S.sub(T, ellipsoid(c, radii), "Void", 0.07)
    S.sub(T, ellipsoid(c + (0, -0.05, 0.25), np.asarray(radii) * (0.65, 0.72, 0.8)), "Void", 0.05)
    for y in (0.25, 0.0, -0.25):
        for s in (1, -1):
            S.add(T, tube([c + (s * radii[0] * 0.9, y * radii[1], 0.05), c + (s * radii[0] * 0.45, y * radii[1] - 0.05, 0.12)],
                          [0.035, 0.012]), "Bone", 0.02)


def normal_torso(S, T, open=False, m=1.0):
    S.add(T, ellipsoid((0, -0.85, 0.05), (0.62, 0.38, 0.44)), "Skin", 0.2)
    S.add(T, ellipsoid((0, -0.35, -0.02), (0.5, 0.45, 0.38)), "Skin", 0.25)
    S.add(T, ellipsoid((0, 0.3, 0), (0.66 * m, 0.6, 0.46 * m), (-5, 0, 0)), "Skin", 0.25)
    S.add(T, ellipsoid((0, 0.35, 0.22), (0.58 * m, 0.55, 0.3 * m)), "Skin", 0.2)
    for s in (1, -1):
        S.add(T, ellipsoid(X(s, (0.3 * m, 0.45, -0.34 * m)), (0.32 * m, 0.24, 0.16 * m), (-10, 0, -10 * s)), "SkinLight", 0.1)
        S.add(T, ellipsoid(X(s, (0.72 * m, 0.62, 0)), (0.34 * m, 0.3 * m, 0.34 * m)), "Skin", 0.2)
        S.add(T, ellipsoid(X(s, (0.5 * m, 0.1, 0.12)), (0.2 * m, 0.5, 0.3 * m), (0, 0, 10 * s)), "Skin", 0.15)
        S.add(T, ellipsoid(X(s, (0.3 * m, 0.82, 0.05)), (0.3 * m, 0.18 * m, 0.25 * m), (0, 0, 20 * s)), "Skin", 0.15)
        for r in range(3):
            S.add(T, ellipsoid(X(s, (0.14, -0.05 - 0.2 * r, -0.36 * m)), (0.12, 0.09, 0.06)), "SkinLight", 0.06)
    S.add(T, round_cone((0, 0.75, 0.02), (0, 1.12, -0.04), 0.25 * m, 0.2 * m), "Skin", 0.15)
    S.sub(T, tube([(0, -0.6, 0.36), (0, 0.3, 0.5 * m), (0, 0.85, 0.35)], [0.025, 0.03, 0.02]), None, 0.03)
    S.sub(T, tube([(0, 0.65, -0.44 * m), (0, 0.2, -0.47 * m)], [0.02, 0.02]), None, 0.02)
    if open:
        open_chest(S, T, (0, 0.15, -0.5 * m), (0.34 * m, 0.5, 0.32))
    S.noise(T, 0.01, 4.0)


NORMAL_LAYOUT = dict(neck=[0, 1.0, -0.05], shoulder=[1.0, 0.55, 0], hip=[1.0, -1, 0], tailRoot=[0, -0.8, 0.42], legExtra=0)

for _open in (False, True):
    component("NormalTorsoOpen" if _open else "NormalTorso", "Torso", "Grade4", "torso",
              layout=NORMAL_LAYOUT, sockets=torso_sockets(0.5, 0.5, 1.0, 0.95),
              variants=None if _open else {"Open": "NormalTorsoOpen"}, hidden=_open, tags=["humanoid"],
              voxel=0.028, tris=7000)(lambda S, T, o=_open: normal_torso(S, T, o))


def muscular_torso(S, T, open=False):
    normal_torso(S, T, False, m=1.2)
    for s in (1, -1):
        S.add(T, ellipsoid(X(s, (0.36, 0.45, -0.42)), (0.42, 0.3, 0.2), (-10, 0, -8 * s)), "SkinLight", 0.1)
        S.add(T, ellipsoid(X(s, (0.88, 0.62, 0)), (0.44, 0.42, 0.44)), "Skin", 0.18)
        S.add(T, ellipsoid(X(s, (0.66, 0.15, 0.12)), (0.3, 0.55, 0.38), (0, 0, 14 * s)), "Skin", 0.15)
        S.add(T, ellipsoid(X(s, (0.34, 0.88, 0.1)), (0.38, 0.26, 0.32), (0, 0, 22 * s)), "Skin", 0.15)
        for j in range(3):  # raised veins over the shoulders
            S.add(T, tube([X(s, (0.55 + j * 0.1, 0.9, -0.2 + j * 0.1)), X(s, (0.75 + j * 0.08, 0.5, -0.3 + j * 0.12))],
                          [0.022, 0.018]), "SkinDark", 0.02)
    if open:
        open_chest(S, T, (0, 0.15, -0.62), (0.38, 0.52, 0.34))


for _open in (False, True):
    component("MuscularTorsoOpen" if _open else "MuscularTorso", "Torso", "Grade4", "torso",
              layout=dict(neck=[0, 0.95, -0.08], shoulder=[1.2, 0.55, 0], hip=[1.05, -1, 0], tailRoot=[0, -0.8, 0.5], legExtra=0),
              sockets=torso_sockets(0.62, 0.62, 1.2, 1.05), variants=None if _open else {"Open": "MuscularTorsoOpen"},
              hidden=_open, tags=["muscle"], voxel=0.03, tris=8000)(lambda S, T, o=_open: muscular_torso(S, T, o))


def emaciated_torso(S, T, open=False):
    S.add(T, ellipsoid((0, -0.85, 0.05), (0.5, 0.32, 0.36)), "Skin", 0.15)
    S.add(T, ellipsoid((0, -0.3, 0.05), (0.36, 0.42, 0.28)), "Skin", 0.22)
    S.add(T, ellipsoid((0, 0.32, 0), (0.52, 0.6, 0.4)), "Skin", 0.22)
    S.add(T, round_cone((0, 0.7, 0.02), (0, 1.1, -0.05), 0.17, 0.14), "Skin", 0.12)
    for i in range(6):
        y = 0.72 - i * 0.16
        for s in (1, -1):
            S.add(T, tube([X(s, (0.06, y, -0.4)), X(s, (0.4, y - 0.04, -0.32)), X(s, (0.53, y - 0.1, 0.0)), X(s, (0.4, y - 0.15, 0.3))],
                          [0.035, 0.04, 0.035, 0.025]), "SkinLight", 0.035)
    for i in range(8):
        S.add(T, sphere((0, -0.8 + i * 0.25, 0.36 - abs(i - 4) * 0.01), 0.06), "SkinLight", 0.04)
    for s in (1, -1):
        S.add(T, tube([X(s, (0.05, 0.9, -0.3)), X(s, (0.62, 0.95, -0.08))], [0.045, 0.04]), "SkinLight", 0.04)
        S.add(T, ellipsoid(X(s, (0.4, -0.75, -0.22)), (0.12, 0.14, 0.1)), "SkinLight", 0.08)
        S.add(T, ellipsoid(X(s, (0.66, 0.72, 0)), (0.2, 0.2, 0.22)), "Skin", 0.12)
    S.sub(T, ellipsoid((0, -0.35, -0.42), (0.3, 0.3, 0.14)), None, 0.15)
    if open:
        open_chest(S, T, (0, 0.2, -0.42), (0.28, 0.42, 0.28))
    S.noise(T, 0.008, 5.0)


for _open in (False, True):
    component("EmaciatedTorsoOpen" if _open else "EmaciatedTorso", "Torso", "Grade4", "torso",
              layout=dict(neck=[0, 1.0, -0.03], shoulder=[0.85, 0.6, 0], hip=[0.9, -1, 0], tailRoot=[0, -0.8, 0.35], legExtra=0.1),
              sockets=torso_sockets(0.42, 0.42, 0.85, 0.9, hip_x=0.5), variants=None if _open else {"Open": "EmaciatedTorsoOpen"},
              hidden=_open, tags=["thin", "bone"], voxel=0.024, tris=8000)(lambda S, T, o=_open: emaciated_torso(S, T, o))


def massive_torso(S, T, open=False):
    S.add(T, ellipsoid((0, -0.8, 0.05), (0.85, 0.45, 0.6)), "Skin", 0.25)
    S.add(T, ellipsoid((0, -0.3, -0.18), (0.85, 0.6, 0.65)), "Skin", 0.3)
    S.add(T, ellipsoid((0, 0.3, 0), (1.0, 0.72, 0.72), (-10, 0, 0)), "Skin", 0.3)
    S.add(T, ellipsoid((0, 0.75, 0.3), (0.85, 0.55, 0.6), (-25, 0, 0)), "SkinLight", 0.3)
    for s in (1, -1):
        S.add(T, ellipsoid(X(s, (1.08, 0.5, -0.05)), (0.55, 0.55, 0.58), (0, 0, 20 * s)), "Skin", 0.25)
        S.add(T, ellipsoid(X(s, (0.45, 0.8, -0.3)), (0.5, 0.35, 0.45), (0, 0, 30 * s)), "Skin", 0.2)
        S.add(T, ellipsoid(X(s, (0.45, 0.35, -0.6)), (0.45, 0.32, 0.22), (-10, 0, -10 * s)), "SkinLight", 0.12)
    for j, y in enumerate((-0.05, -0.3, -0.55)):
        S.sub(T, tube([(-0.55, y, -0.68 + j * 0.02), (0, y - 0.05, -0.82), (0.55, y, -0.68 + j * 0.02)], [0.03, 0.035, 0.03]), None, 0.04)
    S.sub(T, tube([(-0.7, 0.9, 0.75), (0, 1.0, 0.85), (0.7, 0.9, 0.75)], [0.035, 0.04, 0.035]), None, 0.04)
    if open:
        open_chest(S, T, (0, 0.1, -0.78), (0.45, 0.55, 0.4))
    S.noise(T, 0.014, 3.5)


for _open in (False, True):
    component("MassiveTorsoOpen" if _open else "MassiveTorso", "Torso", "Grade1", "torso",
              layout=dict(neck=[0, 0.85, -0.35], shoulder=[1.45, 0.45, -0.05], hip=[1.15, -1, 0], tailRoot=[0, -0.8, 0.62], legExtra=0.15),
              sockets=torso_sockets(0.82, 0.9, 1.45, 1.05, neck=(0, 1.1, -0.2), tail=(0, -0.8, 0.62), hip_x=0.8),
              variants=None if _open else {"Open": "MassiveTorsoOpen"}, hidden=_open, tags=["massive"],
              voxel=0.034, tris=9000)(lambda S, T, o=_open: massive_torso(S, T, o))

component("HuskTorso", "Torso", "Grade3", "torso", origin=(0, 3, 0), roles=ROLE,
          layout=dict(neck=[0, 0.6, -0.8], shoulder=[1.05, 0.55, -0.2], hip=[0.98, -1, 0.05], tailRoot=[-0.2, -0.7, 0.55], legExtra=0.35),
          sockets=torso_sockets(0.95, 0.95, 1.1, 1.05, chest_y=0.05, belly_y=-0.5, neck=(0, 1.05, -0.3), tail=(-0.2, -0.7, 0.55), hip_x=0.72),
          tags=["hunched", "reference"], voxel=0.028, tris=10000)(lambda S, T: husk.torso(S, T))


# ============================================================================ heads
def head_sockets(crown, top, brow, face, eye, mouth, jaw, cheek, temple, ear, back, eye_yaw=0, top_tilt=30):
    s = dict(Crown=(crown, UP), Brow=(brow, (-60, 0, 0)), Face=(face, FRONT), Mouth=(mouth, FRONT), Jaw=(jaw, DOWN),
             BackOfHead=(back, BACK))
    s.update(pair("Top", top, (0, 0, -top_tilt)))
    s.update(pair("Eye", eye, (-90, 0, -eye_yaw)))
    s.update(pair("Cheek", cheek, (-90, 0, -45)))
    s.update(pair("Temple", temple, RIGHT))
    s.update(pair("Ear", ear, RIGHT))
    return sockets_from(**s)


@component("HumanCurseHead", "Head", "Grade4", "head", tags=["humanoid"], voxel=0.016, tris=7000,
           defaults=dict(Eyes=[dict(id="Eye", socket="EyeR"), dict(id="Eye", socket="EyeL")], Mouths=[]),
           sockets=head_sockets((0, 0.85, 0.05), (0.35, 0.72, 0), (0, 0.4, -0.58), (0, 0.05, -0.68), (0.24, 0.1, -0.52),
                                (0, -0.26, -0.64), (0, -0.62, -0.25), (0.45, -0.1, -0.42), (0.6, 0.3, -0.05), (0.62, 0.02, 0.05),
                                (0, 0.25, 0.7)))
def human_head(S, H):
    S.add(H, ellipsoid((0, -0.45, 0.05), (0.3, 0.25, 0.3)), "Skin", 0.15)
    S.add(H, ellipsoid((0, 0.18, 0.05), (0.6, 0.66, 0.66)), "Skin", 0.2)
    S.add(H, tube([(-0.42, 0.3, -0.48), (0, 0.36, -0.6), (0.42, 0.3, -0.48)], [0.09, 0.1, 0.09]), "Skin", 0.08)
    S.add(H, ellipsoid((0, -0.33, -0.2), (0.46, 0.3, 0.46)), "Skin", 0.18)
    S.add(H, ellipsoid((0, -0.5, -0.46), (0.18, 0.12, 0.12)), "Skin", 0.1)
    S.add(H, round_cone((0, 0.15, -0.6), (0, -0.08, -0.68), 0.06, 0.085), "Skin", 0.06)
    for s in (1, -1):
        S.add(H, ellipsoid(X(s, (0.3, -0.05, -0.45)), (0.18, 0.14, 0.16)), "SkinLight", 0.1)
        S.add(H, ellipsoid(X(s, (0.6, 0.02, 0.05)), (0.06, 0.18, 0.12)), "SkinDark", 0.06)
        S.sub(H, sphere(X(s, (0.24, 0.1, -0.6)), 0.12), "SkinDeep", 0.04)
    S.sub(H, tube([(-0.2, -0.24, -0.62), (0, -0.27, -0.67), (0.2, -0.24, -0.62)], [0.025, 0.03, 0.025]), "SkinDeep", 0.02)
    S.add(H, ellipsoid((0.25, 0.62, 0.1), (0.22, 0.14, 0.2)), "SkinLight", 0.12)
    S.noise(H, 0.008, 5)


@component("BeastHead", "Head", "Grade4", "head", tags=["beast"], voxel=0.016, tris=7000,
           defaults=dict(Eyes=[dict(id="Eye", socket="EyeR"), dict(id="Eye", socket="EyeL")], Mouths=[]),
           sockets=head_sockets((0, 0.72, 0.2), (0.3, 0.62, 0.12), (0, 0.45, -0.3), (0, 0.05, -0.9), (0.3, 0.28, -0.32),
                                (0, -0.3, -0.92), (0, -0.55, -0.6), (0.4, -0.05, -0.4), (0.5, 0.3, 0.15), (0.45, 0.45, 0.35),
                                (0, 0.3, 0.8), eye_yaw=35, top_tilt=25))
def beast_head(S, H):
    S.add(H, ellipsoid((0, -0.35, 0.2), (0.32, 0.28, 0.32)), "Skin", 0.15)
    S.add(H, ellipsoid((0, 0.2, 0.2), (0.52, 0.5, 0.58)), "Skin", 0.2)
    S.add(H, round_cone((0, 0.0, -0.15), (0, -0.16, -0.95), 0.34, 0.22), "Skin", 0.15)
    S.add(H, round_cone((0, -0.3, -0.15), (0, -0.4, -0.85), 0.26, 0.17), "SkinDark", 0.1)
    S.add(H, ellipsoid((0, 0.24, -0.42), (0.4, 0.14, 0.3), (-20, 0, 0)), "SkinLight", 0.1)
    S.add(H, ellipsoid((0, -0.1, -1.0), (0.14, 0.1, 0.1)), "SkinDeep", 0.06)
    S.sub(H, tube([(-0.2, -0.25, -0.3), (0, -0.28, -0.98), (0.2, -0.25, -0.3)], [0.04, 0.03, 0.04]), "Void", 0.03)
    for s in (1, -1):
        for i in range(6):
            z = -0.38 - i * 0.1
            S.add(H, round_cone(X(s, (0.16 - i * 0.012, -0.2, z)), X(s, (0.15 - i * 0.012, -0.34, z - 0.01)), 0.03, 0.006), "Teeth", 0.0)
            S.add(H, round_cone(X(s, (0.14 - i * 0.012, -0.38, z - 0.05)), X(s, (0.13 - i * 0.012, -0.27, z - 0.05)), 0.025, 0.005), "Teeth", 0.0)
        S.add(H, tube([X(s, (0.3, 0.55, 0.28)), X(s, (0.42, 0.85, 0.4)), X(s, (0.5, 1.08, 0.55))], [0.13, 0.08, 0.02]), "SkinDark", 0.06)
        S.sub(H, sphere(X(s, (0.3, 0.28, -0.34)), 0.1), "SkinDeep", 0.04)
        S.sub(H, sphere(X(s, (0.06, -0.08, -1.08)), 0.03), "Void", 0.02)
    S.noise(H, 0.01, 5)


@component("SkullHead", "Head", "Grade2", "head", tags=["bone"], voxel=0.014, tris=7000,
           defaults=dict(Eyes=[dict(id="GlowPoint", socket="EyeR"), dict(id="GlowPoint", socket="EyeL")], Mouths=[]),
           sockets=head_sockets((0, 0.82, 0.05), (0.33, 0.7, 0), (0, 0.4, -0.55), (0, 0.05, -0.7), (0.23, 0.12, -0.46),
                                (0, -0.4, -0.64), (0, -0.66, -0.2), (0.46, -0.12, -0.35), (0.56, 0.3, 0), (0.58, 0.05, 0.05),
                                (0, 0.25, 0.66)))
def skull_head(S, H):
    S.add(H, round_cone((0, -0.8, 0.12), (0, -0.35, 0.1), 0.12, 0.14), "BoneDark", 0.06)
    S.add(H, ellipsoid((0, 0.2, 0.05), (0.56, 0.6, 0.62)), "Bone", 0.2)
    S.add(H, ellipsoid((0, -0.1, -0.35), (0.46, 0.34, 0.34)), "Bone", 0.15)
    for s in (1, -1):
        S.sub(H, ellipsoid(X(s, (0.23, 0.12, -0.55)), (0.15, 0.14, 0.14)), "Void", 0.04)
        S.add(H, ellipsoid(X(s, (0.4, -0.12, -0.36)), (0.14, 0.09, 0.18)), "Bone", 0.06)
    S.sub(H, ellipsoid((0, -0.08, -0.66), (0.07, 0.1, 0.08)), "Void", 0.03)
    S.add(H, ellipsoid((0, -0.5, -0.16), (0.42, 0.15, 0.42)), "BoneDark", 0.08)
    for i in range(8):
        x = -0.28 + i * 0.08
        z = -0.58 + abs(x) * 0.3
        S.add(H, ellipsoid((x, -0.34, z), (0.034, 0.075, 0.035)), "Teeth", 0.0)
        S.add(H, ellipsoid((x * 0.95, -0.44, z + 0.03), (0.032, 0.065, 0.033)), "Teeth", 0.0)
    S.sub(H, tube([(-0.1, 0.7, -0.35), (0.05, 0.45, -0.5), (0.0, 0.25, -0.6)], [0.015, 0.018, 0.01]), "BoneDark", 0.01)
    S.noise(H, 0.006, 6)


@component("MandibleHead", "Head", "Grade3", "head", tags=["insect"], voxel=0.016, tris=7000,
           defaults=dict(Eyes=[], Mouths=[dict(id="Mandibles", socket="Mouth")]),
           sockets=head_sockets((0, 0.72, 0.1), (0.3, 0.62, 0), (0, 0.45, -0.52), (0, 0.1, -0.78), (0.42, 0.25, -0.3),
                                (0, -0.35, -0.72), (0, -0.5, -0.4), (0.45, -0.1, -0.45), (0.5, 0.35, 0.1), (0.5, 0.2, 0.25),
                                (0, 0.35, 0.85), eye_yaw=60))
def mandible_head(S, H):
    S.add(H, round_cone((0, 0.35, 0.4), (0, -0.1, -0.55), 0.5, 0.36), "SkinDark", 0.1)
    S.add(H, ellipsoid((0, 0.48, 0.02), (0.48, 0.16, 0.6), (10, 0, 0)), "Skin", 0.06)
    S.add(H, ellipsoid((0, 0.22, -0.6), (0.24, 0.14, 0.16), (-30, 0, 0)), "Skin", 0.06)
    S.add(H, ellipsoid((0, -0.45, 0.3), (0.26, 0.2, 0.26)), "SkinDark", 0.12)
    for s in (1, -1):
        S.add(H, ellipsoid(X(s, (0.4, 0.22, -0.25)), (0.18, 0.24, 0.28), (0, -20 * s, 0)), "Void", 0.03)
        for i in range(7):
            a = i * 0.9
            S.add(H, sphere(X(s, (0.55 + 0.02 * math.cos(a), 0.22 + 0.13 * math.sin(a), -0.25 + 0.14 * math.cos(a * 1.3))), 0.025), "Glow", 0.0)
    S.add(H, tube([(0, 0.55, 0.5), (0, 0.4, 0.85), (0, 0.1, 1.0)], [0.08, 0.05, 0.02]), "SkinDark", 0.05)
    S.noise(H, 0.006, 6)


@component("FacelessHead", "Head", "Grade4", "head", tags=["faceless"], voxel=0.018, tris=5000,
           defaults=dict(Eyes=[], Mouths=[]),
           sockets=head_sockets((0, 0.92, 0), (0.33, 0.78, 0), (0, 0.45, -0.58), (0, 0.05, -0.66), (0.25, 0.15, -0.62),
                                (0, -0.25, -0.62), (0, -0.62, -0.15), (0.45, -0.1, -0.42), (0.58, 0.3, 0), (0.6, 0.05, 0.05),
                                (0, 0.3, 0.66)))
def faceless_head(S, H):
    S.add(H, ellipsoid((0, -0.45, 0.05), (0.3, 0.25, 0.3)), "Skin", 0.15)
    S.add(H, ellipsoid((0, 0.15, 0), (0.6, 0.76, 0.66)), "Skin", 0.2)
    S.add(H, ellipsoid((0, 0.05, -0.45), (0.46, 0.5, 0.2)), "SkinLight", 0.2)
    S.sub(H, tube([(0, 0.75, -0.5), (0, 0.1, -0.66), (0, -0.5, -0.45)], [0.012, 0.015, 0.01]), "SkinDark", 0.015)
    S.noise(H, 0.006, 4)


@component("SplitJawHead", "Head", "Grade2", "head", tags=["maw", "transformation"], voxel=0.016, tris=8000,
           defaults=dict(Eyes=[], Mouths=[]),
           sockets=head_sockets((0, 0.85, 0.15), (0.4, 0.75, 0.1), (0, 0.55, -0.5), (0, 0.3, -0.6), (0.3, 0.45, -0.52),
                                (0, -0.4, -0.65), (0, -1.0, -0.15), (0.75, -0.2, -0.3), (0.65, 0.45, 0), (0.66, 0.3, 0.1),
                                (0, 0.4, 0.8)))
def split_jaw_head(S, H):
    S.add(H, ellipsoid((0, 0.4, 0.15), (0.65, 0.48, 0.68)), "Skin", 0.2)
    for s in (1, -1):
        S.add(H, ellipsoid(X(s, (0.5, -0.42, -0.12)), (0.32, 0.6, 0.58), (0, 0, 28 * s)), "Skin", 0.15)
        for k in range(6):
            y = 0.05 - k * 0.18
            x = 0.24 + k * 0.08
            S.add(H, round_cone(X(s, (x, y, -0.5)), X(s, (x - 0.16, y - 0.05, -0.55)), 0.045, 0.006), "Teeth", 0.0)
        for i in range(2):
            S.sub(H, sphere(X(s, (0.14 + i * 0.2, 0.62 - i * 0.05, -0.42)), 0.07), "SkinDeep", 0.02)
            S.add(H, sphere(X(s, (0.14 + i * 0.2, 0.62 - i * 0.05, -0.44)), 0.045), "Eye", 0.0)
    S.sub(H, ellipsoid((0, -0.35, -0.28), (0.36, 0.62, 0.5)), "Void", 0.06)
    for k in range(5):
        S.add(H, round_cone((-0.22 + k * 0.11, 0.08, -0.55), (-0.22 + k * 0.11, -0.12, -0.6), 0.04, 0.006), "Teeth", 0.0)
    S.noise(H, 0.01, 5)


component("HuskHead", "Head", "Grade2", "head", origin=(0, 4.1, -0.8), roles=ROLE, tags=["reference", "tentacle"],
          voxel=0.016, tris=10000, defaults=dict(Eyes=[], Mouths=[]),
          sockets=head_sockets((0, 0.95, 0.35), (0.42, 0.82, 0.2), (0, 0.22, -0.45), (0, -0.12, -0.62), (0.4, 0.0, -0.3),
                               (0, -0.45, -0.52), (0, -0.62, -0.3), (0.42, -0.15, -0.38), (0.58, 0.25, 0.02), (0.58, 0.0, 0.1),
                               (0, 0.6, 0.85), eye_yaw=50))(lambda S, H: husk.head(S, H))


# ============================================================================ arms (arm space, right side)
def arm_sockets(S_, E, W, t, hand=True):
    s = dict(Shoulder=((S_[0], S_[1] + 0.3, S_[2]), UP), UpperArm=(((S_[0] + E[0]) / 2 + 0.3 * t, (S_[1] + E[1]) / 2, 0), RIGHT),
             Elbow=((E[0], E[1], E[2] + 0.25 * t), BACK), Forearm=(((E[0] + W[0]) / 2 + 0.25 * t, (E[1] + W[1]) / 2, (E[2] + W[2]) / 2), RIGHT))
    if hand:
        s["Hand"] = ((W[0], W[1] - 0.05, W[2]), UP)  # hand space is authored upright (fingers toward -Y)
        s["Palm"] = ((W[0] - 0.15, W[1] - 0.3, W[2]), (0, 0, 90))
    return sockets_from(**s)


def basic_arm(S, A, up, fore, deltoid=1.0, biceps=0.0, veins=False, S_=(-0.42, 0.42, 0), E=(-0.33, -0.35, 0.06), W=(-0.3, -1.05, -0.08)):
    S.add(A, ellipsoid((S_[0] + 0.02, S_[1] + 0.06, 0), np.array((0.36, 0.32, 0.38)) * deltoid), "Skin", 0.15)
    S.add(A, round_cone(S_, E, up, up * 0.78), "Skin", 0.15)
    if biceps:
        S.add(A, ellipsoid(((S_[0] + E[0]) / 2 + 0.03, (S_[1] + E[1]) / 2, -up * 0.45), (up * 0.75, 0.3 * biceps / 0.5, up * 0.6)), "SkinLight", 0.1)
    S.add(A, sphere((E[0], E[1] - 0.01, E[2] + up * 0.35), up * 0.5), "Skin", 0.1)
    S.add(A, round_cone(E, W, fore, fore * 0.7), "Skin", 0.12)
    S.add(A, ellipsoid(((E[0] + W[0]) / 2 + 0.03, E[1] + (W[1] - E[1]) * 0.3, -fore * 0.3), (fore * 0.8, 0.3, fore * 0.72)), "Skin", 0.12)
    S.add(A, ellipsoid(W, (fore * 0.55, 0.1, fore * 0.62)), "Skin", 0.08)
    if veins:
        for j in range(3):
            y0 = E[1] - 0.1 - j * 0.15
            S.add(A, tube([(E[0] + 0.12, y0, -fore * 0.9), (E[0] + 0.02, y0 - 0.3, -fore * 0.85)], [0.02, 0.015]), "SkinDark", 0.02)
    S.noise(A, 0.008, 5)


def arm_def(cid, grade, fn, up, fore, S_=(-0.42, 0.42, 0), E=(-0.33, -0.35, 0.06), W=(-0.3, -1.05, -0.08), hand=True, tags=("arm",), **meta):
    component(cid, "Arms", grade, "arm", sided=True, pivot=[-0.5, 0.5, 0], tags=list(tags), voxel=0.018, tris=5000,
              sockets=arm_sockets(S_, E, W, up / 0.27, hand), **meta)(fn)


arm_def("NormalArm", "Grade4", lambda S, A: basic_arm(S, A, 0.27, 0.22), 0.27, 0.22)
arm_def("MuscularArm", "Grade4", lambda S, A: basic_arm(S, A, 0.37, 0.3, deltoid=1.3, biceps=0.5, veins=True), 0.37, 0.3)
_THIN = dict(S_=(-0.45, 0.42, 0), E=(-0.38, -0.45, 0.06), W=(-0.35, -1.25, -0.05))
arm_def("ThinArm", "Grade4", lambda S, A: basic_arm(S, A, 0.15, 0.12, deltoid=0.6, **_THIN), 0.15, 0.12, **_THIN)


def bone_arm(S, A):
    S_, E, W = (-0.42, 0.42, 0), (-0.33, -0.35, 0.06), (-0.3, -1.05, -0.08)
    S.add(A, ellipsoid((-0.4, 0.5, 0), (0.3, 0.26, 0.3)), "SkinDark", 0.1)
    S.add(A, round_cone(S_, E, 0.1, 0.08), "Bone", 0.06)
    S.add(A, sphere(E, 0.12), "BoneDark", 0.05)
    S.add(A, round_cone((E[0] + 0.06, E[1], E[2]), (W[0] + 0.05, W[1], W[2]), 0.07, 0.055), "Bone", 0.03)
    S.add(A, round_cone((E[0] - 0.06, E[1], E[2] - 0.04), (W[0] - 0.05, W[1], W[2] - 0.03), 0.06, 0.05), "BoneDark", 0.03)
    S.add(A, ellipsoid(W, (0.12, 0.08, 0.12)), "BoneDark", 0.04)
    for a in (0.14, -0.14, 0.02):
        S.add(A, tube([(S_[0] + a, S_[1] - 0.1, 0.08), (E[0] + a * 0.6, (S_[1] + E[1]) / 2, -0.06), (E[0] + a * 0.4, E[1] + 0.05, 0.02)],
                      [0.035, 0.028, 0.03]), "SkinDark", 0.02)


arm_def("BoneArm", "Grade2", bone_arm, 0.14, 0.1, tags=("arm", "bone"))


def tentacle_arm(S, A):
    pts = np.concatenate([bezier_points((-0.42, 0.42, 0), (-0.25, -0.5, 0.2), (-0.15, -1.1, -0.2), 10),
                          bezier_points((-0.15, -1.1, -0.2), (-0.1, -1.45, -0.45), (-0.3, -1.4, -0.65), 5)[1:]])
    S.add(A, ellipsoid((-0.4, 0.48, 0), (0.34, 0.3, 0.34)), "Skin", 0.15)
    S.add(A, tube(pts, np.linspace(0.28, 0.05, len(pts)), k=0.08), "Skin", 0.1)
    for i in range(2, len(pts) - 1):
        d = pts[i + 1] - pts[i - 1]
        side = np.cross(d, (1, 0, 0))
        side = side / (np.linalg.norm(side) + 1e-9)
        r = 0.28 - (0.23 * i / len(pts))
        S.add(A, sphere(pts[i] + side * r * 0.85, r * 0.28), "Flesh", 0.03)
    S.noise(A, 0.006, 5)


arm_def("TentacleArm", "Grade2", tentacle_arm, 0.28, 0.2, hand=False, tags=("arm", "tentacle"))

component("HuskArm", "Arms", "Grade3", "arm", origin=(1.55, 3.05, -0.2), roles=ROLE, sided=True, pivot=[-0.5, 0.5, 0],
          tags=["arm", "reference"], voxel=0.02, tris=7000,
          sockets=arm_sockets((-0.47, 0.4, 0.05), (-0.27, -0.35, 0.08), (-0.25, -1.1, -0.2), 1.3))(lambda S, A: husk.arm(S, A, 1))


# ============================================================================ hands (hand space, right hand)
component("Fist", "Hands", "Grade4", "hand", origin=(1.3, 1.95, -0.4), roles=ROLE, sided=True, tags=["hand", "reference"],
          voxel=0.011, tris=4000)(lambda S, H: husk.fist(S, H, 1))


def fingers_hand(S, H, n=4, length=0.35, curl=0.4, claw=0.0, blade=0.0, talon=False):
    S.add(H, ellipsoid((0.02, -0.2, -0.02), (0.13, 0.22, 0.25)), "Skin", 0.08)
    zs = np.linspace(-0.18, 0.18, n) if n > 1 else [0.0]
    for i, z in enumerate(zs):
        L = length * (1 - abs(z) * 0.8)
        base = (0.0, -0.38, z)
        mid = (-0.05 * curl, -0.38 - L * 0.55, z)
        tip = (-0.2 * curl, -0.38 - L, z * 1.1)
        r = 0.055 if not talon else 0.06
        S.add(H, tube([base, mid, tip], [r, r * 0.9, r * 0.75]), "Skin", 0.04)
        S.add(H, sphere((0.03, -0.38, z), r * 1.15), "SkinLight", 0.04)
        if claw:
            S.add(H, tube([tip, (tip[0] - 0.06 - claw * 0.2, tip[1] - claw * 0.6, tip[2]), (tip[0] - 0.08 - claw * 0.5, tip[1] - claw * 0.85, tip[2])],
                          [r * 0.7, r * 0.4, 0.004]), "Claw", 0.015)
        if blade:
            S.add(H, squashed(round_cone(tip, (tip[0] - 0.05, tip[1] - blade, tip[2]), 0.07, 0.005), tip, (0.35, 1, 1)), "Claw", 0.02)
    S.add(H, tube([(-0.05, -0.15, -0.24), (-0.15, -0.3, -0.3), (-0.2, -0.43, -0.28)], [0.065, 0.055, 0.045]), "Skin", 0.04)
    if claw:
        S.add(H, round_cone((-0.2, -0.43, -0.28), (-0.3, -0.55, -0.28), 0.035, 0.004), "Claw", 0.015)
    S.noise(H, 0.005, 7)


for cid, grade, kw, tags in (
        ("ClawedHand", "Grade3", dict(claw=0.22, curl=0.5), ["hand", "claw"]),
        ("BladedHand", "Grade2", dict(blade=0.85, curl=0.0, length=0.22), ["hand", "blade"]),
        ("TalonHand", "Grade3", dict(n=3, length=0.62, curl=0.7, claw=0.3, talon=True), ["hand", "claw"]),
        ("OpenHand", "Grade4", dict(curl=0.25), ["hand"])):
    component(cid, "Hands", grade, "hand", sided=True, tags=tags, voxel=0.01, tris=3500)(lambda S, H, kw=kw: fingers_hand(S, H, **kw))


# ============================================================================ legs (leg space, right leg)
def leg_sockets(H, K, An, t, foot=(0.02, -1.0, 0.0)):
    return sockets_from(Thigh=(((H[0] + K[0]) / 2, (H[1] + K[1]) / 2, -0.3 * t), FRONT), Knee=((K[0], K[1], K[2] - 0.2 * t), FRONT),
                        Shin=((0.2 * t, (K[1] + An[1]) / 2, (K[2] + An[2]) / 2), RIGHT), Foot=(foot, UP))


def basic_leg(S, L, thigh, shin, calf=1.0, H=(0.02, 0.75, 0.0), K=(0.02, -0.1, -0.12), An=(0.02, -0.85, 0.03)):
    S.add(L, ellipsoid((0.0, 0.85, 0.02), (thigh * 1.05, 0.3, thigh * 1.1)), "Skin", 0.18)
    S.add(L, round_cone(H, K, thigh, thigh * 0.62), "Skin", 0.18)
    S.add(L, ellipsoid((0.0, 0.35, -thigh * 0.45), (thigh * 0.8, 0.4, thigh * 0.62), (10, 0, 0)), "Skin", 0.12)
    S.add(L, sphere(K, thigh * 0.5), "SkinLight", 0.1)
    S.add(L, round_cone(K, An, shin, shin * 0.62), "Skin", 0.12)
    S.add(L, ellipsoid((0.02, -0.3, shin * 0.5), (shin * 0.85, 0.3, shin * 0.85 * calf)), "Skin", 0.12)
    S.add(L, ellipsoid(An, (shin * 0.7, 0.1, shin * 0.75)), "Skin", 0.08)
    S.noise(L, 0.008, 5)


def leg_def(cid, grade, fn, thigh, shin, span=2.0, H=(0.02, 0.75, 0.0), K=(0.02, -0.1, -0.12), An=(0.02, -0.85, 0.03),
            foot=(0.02, -1.0, 0.0), tags=("leg",), **meta):
    component(cid, "Legs", grade, "leg", sided=True, pivot=[0.5, 1, 0], span=span, tags=list(tags), voxel=0.018, tris=5000,
              sockets=leg_sockets(H, K, An, thigh / 0.32, foot), **meta)(fn)


leg_def("NormalLeg", "Grade4", lambda S, L: basic_leg(S, L, 0.32, 0.2), 0.32, 0.2)
leg_def("ThinLeg", "Grade4", lambda S, L: basic_leg(S, L, 0.2, 0.12), 0.2, 0.12)
leg_def("MassiveLeg", "Grade3", lambda S, L: basic_leg(S, L, 0.46, 0.32, calf=1.3), 0.46, 0.32)


def digitigrade_leg(S, L):
    Hp, K, Hk, B = (0.02, 0.75, 0.05), (0.0, 0.05, -0.35), (0.0, -0.55, 0.4), (0.0, -0.93, -0.12)
    S.add(L, ellipsoid((0.0, 0.85, 0.02), (0.36, 0.3, 0.38)), "Skin", 0.18)
    S.add(L, round_cone(Hp, K, 0.36, 0.22), "Skin", 0.15)
    S.add(L, ellipsoid((0, 0.4, -0.2), (0.28, 0.4, 0.25), (-25, 0, 0)), "Skin", 0.12)
    S.add(L, sphere(K, 0.17), "SkinLight", 0.08)
    S.add(L, round_cone(K, Hk, 0.19, 0.13), "Skin", 0.1)
    S.add(L, sphere(Hk, 0.13), "SkinDark", 0.06)
    S.add(L, round_cone(Hk, B, 0.12, 0.08), "SkinDark", 0.08)
    S.noise(L, 0.008, 5)


leg_def("DigitigradeLeg", "Grade2", digitigrade_leg, 0.36, 0.19, K=(0, 0.05, -0.35), An=(0, -0.55, 0.4), foot=(0, -1.0, -0.14),
        tags=("leg", "beast"), legExtra=0.2)
component("HuskLeg", "Legs", "Grade3", "leg", origin=(0.48, 1.35, 0.05), roles=ROLE, sided=True, pivot=[0.5, 1, 0], span=2.35,
          tags=["leg", "reference"], voxel=0.02, tris=6000,
          sockets=leg_sockets((-0.03, 0.77, -0.05), (0.02, -0.15, -0.23), (0.02, -1.07, -0.03), 1.15, foot=(0.02, -1.35, -0.03)))(
    lambda S, L: husk.leg(S, L, 1))


# ============================================================================ feet (foot space, right foot)
component("SplayedFoot", "Feet", "Grade3", "foot", origin=(0.5, 0, 0.02), roles=ROLE, sided=True, tags=["foot", "reference"],
          voxel=0.012, tris=3500)(lambda S, F: husk.foot(S, F, 1))


@component("TalonFoot", "Feet", "Grade2", "foot", sided=True, tags=["foot", "bird"], voxel=0.011, tris=3000)
def talon_foot(S, F):
    S.add(F, ellipsoid((0, 0.14, 0.04), (0.14, 0.13, 0.16)), "SkinDark", 0.08)
    for dx in (-0.1, 0.0, 0.1):
        base, mid, tip = (dx, 0.11, -0.08), (dx * 1.4, 0.09, -0.38), (dx * 1.7, 0.05, -0.62)
        S.add(F, tube([base, mid, tip], [0.06, 0.05, 0.04]), "SkinDark", 0.04)
        S.add(F, tube([tip, (tip[0], 0.04, tip[2] - 0.12), (tip[0], -0.02, tip[2] - 0.16)], [0.035, 0.02, 0.004]), "Claw", 0.01)
    S.add(F, tube([(0, 0.1, 0.1), (0, 0.06, 0.32), (0, 0.0, 0.42)], [0.05, 0.035, 0.005]), "Claw", 0.02)
    S.sub(F, sphere((0, -5.0, -0.2), 5.0), None, 0.01)


@component("HoofFoot", "Feet", "Grade3", "foot", sided=True, tags=["foot", "hoof"], voxel=0.011, tris=2500)
def hoof_foot(S, F):
    S.add(F, ellipsoid((0, 0.3, 0.02), (0.15, 0.13, 0.15)), "Skin", 0.1)
    S.add(F, round_cone((0, 0.24, 0.0), (0, 0.06, -0.05), 0.17, 0.22), "Claw", 0.04)
    S.sub(F, ellipsoid((0, 0.1, -0.26), (0.02, 0.12, 0.08)), "Void", 0.01)
    S.sub(F, sphere((0, -5.0, 0), 5.0), None, 0.01)


@component("ClawedFoot", "Feet", "Grade3", "foot", sided=True, tags=["foot", "claw"], voxel=0.011, tris=3000)
def clawed_foot(S, F):
    S.add(F, ellipsoid((0, 0.14, 0.12), (0.17, 0.14, 0.18)), "Skin", 0.1)
    S.add(F, ellipsoid((0, 0.12, -0.18), (0.22, 0.11, 0.3)), "Skin", 0.12)
    for dx in (-0.12, 0.0, 0.12):
        base, tip = (dx, 0.1, -0.38), (dx * 1.3, 0.07, -0.62)
        S.add(F, tube([base, tip], [0.065, 0.05]), "Skin", 0.04)
        S.add(F, tube([tip, (tip[0], 0.05, tip[2] - 0.14), (tip[0], -0.01, tip[2] - 0.2)], [0.04, 0.022, 0.004]), "Claw", 0.01)
    S.sub(F, sphere((0, -5.0, -0.2), 5.0), None, 0.01)
    S.noise(F, 0.005, 6)


@component("Foot", "Feet", "Grade4", "foot", sided=True, tags=["foot"], voxel=0.011, tris=2500)
def plain_foot(S, F):
    S.add(F, ellipsoid((0, 0.13, 0.1), (0.15, 0.13, 0.17)), "Skin", 0.1)
    S.add(F, ellipsoid((0, 0.1, -0.18), (0.2, 0.1, 0.3)), "Skin", 0.12)
    for dx in (-0.12, -0.04, 0.04, 0.12):
        S.add(F, tube([(dx, 0.08, -0.36), (dx * 1.15, 0.06, -0.52)], [0.05, 0.042]), "Skin", 0.04)
    S.sub(F, sphere((0, -5.0, -0.2), 5.0), None, 0.01)
    S.noise(F, 0.005, 6)


# Special Grade: no legs — a coiling serpent body carries the torso (legs still animate, invisibly).
@component("SerpentBody", "Legs", "SpecialGrade", "serpent", tags=["abnormal", "serpent"], voxel=0.03, tris=9000)
def serpent_body(S, T):
    pts = np.concatenate([bezier_points((0, -0.7, 0.05), (0, -2.6, -0.1), (0.2, -2.8, 0.9), 10),
                          bezier_points((0.2, -2.8, 0.9), (0.35, -2.95, 2.0), (-0.9, -2.9, 2.2), 9)[1:],
                          bezier_points((-0.9, -2.9, 2.2), (-1.9, -2.85, 2.2), (-1.8, -2.6, 1.2), 7)[1:]])
    radii = np.linspace(0.7, 0.12, len(pts))
    S.add(T, tube(pts, radii, k=0.1), "Skin", 0.1)
    for i in range(2, len(pts) - 2, 2):
        d = pts[i + 1] - pts[i - 1]
        side = np.cross(d, (0, 1, 0))
        n = np.cross(side, d)
        n = n / (np.linalg.norm(n) + 1e-9)
        if n[1] > 0:
            n = -n
        S.add(T, ellipsoid(pts[i] + n * radii[i] * 0.55 + (0, 0, -radii[i] * 0.4), (radii[i] * 0.75, radii[i] * 0.25, radii[i] * 0.55)), "Flesh", 0.06)
    S.sub(T, sphere((0, -8.0 - 2.9 + 0.02, 0), 8.0), None, 0.02)  # rests flat on the ground (torso center 3 above it)
    S.noise(T, 0.012, 3)


# ============================================================================ horns (surface space)
def sweep(length, r0, taper, curve, curve_dir, spiral, tilt, n):
    def rot(v, k, a):
        c, s = math.cos(a), math.sin(a)
        return v * c + np.cross(k, v) * s + k * (k @ v) * (1 - c)

    d = np.array(rot_matrix(tilt[0], 0, tilt[1]) @ np.array([0.0, 1.0, 0.0]))
    b = np.array([curve_dir[0], 0.0, curve_dir[1]], float)
    b = b - d * (b @ d)
    b /= np.linalg.norm(b)
    pts, radii = [np.zeros(3) - d * 0.03], [r0]
    a, sp = math.radians(curve / n), math.radians(spiral / n)
    for i in range(1, n + 1):
        axis = np.cross(d, b)
        if np.linalg.norm(axis) > 1e-6:
            axis /= np.linalg.norm(axis)
            d, b = rot(d, axis, a), rot(b, axis, a)
        if sp:
            b = rot(b, d / np.linalg.norm(d), sp)
        pts.append(pts[-1] + d * (length / n))
        radii.append(r0 * (1 + (taper - 1) * (i / n) ** 0.8))
    return np.array(pts), np.array(radii)


def horn(S, Hn, length, thickness, curve=40, curve_dir=(0, 1), spiral=0, tilt=(0, 0), taper=0.12, n=10, broken=0.0,
         branches=0, role="Bone", ridges=True, tip=None):
    pts, radii = sweep(length, thickness, taper, curve, curve_dir, spiral, tilt, n)
    keep = n + 1 if broken == 0 else max(2, int((n + 1) * (1 - broken)))
    S.add(Hn, ellipsoid((0, -0.05, 0), (thickness * 1.4, thickness * 0.55, thickness * 1.4)), "Skin", 0.05)
    base = max(2, keep // 4)
    S.add(Hn, tube(pts[:base + 1], radii[:base + 1], k=0.03), "BoneDark", 0.06)
    S.add(Hn, tube(pts[base:keep], radii[base:keep], k=0.03), role, 0.02)
    if ridges:
        for i in range(2, keep - 1, 2):
            S.add(Hn, torus(pts[i], radii[i] * 0.95, radii[i] * 0.12,
                            rot=_align_rot(pts[i + 1] - pts[i - 1])), "BoneDark", 0.01)
    if tip and keep == n + 1:
        S.add(Hn, tube(pts[-3:], radii[-3:] * 1.02, k=0.01), tip, 0.0)
    if broken:
        t, r = pts[keep - 1], radii[keep - 1]
        S.sub(Hn, sphere(t + (0.02, r * 0.6, 0.0), r * 0.9), "BoneDark", 0.02)
    for j in range(branches):
        i = int(n * (0.3 + 0.55 * (j + 1) / (branches + 1)))
        d = pts[i] - pts[i - 1]
        bdir = d / np.linalg.norm(d) + np.array([0, 0.2, 0.9 if j % 2 == 0 else -0.9])
        bpts, brad = sweep(length * 0.4, radii[i] * 0.75, 0.2, 25, (0, 1), 0, (0, 0), 4)
        # orient the tine along bdir
        R = _align_rot_matrix(bdir)
        S.add(Hn, tube([pts[i] + R @ p for p in bpts], brad, k=0.02), role, 0.03)


def _align_rot_matrix(v):
    v = np.asarray(v, float)
    v = v / np.linalg.norm(v)
    y = np.array([0.0, 1.0, 0.0])
    ax = np.cross(y, v)
    s, c = np.linalg.norm(ax), y @ v
    if s < 1e-8:
        return np.eye(3) if c > 0 else np.diag([1, -1, -1.0])
    ax /= s
    K = np.array([[0, -ax[2], ax[1]], [ax[2], 0, -ax[0]], [-ax[1], ax[0], 0]])
    return np.eye(3) + K * s + K @ K * (1 - c)


def _align_rot(v):
    """Euler XYZ degrees whose rotation takes +Y to v (for torus orientation)."""
    R = _align_rot_matrix(v)
    # decompose R = Rx Ry Rz
    ry = math.asin(max(-1.0, min(1.0, R[0, 2])))
    rx = math.atan2(-R[1, 2], R[2, 2])
    rz = math.atan2(-R[0, 1], R[0, 0])
    return (math.degrees(rx), math.degrees(ry), math.degrees(rz))


HORNS = {
    "StubHorn": ("Grade4", dict(length=0.35, thickness=0.11, curve=10, taper=0.35, n=5, ridges=False)),
    "StraightHorn": ("Grade4", dict(length=1.0, thickness=0.11, curve=12, curve_dir=(0.3, 1), n=8)),
    "CurvedHorn": ("Grade3", dict(length=1.3, thickness=0.13, curve=85, curve_dir=(1, 0.6), tilt=(0, -10), n=10)),
    "BackHorn": ("Grade3", dict(length=1.4, thickness=0.13, curve=70, curve_dir=(0.35, 1), tilt=(35, 0), n=10, tip="Claw")),
    "RamHorn": ("Grade3", dict(length=2.3, thickness=0.17, taper=0.25, curve=330, curve_dir=(0.25, 1), spiral=90, tilt=(20, -15), n=18)),
    "Antler": ("Grade2", dict(length=1.6, thickness=0.09, taper=0.35, curve=35, curve_dir=(1, 0.4), branches=3, role="BoneDark", ridges=False, n=9)),
    "BrokenHorn": ("Grade3", dict(length=1.3, thickness=0.14, curve=60, curve_dir=(1, 0.5), broken=0.5, n=10)),
    "MassiveHorn": ("Grade2", dict(length=2.5, thickness=0.3, taper=0.08, curve=95, curve_dir=(1, 0.25), tilt=(0, -15), n=14, tip="Claw")),
}
for _id, (_grade, _kw) in HORNS.items():
    component(_id, "Horns", _grade, "surface", sided=True, tags=["horn", "bone"], voxel=None, tris=2500,
              socket="Crown")(lambda S, Hn, kw=_kw: horn(S, Hn, **kw))


# ============================================================================ eyes, mouths (surface space)
def eye_shape(S, E, r=0.12, iris=None, lid=True, pupil=True, rim=True, role="Eye"):
    if rim:
        S.add(E, ellipsoid((0, -0.03, 0), (r * 1.9, r * 0.6, r * 1.75)), "Skin", 0.05)
        S.add(E, torus((0, r * 0.25, 0), r * 1.1, r * 0.28), "SkinDark", 0.04)
    S.add(E, sphere((0, r * 0.1, 0), r), role, 0.0)
    if iris:
        S.add(E, squashed(sphere((0, r * 0.95, 0), r * 0.55), (0, r * 0.95, 0), (1, 0.25, 1)), iris, 0.0)
    if pupil:
        S.add(E, squashed(sphere((0, r * 1.05, 0), r * 0.5), (0, r * 1.05, 0), (0.28, 0.2, 1)), "Pupil", 0.0)
    if lid:
        S.add(E, ellipsoid((0, r * 0.4, r * 0.62), (r * 1.3, r * 0.45, r * 0.55), (15, 0, 0)), "SkinDark", 0.03)


component("Eye", "Eyes", "Grade4", "surface", tags=["eye"], socket="Face", voxel=0.006, tris=1400, slots=["Eyes", "Disfigurements"])(
    lambda S, E: eye_shape(S, E))
component("GiantEye", "Eyes", "Grade3", "surface", tags=["eye"], socket="Face", voxel=0.012, tris=2500, slots=["Eyes", "Disfigurements"])(
    lambda S, E: eye_shape(S, E, r=0.38, iris="Glow"))
component("GlowPoint", "Eyes", "Grade4", "surface", tags=["eye"], socket="Face", voxel=0.005, tris=300, slots=["Eyes"], hidden=True)(
    lambda S, E: S.add(E, sphere((0, 0.0, 0), 0.07), "Glow", 0.0))


@component("EyeCluster", "Eyes", "Grade3", "surface", tags=["eye"], socket="Face", voxel=0.008, tris=3000, count=5,
           slots=["Eyes", "Disfigurements"])
def eye_cluster(S, E):
    S.add(E, ellipsoid((0, -0.06, 0), (0.42, 0.12, 0.38)), "Skin", 0.08)
    rng = np.random.RandomState(9)
    for i in range(5):
        a = i * 2.4
        rr = 0.26 * math.sqrt((i + 0.5) / 5)
        r = rng.uniform(0.05, 0.085)
        c = np.array((math.cos(a) * rr, 0.02, math.sin(a) * rr))
        S.add(E, torus(c + (0, r * 0.25, 0), r * 1.05, r * 0.26), "SkinDark", 0.03)
        S.add(E, sphere(c + (0, r * 0.1, 0), r), "Eye", 0.0)
        S.add(E, squashed(sphere(c + (0, r * 1.05, 0), r * 0.5), c + (0, r * 1.05, 0), (0.3, 0.2, 1)), "Pupil", 0.0)


@component("CompoundEye", "Eyes", "Grade3", "surface", tags=["eye", "insect"], socket="Face", voxel=0.008, tris=1500,
           slots=["Eyes", "Disfigurements"])
def compound_eye(S, E):
    S.add(E, ellipsoid((0, 0.02, 0), (0.24, 0.2, 0.28)), "Void", 0.03)
    for i in range(9):
        a = i * 2.4
        rr = 0.16 * math.sqrt((i + 0.5) / 9)
        S.add(E, sphere((math.cos(a) * rr, 0.2 - rr * 0.3, math.sin(a) * rr * 1.2), 0.025), "Eye", 0.0)


@component("GrinMouth", "Mouths", "Grade3", "surface", tags=["mouth", "teeth"], socket="Mouth", voxel=0.009, tris=4000,
           slots=["Mouths", "Disfigurements"])
def grin_mouth(S, M):
    w = 0.42

    def curve(x):
        return 0.12 * (x / w) ** 2

    S.add(M, ellipsoid((0, -0.05, 0.03), (w * 1.35, 0.12, 0.3)), "Skin", 0.08)
    S.add(M, squashed(sphere((0, 0.0, 0.06), 1), (0, 0.0, 0.06), (w * 0.95, 0.05, 0.09)), "Void", 0.0)
    xs = np.linspace(-w, w, 9)
    upper = [(x, 0.04, curve(x) + 0.12) for x in xs]
    lower = [(x, 0.04, curve(x) - 0.03) for x in xs]
    S.add(M, tube(upper, [0.05] * len(xs), k=0.03), "SkinDark", 0.04)
    S.add(M, tube(lower, [0.05] * len(xs), k=0.03), "SkinDark", 0.04)
    for x in np.linspace(-w * 0.9, w * 0.9, 11):
        z = curve(x)
        S.add(M, round_cone((x, 0.05, z + 0.09), (x, 0.06, z + 0.03), 0.028, 0.004), "Teeth", 0.0)
        S.add(M, round_cone((x + 0.02, 0.05, z - 0.0), (x + 0.02, 0.06, z + 0.055), 0.026, 0.004), "Teeth", 0.0)


@component("Maw", "Mouths", "Grade2", "surface", tags=["mouth", "teeth"], socket="Chest", voxel=0.012, tris=5000,
           slots=["Mouths", "Disfigurements"])
def maw(S, M):
    S.add(M, squashed(torus((0, 0.04, 0), 0.4, 0.13, rot=(0, 0, 0)), (0, 0.04, 0), (0.8, 1, 1.15)), "SkinDark", 0.08)
    S.add(M, ellipsoid((0, -0.02, 0), (0.46, 0.12, 0.58)), "Skin", 0.1)
    S.add(M, squashed(sphere((0, 0.0, 0), 1), (0, 0.0, 0), (0.3, 0.08, 0.42)), "Void", 0.0)
    for i in range(16):
        a = i / 16 * math.pi * 2
        o = np.array((math.cos(a) * 0.3, 0.1, math.sin(a) * 0.44))
        S.add(M, round_cone(o, o * np.array((0.55, 1.3, 0.55)), 0.04, 0.005), "Teeth", 0.0)


@component("Mandibles", "Mouths", "Grade3", "surface", tags=["mouth", "insect"], socket="Mouth", voxel=0.009, tris=2500,
           slots=["Mouths", "Disfigurements"])
def mandibles(S, M):
    S.add(M, ellipsoid((0, 0.0, 0), (0.18, 0.08, 0.12)), "SkinDark", 0.05)
    for s in (1, -1):
        pts = [X(s, (0.14, 0.02, 0)), X(s, (0.34, 0.2, -0.08)), X(s, (0.3, 0.5, -0.25)), X(s, (0.08, 0.64, -0.36))]
        S.add(M, tube(pts, [0.07, 0.06, 0.04, 0.008], k=0.02), "Claw", 0.03)
        for t in (0.35, 0.6):
            q = np.array(pts[1]) * (1 - t) + np.array(pts[2]) * t
            S.add(M, round_cone(q, q + (-0.08 * s, 0.02, 0), 0.02, 0.004), "Teeth", 0.0)


# ============================================================================ growths & disfigurements (surface space)
GROWTH = ["HeadGrowths", "Disfigurements", "TorsoGrowths"]


@component("Tumor", "Disfigurements", "Grade4", "surface", tags=["growth", "flesh"], socket="ShoulderR", voxel=0.01, tris=2500, slots=GROWTH + ["Back"])
def tumor(S, G):
    rng = np.random.RandomState(3)
    roles = ["Skin", "SkinLight", "Flesh", "SkinDark"]
    for i in range(7):
        r = rng.uniform(0.1, 0.22)
        c = (rng.uniform(-0.2, 0.2), r * 0.35 + rng.uniform(0, 0.08), rng.uniform(-0.2, 0.2))
        S.add(G, ellipsoid(c, (r, r * rng.uniform(0.7, 0.95), r * rng.uniform(0.85, 1.1))), roles[i % 4], 0.08)
    for i in range(4):
        a = i * 1.6
        S.add(G, tube([(math.cos(a) * 0.32, 0.0, math.sin(a) * 0.3), (math.cos(a) * 0.12, 0.2, math.sin(a) * 0.1)], [0.022, 0.012]), "SkinDark", 0.02)
    S.noise(G, 0.01, 8)


@component("BoneSpur", "Disfigurements", "Grade4", "surface", tags=["bone"], socket="BackOfHead", voxel=0.008, tris=1500, slots=GROWTH)
def bone_spur(S, G):
    horn(S, G, length=0.45, thickness=0.08, curve=25, curve_dir=(0, 1), taper=0.1, n=5, ridges=False)


@component("BoneProtrusion", "Disfigurements", "Grade3", "surface", tags=["bone", "wound"], socket="Forearm_R", voxel=0.008, tris=2500)
def bone_protrusion(S, G):
    S.add(G, torus((0, 0.02, 0), 0.14, 0.06), "Flesh", 0.04)
    S.add(G, ellipsoid((0, -0.03, 0), (0.24, 0.07, 0.24)), "SkinDark", 0.05)
    S.add(G, round_cone((0, -0.05, 0), (0.08, 0.6, 0.12), 0.09, 0.02), "Bone", 0.02)
    S.add(G, sphere((0.08, 0.6, 0.12), 0.035), "BoneDark", 0.02)


@component("CrackedFlesh", "Disfigurements", "Grade3", "surface", tags=["wound", "energy"], socket="ChestR", voxel=0.008, tris=3000)
def cracked_flesh(S, G):
    S.add(G, ellipsoid((0, -0.04, 0), (0.42, 0.09, 0.42)), "Skin", 0.06)
    rng = np.random.RandomState(11)
    for c in range(4):
        pts = [np.array((rng.uniform(-0.1, 0.1), 0.045, rng.uniform(-0.1, 0.1)))]
        a = rng.uniform(0, 2 * math.pi)
        for _ in range(4):
            a += rng.uniform(-0.8, 0.8)
            pts.append(pts[-1] + np.array((math.cos(a) * 0.09, -0.004, math.sin(a) * 0.09)))
        S.sub(G, tube(pts, np.linspace(0.03, 0.012, len(pts))), "VoidRim", 0.01)
        S.add(G, tube([p - (0, 0.02, 0) for p in pts], np.linspace(0.016, 0.006, len(pts))), "Glow", 0.0)


@component("ExtraEar", "Disfigurements", "Grade4", "surface", tags=["growth"], socket="TempleR", voxel=0.007, tris=1500, slots=GROWTH)
def extra_ear(S, G):
    S.add(G, squashed(ellipsoid((0, 0.12, 0.05), (0.14, 0.22, 0.18)), (0, 0.12, 0.05), (1, 1, 0.35), rot=(0, 0, 0)), "SkinDark", 0.05)
    S.sub(G, ellipsoid((0, 0.14, -0.02), (0.08, 0.15, 0.08)), "SkinDeep", 0.03)


@component("RibGrowth", "TorsoGrowths", "Grade3", "surface", tags=["bone"], socket="FlankR", voxel=0.01, tris=3000, count=1,
           slots=["TorsoGrowths", "Disfigurements"], sided=True)
def rib_growth(S, G):
    S.add(G, ellipsoid((0, -0.03, 0), (0.18, 0.08, 0.55)), "Flesh", 0.05)
    for i in range(4):
        z = (i - 1.5) * 0.24
        S.add(G, tube([(0, -0.02, z), (0.02, 0.35, z - 0.1), (-0.08, 0.55, z - 0.35), (-0.25, 0.55, z - 0.55)],
                      [0.055, 0.05, 0.04, 0.01], k=0.02), "Bone", 0.03)


# ============================================================================ tails, back (body space)
component("HuskTail", "Tails", "Grade3", "body", origin=(-0.2, 2.3, 0.55), roles=ROLE, tags=["tail", "reference"], voxel=0.018, tris=3500,
          socket="TailRoot")(lambda S, T: husk.tail(S, T))


@component("BoneTail", "Tails", "Grade2", "body", tags=["tail", "bone"], socket="TailRoot", voxel=0.016, tris=4000)
def bone_tail(S, T):
    pts = bezier_points((0, 0, 0), (0, -0.2, 1.3), (0.2, -1.4, 2.0), 14)
    S.add(T, tube(pts, np.linspace(0.1, 0.03, len(pts))), "SkinDark", 0.04)
    for i, p in enumerate(pts[:-1]):
        r = 0.19 - 0.12 * i / len(pts)
        S.add(T, ellipsoid(p, (r, r * 0.8, r)), "Bone", 0.03)
        if i % 2 == 0:
            d = pts[i + 1] - p
            up = np.cross(d, (1, 0, 0))
            up = up / np.linalg.norm(up) * np.sign(up[1] + 1e-6)
            S.add(T, round_cone(p, p + up * r * 2.2 + d * 0.3, r * 0.4, 0.005), "BoneDark", 0.02)


@component("BladeTail", "Tails", "Grade2", "body", tags=["tail", "blade"], socket="TailRoot", voxel=0.016, tris=3500)
def blade_tail(S, T):
    pts = bezier_points((0, 0, 0), (0.1, -0.3, 1.3), (0.2, -0.9, 2.2), 12)
    S.add(T, tube(pts, np.linspace(0.24, 0.07, len(pts))), "Skin", 0.06)
    tip = pts[-1]
    S.add(T, squashed(ellipsoid(tip + (0, -0.1, 0.35), (0.3, 0.12, 0.45), (20, 0, 0)), tip + (0, -0.1, 0.35), (0.25, 1, 1)), "Claw", 0.04)
    for i in range(3, 11, 2):
        p = pts[i]
        S.add(T, round_cone(p, p + (0, 0.25, 0.08), 0.05, 0.005), "Bone", 0.02)


@component("Wing", "Back", "Grade2", "body", sided=True, tags=["wing"], socket="BackR", voxel=0.02, tris=5000, joint=True)
def wing(S, W, bones_only=False):
    base, E, Wr = np.array((0, 0.05, 0.05)), np.array((0.8, 0.5, 0.45)), np.array((1.45, 0.45, 0.8))
    tips = [np.array(t) for t in ((2.2, 1.35, 1.0), (2.65, 0.55, 1.1), (2.3, -0.3, 0.95), (1.5, -0.7, 0.75))]
    role = "Bone" if bones_only else "SkinDark"
    S.add(W, ellipsoid(base, (0.26, 0.24, 0.28)), "Skin", 0.1)
    S.add(W, tube([base, E, Wr], [0.13, 0.1, 0.08]), role, 0.05)
    for t in tips:
        S.add(W, tube([Wr, Wr + (t - Wr) * 0.55, t], [0.06, 0.045, 0.012]), role, 0.03)
        if bones_only:
            S.add(W, round_cone(t, t + (t - Wr) * 0.15 + (0, 0.1, 0), 0.02, 0.004), "BoneDark", 0.01)
    if not bones_only:
        for a, b in zip(tips[:-1], tips[1:]):
            S.add(W, triangle(Wr, a, b, 0.018), "Membrane", 0.02)
        S.add(W, triangle(base, Wr, tips[-1], 0.018), "Membrane", 0.02)
        S.add(W, triangle(base, E, Wr, 0.018), "Membrane", 0.02)


component("BoneWing", "Back", "Grade1", "body", sided=True, tags=["wing", "bone"], socket="BackR", voxel=0.02, tris=4000, joint=True)(
    lambda S, W: wing(S, W, bones_only=True))


@component("Tendril", "Back", "Grade2", "body", tags=["tendril"], socket="UpperBack", voxel=0.014, tris=3000, joint=True)
def tendril(S, T):
    pts = bezier_points((0, 0, 0), (0.1, 0.9, 0.5), (0.35, 0.8, 1.4), 12)
    S.add(T, tube(pts, np.linspace(0.14, 0.02, len(pts))), "Skin", 0.05)
    for i in range(2, 10):
        d = pts[i + 1] - pts[i - 1]
        n = np.cross(d, (1, 0, 0))
        n /= np.linalg.norm(n)
        S.add(T, sphere(pts[i] - n * (0.13 - 0.01 * i), 0.03), "Flesh", 0.02)


@component("Spikes", "Back", "Grade3", "body", tags=["bone", "spine"], socket="UpperBack", voxel=0.012, tris=3000,
           slots=["Back", "Disfigurements"])
def spikes(S, T):
    for i in range(6):
        y = -i * 0.28
        L = 0.62 - i * 0.07
        S.add(T, ellipsoid((0, y, 0.0), (0.12, 0.09, 0.09)), "SkinDark", 0.06)
        S.add(T, round_cone((0, y, 0.02), (0, y + L * 0.55, L * 0.85), 0.085, 0.006), "Bone", 0.04)


@component("Shell", "Back", "Grade2", "body", tags=["armor", "shell"], socket="Back", voxel=0.02, tris=4500)
def shell(S, T):
    for r in range(4):
        y = 0.55 - r * 0.42
        S.add(T, ellipsoid((0, y, 0.12 + r * 0.02), (0.95 - r * 0.08, 0.3, 0.3), (-15, 0, 0)), "SkinDark" if r % 2 else "SkinDeep", 0.05)
        S.add(T, tube([(-0.85 + r * 0.08, y - 0.18, 0.3), (0, y - 0.22, 0.45), (0.85 - r * 0.08, y - 0.18, 0.3)], [0.04, 0.05, 0.04]), "BoneDark", 0.03)


# ============================================================================ bake
# Triangle budget: fraction of each component's authored `tris`. 0.25 keeps the silhouette
# and (with the textures carrying fine detail) looks near-identical to full detail, while
# putting a typical Curse around 13–22k triangles. MIN_TRIS keeps tiny parts round.
BUDGET = 0.25
MIN_TRIS = 300

def sculpt_component(c):
    S = Sculpt(c["id"])
    name = c["id"]
    c["fn"](S, name)
    origin = np.asarray(c.get("origin", (0, 0, 0)), float)
    S.shift[name] = tuple(-origin)
    return S


def auto_voxel(S, name, want):
    lo, hi = S.bounds(name)
    ext = (hi - lo).max()
    if want:
        return want
    return float(np.clip(ext / 120, 0.005, 0.03))


def bake_all(only=None, fast=False, render=True, budget=None):
    budget = BUDGET if budget is None else budget
    from PIL import Image, ImageDraw
    from sculpt import raster

    out_dir = os.path.join(ROOT, "assets", "meshes", "library")
    os.makedirs(out_dir, exist_ok=True)
    manifest_path = os.path.join(ROOT, "assets", "meshes", "library", "Library.json")
    lua_path = os.path.join(ROOT, "src", "shared", "CurseBody", "Meshes", "Library.lua")
    manifest = {"components": {}}
    if os.path.exists(manifest_path) and only:
        manifest = json.load(open(manifest_path))
    by_category = {}
    previews = {}
    for cid, c in COMPONENTS.items():
        if only and cid not in only:
            continue
        t0 = time.time()
        S = sculpt_component(c)
        voxel = auto_voxel(S, cid, c.get("voxel")) * (1.7 if fast else 1.0)
        max_tris = max(MIN_TRIS, int(c.get("tris", 4000) * budget))
        verts, faces, normals, face_mat = mesh_bone(S, cid, voxel=voxel, max_tris=max_tris, smooth_iters=8)
        roles = c.get("roles", {})
        pieces, meshes = [], []
        border = texture.border_flags(faces, face_mat, len(verts))
        sdf = (lambda q, b=cid, S=S: S.evaluate(b, q)[0])
        matfn = (lambda q, b=cid, S=S: S.evaluate(b, q)[1])
        for mat in sorted(set(face_mat)):
            if not mat:
                continue
            f = faces[face_mat == mat]
            if len(f) < 4:
                continue
            role = roles.get(mat, mat)
            pname = f"{cid}_{role}"
            while any(p["name"] == pname for p in pieces):
                pname += "2"
            vmap, idx, uvs, img = texture.bake_piece(verts, normals, f, border, mat, sdf, matfn=matfn)
            tex = None
            if img is not None:
                os.makedirs(os.path.join(out_dir, "textures"), exist_ok=True)
                tex = pname + ".png"
                img.save(os.path.join(out_dir, "textures", tex), optimize=True)
            V, N = verts[vmap], normals[vmap]
            lo, hi = V.min(0), V.max(0)
            center = (lo + hi) / 2
            pieces.append(dict(name=pname, role=role, offset=list(np.round(center, 4)), size=list(np.round(hi - lo, 4)),
                               tris=int(len(idx)), texture=tex))
            meshes.append(dict(name=pname, v=V - center, n=N, f=idx, uv=uvs, mtl=pname, tex=tex, center=center))
        cat = c["slot"]
        by_category.setdefault(cat, [])
        by_category[cat] = [m for m in by_category[cat] if not m["name"].startswith(cid + "_")]
        for m in meshes:
            by_category[cat].append(m)
            if c.get("sided"):
                # mirrored left piece: same UVs, same texture
                by_category[cat].append(dict(m, name=m["name"] + "_L", v=m["v"] * np.array((-1, 1, 1)),
                                             n=m["n"] * np.array((-1, 1, 1)), f=m["f"][:, ::-1]))
        entry = {k: c[k] for k in ("slot", "grade", "space") if k in c}
        for k in ("tags", "sockets", "layout", "variants", "defaults", "pivot", "span", "socket", "count", "slots", "hidden",
                  "legExtra", "joint"):
            if c.get(k) is not None:
                entry[k] = c[k]
        entry["sided"] = bool(c.get("sided"))
        entry["pieces"] = pieces
        manifest["components"][cid] = entry
        previews[cid] = [dict(verts=m["v"] + m["center"], faces=m["f"], normals=m["n"], uv=m["uv"],
                              tex=load_tex(out_dir, m["tex"]), color=ROLE_PREVIEW.get(p["role"], (0.6, 0.2, 0.2)),
                              neon=p["role"] in ("Eye", "Glow")) for m, p in zip(meshes, pieces)]
        print(f"  {cid:20s} {sum(p['tris'] for p in pieces):6d} tris {len(pieces)} pieces ({time.time() - t0:.1f}s)")

    # one OBJ per category: import each once into Studio
    for cat, meshes in by_category.items():
        path = os.path.join(out_dir, f"Curse{cat}.obj")
        write_category(path, meshes, merge=bool(only))
    os.makedirs(os.path.dirname(manifest_path), exist_ok=True)
    json.dump(manifest, open(manifest_path, "w"), indent=1, sort_keys=True)
    os.makedirs(os.path.dirname(lua_path), exist_ok=True)
    write_lua_manifest(manifest, lua_path)
    total = sum(p["tris"] for c in manifest["components"].values() for p in c["pieces"])
    print(f"library: {len(manifest['components'])} components, {total} triangles (right side)")
    if render:
        render_sheet(previews)
    return manifest


ROLE_PREVIEW = {
    "Skin": (0.66, 0.17, 0.2), "SkinLight": (0.75, 0.25, 0.27), "SkinDark": (0.45, 0.1, 0.13), "SkinDeep": (0.25, 0.05, 0.08),
    "Flesh": (0.88, 0.8, 0.64), "FleshDark": (0.66, 0.56, 0.42), "Bone": (0.87, 0.83, 0.74), "BoneDark": (0.66, 0.61, 0.52),
    "Void": (0.04, 0.03, 0.03), "VoidRim": (0.18, 0.11, 0.1), "Eye": (0.9, 0.89, 0.84), "Pupil": (0.08, 0.04, 0.04),
    "Claw": (0.11, 0.08, 0.08), "Teeth": (0.91, 0.88, 0.8), "Membrane": (0.35, 0.07, 0.1), "Spot": (0.14, 0.03, 0.05),
    "Glow": (1.0, 0.35, 0.24),
}


def load_tex(out_dir, name):
    if not name:
        return None
    from PIL import Image
    return np.asarray(Image.open(os.path.join(out_dir, "textures", name)).convert("RGBA"), float) / 255


def write_category(path, meshes, merge=False):
    """One OBJ (+ MTL) per slot. Objects are centered on themselves; textures live in textures/."""
    names = {m["name"] for m in meshes}
    items = []
    if merge and os.path.exists(path):
        items = [m for m in read_objects(path) if m["name"] not in names]
    items += meshes
    base = os.path.splitext(path)[0]
    mtl_name = os.path.basename(base) + ".mtl"
    with open(base + ".mtl", "w") as fh:
        seen = set()
        for m in items:
            if m["mtl"] in seen:
                continue
            seen.add(m["mtl"])
            fh.write(f"newmtl {m['mtl']}\nKd 1 1 1\nd 1\n")
            if m.get("tex"):
                fh.write(f"map_Kd textures/{m['tex']}\n")
            fh.write("\n")
    with open(path, "w") as fh:
        fh.write(f"mtllib {mtl_name}\n")
        vbase = 1
        for m in items:
            fh.write(f"o {m['name']}\nusemtl {m['mtl']}\n")
            fh.write("".join(f"v {a:.4f} {b:.4f} {c:.4f}\n" for a, b, c in m["v"]))
            fh.write("".join(f"vt {a:.5f} {b:.5f}\n" for a, b in m["uv"]))
            fh.write("".join(f"vn {a:.4f} {b:.4f} {c:.4f}\n" for a, b, c in m["n"]))
            ff = m["f"] + vbase
            fh.write("".join(f"f {a}/{a}/{a} {b}/{b}/{b} {c}/{c}/{c}\n" for a, b, c in ff))
            vbase += len(m["v"])


def read_objects(path):
    """Parse an OBJ written by write_category back into objects (local indices)."""
    mtl_tex = {}
    mtl_path = os.path.splitext(path)[0] + ".mtl"
    if os.path.exists(mtl_path):
        cur = None
        for line in open(mtl_path):
            if line.startswith("newmtl "):
                cur = line.split()[1]
                mtl_tex[cur] = None
            elif line.startswith("map_Kd ") and cur:
                mtl_tex[cur] = os.path.basename(line.split()[1])
    objs, cur, vcount = [], None, 0
    for line in open(path):
        if line.startswith("o "):
            cur = dict(name=line[2:].strip(), v=[], uv=[], n=[], f=[], base=vcount, mtl=None)
            objs.append(cur)
        elif line.startswith("usemtl "):
            cur["mtl"] = line.split()[1]
            cur["tex"] = mtl_tex.get(cur["mtl"])
        elif line.startswith("v "):
            cur["v"].append(tuple(map(float, line.split()[1:])))
            vcount += 1
        elif line.startswith("vt "):
            cur["uv"].append(tuple(map(float, line.split()[1:3])))
        elif line.startswith("vn "):
            cur["n"].append(tuple(map(float, line.split()[1:])))
        elif line.startswith("f "):
            cur["f"].append([int(t.split("/")[0]) - 1 - cur["base"] for t in line.split()[1:]])
    for o in objs:
        for k in ("v", "uv", "n", "f"):
            o[k] = np.array(o[k])
    return objs


def write_lua_manifest(manifest, path):
    sys.path.insert(0, HERE)
    from bake import to_lua
    with open(path, "w") as fh:
        fh.write("-- GENERATED by tools/sculpt/library.py — do not edit. Mesh library manifest:\n"
                 "-- every component's MeshPart pieces (name, palette role, offset, size), sockets, layout.\n")
        fh.write("return " + to_lua(manifest) + "\n")


def render_sheet(previews):
    from PIL import Image, ImageDraw
    from sculpt import raster
    out = os.path.join(ROOT, "previews", "mesh", "library")
    os.makedirs(out, exist_ok=True)
    for cid, pieces in previews.items():
        if not pieces:
            continue
        allv = np.concatenate([p["verts"][np.unique(p["faces"])] for p in pieces])
        lo, hi = allv.min(0), allv.max(0)
        ext = max((hi - lo).max(), 0.3)
        ppu = 200 / ext
        img = raster.render(pieces, 30, pitch=-12, size=(260, 260), center=(lo + hi) / 2, ppu=ppu)
        ImageDraw.Draw(img).text((6, 4), cid, fill=(20, 20, 20))
        img.save(os.path.join(out, f"{cid}.png"))


def refresh_meta():
    """Rewrite the manifest's metadata (sockets, layout, grades …) without re-meshing."""
    path = os.path.join(ROOT, "assets", "meshes", "library", "Library.json")
    manifest = json.load(open(path))
    for cid, c in COMPONENTS.items():
        entry = manifest["components"].get(cid)
        if not entry:
            continue
        for k in ("slot", "grade", "space", "tags", "sockets", "layout", "variants", "defaults", "pivot", "span", "socket",
                  "count", "slots", "hidden", "legExtra", "joint"):
            if c.get(k) is not None:
                entry[k] = c[k]
        entry["sided"] = bool(c.get("sided"))
    json.dump(manifest, open(path, "w"), indent=1, sort_keys=True)
    write_lua_manifest(manifest, os.path.join(ROOT, "src", "shared", "CurseBody", "Meshes", "Library.lua"))
    print("manifest metadata refreshed")


if __name__ == "__main__":
    if "--meta-only" in sys.argv:
        refresh_meta()
        sys.exit(0)
    only = None
    if "--only" in sys.argv:
        only = set(sys.argv[sys.argv.index("--only") + 1].split(","))
    budget = float(sys.argv[sys.argv.index("--budget") + 1]) if "--budget" in sys.argv else None
    bake_all(only=only, fast="--fast" in sys.argv, render="--no-render" not in sys.argv, budget=budget)
