"""Geometry spec for the red creature, rebuilt on a classic R6 rig.

Single source of truth: build.py turns this into the Roblox build script
and into preview renders, so the previews show exactly what Studio builds.

Conventions (same as Roblox):
  * studs, -Z is the character's front, +X is the character's right side
  * rotations are CFrame.Angles(rx, ry, rz) in degrees (X, then Y, then Z)
  * every piece is an ellipsoid (a Part with a Sphere SpecialMesh) welded to
    one base part; `pos` / `rot` are relative to that base part's CFrame
"""

# ---------------------------------------------------------------------------
# Materials / colors (sampled from and tuned against the reference)
# ---------------------------------------------------------------------------
PALETTE = {
    #  name          RGB               material        (neon = glows)
    "red":        ((148, 32, 40),   "SmoothPlastic"),
    "red_hi":     ((172, 50, 56),   "SmoothPlastic"),
    "red_dark":   ((104, 20, 28),   "SmoothPlastic"),
    "red_deep":   ((58, 10, 16),    "SmoothPlastic"),
    "beige":      ((204, 186, 150), "SmoothPlastic"),
    "beige_dark": ((158, 136, 102), "SmoothPlastic"),
    "cavity_rim": ((46, 28, 26),    "Slate"),
    "cavity":     ((10, 8, 8),      "Slate"),
    "claw":       ((28, 20, 20),    "SmoothPlastic"),
    "claw_tip":   ((196, 190, 180), "SmoothPlastic"),
    "spot":       ((36, 8, 12),     "SmoothPlastic"),
    "eye":        ((228, 226, 214), "Neon"),
}

# ---------------------------------------------------------------------------
# R6 base body (standard classic sizes; kept so default R6 animations work)
# ---------------------------------------------------------------------------
R6_SIZES = {
    "HumanoidRootPart": (2, 2, 1),
    "Torso": (2, 2, 1),
    "Head": (2, 1, 1),
    "Right Arm": (1, 2, 1),
    "Left Arm": (1, 2, 1),
    "Right Leg": (1, 2, 1),
    "Left Leg": (1, 2, 1),
}

# Motor6D joints. Names and hierarchy are the standard R6 ones; only the C0
# positions move, to build the hunch in (head low + forward, shoulders wide +
# forward, hips wider). Animations write Motor6D.Transform, so they still play.
# Rotation parts are the standard R6 matrices ("rot" key names below).
JOINTS = [
    # name,             part0,              part1,        C0 pos,               C1 pos,           rot
    ("RootJoint",      "HumanoidRootPart", "Torso",      (0, 0, 0),            (0, 0, 0),        "root"),
    ("Neck",           "Torso",            "Head",       (0, 0.35, -0.95),     (0, -0.5, 0),     "root"),
    ("Right Shoulder", "Torso",            "Right Arm",  (1.3, 0.3, -0.35),   (-0.5, 0.5, 0),   "right"),
    ("Left Shoulder",  "Torso",            "Left Arm",   (-1.3, 0.3, -0.35),  (0.5, 0.5, 0),    "left"),
    ("Right Hip",      "Torso",            "Right Leg",  (1.15, -1, 0.05),     (0.5, 1, 0),      "right"),
    ("Left Hip",       "Torso",            "Left Leg",   (-1.15, -1, 0.05),    (-0.5, 1, 0),     "left"),
]

# Tail: a chain of invisible joint parts driven by Motor6Ds so it can be
# animated. Each segment hangs along its own -Y axis from its top end.
#   (length, radius, joint rotation relative to the parent segment)
TAIL_ROOT = ("Torso", (-0.25, -0.8, 0.5))   # lower back, slightly to the left
TAIL = [
    (0.95, 0.46, (-88, 0, -16)),
    (0.95, 0.38, (24, 0, -16)),
    (0.90, 0.30, (28, 0, -10)),
    (0.75, 0.22, (14, 0, 0)),
    (0.60, 0.15, (-88, 0, 30)),
]


