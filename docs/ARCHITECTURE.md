# Curse Body System — Architecture

**R6 skeleton + sculpted organic meshes + modular curse anatomy.**

The classic R6 rig is only the **skeleton**: six invisible parts, six standard
Motor6Ds, the Humanoid. Everything you see is a sculpted **MeshPart** from a mesh
library, welded to those bones. The R6 blocks never show and never decide the
silhouette. They exist so every R6 animation, the default `Animate` script,
physics, ragdoll and hitboxes keep working.

```
 tools/sculpt (Python, offline)                 Roblox (runtime)
 ┌────────────────────────────────┐             ┌───────────────────────────────────────┐
 │ SDF sculpts → marching cubes → │  OBJ files  │ ReplicatedStorage.CurseAssets          │
 │ smooth → decimate → split by   │ ──import──▶ │   (imported MeshParts, by piece name)  │
 │ palette role → mirror L        │             │                                        │
 │                                │  manifest   │ CurseBody (framework)                  │
 │ Library.lua: pieces, sockets,  │ ──────────▶ │   appearance + grade → clone, scale,   │
 │ joint layout, variants         │             │   weld meshes onto the R6 skeleton     │
 └────────────────────────────────┘             └───────────────────────────────────────┘
```

| Path | Role |
|---|---|
| `tools/sculpt/sdf.py` | sculpting engine: SDF primitives, smooth blending, carving, material painting, meshing |
| `tools/sculpt/texture.py` | UV unwrapping (xatlas) + procedural hand-drawn texture overlays baked from the sculpt |
| `tools/sculpt/library.py` | every modular component, sculpted in its own local space → `assets/meshes/library/*.obj` + manifest |
| `tools/sculpt/husk.py` | the reference creature's parts (shared with the library as `Husk*` components) |
| `src/shared/CurseBody/` | runtime framework (`ReplicatedStorage.CurseBody`) |
| `src/shared/CurseBody/Meshes/Library.lua` | generated manifest: pieces, sockets, joint layouts, variants |
| `src/shared/CurseBody/Catalog/` | `Meshes` (registers the library), `Sets` (horn sets, wing pairs, mutations), `Transformations` |
| `src/server/`, `src/client/` | CurseService (profiles, grade checks, forms), CurseClient (sway, extra-limb motion, grow-in) |

---

## 1. R6 base rig structure

```
Character (Model)
├ HumanoidRootPart ── RootJoint ──▶ Torso
├ Torso ── Neck ──▶ Head
│       ── Right Shoulder / Left Shoulder ──▶ Right Arm / Left Arm
│       ── Right Hip / Left Hip ──▶ Right Leg / Left Leg
├ Humanoid (RigType R6)
└ CurseBody (Model)   ← every visible mesh, extra limb and joint this system adds
```

* The six parts keep their standard names, sizes and Motor6D names. They are
  **invisible** (`Transparency = 1`) and only provide joints, collisions and
  hitboxes.
* The joint **layout** comes from the torso mesh. Each sculpted torso ships the
  C0 positions its anatomy was sculpted around (neck, shoulders, hips, tail root)
  and its leg extension. A hunched torso puts the neck low and forward. A massive
  one puts the shoulders wide. Animations write `Motor6D.Transform` on top of C0,
  so posture survives every animation.
* Visible leg length uses `Humanoid.HipHeight`, which on R6 is an offset added to
  the leg length. Leg meshes are stretched to reach the ground. CrimsonHusk's
  legs are 0.35 studs longer than an R6 leg, like the reference.
* `Appearance.Height` (`Model:ScaleTo`) is overall size only, capped per grade.

## 2. Modular body-part structure

Anatomy is split into **slots** (`Slots.lua`, pure data). Each slot holds
components from the mesh library.

| Region | Slot | Kind | Library components |
|---|---|---|---|
| Head | `Head` | single | HumanCurseHead, BeastHead, SkullHead, MandibleHead, FacelessHead, SplitJawHead, HuskHead |
| | `Horns` | multi | StubHorn, StraightHorn, CurvedHorn, BackHorn, RamHorn, Antler, BrokenHorn, MassiveHorn + sets |
| | `Eyes` | multi | Eye, GiantEye, EyeCluster, CompoundEye |
| | `Mouths` | multi | GrinMouth, Maw, Mandibles |
| | `HeadGrowths` | multi | BoneSpur, ExtraEar, Tumor |
| Torso | `Torso` | single | NormalTorso, MuscularTorso, EmaciatedTorso, MassiveTorso, HuskTorso (each with a carved-open variant) |
| | `TorsoGrowths` | multi | ChestCavity (opens the torso mesh), RibGrowth, BoneSpur, Tumor |
| Arms | `Arms` | sided | NormalArm, MuscularArm, ThinArm, BoneArm, TentacleArm, HuskArm |
| | `Hands` | sided | OpenHand, Fist, ClawedHand, BladedHand, TalonHand |
| | `ExtraArms` | limbs | any arm + hand, at any torso socket |
| Legs | `Legs` | sided | NormalLeg, ThinLeg, MassiveLeg, DigitigradeLeg, HuskLeg, SerpentBody |
| | `Feet` | sided | Foot, ClawedFoot, HoofFoot, TalonFoot, SplayedFoot |
| | `ExtraLegs` | limbs | any leg + foot |
| Back | `Back` | multi | Wings, BoneWings, Tendrils, Spikes, Shell, BackEyes |
| | `ExtraHeads` | limbs | any head (with its own eyes/mouths/horns) |
| | `Tails` | multi | HuskTail, BoneTail, BladeTail |
| Anywhere | `Disfigurements` | multi | any eye / mouth / growth at any socket, BoneProtrusion, CrackedFlesh, mutations |

