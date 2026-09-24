--!nonstrict
--[[
	Body archetypes. A body type does NOT scale the character: it changes how big
	each region is built (mass) and where the R6 joints sit (layout). Region
	components read these through ctx:m("ArmThick") etc.

	mass keys (1 = normal)
	  TorsoW TorsoH TorsoD  torso shell width / height / depth
	  Shoulder              shoulder + trapezius mass
	  Neck                  neck / upper-back mass wrapped around the head
	  Head                  head size
	  ArmThick ArmLength    arm girth / visible arm length (hands hang lower)
	  Hand Foot             hand / foot size
	  LegThick              leg girth
	layout keys
	  hunch          forward lean of the torso in degrees (moves neck + shoulders with it)
	  neckForward    extra forward offset of the head
	  neckDrop       how deep the head sinks between the shoulders
	  shoulderDrop / shoulderForward / hipSpread
	  legExtra       studs added to visible leg length (Humanoid.HipHeight offset)
]]

local Util = require(script.Parent.Util)

local BodyTypes = {}

local NORMAL_MASS = {
	TorsoW = 1, TorsoH = 1, TorsoD = 1, Shoulder = 1, Neck = 1, Head = 1,
	ArmThick = 1, ArmLength = 1, Hand = 1, LegThick = 1, Foot = 1,
}
local NORMAL_LAYOUT = {
	hunch = 0, neckForward = 0, neckDrop = 0, shoulderDrop = 0, shoulderForward = 0, hipSpread = 0, legExtra = 0,
}

BodyTypes.defs = {
	Lean = {
		mass = { TorsoW = 0.85, TorsoH = 1.05, TorsoD = 0.8, Shoulder = 0.8, Neck = 0.8, ArmThick = 0.72,
			ArmLength = 1.1, Hand = 0.95, LegThick = 0.72, Foot = 0.95 },
		layout = { hunch = 4, legExtra = 0.15 },
	},
	Normal = {},
	Muscular = {
		mass = { TorsoW = 1.2, TorsoD = 1.1, Shoulder = 1.3, Neck = 1.25, Head = 0.95, ArmThick = 1.25,
			Hand = 1.1, LegThick = 1.15, Foot = 1.05 },
		layout = { hunch = 5, neckDrop = 0.1 },
	},
	Heavy = {
		mass = { TorsoW = 1.35, TorsoD = 1.3, Shoulder = 1.35, Neck = 1.4, Head = 0.95, ArmThick = 1.35,
			Hand = 1.25, LegThick = 1.35, Foot = 1.2 },
		layout = { hunch = 8, neckDrop = 0.2 },
	},
	Hunched = { -- the reference creature's build
		mass = { TorsoW = 1.25, TorsoH = 1.05, TorsoD = 1.25, Shoulder = 1.3, Neck = 1.3, Head = 1.05,
			ArmThick = 1.2, ArmLength = 1.25, Hand = 1.25, LegThick = 1.1, Foot = 1.3 },
		layout = { hunch = 26, neckForward = 0.15, neckDrop = 0.35, shoulderDrop = 0.1 },
	},
	Deformed = {
		mass = { TorsoW = 1.15, TorsoD = 1.1, Shoulder = 1.15, Neck = 1.2, ArmThick = 1.1, Hand = 1.1, LegThick = 1.05 },
		layout = { hunch = 14, neckDrop = 0.2 },
		side = {
			Right = { ArmThick = 1.35, ArmLength = 1.15, Hand = 1.45, Shoulder = 1.45 },
			Left = { ArmThick = 0.8, ArmLength = 0.9, Hand = 0.85, LegThick = 0.9 },
		},
	},
	Monstrous = {
		mass = { TorsoW = 1.5, TorsoH = 1.1, TorsoD = 1.45, Shoulder = 1.6, Neck = 1.5, Head = 0.9,
			ArmThick = 1.55, ArmLength = 1.3, Hand = 1.5, LegThick = 1.45, Foot = 1.4 },
		layout = { hunch = 22, neckForward = 0.1, neckDrop = 0.2, shoulderDrop = 0.05 },
	},
	Massive = {
		mass = { TorsoW = 1.8, TorsoH = 1.2, TorsoD = 1.7, Shoulder = 1.9, Neck = 1.8, Head = 0.8,
			ArmThick = 1.8, ArmLength = 1.2, Hand = 1.7, LegThick = 1.75, Foot = 1.6 },
		layout = { hunch = 14, neckDrop = 0.45, legExtra = 0.3 },
	},
}

-- Appearance.Scales keys → mass keys they multiply
BodyTypes.scaleKeys = {
	Torso = { "TorsoW", "TorsoH", "TorsoD" },
	Shoulders = { "Shoulder" },
	Neck = { "Neck" },
	Head = { "Head" },
	Arms = { "ArmThick" },
	ArmLength = { "ArmLength" },
	Hands = { "Hand" },
	Legs = { "LegThick" },
	Feet = { "Foot" },
}

function BodyTypes.exists(name)
	return BodyTypes.defs[name] ~= nil
end

--[[
	Resolve a body: body type → Appearance.Scales (already grade-clamped).
	Component mutate hooks and transformation layouts are applied afterwards by the caller.
]]
function BodyTypes.resolve(appearance)
	local def = BodyTypes.defs[appearance.BodyType] or BodyTypes.defs.Normal
	local body = {
		type = appearance.BodyType,
		mass = Util.merge(NORMAL_MASS, def.mass),
		layout = Util.merge(NORMAL_LAYOUT, def.layout),
		side = { Right = Util.deepCopy(def.side and def.side.Right or {}), Left = Util.deepCopy(def.side and def.side.Left or {}) },
	}
	for scaleKey, value in pairs(appearance.Scales or {}) do
		local sideName, key = string.match(scaleKey, "^(%a-)_(%a+)$")
		local targets = BodyTypes.scaleKeys[key or scaleKey]
		if targets then
			for _, massKey in ipairs(targets) do
				if sideName == "Right" or sideName == "Left" then
					body.side[sideName][massKey] = (body.side[sideName][massKey] or 1) * value
				else
					body.mass[massKey] = body.mass[massKey] * value
				end
			end
		end
	end
	return body
end

-- mass value for a key, including the per-side multiplier ("Right"/"Left"/nil)
function BodyTypes.get(body, key, sideName)
	local v = body.mass[key] or 1
	if sideName and body.side[sideName] and body.side[sideName][key] then
		v *= body.side[sideName][key]
	end
	return v
end

return BodyTypes