def P(part, group, name, pos, size, rot=(0, 0, 0), color="red"):
    return dict(part=part, group=group, name=name, pos=pos, size=size, rot=rot, color=color)


def mirror(pieces, from_side="Right", to_side="Left"):
    """Mirror right-side pieces to the left (flip X; Y and Z rotations negate)."""
    out = []
    for p in pieces:
        q = dict(p)
        q["part"] = p["part"].replace(from_side, to_side)
        q["group"] = p["group"].replace(from_side, to_side)
        q["name"] = p["name"].replace(from_side, to_side)
        x, y, z = p["pos"]
        rx, ry, rz = p["rot"]
        q["pos"] = (-x, y, z)
        q["rot"] = (rx, -ry, -rz)
        out.append(q)
    return out


# ---------------------------------------------------------------------------
# HEAD  (head-local; the head sits low and forward, half buried in the hump)
# ---------------------------------------------------------------------------
HEAD = [
    # big bulbous cranium sweeping up and back into the hump
    P("Head", "Head", "Cranium",      (0, 0.40, 0.30),    (1.95, 1.75, 2.35), (38, 0, 0)),
    P("Head", "Head", "CraniumBack",  (0.05, 0.85, 0.75), (1.55, 1.15, 1.45), (25, 0, 6), "red_hi"),
    P("Head", "Head", "Face",         (0, -0.10, -0.50),  (1.65, 1.25, 1.15), (-12, 0, 0)),
    P("Head", "Head", "Snout",        (0, -0.35, -0.85),  (1.20, 0.80, 0.70), (-25, 0, 0), "red_hi"),
    # heavy brow + folds (asymmetric on purpose)
    P("Head", "Head", "Brow",         (0.05, 0.30, -0.72), (1.50, 0.38, 0.62), (-30, 0, 4), "red"),
    P("Head", "Head", "BrowCrease",   (0.05, 0.50, -0.55), (1.10, 0.12, 0.40), (-30, 0, 4), "red_dark"),
    P("Head", "Head", "FoldR1",       (0.82, 0.40, 0.15),  (0.34, 0.30, 1.50), (38, 0, -10), "red_hi"),
    P("Head", "Head", "FoldR2",       (0.78, 0.00, 0.10),  (0.30, 0.22, 1.30), (30, 0, -18), "red_dark"),
    P("Head", "Head", "FoldL1",       (-0.84, 0.48, 0.25), (0.34, 0.32, 1.60), (40, 0, 12), "red_hi"),
    P("Head", "Head", "FoldL2",       (-0.80, 0.05, 0.05), (0.30, 0.22, 1.20), (28, 0, 20), "red_dark"),
    P("Head", "Head", "FoldTop",      (0, 1.15, 0.45),     (1.10, 0.22, 0.70), (35, 0, 0), "red_dark"),
    # dark speckles on the crown
    P("Head", "Head", "Spot1",        (0.25, 1.22, 0.05),  (0.26, 0.12, 0.24), (30, 0, 0), "spot"),
    P("Head", "Head", "Spot2",        (-0.15, 1.30, 0.35), (0.30, 0.12, 0.26), (35, 0, 0), "spot"),
    P("Head", "Head", "Spot3",        (0.50, 1.02, 0.45),  (0.20, 0.10, 0.20), (35, 0, -30), "spot"),
    P("Head", "Head", "Spot4",        (-0.42, 1.10, -0.02), (0.18, 0.10, 0.18), (25, 0, 30), "spot"),
    P("Head", "Head", "Spot5",        (0.05, 1.05, -0.28), (0.16, 0.09, 0.16), (20, 0, 0), "spot"),
    P("Head", "Head", "Spot6",        (0.35, 1.32, 0.55),  (0.14, 0.08, 0.14), (40, 0, 0), "spot"),
]

