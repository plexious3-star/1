--!nonstrict
--[[
	Transformations: named Partial / Full stages, each a partial appearance override.
	They swap whole sculpted components (a new head mesh, an opened torso mesh, extra limb
	meshes), not colors.
	  plain value              replaces the slot            Head = "SplitJawHead"
	  { add = …, remove = … }  edits a multi/limb slot      ExtraArms = { add = 2 }
	  Scales = { … }           multiplies                   Scales = { Arms = 1.2 }
	  Layout = { … }           adds to posture              Layout = { neckDrop = 0.1 }
	  Height = { mul = x }     multiplies height
	Full inherits Partial unless Full.inherit == false. Grades cap which stage is usable.
]]

return {
	{
		id = "SplitMaw",
		grade = "Grade3",
		description = "The head splits open into a toothed maw; at full power the chest tears open too.",
		stages = {
			Partial = { Head = "SplitJawHead" },
			Full = {
				TorsoGrowths = { add = { "ChestCavity" } },
				Mouths = { add = { { id = "Maw", socket = "Belly", scale = 0.8 } } },
			},
		},
	},
	{
		id = "FourArms",
		grade = "Grade3",
		description = "A second pair of arms tears out of the flanks.",
		stages = {
			Partial = { ExtraArms = { add = 1 } },
			Full = { ExtraArms = { add = 1 }, Scales = { Arms = 1.15, Shoulders = 1.2 } },
		},
	},
	{
		id = "OpenChest",
		grade = "Grade3",
		description = "The torso opens and reveals a black cavity; ribs burst out of the flanks.",
		stages = {
			Partial = { TorsoGrowths = { add = { "ChestCavity" } } },
			Full = {
				TorsoGrowths = { add = { { id = "RibGrowth", socket = "FlankR" }, { id = "RibGrowth", socket = "FlankL" } } },
				Mouths = { add = { { id = "Maw", socket = "Belly", scale = 0.7 } } },
			},
		},
	},
	{
		id = "BladeForm",
		grade = "Grade2",
		description = "Fingers harden into blades; a bladed tail and spines follow.",
		stages = {
			Partial = { Hands = "BladedHand" },
			Full = { Tails = { add = { "BladeTail" } }, Back = { add = { "Spikes" } } },
		},
	},
	{
		id = "Hive",
		grade = "Grade2",
		description = "Eyes open across the body.",
		stages = {
			Partial = { Eyes = { add = { { id = "EyeCluster", socket = "ChestR" } } } },
			Full = { Eyes = { add = { { id = "EyeCluster", socket = "ChestL" } } }, Back = { add = { "BackEyes" } } },
		},
	},
	{
		id = "MonstrousSurge",
		grade = "Grade1",
		description = "Mass floods the body: bigger frame, massive horns, bone wings.",
		stages = {
			Partial = { Scales = { Torso = 1.12, Arms = 1.2, Hands = 1.2, Shoulders = 1.2 } },
			Full = {
				Torso = "MassiveTorso",
				Height = { mul = 1.15 },
				Horns = { remove = "all", add = { "MassiveHorns" } },
				Back = { add = { "BoneWings" } },
			},
		},
	},
	{
		id = "Unravel",
		grade = "SpecialGrade",
		description = "The body comes apart into something that was never human.",
		stages = {
			Partial = { ExtraArms = { add = 2 }, Back = { add = { "Tendrils" } } },
			Full = {
				Legs = "SerpentBody",
				ExtraHeads = { add = 2 },
				ExtraArms = { add = 2 },
				Eyes = { add = { { id = "EyeCluster", socket = "Belly" } } },
			},
		},
	},
}