"Sided" slots take one id or `{ Right = id, Left = id }` (asymmetric bodies).
Components are authored for the right side. The baker exports mirrored `_L`
meshes, since a MeshPart can't be mirrored by negative scale.

In the character:

```
CurseBody
├ Head   ├ BaseHead ├ HornSet ├ Eyes ├ Mouths └ HeadGrowths
├ Torso  ├ BaseTorso └ TorsoGrowths
├ Arms   ├ ArmVariant ├ HandVariant └ ExtraArms
├ Legs   ├ LegVariant ├ FootVariant └ ExtraLegs
├ Back   ├ BackParts ├ Tails └ ExtraHeads
└ Disfigurements
```

Each folder belongs to one slot, so unequipping a slot destroys only its folder.

## 3. How body parts attach to R6

Every library component is sculpted in the **local space** of what it attaches
to. `Catalog/Meshes.lua` knows how to place and scale each space:

| Space | Attaches to | Scaled by |
|---|---|---|
| `torso` | Torso (its center) | TorsoW / TorsoH / TorsoD; carries joint layout + torso sockets |
| `head` | Head or an extra head | Head, around the neck joint |
| `arm` | an arm part | thickness × length around the shoulder pivot; defines `Hand_<s>` |
| `hand` | the arm's `Hand_<s>` socket | Hand |
| `leg` | a leg part | thickness, stretched to the visible leg length; defines `Foot_<s>` |
| `foot` | the leg's `Foot_<s>` socket | Foot |
| `surface` | any socket, +Y out of the body | the entry's scale (horns, eyes, mouths, growths) |
| `body` | a socket position, torso-aligned, on its own Motor6D | the entry's scale (tails, wings, tendrils, spikes) |
| `serpent` | the Torso (replaces the legs) | TorsoW |

Each piece is a MeshPart cloned from `CurseAssets`, resized, colored by its
palette **role**, and welded to one bone (`Weld.C0` = offset). Its texture is an
overlay (ink hatching, gloss, veins, tissue striations, border ink) with alpha.
The part's palette `Color` shows through the transparent texels, so textures
never lock a Curse's colors. Pieces are
massless and don't collide, so nothing spans two bones or blocks a joint.
Meshes overlap generously at the joints: the arm's deltoid sinks into the
torso's shoulder mass, and the head's neck plug into the neck wrap. Rotating a
limb therefore never opens a hole.

**Sockets** are named, oriented attach points each component defines on its own
sculpted surface. For example, `HuskHead` puts `TopR`/`TopL` on its swept-back
cranium and `MuscularTorso` puts `Chest` further out than `EmaciatedTorso` does.
Horns, eyes, mouths, growths, wings, tails and extra limbs ask for a socket by
name, so they land on the actual surface underneath. Sockets also exist as
`Attachment`s (`CurseSocket_<Name>`) for VFX and gameplay.

## 4. How different body proportions are handled

A **body type** supplies per-region **mass** (torso width, height and depth;
shoulders; neck; head; arm thickness and length per side; hands; leg
thickness; feet). Meshes scale by `mass^0.75` per axis around their own pivot,
so a heavy build gets a bigger torso mesh, thicker arms and legs, bigger hands
and a wider joint layout, not a scaled-up character.

Posture and anatomy that scaling can't create, like a hunch or ribs pushing
through the skin, are **different sculpts**: `EmaciatedTorso`, `MassiveTorso`,
`HuskTorso`, `DigitigradeLeg` and so on. Transformations swap them.

Resolution order: body type → `Appearance.Scales` (clamped per grade) →
component `mutate` hooks (SwollenHand, ElongatedArm, AsymmetricShoulder…) →
transformation stage.

## 5. How horns and disfigurements are attached

**Horns** are sculpted by one sweep builder (`library.py: horn()`): a tapered,
ridged tube bent along a curve with optional spiral, branches (antlers) and a
snapped end (broken). Each horn starts with a skin-colored root flare, so it
grows out of the skull. The eight horn meshes combine into sets in `Sets.lua`
(HornPair, ThreeHorns, CrownOfHorns, RamHorns, DemonHorns, Antlers,
AsymmetricHorns, MassiveHorns, UnicornHorn). Any entry can override its socket,
offset, rotation and scale:

```lua
Horns = { "RamHorns", { id = "BrokenHorn", socket = "Brow", rot = { 0, 0, 15 }, scale = 1.4 } }
```

