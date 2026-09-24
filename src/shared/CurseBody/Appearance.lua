--!nonstrict
--[[
	Appearance = the saved, JSON-safe description of a Curse's anatomy.

	  normalize(a)          fill defaults, migrate old/alias keys, canonical entry tables
	  sanitize(a, grade)    strip/clamp anything the grade does not allow → clean, issues
	  resolve(a, stage, grade)  apply transformation stage overrides, then sanitize
	  applyOverride(a, over)    override semantics used by transformations and equip()

	Slot values
	  single  "OctopoidHead"
	  sided   "ThinArm" | { Right = "MuscularArm", Left = "ThinArm" }
	  multi   { "RamHorns", { id = "CurvedHorn", socket = "Brow", pos = {…}, rot = {…}, scale = 1.3, params = {…} } }
	  limbs   2 | { { id = "ThinArm", hand = "BladedFingers", socket = "BackR" }, … }
	  nil for a multi slot = the head/torso component's defaults; {} = none.
]]

local Util = require(script.Parent.Util)
local Slots = require(script.Parent.Slots)
local Grades = require(script.Parent.Grades)
local Registry = require(script.Parent.Registry)
local Palettes = require(script.Parent.Palettes)
local BodyTypes = require(script.Parent.BodyTypes)

local Appearance = {}

Appearance.VERSION = 1

Appearance.DEFAULT = {
	Version = 1,
	Seed = 1,
	BodyType = "Normal",
	Palette = "Crimson",
	Height = 1,
	Scales = {},
	Layout = {},
}

-- which catalog slot validates the ids inside each limb slot
Appearance.LIMB_SLOTS = {
	ExtraArms = { id = "Arms", hand = "Hands" },
	ExtraLegs = { id = "Legs", foot = "Feet" },
	ExtraHeads = { id = "Head" },
}

-- aliases accepted from older saves / hand-written data
local ALIASES = {
	Tail = "Tails", TorsoGrowth = "TorsoGrowths", Mouth = "Mouths", Eye = "Eyes", Horn = "Horns",
	ExtraLimbs = "ExtraArms", Disfigurement = "Disfigurements", HeadGrowth = "HeadGrowths",
	BackParts = "Back", ExtraHead = "ExtraHeads", Arm = "Arms", Leg = "Legs", Hand = "Hands", Foot = "Feet",
}

local function toEntry(v)
	if type(v) == "string" then
		return { id = v }
	elseif type(v) == "table" then
		return Util.deepCopy(v)
	end
	return nil
end

function Appearance.toList(value)
	if value == nil then
		return {}
	end
	if type(value) == "number" then
		local out = {}
		for _ = 1, math.max(0, math.floor(value)) do
			table.insert(out, {})
		end
		return out
	end
	if type(value) == "string" or (type(value) == "table" and value.id) then
		return { toEntry(value) }
	end
	local out = {}
	for _, v in ipairs(value) do
		table.insert(out, toEntry(v))
	end
	return out
end

function Appearance.migrate(a)
	a = Util.deepCopy(a or {})
	for old, new in pairs(ALIASES) do
		if a[old] ~= nil and a[new] == nil then
			a[new] = a[old]
		end
		a[old] = nil
	end
	a.Version = Appearance.VERSION
	return a
end

function Appearance.normalize(a)
	a = Appearance.migrate(a)
	for k, v in pairs(Appearance.DEFAULT) do
		if a[k] == nil then
			a[k] = Util.deepCopy(v)
		end
	end
	for _, slot in ipairs(Slots.list) do
		local v = a[slot.name]
		if v ~= nil and (slot.kind == "multi" or slot.kind == "limbs") then
			a[slot.name] = Appearance.toList(v)
		end
	end
	return a
end

-- nil multi slots → defaults declared by the head / torso components
function Appearance.materializeDefaults(a)
	local head = Registry.get(a.Head or "")
	local torso = Registry.get(a.Torso or "")
	for _, slot in ipairs(Slots.list) do
		if (slot.kind == "multi" or slot.kind == "limbs") and a[slot.name] == nil then
			local d = (head and head.defaults and head.defaults[slot.name])
				or (torso and torso.defaults and torso.defaults[slot.name])
			a[slot.name] = Appearance.toList(Util.deepCopy(d))
		end
	end
	return a
end

---------------------------------------------------------------------------- sanitize

local function allowed(def, slotName, grade)
	return def ~= nil and Registry.accepts(def, slotName) and Grades.atLeast(grade, def.grade)
end

local function sanitizeId(id, slotName, grade, issues, fallback)
	local def = type(id) == "string" and Registry.get(id) or nil
	if allowed(def, slotName, grade) then
		return id
	end
	if id ~= nil then
		table.insert(issues, ("%s: %s not allowed at %s"):format(slotName, tostring(id), grade))
	end
	return fallback
end

local function clampScale(scale, grade)
	local range = Grades.cap(grade, "ScaleRange")
	local hi = 1 + 2 * range
	if type(scale) == "number" then
		return math.clamp(scale, 0.3, hi)
	elseif type(scale) == "table" then
		return { math.clamp(scale[1] or 1, 0.3, hi), math.clamp(scale[2] or 1, 0.3, hi), math.clamp(scale[3] or 1, 0.3, hi) }
	end
	return nil
end