EYES = [
    # small, pale, sunk into dark sockets on the sides of the face
    P("Head", "Eyes", "RightSocket",  (0.70, 0.05, -0.62), (0.40, 0.36, 0.30), (0, -50, 0), "red_deep"),
    P("Head", "Eyes", "RightEye",     (0.76, 0.05, -0.68), (0.20, 0.19, 0.14), (0, -50, 0), "eye"),
    P("Head", "Eyes", "LeftSocket",   (-0.70, 0.05, -0.62), (0.40, 0.36, 0.30), (0, 50, 0), "red_deep"),
    P("Head", "Eyes", "LeftEye",      (-0.76, 0.05, -0.68), (0.20, 0.19, 0.14), (0, 50, 0), "eye"),
]

# face tendrils hanging from under the snout (the "compressed, downward face")
FACE_TENDRILS = []
for i, (x, length, sway) in enumerate([(-0.42, 0.55, 10), (-0.21, 0.70, 4), (0.0, 0.78, -2),
                                       (0.21, 0.68, -6), (0.42, 0.52, -12)]):
    FACE_TENDRILS += [
        P("Head", "Head", f"Tendril{i+1}A", (x, -0.70, -0.88),
          (0.28, 0.62, 0.30), (-8, 0, sway), "red"),
        P("Head", "Head", f"Tendril{i+1}B", (x * 1.05 - sway * 0.004, -0.72 - length * 0.60, -0.92),
          (0.22, length * 0.80, 0.24), (-4, 0, sway * 1.6), "red_hi" if i % 2 else "red_dark"),
    ]

# ---------------------------------------------------------------------------
# TORSO  (torso-local)
# ---------------------------------------------------------------------------
TORSO = [
    # the hump: the torso dominates the silhouette
    P("Torso", "Torso", "Hump",          (0, 0.75, 0.40),    (2.80, 2.60, 2.30), (-28, 0, 0)),
    P("Torso", "Torso", "HumpTop",       (0.10, 1.40, 0.35), (2.20, 1.30, 1.80), (-32, 0, 5), "red_hi"),
    P("Torso", "Torso", "HumpRidge",     (-0.30, 1.05, 0.95), (1.60, 0.30, 1.20), (-40, 0, 10), "red_dark"),
    P("Torso", "Torso", "RightShoulderMass", (1.20, 0.60, -0.15), (1.45, 1.50, 1.80), (0, 0, 22)),
    P("Torso", "Torso", "RightShoulderFold", (1.25, 1.00, 0.10), (1.00, 0.32, 1.40), (-10, 0, 30), "red_hi"),
    P("Torso", "Torso", "RightNeckWrap", (0.72, 0.75, -0.70), (1.10, 0.95, 1.15), (-20, 0, 30)),
    P("Torso", "Torso", "RightFlank",    (0.95, -0.30, 0.15), (0.70, 1.50, 1.20), (0, 0, 5)),
    # pelvis / hips
    P("Torso", "Torso", "PelvisBack",    (0, -0.70, 0.25),   (2.40, 1.20, 1.40), (10, 0, 0)),
]
TORSO_LEFT_EXTRA = [
    P("Torso", "Torso", "LeftShoulderFold2", (-1.25, 0.25, -0.75), (0.30, 1.10, 0.45), (0, 0, -12), "red_dark"),
]

# exposed beige flesh on the front: layered, ribbed, not clothing
BEIGE = [
    P("Torso", "BeigeFlesh", "Chest",        (0.05, 0.10, -0.35), (2.35, 2.00, 1.40), (0, 0, 0), "beige"),
    P("Torso", "BeigeFlesh", "RightPec",     (0.70, 0.45, -0.75), (1.00, 1.10, 0.65), (0, 0, -10), "beige"),
    P("Torso", "BeigeFlesh", "LeftPec",      (-0.70, 0.40, -0.72), (0.95, 1.00, 0.60), (0, 0, 10), "beige"),
    P("Torso", "BeigeFlesh", "Belly",        (0, -0.70, -0.30),  (2.00, 1.10, 1.30), (0, 0, 0), "beige"),
    P("Torso", "BeigeFlesh", "Groin",        (0, -1.10, -0.25),  (1.10, 0.70, 1.00), (0, 0, 0), "beige"),
]
for j, y in enumerate([0.75, 0.48, 0.21, -0.06]):
    BEIGE.append(P("Torso", "BeigeFlesh", f"RightRib{j+1}", (0.78, y, -0.98 + abs(y) * 0.05),
                   (0.62, 0.10, 0.22), (0, 12, -12 + j * 3), "beige_dark"))
    BEIGE.append(P("Torso", "BeigeFlesh", f"LeftRib{j+1}", (-0.80, y - 0.04, -0.95 + abs(y) * 0.05),
                   (0.55, 0.10, 0.22), (0, -12, 12 - j * 3), "beige_dark"))
