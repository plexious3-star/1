--!nonstrict
--[[
	Anatomy slots. Pure data: add a row to add a new kind of body part.

	kind      "single" – one component id
	          "sided"  – one id for both sides, or { Right = id, Left = id }
	          "multi"  – list of entries (id string or { id=, socket=, pos=, rot=, scale=, params= })
	          "limbs"  – like multi, but a plain number means "that many extra limbs"
	order     build order (sockets defined by earlier slots are available to later ones)
	region    top-level folder under CurseBody
	folder    folder that holds this slot's geometry
	dependents  slots rebuilt when this one changes (they use its sockets)
	cap       key into Grades caps limiting how many entries/limbs are allowed
]]

local Slots = {}

Slots.list = {
	{ name = "Torso", region = "Torso", folder = "BaseTorso", kind = "single", order = 10, default = "NormalTorso",
		dependents = { "Head", "Arms", "Legs", "TorsoGrowths", "Back", "Tails", "ExtraArms", "ExtraLegs", "ExtraHeads", "Disfigurements" } },
	{ name = "Head", region = "Head", folder = "BaseHead", kind = "single", order = 20, default = "HumanCurseHead",
		dependents = { "Horns", "Eyes", "Mouths", "HeadGrowths", "Disfigurements" } },
	{ name = "Arms", region = "Arms", folder = "ArmVariant", kind = "sided", order = 30, default = "NormalArm",
		dependents = { "Hands", "ExtraArms", "Disfigurements" } },
	{ name = "Hands", region = "Arms", folder = "HandVariant", kind = "sided", order = 35, default = "OpenHand",
		dependents = { "ExtraArms", "Disfigurements" } },
	{ name = "Legs", region = "Legs", folder = "LegVariant", kind = "sided", order = 40, default = "NormalLeg",
		dependents = { "Feet", "ExtraLegs", "Disfigurements" } },
	{ name = "Feet", region = "Legs", folder = "FootVariant", kind = "sided", order = 45, default = "Foot",
		dependents = { "ExtraLegs", "Disfigurements" } },
	{ name = "ExtraArms", region = "Arms", folder = "ExtraArms", kind = "limbs", order = 50, cap = "ExtraArms",
		dependents = { "Disfigurements" } },
	{ name = "ExtraLegs", region = "Legs", folder = "ExtraLegs", kind = "limbs", order = 55, cap = "ExtraLegs",
		dependents = { "Disfigurements" } },
	{ name = "ExtraHeads", region = "Back", folder = "ExtraHeads", kind = "limbs", order = 58, cap = "ExtraHeads",
		dependents = { "Disfigurements" } },
	{ name = "Horns", region = "Head", folder = "HornSet", kind = "multi", order = 60, cap = "Horns" },
	{ name = "Eyes", region = "Head", folder = "Eyes", kind = "multi", order = 62, cap = "Eyes" },
	{ name = "Mouths", region = "Head", folder = "Mouths", kind = "multi", order = 64, cap = "Mouths" },
	{ name = "HeadGrowths", region = "Head", folder = "HeadGrowths", kind = "multi", order = 66, cap = "HeadGrowths" },
	{ name = "TorsoGrowths", region = "Torso", folder = "TorsoGrowths", kind = "multi", order = 70, cap = "TorsoGrowths",
		dependents = { "Disfigurements" } },
	{ name = "Back", region = "Back", folder = "BackParts", kind = "multi", order = 75, cap = "Back" },
	{ name = "Tails", region = "Back", folder = "Tails", kind = "multi", order = 80, cap = "Tails" },
	{ name = "Disfigurements", region = "Disfigurements", folder = "Disfigurements", kind = "multi", order = 90,
		cap = "Disfigurements" },
}

Slots.byName = {}
for _, slot in ipairs(Slots.list) do
	Slots.byName[slot.name] = slot
end
table.sort(Slots.list, function(a, b)
	return a.order < b.order
end)

function Slots.get(name)
	return Slots.byName[name]
end

-- All slots that must rebuild when `name` changes (transitively).
function Slots.dependentsOf(name, out)
	out = out or {}
	local slot = Slots.byName[name]
	for _, dep in ipairs(slot and slot.dependents or {}) do
		if not out[dep] then
			out[dep] = true
			Slots.dependentsOf(dep, out)
		end
	end
	return out
end

return Slots
