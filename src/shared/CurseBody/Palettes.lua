--!nonstrict
--[[
	Palettes map material ROLES to colors/materials. Components only ever ask for a
	role ("Skin", "Bone", "Void" …), so every part recolors per Curse.

	Appearance.Palette is either a palette name or a table of role → "#RRGGBB"
	(or { color = "#RRGGBB", material = "Slate", transparency = 0.2 }) layered over
	`base` (default Crimson).
]]

local Palettes = {}

Palettes.roles = {
	"Skin", "SkinLight", "SkinDark", "SkinDeep", "Flesh", "FleshDark", "Bone", "BoneDark",
	"Void", "VoidRim", "Eye", "Pupil", "Claw", "Teeth", "Membrane", "Spot", "Glow",
}

local MATERIALS = {
	Eye = "Neon", Glow = "Neon", Void = "Slate", VoidRim = "Slate",
}
local TRANSPARENCY = { Membrane = 0.15 }

Palettes.defs = {
	Crimson = { -- the reference creature
		Skin = "#942028", SkinLight = "#AC3238", SkinDark = "#68141C", SkinDeep = "#3A0A10",
		Flesh = "#CCBA96", FleshDark = "#9E8866", Bone = "#DDD3BC", BoneDark = "#A89C84",
		Void = "#0A0808", VoidRim = "#2E1C1A", Eye = "#E4E2D6", Pupil = "#140A0A",
		Claw = "#1C1414", Teeth = "#E8E0CC", Membrane = "#5A1218", Spot = "#240810", Glow = "#FF5A3C",
	},
	Pale = {
		Skin = "#D9D4CB", SkinLight = "#EEEAE2", SkinDark = "#A8A198", SkinDeep = "#6E675F",
		Flesh = "#C99A92", FleshDark = "#94645E", Bone = "#F2EEE4", BoneDark = "#BDB6A6",
		Void = "#0C0A0C", VoidRim = "#3A3033", Eye = "#1A1A1A", Pupil = "#FFFFFF",
		Claw = "#2A2626", Teeth = "#FAF6EA", Membrane = "#B8B0A6", Spot = "#8C847A", Glow = "#9FE8FF",
	},
	Ash = {
		Skin = "#4A4648", SkinLight = "#625D60", SkinDark = "#2E2B2D", SkinDeep = "#161415",
		Flesh = "#8A7D74", FleshDark = "#5E534C", Bone = "#BEB7AA", BoneDark = "#857E72",
		Void = "#050505", VoidRim = "#1E1A1A", Eye = "#FFD24A", Pupil = "#0A0A0A",
		Claw = "#0E0E0E", Teeth = "#CFC8B8", Membrane = "#2A2628", Spot = "#1A1819", Glow = "#FFB020",
	},
	Bruise = {
		Skin = "#5E3A6E", SkinLight = "#7A5088", SkinDark = "#3E2248", SkinDeep = "#20102A",
		Flesh = "#C49AA8", FleshDark = "#8E6272", Bone = "#E2D8CC", BoneDark = "#A89C90",
		Void = "#08050A", VoidRim = "#2A1830", Eye = "#E8F070", Pupil = "#140A14",
		Claw = "#1A1020", Teeth = "#EDE4D0", Membrane = "#4A2A56", Spot = "#2A1434", Glow = "#C070FF",
	},
	Bile = {
		Skin = "#7A8440", SkinLight = "#949E56", SkinDark = "#525A28", SkinDeep = "#2C3014",
		Flesh = "#D2C68A", FleshDark = "#A09660", Bone = "#E6DEBE", BoneDark = "#ACA484",
		Void = "#0A0A04", VoidRim = "#2A2A14", Eye = "#F0F0E0", Pupil = "#101008",
		Claw = "#1E1E10", Teeth = "#EEE6C8", Membrane = "#5A6230", Spot = "#3A4018", Glow = "#B8FF3C",
	},
	Void = {
		Skin = "#141216", SkinLight = "#221E26", SkinDark = "#0A090B", SkinDeep = "#040404",
		Flesh = "#3A3240", FleshDark = "#241E28", Bone = "#D8D2E0", BoneDark = "#8E8698",
		Void = "#000000", VoidRim = "#16101A", Eye = "#FF2A2A", Pupil = "#000000",
		Claw = "#E6E0EA", Teeth = "#F0EAF4", Membrane = "#0E0C10", Spot = "#2A2230", Glow = "#FF2A2A",
	},
	Flayed = {
		Skin = "#B8525A", SkinLight = "#D06E72", SkinDark = "#86343C", SkinDeep = "#4E1A20",
		Flesh = "#E8B4A4", FleshDark = "#B47C70", Bone = "#F0E6D2", BoneDark = "#B8AA92",
		Void = "#100606", VoidRim = "#3E1616", Eye = "#F8F4E8", Pupil = "#1A0A0A",
		Claw = "#2A1414", Teeth = "#F4ECD8", Membrane = "#9A3E46", Spot = "#5A2026", Glow = "#FF8A5A",
	},
}

local function toColor(value)
	if typeof(value) == "Color3" then
		return value
	end
	return Color3.fromHex(value)
end

function Palettes.exists(name)
	return Palettes.defs[name] ~= nil
end

-- Returns role → { Color = Color3, Material = Enum.Material, Transparency = number }
function Palettes.resolve(palette)
	local base = Palettes.defs.Crimson
	local custom = {}
	if type(palette) == "string" then
		base = Palettes.defs[palette] or base
	elseif type(palette) == "table" then
		base = Palettes.defs[palette.base] or base
		custom = palette
	end
	local out = {}
	for _, role in ipairs(Palettes.roles) do
		local entry = custom[role]
		local color, material, transparency = base[role], MATERIALS[role] or "SmoothPlastic", TRANSPARENCY[role] or 0
		if type(entry) == "string" then
			color = entry
		elseif type(entry) == "table" then
			color = entry.color or color
			material = entry.material or material
			transparency = entry.transparency or transparency
		end
		local ok, c = pcall(toColor, color)
		local okMaterial, enumMaterial = pcall(function()
			return Enum.Material[material]
		end)
		out[role] = {
			Color = ok and c or Color3.new(1, 0, 1),
			Material = okMaterial and enumMaterial or Enum.Material.SmoothPlastic,
			Transparency = transparency,
		}
	end
	return out
end

function Palettes.valid(palette)
	if type(palette) == "string" then
		return Palettes.defs[palette] ~= nil
	end
	return type(palette) == "table"
end

return Palettes