for j, y in enumerate([-0.55, -0.80, -1.05, -1.30]):
    BEIGE.append(P("Torso", "BeigeFlesh", f"BellyRidge{j+1}", (0, y, -0.93 + j * 0.03),
                   (1.45 - j * 0.12, 0.09, 0.30), (0, 0, 0), "beige_dark"))

# the black organic cavity in the chest (a void, not a shirt)
CAVITY = [
    P("Torso", "Cavity", "CavityRim",   (-0.15, 0.10, -1.00), (1.45, 2.05, 0.36), (0, 0, 6), "cavity_rim"),
    P("Torso", "Cavity", "Cavity",      (-0.15, 0.10, -1.07), (1.28, 1.88, 0.32), (0, 0, 6), "cavity"),
    P("Torso", "Cavity", "CavityDrip",  (-0.02, -0.85, -1.00), (0.45, 0.80, 0.24), (0, 0, -4), "cavity"),
]

# ---------------------------------------------------------------------------
# ARMS (right arm authored, left mirrored). Arm-local, 1x2x1, pivot at top.
# The shell runs past the base arm so the fists hang near the knees.
# ---------------------------------------------------------------------------
RIGHT_ARM = [
    P("Right Arm", "RightArm", "Deltoid",      (0.05, 0.85, 0.00),  (1.35, 0.95, 1.35), (0, 0, 10), "red_hi"),
    P("Right Arm", "RightArm", "UpperArm",     (0.06, 0.25, 0.02),  (1.20, 1.70, 1.20)),
    P("Right Arm", "RightArm", "Elbow",        (0.12, -0.50, 0.22), (0.90, 0.70, 0.85), (0, 0, 0), "red_dark"),
    P("Right Arm", "RightArm", "Forearm",      (0.08, -0.95, -0.08), (1.15, 1.70, 1.10), (8, 0, 0)),
    P("Right Arm", "RightArm", "ForearmBeige", (-0.38, -0.85, -0.20), (0.45, 1.60, 0.75), (8, 0, 4), "beige"),
    P("Right Arm", "RightArm", "ForearmRidge", (0.48, -0.80, -0.10), (0.30, 1.30, 0.60), (8, 0, -4), "red_hi"),
    P("Right Arm", "RightArm", "Fist",         (0.08, -1.85, -0.18), (1.30, 1.10, 1.25)),
    P("Right Arm", "RightArm", "Thumb",        (-0.48, -1.75, -0.58), (0.40, 0.70, 0.45), (-20, 0, 25), "red_hi"),
]
for k, x in enumerate([-0.36, -0.08, 0.20, 0.47]):
    RIGHT_ARM.append(P("Right Arm", "RightArm", f"Finger{k+1}", (x, -2.18, -0.52),
                       (0.36, 0.58, 0.62), (-30, 0, 0), "red_hi"))
    RIGHT_ARM.append(P("Right Arm", "RightArm", f"Claw{k+1}", (x, -2.40, -0.25),
                       (0.18, 0.22, 0.30), (20, 0, 0), "claw"))
for k, y in enumerate([-0.20, -0.55, -0.90, -1.25]):
    RIGHT_ARM.append(P("Right Arm", "RightArm", f"BeigeRidge{k+1}", (-0.52, y - 0.2, -0.28),
                       (0.18, 0.08, 0.60), (8, 0, 4), "beige_dark"))

