--!nonstrict
--[[
	Example Curses. Each is just an appearance table over the sculpted mesh library:
	the same invisible R6 skeleton, radically different bodies.

	  local p = CurseBody.Presets.CrimsonHusk
	  CurseBody.apply(character, p.appearance, { grade = p.grade })
]]

return {
	-- The reference creature, assembled from its own sculpted parts.
	CrimsonHusk = {
		grade = "Grade2",
		description = "Hunched crimson husk: octopoid head, opened chest, heavy fists, splayed feet, clawed tail.",
		appearance = {
			Seed = 7,
			BodyType = "Normal",
			Palette = "Crimson",
			Height = 1.3,
			Head = "HuskHead",
			Torso = "HuskTorso",
			Arms = "HuskArm",
			Hands = "Fist",
			Legs = "HuskLeg",
			Feet = "SplayedFoot",
			Tails = { "HuskTail" },
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
			Head = "FacelessHead",
			Eyes = { { id = "GiantEye", socket = "Face", scale = 0.75 } },
			Mouths = { { id = "GrinMouth", socket = "Mouth", scale = 0.7 } },
			Horns = { "HornPair" },
			Torso = "EmaciatedTorso",
			Arms = "ThinArm",
			Hands = "ClawedHand",
			Legs = "ThinLeg",
			Feet = "Foot",
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
			Height = 1.3,
			Head = "HumanCurseHead",
			Eyes = {
				{ id = "EyeCluster", socket = "Face", scale = 0.7 },
				{ id = "EyeCluster", socket = "ChestR" },
				{ id = "EyeCluster", socket = "ChestL" },
				{ id = "Eye", socket = "UpperArm_R", scale = 1.8 },
			},
			Mouths = { { id = "GrinMouth", socket = "Belly", scale = 1.4 } },
			Horns = { "DemonHorns" },
			Torso = "MuscularTorso",
			Arms = "MuscularArm",
			Hands = "ClawedHand",
			ExtraArms = 2,
			Legs = "MassiveLeg",
			Feet = "ClawedFoot",
			Tails = { "BoneTail" },
			Transformation = "MonstrousSurge",
		},
	},

	-- insectoid, extremely thin, long-limbed, multiple-jawed, winged
	Mantis = {
		grade = "Grade1",
		description = "Emaciated insect with bladed hands, mandibles and membrane wings.",
		appearance = {
			Seed = 11,
			BodyType = "Lean",
			Palette = "Bile",
			Height = 1.25,
			Scales = { ArmLength = 1.3 },
			Head = "MandibleHead",
			Torso = "EmaciatedTorso",
			Arms = "ThinArm",
			Hands = "BladedHand",
			ExtraArms = { { id = "ThinArm", hand = "TalonHand" } },
			Legs = "DigitigradeLeg",
			Feet = "TalonFoot",
			Back = { "Wings" },
			Transformation = "BladeForm",
		},
	},

	-- a fresh Grade 4 curse: barely more than a disfigured person
	Grub = {
		grade = "Grade4",
		description = "Newborn curse: one empty eye socket, a stub horn and a growth on the shoulder.",
		appearance = {
			Seed = 5,
			BodyType = "Normal",
			Palette = "Ash",
			Head = "HumanCurseHead",
			Eyes = { { id = "Eye", socket = "EyeR" } },
			Horns = { { id = "StubHorn", socket = "TopL" } },
			Torso = "NormalTorso",
			Arms = { Right = "NormalArm", Left = "ThinArm" },
			Hands = "OpenHand",
			Legs = "NormalLeg",
			Feet = "Foot",
			Disfigurements = { { id = "Tumor", socket = "ShoulderR", scale = 0.7 } },
		},
	},

	Hollow = {
		grade = "Grade2",
		description = "Skull-headed, opened husk on reversed legs and hooves, spines down its back.",
		appearance = {
			Seed = 17,
			BodyType = "Deformed",
			Palette = "Bruise",
			Head = "SkullHead",
			Horns = { "Antlers" },
			Torso = "EmaciatedTorso",
			TorsoGrowths = { "ChestCavity" },
			Arms = "BoneArm",
			Hands = "TalonHand",
			Legs = "DigitigradeLeg",
			Feet = "HoofFoot",
			Back = { "Spikes" },
			Tails = { "BoneTail" },
			Disfigurements = { { id = "CrackedFlesh", socket = "ChestR" }, { id = "BoneProtrusion", socket = "Forearm_L" } },
		},
	},

	-- Special Grade: anatomy that no longer resembles a person
	Amalgam = {
		grade = "SpecialGrade",
		description = "Serpent-bodied amalgam of heads, arms and eyes.",
		appearance = {
			Seed = 42,
			BodyType = "Heavy", -- the MassiveTorso sculpt already carries the bulk
			-- custom palette: Void base with lifted skin values and a sickly glow
			Palette = { base = "Void", Skin = "#3A3044", SkinLight = "#524660", SkinDark = "#241D2B", Glow = "#9CFF4A", Eye = "#E8FF9A" },
			Height = 1.2,
			Head = "SplitJawHead",
			Eyes = { { id = "EyeCluster", socket = "ChestR" }, { id = "GiantEye", socket = "ChestL", scale = 0.6 } },
			Mouths = { { id = "Maw", socket = "Belly" } },
			Horns = { "CrownOfHorns" },
			Torso = "MassiveTorso",
			Arms = { Right = "TentacleArm", Left = "MuscularArm" },
			Hands = "ClawedHand",
			ExtraArms = { { id = "TentacleArm", socket = "FlankR" }, { id = "BoneArm", hand = "TalonHand", socket = "BackL" } },
			ExtraHeads = { { id = "SkullHead", socket = "ShoulderR" }, { id = "FacelessHead", socket = "ShoulderL", Eyes = { { id = "GiantEye", socket = "Face", scale = 0.6 } } } },
			Legs = "SerpentBody",
			Back = { "BoneWings", "Tendrils" },
			Transformation = "Unravel",
		},
	},
}
