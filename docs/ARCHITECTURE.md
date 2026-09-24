# Curse Body System — Architecture

A data-driven anatomy framework for player-controlled Curses on the classic
Roblox **R6** rig. One appearance table in, one grotesque (and fully animated)
body out. The red creature in `reference/` is the quality bar: it is rebuilt
here as one preset (`CrimsonHusk`), not as the system itself.

```
 profile (DataStore)            catalog (data + builders)          character
 ┌──────────────────┐           ┌───────────────────────┐          ┌──────────────────────┐
 │ Grade            │           │ Heads  Horns  Eyes    │          │ R6 rig (6 parts,     │
 │ Appearance ──────┼─sanitize─▶│ Mouths Torsos Arms …  │─build──▶ │ standard Motor6Ds)   │
 │ Forms / Unlocks  │ (grade)   │ Transformations       │          │ └ CurseBody (Model)  │
 └──────────────────┘           └───────────────────────┘          │   ├ Head/ Torso/ …   │
                                                                   │   └ sockets, limbs   │
                                                                   └──────────────────────┘
```

Code lives in `src/` (Rojo layout, see `default.project.json`):

| Path | Becomes | Role |
|---|---|---|
| `src/shared/CurseBody/` | `ReplicatedStorage.CurseBody` | the framework (ModuleScripts) |
| `src/shared/CurseBody/Catalog/` | | every body part, horn, growth, transformation |
| `src/server/CurseService.server.lua` | `ServerScriptService` | loads/saves profiles, builds bodies, handles transformation requests |
| `src/client/CurseClient.client.lua` | `StarterPlayerScripts` | tail/tendril sway, extra-limb motion, grow-in effects |

---

## 1. R6 base rig structure

The rig is never replaced. Every Curse is a normal R6 character:

```
Character (Model)
├ HumanoidRootPart ── RootJoint ──▶ Torso
├ Torso ── Neck ──▶ Head
│       ── Right Shoulder / Left Shoulder ──▶ Right Arm / Left Arm
│       ── Right Hip / Left Hip ──▶ Right Leg / Left Leg
├ Humanoid (RigType R6)
└ CurseBody (Model)   ← everything this system adds
```

* The six body parts keep their **standard names, sizes and Motor6D names**, so
  the default `Animate` script and any R6 animation play unchanged.
* The base parts become invisible once a region variant covers them; they still
  provide collisions, hit detection and the joints everything hangs from.
* Posture is joint layout, not part size: the body type (and transformations)
  move the Motor6D **C0** positions (head low and forward, wide shoulders, wide
  hips). Animations write `Motor6D.Transform` on top of C0, so a hunch survives
  every animation.
* Visible leg length is changed with `Humanoid.HipHeight`, which on R6 is an
  offset added to the leg length. Long legs extend the leg shell below the base
  leg and raise the body; short legs do the opposite. The base legs keep
  animating either way.
* Overall size (`Appearance.Height`) is the only thing done with `Model:ScaleTo`,
  and it is capped per grade. Anatomy never depends on it.

## 2. Modular body-part structure

Anatomy is split into **slots**. Each slot holds one or more **components** from
the catalog. The slot table (`Slots.lua`) is data, so new slots can be added.

| Region | Slot | Kind | Examples |
|---|---|---|---|
| Head | `Head` | single | HumanCurseHead, AnimalHead, OctopoidHead, SplitJawHead, FacelessHead, SkullHead… |
| | `Horns` | multi | RamHorns, CrownOfHorns, Antlers, BrokenHorn, custom horns with params… |
| | `Eyes` | multi | Eye, GiantEye, EyeCluster, EyeStalk, CompoundEye, MissingEye |
| | `Mouths` | multi | SlitMouth, GrinMouth, Maw, LampreyMouth, Mandibles, TongueMouth |
| | `HeadGrowths` | multi | ExtraEar, BoneSpur, FacePlate, Tumor, Crest, Antennae… |
| Torso | `Torso` | single | NormalTorso, MuscularTorso, EmaciatedTorso, HunchedTorso, WideTorso, RibbedTorso, OrbTorso |
| | `TorsoGrowths` | multi | ChestCavity, ExposedOrgans, BonePlating, OrganicArmor, RibGrowth, ShoulderGrowth, SecondaryMass |
| Arms | `Arms` | sided | NormalArm, MuscularArm, ThinArm, LongArm, BoneArm, TentacleArm, MultiJointArm… |
| | `Hands` | sided | Hand, Fist, ClawedHand, BladedFingers, TalonHand, OversizedHand… |
| | `ExtraArms` | multi | any arm and hand pair, at any torso socket |
| Legs | `Legs` | sided | NormalLeg, MassiveLeg, ThinLeg, DigitigradeLeg, ReverseJointLeg, LongLeg, SerpentBody… |
| | `Feet` | sided | Foot, ClawedFoot, HoofFoot, TalonFoot, EnlargedFoot… |
| | `ExtraLegs` | multi | any leg and foot pair |
| Back | `Back` | multi | Wings, BoneWings, Tendrils, Spikes, Shell, BackEyes, OrganicGrowth |
| | `ExtraHeads` | multi | any head variant on a neck socket |
| | `Tails` | multi | ThinTail, ThickTail, BladeTail, BoneTail, TendrilTail, CreatureTail… |
| Anywhere | `Disfigurements` | multi | any eye/mouth/growth anywhere, BoneProtrusion, CrackedFlesh, Tumors, SwollenHand, MissingFingers… |