# ---------------------------------------------------------------------------
# LEGS (right leg authored, left mirrored). Leg-local, 1x2x1, sole at y=-1.
# ---------------------------------------------------------------------------
RIGHT_LEG = [
    P("Right Leg", "RightLeg", "Thigh",       (0.08, 0.50, 0.08),  (1.35, 1.55, 1.40)),
    P("Right Leg", "RightLeg", "ThighBeige",  (-0.10, 0.40, -0.40), (1.05, 1.50, 0.85), (-4, 0, 0), "beige"),
    P("Right Leg", "RightLeg", "Knee",        (0.02, -0.18, -0.12), (1.00, 0.75, 0.95), (0, 0, 0), "red_hi"),
    P("Right Leg", "RightLeg", "Shin",        (0.02, -0.42, 0.05), (0.95, 1.30, 1.00)),
    P("Right Leg", "RightLeg", "CalfBeige",   (-0.32, -0.38, 0.05), (0.38, 1.10, 0.62), (0, 0, 4), "beige"),
    P("Right Leg", "RightLeg", "Ankle",       (0.00, -0.78, 0.08), (0.82, 0.45, 0.85)),
    P("Right Leg", "RightLeg", "Foot",        (0.00, -0.80, -0.50), (1.15, 0.42, 1.70)),
    P("Right Leg", "RightLeg", "Heel",        (0.00, -0.82, 0.38), (0.72, 0.36, 0.60), (0, 0, 0), "red_dark"),
]
for k, (x, spread) in enumerate([(-0.38, 8), (-0.13, 3), (0.12, -3), (0.37, -9)]):
    RIGHT_LEG.append(P("Right Leg", "RightLeg", f"Toe{k+1}", (x, -0.87, -1.35),
                       (0.30, 0.26, 0.95), (0, spread, 0), "red_hi" if k % 2 else "red"))
    RIGHT_LEG.append(P("Right Leg", "RightLeg", f"ToeClaw{k+1}", (x - spread * 0.008, -0.92, -1.85),
                       (0.17, 0.12, 0.30), (-10, spread, 0), "claw"))
for k, y in enumerate([0.85, 0.55, 0.25]):
    RIGHT_LEG.append(P("Right Leg", "RightLeg", f"ThighRidge{k+1}", (-0.15, y, -0.76),
                       (0.70, 0.08, 0.20), (0, 0, 0), "beige_dark"))


# ---------------------------------------------------------------------------
# TAIL (pieces attach to the tail joint parts Tail1..Tail5)
# ---------------------------------------------------------------------------
TAIL_PIECES = []
for i, (length, radius, _) in enumerate(TAIL):
    seg = f"Tail{i+1}"
    TAIL_PIECES.append(P(seg, "Tail", f"{seg}Flesh", (0, 0, 0),
                         (radius * 2, length * 1.35, radius * 2), (0, 0, 0), "red" if i % 2 == 0 else "red_hi"))
    TAIL_PIECES.append(P(seg, "Tail", f"{seg}Underside", (radius * 0.25, 0, radius * 0.35),
                         (radius * 1.3, length * 1.2, radius * 1.4), (0, 0, 0), "red_dark"))
TAIL_PIECES += [
    P("Tail5", "Tail", "TailClaw",     (0, -0.55, 0),    (0.16, 0.60, 0.16), (0, 0, 0), "claw"),
    P("Tail5", "Tail", "TailClawTip",  (0, -0.85, 0.02), (0.08, 0.28, 0.08), (0, 0, 0), "claw_tip"),
]


PIECES = (HEAD + EYES + FACE_TENDRILS
          + TORSO + mirror([p for p in TORSO if p["name"].startswith("Right")]) + TORSO_LEFT_EXTRA
          + BEIGE + CAVITY
          + RIGHT_ARM + mirror(RIGHT_ARM)
          + RIGHT_LEG + mirror(RIGHT_LEG)
          + TAIL_PIECES)

