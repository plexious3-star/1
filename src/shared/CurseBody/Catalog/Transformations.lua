--!nonstrict
--[[
	Transformations: named Partial / Full stages, each a partial appearance override.
	  plain value           replaces the slot            Head = "SplitJawHead"
	  { add = …, remove = … }  edits a multi/limb slot    ExtraArms = { add = 2 }
	  Scales = { … }        multiplies                    Scales = { Arms = 1.2 }
	  Layout = { … }        adds to posture               Layout = { hunch = 10 }
	  Height = { mul = x }  multiplies height
	Full inherits Partial unless Full.inherit == false. Grades cap which stage is usable.
]]

return {
	{
		id = "SplitMaw",
		grade = "Grade3",
		description = "The head splits open into a maw; at full power the chest tears open too.",
		stages = {
			Partial = { Head = "SplitJawHead", Layout = { hunch = 6 } },
			Full = {
				TorsoGrowths = { add = { "OpenChest" } },
				Mouths = { add = { { id = "Maw", socket = "Belly", params = { size = 0.45 } } } },
				Layout = { hunch = 6 },
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
		description = "The torso opens and reveals a black cavity, then its organs.",
		stages = {
			Partial = { TorsoGrowths = { add = { "ChestCavity" } } },
			Full = { TorsoGrowths = { remove = { "ChestCavity" }, add = { "ExposedOrgans", "RibGrowth" } } },
		},
	},
	{
		id = "BladeForm",
		grade = "Grade2",
		description = "Fingers harden into blades; a bladed tail and spines follow.",
		stages = {
			Partial = { Hands = "BladedFingers" },
			Full = { Tails = { add = { "BladeTail" } }, Back = { add = { "Spikes" } } },
		},
	},
	{
		id = "Hive",
		grade = "Grade2",
		description = "Eyes open across the body.",
		stages = {
			Partial = { Eyes = { add = { { id = "EyeCluster", socket = "ChestR", params = { count = 3 } } } } },
			Full = {
				Eyes = { add = { { id = "EyeCluster", socket = "ChestL", params = { count = 3 } } } },
				Back = { add = { "BackEyes" } },
			},
		},
	},
	{
		id = "MonstrousSurge",
		grade = "Grade1",
		description = "Mass floods the body: bigger frame, massive horns, bone wings.",
		stages = {
			Partial = { Scales = { Torso = 1.12, Arms = 1.2, Hands = 1.2, Shoulders = 1.2 }, Layout = { hunch = 6 } },
			Full = {
				BodyType = "Monstrous",
				Height = { mul = 1.2 },
				Horns = { remove = "all", add = { { id = "MassiveHorn", socket = "TopR" }, { id = "MassiveHorn", socket = "TopL" } } },
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
				Eyes = { add = { { id = "EyeCluster", socket = "Belly", params = { count = 6 } } } },
			},
		},
	},
}