"Sided" slots take either one id (both sides) or `{ Right = id, Left = id }`,
which is how asymmetric arms, legs and feet work.

A **component** is a table registered in the catalog:

```lua
{
    id = "RamHorns",
    slots = { "Horns" },          -- which slots accept it
    grade = "Grade3",             -- lowest grade that may equip it
    tags = { "bone", "horn" },
    params = { length = 2.2, curl = 320 },   -- defaults, overridable per entry
    build = function(ctx, params, entry) ... end,   -- makes geometry
    mutate = function(body, params, entry) ... end, -- optional: changes proportions
}
```

In the character this becomes the tree from the brief:

```
CurseBody
├ Head   ├ BaseHead  ├ Horns  ├ Eyes  ├ Mouths  └ HeadGrowths
├ Torso  ├ BaseTorso └ TorsoGrowths
├ Arms   ├ RightArm  ├ LeftArm  ├ RightHand  ├ LeftHand  └ ExtraArms
├ Legs   ├ RightLeg  ├ LeftLeg  ├ RightFoot  ├ LeftFoot  └ ExtraLegs
├ Back   ├ Back  ├ Tails  └ ExtraHeads
└ Disfigurements
```

Each leaf is a Folder that one slot owns. Unequipping a slot destroys its
folder and nothing else.

## 3. How body parts attach to R6

All geometry is built by the **builder context** (`Builder.lua`), never by hand:

| Call | Result |
|---|---|
| `ctx:blob(part, pos, size, rot, role)` | ellipsoid (Part + Sphere SpecialMesh), the organic workhorse |
| `ctx:box / ctx:wedge / ctx:cylinder` | hard-surface pieces: plates, blades, teeth |
| `ctx:triangle(part, a, b, c, role)` | two WedgeParts forming any triangle: membranes, blades, fins |
| `ctx:mesh(part, cf, size, meshId, role)` | custom art (`SpecialMesh` FileMesh, settable at runtime) |
| `ctx:template(name, part, cf)` | clones a MeshPart or model from `CurseBody/Assets` |
| `ctx:chain(part, cf, segments, opts)` | Motor6D chain of segments: tails, tendrils, tentacles, stalks, wing bones |
| `ctx:limb(kind, name, side, c0, mirrorJoint, opts)` | extra R6-style limb part driven by its own Motor6D |

Rules every piece follows:

* It is welded to **exactly one** R6 part, extra limb or chain segment, with a
  `Weld` whose `C0` is the offset. Nothing spans two limbs, so nothing locks a
  joint, and pieces follow their part through every animation, ragdoll and
  knockback.
* Pieces are `Massless`, `CanCollide = false`, `CanTouch = false` and
  `CanQuery = false`. Physics and hitboxes stay those of a normal R6 character.
* Colors come from **roles** (`Skin`, `SkinDark`, `Flesh`, `Bone`, `Void`,
  `Eye`, `Claw`, `Teeth`, `Membrane`, …) resolved through the Curse's
  **palette**. The same component is red on one Curse and bone-white on another.
* Sided components are authored once for the right side; `ctx.side = -1`
  mirrors positions and rotations for the left.

**Sockets** are named, oriented attach points: part plus CFrame, with +Y
pointing out of the surface. Region variants define them on their own surface
as they build. For example, `OctopoidHead` puts `Crown`, `TopL`, `TopR`,
`EyeL`, `EyeR`, `Mouth` and `Jaw` where its skull and face actually are, and
`MuscularTorso` puts `Chest` further forward than `EmaciatedTorso` does.
Everything placed later (horns, eyes, mouths, growths, wings, tails, extra
limbs) asks for a socket by name, so it lands on the real surface of whatever
body is underneath. Each socket is also created as an `Attachment`
(`CurseSocket_<Name>`) for VFX and gameplay, for example spawning a projectile
from a hand mouth.

