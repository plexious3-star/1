--!nonstrict
--[[
	Example Curses. Each is just an appearance table: the same system, the same R6 rig,
	radically different bodies. Use them as starting points or NPC templates:

	  local p = CurseBody.Presets.CrimsonHusk
	  CurseBody.apply(character, p.appearance, { grade = p.grade })
]]

return {
	-- The reference creature, rebuilt from modular parts.
	CrimsonHusk = {
		grade = "Grade2",
		description = "Hunched crimson husk: octopoid head, black chest cavity, heavy fists, clawed tail.",
		appearance = {
			Seed = 7,
			BodyType = "Hunched",
			Palette = "Crimson",
			Height = 1.3,
			Head = "OctopoidHead",
			Torso = "HunchedTorso",
			TorsoGrowths = { { id = "ChestCavity", socket = "Chest", pos = { -0.12, 0, 0.1 } } },
			Arms = "HeavyArm",
			Hands = "Fist",
			Legs = "HuskLeg",
			Feet = "EnlargedFoot",
			Tails = { "CreatureTail" },
			Transformation = "SplitMaw",
		},
	},

	-- humanoid, skinny, horned, pale, one-eyed
	PaleSeer = {
		grade = "Grade3",
		description = "Gaunt pale humanoid with a single giant eye and a pair of horns.",
		appearance = {
			Seed = 21,
			BodyType = "Lean",
			Palette = "Pale",
			Height = 1.1,
			Head = "HumanCurseHead",
			Eyes = { { id = "GiantEye", socket = "Face", pos = { 0, 0, 0.1 } } },
			Mouths = { "SlitMouth" },
			Horns = { "HornPair" },
			Torso = "EmaciatedTorso",
			Arms = "ThinArm",
			Hands = "ClawedHand",
			Legs = "ThinLeg",
			Feet = "Foot",
			Disfigurements = { { id = "MissingFingers", socket = "Hand_L" } },
			Transformation = "OpenChest",
		},
	},

	-- enormous, muscular, hunched, four-armed, red, covered in eyes, with a tail
	Behemoth = {
		grade = "Grade1",
		description = "Four-armed red mountain of muscle covered in eyes.",
		appearance = {
			Seed = 3,
			BodyType = "Monstrous",
			Palette = "Flayed",
			Height = 1.35,
			Head = "SmallHead",
			Eyes = {
				{ id = "EyeCluster", socket = "Face", params = { count = 5, spread = 0.25 } },
				{ id = "EyeCluster", socket = "ChestR", params = { count = 4 } },
				{ id = "EyeCluster", socket = "ChestL", params = { count = 4 } },
				{ id = "Eye", socket = "UpperArm_R", scale = 1.6 },
				{ id = "Eye", socket = "UpperArm_L", scale = 1.6 },
			},
			Mouths = { { id = "GrinMouth", socket = "Belly", params = { width = 1.1 } } },
			Horns = { "DemonHorns" },
			Torso = "MuscularTorso",
			TorsoGrowths = { "BonePlating" },
			Arms = "MuscularArm",
			Hands = "ClawedHand",
			ExtraArms = 2,
			Legs = "MassiveLeg",
			Feet = "ClawedFoot",
			Tails = { "ThickTail" },
			Transformation = "MonstrousSurge",
		},
	},

	-- insectoid, extremely thin, long-limbed, multiple-jawed, winged
	Mantis = {
		grade = "Grade1",
		description = "Emaciated insect with scythe arms, stacked jaws and membrane wings.",
		appearance = {
			Seed = 11,
			BodyType = "Lean",
			Palette = "Bile",
			Height = 1.25,
			Scales = { ArmLength = 1.3, Legs = 0.9 },
			Head = "MandibleHead",
			Mouths = { "Mandibles", { id = "HangingJaw", socket = "Jaw" } },
			HeadGrowths = { "Antennae" },
			Torso = "EmaciatedTorso",
			TorsoGrowths = { "OrganicArmor" },
			Arms = "ScytheArm",
			ExtraArms = { { id = "ThinArm", hand = "TalonHand" } },
			Legs = "DigitigradeLeg",
			Feet = "TalonFoot",
			ExtraLegs = { { id = "InsectLeg" }, { id = "InsectLeg" } },
			Back = { "Wings" },
			Transformation = "BladeForm",
		},
	},

	-- a fresh Grade 4 curse: barely more than a disfigured person
	Grub = {
		grade = "Grade4",
		description = "Newborn curse: one missing eye, a stub horn and a growth on the shoulder.",
		appearance = {
			Seed = 5,
			BodyType = "Normal",
			Palette = "Ash",
			Head = "HumanCurseHead",
			Eyes = { { id = "Eye", socket = "EyeR" }, { id = "MissingEye", socket = "EyeL" } },
			Mouths = { { id = "SlitMouth", rot = { 0, 0, -8 } } },
			Horns = { { id = "StubHorn", socket = "TopL" } },
			Torso = "NormalTorso",
			Arms = { Right = "NormalArm", Left = "ThinArm" },
			Hands = "Hand",
			Legs = "NormalLeg",
			Feet = "Foot",
			Disfigurements = { { id = "Tumor", socket = "ShoulderR", params = { size = 0.3 } } },
		},
	},

	Hollow = {
		grade = "Grade2",
		description = "Skull-headed, hollow-ribbed thing on reversed legs and hooves.",
		appearance = {
			Seed = 17,
			BodyType = "Deformed",
			Palette = "Bruise",
			Head = "SkullHead",
			Horns = { "Antlers" },
			Torso = "RibbedTorso",
			Arms = "BoneArm",
			Hands = "TalonHand",
			Legs = "ReverseJointLeg",
			Feet = "HoofFoot",
			Back = { "Spikes" },
			Tails = { "BoneTail" },
			Disfigurements = { { id = "CrackedFlesh", socket = "Belly" }, { id = "ExposedBone", socket = "UpperArm_L" } },
		},
	},

	-- Special Grade: anatomy that no longer resembles a person
	Amalgam = {
		grade = "SpecialGrade",
		description = "Serpent-bodied amalgam of heads, arms and eyes.",
		appearance = {
			Seed = 42,
			BodyType = "Massive",
			-- custom palette: Void base with lifted skin values and a sickly glow
			Palette = { base = "Void", Skin = "#2E2735", SkinLight = "#453A50", SkinDark = "#1C1722", Glow = "#9CFF4A", Eye = "#E8FF9A" },
			Height = 1.4,
			Head = "OversizedHead",
			Eyes = {
				{ id = "GiantEye", socket = "Face", scale = 0.8 },
				{ id = "EyeCluster", socket = "Chest", params = { count = 8, spread = 0.6 } },
				{ id = "EyeStalk", socket = "Crown" },
				{ id = "EyeStalk", socket = "TopL", params = { length = 1.2 } },
			},
			Mouths = { { id = "LampreyMouth", socket = "Belly" }, { id = "GrinMouth", socket = "Palm_R", scale = 0.6 } },
			Horns = { "CrownOfHorns" },
			Torso = "OrbTorso",
			Arms = { Right = "MultiJointArm", Left = "TentacleArm" },
			Hands = "BladedFingers",
			ExtraArms = {
				{ id = "TentacleArm", socket = "FlankR" }, { id = "TentacleArm", socket = "FlankL" },
				{ id = "BoneArm", hand = "TalonHand", socket = "BackR" }, { id = "BoneArm", hand = "TalonHand", socket = "BackL" },
			},
			ExtraHeads = { { id = "SkullHead", socket = "ShoulderR" }, { id = "FacelessHead", socket = "ShoulderL", Eyes = { { id = "GiantEye", socket = "Face" } } } },
			Legs = "SerpentBody",
			Back = { "BoneWings", "Tendrils" },
			Disfigurements = { { id = "CrackedFlesh", socket = "Back" } },
			Transformation = "Unravel",
		},
	},
}