**Disfigurements** are real geometry placed at any socket: an eye on the chest, a
`GrinMouth` on `Palm_R`, a `BoneProtrusion` out of a forearm, `CrackedFlesh`
with glowing fissures, or tumors. Each surface mesh carries its own swollen
skin-colored base, lids and rim, so it looks grown into the flesh rather than
stuck on. Mutations (SwollenHand, ElongatedArm, ShrunkenArm, EnlargedMuscle,
AsymmetricShoulder) change the body's mass before the meshes build.

What a separate mesh can't do is carve into another mesh. So cavities that open
the body are sculpted into the **torso itself**: every torso has an `Open`
variant, and `ChestCavity` (or a transformation) switches to it.

## 6. How extra limbs are handled

An extra arm, leg or head is an extra invisible bone (`ExtraArm1`…) on its own
Motor6D from the Torso at a socket. The same arm, hand, leg, foot and head
meshes are built onto it.

* Custom animations can key those Motor6Ds by name.
* By default `CurseClient` **mirrors** a real joint's animated Transform onto
  them (`MirrorJoint`, `MirrorDelay`, `MirrorScale` attributes), so four arms
  swing when the Curse walks.
* Tails, wings and tendrils hang on their own joints and sway with speed
  unless an animation keys them (`AnimationDriven` attribute).

## 7. How transformations swap geometry

A transformation is a set of Partial / Full **overrides** that swap whole
sculpted components:

```lua
{
    id = "SplitMaw", grade = "Grade3",
    stages = {
        Partial = { Head = "SplitJawHead" },                          -- the head mesh splits open
        Full = {
            TorsoGrowths = { add = { "ChestCavity" } },                -- torso swaps to its carved-open sculpt
            Mouths = { add = { { id = "Maw", socket = "Belly" } } },
        },
    },
}
```

`CurseBody.setForm(character, "Full")` diffs the effective appearance slot by
slot and rebuilds only what changed and its dependents. New folders get a
`GrowIn` attribute, and the client scales the new meshes in from nothing.
`CurseService` enforces the grade's maximum stage, cooldowns and duration.

## 8. How Curse grades unlock anatomy

Grade comes from progression (`Grades.compute(profile)`); equipping parts
never raises it.

| | Grade 4 | Grade 3 | Grade 2 | Grade 1 | Special |
|---|---|---|---|---|---|
| Body types | Lean, Normal, Muscular | +Hunched, Heavy | +Deformed | +Monstrous | +Massive |
| Horns / eyes / mouths | 2 / 2 / 1 | 3 / 4 / 2 | 4 / 8 / 3 | 6 / 16 / 5 | 12 / 40 / 12 |
| Extra arms / legs / heads | 0/0/0 | 1/0/0 | 2/2/0 | 4/4/1 | 8/6/4 |
| Tails / back / disfigurements | 1/0/2 | 1/1/4 | 2/2/8 | 3/4/14 | 6/8/30 |
| Height | 0.9–1.1 | 0.85–1.2 | 0.8–1.35 | 0.75–1.6 | 0.6–2.2 |
| Transformation | — | Partial | Partial | Full | Full |

Every component also has a minimum grade. Special Grade unlocks anatomy that
stops being humanoid (`SerpentBody` in place of legs, several heads,
`MassiveTorso` builds). `Appearance.sanitize` enforces all of this on the
server before every build.

## 9. How customization is stored

The appearance is plain JSON-safe data, saved in the player's DataStore profile:

```lua
Appearance = {
    Version = 1, Seed = 48213,
    BodyType = "Heavy", Palette = "Crimson", Height = 1.15,
    Head = "HuskHead", Horns = { "HornPair" },
    Eyes = { { id = "EyeCluster", socket = "ChestL" } },
    Torso = "HuskTorso", TorsoGrowths = { "ChestCavity" },
    Arms = "HuskArm", Hands = "Fist", ExtraArms = 2,
    Legs = "DigitigradeLeg", Feet = "TalonFoot",
    Tails = { "BoneTail" },
    Disfigurements = { { id = "GrinMouth", socket = "Palm_R", scale = 0.6 } },
    Scales = { Hands = 1.2 },
    Transformation = "SplitMaw",
}
```

A missing multi slot means "use the head's defaults", and `{}` means none.
`Palette` is a name or a table of role colors. `Appearance.migrate` keeps old
saves loading.

## 10. How the system expands

1. **New body part:** write a sculpt function in `tools/sculpt/library.py` with
   `@component(id, slot, grade, space, sockets=…)`, then run
   `python3 tools/sculpt/library.py --only YourPart`.
2. **Import it:** import the updated `assets/meshes/library/Curse<Slot>.obj` into
   `CurseAssets`. The manifest registers it automatically, with no Luau changes.
3. **Combinations:** horn sets, pairs and clusters are a few lines in `Sets.lua`.
4. **Hand-made art:** any MeshPart named `<Id>_<Role>` in `CurseAssets` with a
   manifest entry works the same way, so artists can replace a procedural sculpt
   with a Blender model.
5. **New slot, body type, palette or transformation:** one table entry each.
6. **Validation:** `tests/run.py` builds every preset, transformation and
   component and 40 random Curses under a mocked Roblox API. It then renders
   them from the real library meshes (`previews/curse/`).