## 4. How different body proportions are handled

A **body type** (`BodyTypes.lua`) supplies two things:

* **mass**: per-region multipliers (torso width, height and depth; shoulder
  mass; neck; arm thickness and length per side; hand; leg thickness; foot;
  head). Every region builder multiplies its geometry by these, so "Heavy" gets
  a larger torso, shoulders, arms, hands, thicker legs and a bigger neck, not
  a bigger character.
* **layout**: joint positions (shoulder width, height and forward offset; neck
  height and forward offset; hip width), hunch angle and leg extension.

Built in: `Lean`, `Normal`, `Muscular`, `Heavy`, `Hunched`, `Deformed`
(seeded asymmetry), `Monstrous` and `Massive`.

Layered on top, in order:

1. body type
2. `Appearance.Scales` (per-region fine tuning, clamped per grade)
3. component `mutate` hooks (e.g. `OversizedHand` or `ElongatedArm`)
4. the active transformation stage

The result is one resolved `body` table (`mass`, `layout`, `legExtra`) that
every builder reads.

## 5. How horns and disfigurements are attached

**Horns** use one procedural builder (`Catalog/Horns.lua`) that sweeps a
tapered, ridged tube along a curve:

`length, thickness, taper, curve, curveDir, spiral, tilt, segments, broken, branches, ridges, role, rootRole, tipRole, mesh`

The registered horns (`StubHorn`, `StraightHorn`, `CurvedHorn`, `BackHorn`,
`ForwardHorn`, `RamHorn`, `Antler`, `BrokenHorn`, `MassiveHorn`) are just
parameter sets. Horn sets (`HornPair`, `ThreeHorns`, `CrownOfHorns`,
`AsymmetricHorns`, `Antlers`, `RamHorns`, `DemonHorns`, `UnicornHorn`) place several horns on skull
sockets. Every horn starts with a flattened **root blob in the skin role**
sunk into the skull, so it grows out of the head instead of sitting on it
like an accessory. Any entry can override params, socket, offset, rotation
and scale, or swap in a custom mesh:

```lua
Horns = {
    "RamHorns",
    { id = "CurvedHorn", socket = "Brow", rot = {0, 0, 15}, scale = 1.4, params = { broken = 0.4 } },
    { id = "StraightHorn", socket = "TopL", params = { mesh = "rbxassetid://123", role = "Void" } },
}
```

**Disfigurements** are components placed the same way, at any socket on any
region (`{ id = "GrinMouth", socket = "Palm_R" }` gives a mouth on the palm). Some
build geometry (tumor clusters, bone protrusions, cracked or blackened flesh,
extra ears or noses, rib or spine growths). Others only `mutate` proportions
(oversized hand, elongated or shrunken arm, asymmetric shoulder, enlarged
muscle). Cracked and blackened flesh are real geometry (dark raised plates
and fissure strips), not textures.

## 6. How extra limbs are handled

An extra arm, leg or head is a real extra part (`ExtraArm1`, `ExtraLeg2`,
`ExtraHead1`) with its own **Motor6D** from the Torso at a socket (`FlankR`,
`BackL`, `ShoulderL`, …). The normal arm, hand, leg, foot or head components
are then built onto it, so every variant works as an extra limb for free.

Animation, in order of preference:

1. **Custom animations** can key them directly. The Animation Editor sees the
   Motor6Ds by name.
2. By default the client **mirrors** a real joint. Each extra limb's Motor6D
   has `MirrorJoint` (`"Right Shoulder"`, `"Left Hip"`, `"Neck"`),
   `MirrorDelay` and `MirrorScale` attributes. `CurseClient` copies that joint's
   animated Transform, delayed and scaled, so a four-armed Curse swings all four
   arms when it walks, with a slight lag that reads as organic.
3. Chains (tails, tendrils, tentacle arms, eye stalks, wing bones) sway
   procedurally from velocity unless an animation keys them.

Extra limbs are visual. The Humanoid still walks on the two R6 legs, which
keeps movement, climbing and physics reliable.

## 7. How transformations swap geometry

A transformation (`Catalog/Transformations.lua`) is a named set of stages.
Each stage is a partial appearance **override**:

```lua
{
    id = "SplitMaw", grade = "Grade3",
    stages = {
        Partial = { Head = "SplitJawHead", Layout = { hunch = 6 } },
        Full = {
            TorsoGrowths = { add = { "OpenChest" } },
            Mouths = { add = { { id = "Maw", socket = "Belly", params = { size = 0.45 } } } },
            Layout = { hunch = 6 },
        },
    },
}
```