function Appearance.sanitize(input, grade)
	grade = Grades.valid(grade) and grade or "Grade4"
	local issues = {}
	local a = Appearance.normalize(input)
	local out = {
		Version = Appearance.VERSION,
		Seed = math.floor(tonumber(a.Seed) or 1),
		Transformation = nil,
		Forms = nil,
	}

	-- body type
	if BodyTypes.exists(a.BodyType) and Grades.bodyTypeAllowed(grade, a.BodyType) then
		out.BodyType = a.BodyType
	else
		table.insert(issues, "BodyType " .. tostring(a.BodyType) .. " not allowed at " .. grade)
		out.BodyType = "Normal"
	end
	out.Palette = Palettes.valid(a.Palette) and Util.deepCopy(a.Palette) or "Crimson"
	out.Height = math.clamp(tonumber(a.Height) or 1, Grades.cap(grade, "HeightMin"), Grades.cap(grade, "HeightMax"))

	local range = Grades.cap(grade, "ScaleRange")
	out.Scales = {}
	for k, v in pairs(type(a.Scales) == "table" and a.Scales or {}) do
		if type(v) == "number" then
			out.Scales[k] = math.clamp(v, 1 - range * 0.7, 1 + range)
		end
	end
	out.Layout = {}
	for k, v in pairs(type(a.Layout) == "table" and a.Layout or {}) do
		if type(v) == "number" then
			out.Layout[k] = math.clamp(v, -40, 40)
		end
	end

	for _, slot in ipairs(Slots.list) do
		local v = a[slot.name]
		if slot.kind == "single" then
			out[slot.name] = sanitizeId(v or slot.default, slot.name, grade, issues, slot.default)
		elseif slot.kind == "sided" then
			local r, l = v, v
			if type(v) == "table" then
				r, l = v.Right, v.Left
			end
			local right = sanitizeId(r or slot.default, slot.name, grade, issues, slot.default)
			local left = sanitizeId(l or slot.default, slot.name, grade, issues, slot.default)
			out[slot.name] = right == left and right or { Right = right, Left = left }
		elseif v ~= nil then
			local cap, used, list = Grades.cap(grade, slot.cap), 0, {}
			for _, entry in ipairs(Appearance.toList(v)) do
				local ok = true
				if slot.kind == "limbs" then
					for field, catalogSlot in pairs(Appearance.LIMB_SLOTS[slot.name]) do
						if entry[field] ~= nil then
							entry[field] = sanitizeId(entry[field], catalogSlot, grade, issues, nil)
						end
					end
				else
					local def = Registry.get(entry.id or "")
					ok = allowed(def, slot.name, grade)
					if not ok then
						table.insert(issues, ("%s: %s not allowed at %s"):format(slot.name, tostring(entry.id), grade))
					end
				end
				if ok then
					local def = entry.id and Registry.get(entry.id)
					local units = (slot.kind == "limbs" or not def) and 1 or Registry.units(def, entry.params or def.params)
					if used + units <= cap then
						used += units
						entry.scale = clampScale(entry.scale, grade)
						table.insert(list, entry)
					else
						table.insert(issues, ("%s: over the %s cap of %d"):format(slot.name, grade, cap))
					end
				end
			end
			out[slot.name] = list
		end
	end

	local t = a.Transformation and Registry.getTransformation(a.Transformation)
	if t and Grades.atLeast(grade, t.grade) then
		out.Transformation = a.Transformation
	elseif a.Transformation then
		table.insert(issues, "Transformation " .. tostring(a.Transformation) .. " not allowed at " .. grade)
	end
	if type(a.Forms) == "table" then
		out.Forms = Util.deepCopy(a.Forms)
	end
	return out, issues
end

---------------------------------------------------------------------------- overrides

local function entryMatches(entry, key)
	return entry.id == key or entry.name == key
end

function Appearance.applyOverride(a, over)
	a = Util.deepCopy(a)
	for k, v in pairs(over or {}) do
		local slot = Slots.get(k)
		if k == "Scales" then
			a.Scales = a.Scales or {}
			for sk, sv in pairs(v) do
				a.Scales[sk] = (a.Scales[sk] or 1) * sv
			end
		elseif k == "Layout" then
			a.Layout = a.Layout or {}
			for lk, lv in pairs(v) do
				a.Layout[lk] = (a.Layout[lk] or 0) + lv
			end
		elseif k == "Height" and type(v) == "table" then
			a.Height = (a.Height or 1) * (v.mul or 1)
		elseif slot and (slot.kind == "multi" or slot.kind == "limbs") and type(v) == "table" and (v.add ~= nil or v.remove ~= nil) then
			local list = Appearance.toList(a[k])
			if v.remove == "all" then
				list = {}
			elseif v.remove then
				local keep = {}
				for _, entry in ipairs(list) do
					local drop = false
					for _, key in ipairs(Appearance.toList(v.remove)) do
						drop = drop or entryMatches(entry, key.id)
					end
					if not drop then
						table.insert(keep, entry)
					end
				end
				list = keep
			end
			for _, entry in ipairs(Appearance.toList(v.add)) do
				table.insert(list, entry)
			end
			a[k] = list
		else
			a[k] = Util.deepCopy(v)
		end
	end
	return a
end

-- Effective appearance for a transformation stage ("Base" | "Partial" | "Full").
function Appearance.resolve(base, stage, grade)
	local a = Appearance.materializeDefaults(Appearance.normalize(base))
	stage = stage or "Base"
	if stage ~= "Base" and Grades.formAllowed(grade, stage) then
		local def = a.Transformation and Registry.getTransformation(a.Transformation)
		local forms = a.Forms or (def and def.stages) or {}
		if stage == "Full" and forms.Partial and not (forms.Full and forms.Full.inherit == false) then
			a = Appearance.applyOverride(a, forms.Partial)
		end
		local over = forms[stage]
		if over then
			over = Util.deepCopy(over)
			over.inherit = nil
			a = Appearance.applyOverride(a, over)
		end
		-- a head swapped by the transformation brings its defaults for slots left untouched
		a = Appearance.materializeDefaults(a)
	end
	return Appearance.sanitize(a, grade)
end

return Appearance