Override rules: a plain value replaces the slot. `{ add = … }` and
`{ remove = … }` edit multi slots. Numbers add limbs.

`CurseBody.setForm(character, "Full")` resolves the effective appearance for
that stage, **diffs it slot by slot** against what is built, and rebuilds only
the changed slots and their dependents (a new head rebuilds horns, eyes and
mouths; a body-type change rebuilds everything). New folders get a `GrowIn`
attribute and the client scales them in from nothing, which reads as
anatomy erupting rather than swapping. `CurseService` enforces the grade's
maximum stage, the optional duration (auto-revert) and whether a form may be
made permanent (merged into the saved appearance).

## 8. How Curse grades unlock anatomy

Grade is **progression, not decoration**. `Grades.compute(profile)` derives it
from stats (cursed energy, level, exorcisms; replace the formula with your
game's). Equipping parts can never raise it.

Grade gates:

| | Grade 4 | Grade 3 | Grade 2 | Grade 1 | Special |
|---|---|---|---|---|---|
| Body types | Lean, Normal, Muscular | +Hunched, Heavy | +Deformed | +Monstrous | +Massive |
| Horns (max) | 2 | 3 | 4 | 6 | 12 |
| Eyes | 2 | 4 | 8 | 16 | 40 |
| Mouths | 1 | 2 | 3 | 5 | 12 |
| Extra arms / legs / heads | 0/0/0 | 1/0/0 | 2/2/0 | 4/4/1 | 8/6/4 |
| Tails / back parts | 1/0 | 1/1 | 2/2 | 3/4 | 6/8 |
| Disfigurements | 2 | 4 | 8 | 14 | 30 |
| Height | 0.9–1.1 | 0.85–1.2 | 0.8–1.35 | 0.75–1.6 | 0.6–2.2 |
| Scale tuning | ±10% | ±20% | ±35% | ±60% | ±100% |
| Transformation | none | Partial | Partial | Full | Full + unique |

Each component also has a minimum grade. Special Grade unlocks anatomy that
stops being humanoid (`SerpentBody` lower body, `OrbTorso`, headless curses
with faces on the torso, several heads), not just bigger numbers.
`Appearance.sanitize(appearance, grade)` runs on the server before every build
and strips or clamps anything the grade doesn't allow, so a tampered client
request can't equip locked anatomy.

## 9. How customization is stored

The appearance is plain JSON-safe data (strings, numbers, arrays and hex
colors), saved as-is in the player's DataStore profile:

```lua
Appearance = {
    Version = 1, Seed = 48213,
    BodyType = "Heavy", Palette = "Crimson", Height = 1.15,
    Head = "OctopoidHead",
    Horns = { "HornPair" },
    Eyes = { { id = "Eye", socket = "EyeL" }, { id = "EyeCluster", socket = "ChestL" } },
    Mouths = {}, HeadGrowths = {},
    Torso = "HunchedTorso", TorsoGrowths = { "ChestCavity" },
    Arms = "MuscularArm", Hands = "Fist", ExtraArms = 2,
    Legs = "DigitigradeLeg", Feet = "EnlargedFoot",
    Back = {}, Tails = { "CreatureTail" }, ExtraHeads = {},
    Disfigurements = { { id = "Mouth", socket = "Hand_R" } },
    Scales = { Hands = 1.2 },
    Transformation = "SplitMaw",
}
```

* A missing slot means "use the component's defaults" (a head brings its own
  eyes and mouth). An explicit `{}` means none.
* `Seed` drives all procedural asymmetry, so a Curse looks the same on every
  server and every rebuild.
* `Version` plus `Appearance.migrate` keep old saves loading after renames.
* The built character carries the resolved appearance as a JSON attribute
  (`CurseAppearance`) plus `CurseGrade` and `CurseForm`, for UI and other
  systems.

## 10. How the system expands

* **New part:** add an entry to any `Catalog/*.lua` module, or drop a new
  ModuleScript into `Catalog/`, which is auto-loaded. Nothing in the core
  changes.
* **New look for an existing part:** register a new id with different
  `params` (most horns, arms and tails are parameter sets over one builder).
* **Hand-made art:** put MeshParts in `CurseBody/Assets` and use
  `ctx:template`, or give a horn or part a `mesh` param.
* **New slot:** add a row to `Slots.lua` (region, folder, kind, order,
  dependents, default) and a cap to `Grades.lua`.
* **New body type, palette or transformation:** one table entry each.
* **Validation:** `tests/run.py` builds every preset and random appearances
  under a mocked Roblox API, checks every component builds at every grade, and
  renders previews, so a broken catalog entry is caught before it reaches
  Studio.
