--!nonstrict
--[[
	CurseBody — modular R6 Curse anatomy.

	local CurseBody = require(ReplicatedStorage.CurseBody)
	CurseBody.apply(character, appearance, { grade = "Grade2" })   -- build / rebuild
	CurseBody.setForm(character, "Full")                            -- transformation stage
	CurseBody.equip(character, "Horns", { "RamHorns" })             -- change one slot
	CurseBody.setGrade(character, "Grade1")

	See docs/ARCHITECTURE.md. Server-side only: geometry built on the server replicates.
]]

local HttpService = game:GetService("HttpService")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local Util = require(script.Util)
local Slots = require(script.Slots)
local Grades = require(script.Grades)
local Registry = require(script.Registry)
local Palettes = require(script.Palettes)
local BodyTypes = require(script.BodyTypes)
local Appearance = require(script.Appearance)
local Rig = require(script.Rig)
local Builder = require(script.Builder)

local CurseBody = {
	Util = Util,
	Slots = Slots,
	Grades = Grades,
	Registry = Registry,
	Palettes = Palettes,
	BodyTypes = BodyTypes,
	Appearance = Appearance,
	Rig = Rig,
	Builder = Builder,
}

local states = setmetatable({}, { __mode = "k" })

Registry.loadCatalog(script.Catalog)
CurseBody.Presets = require(script.Presets)

---------------------------------------------------------------------------- building

local function mergeParams(def, entry, overrides)
	local params = table.clone(def.params)
	for k, v in pairs(entry.params or {}) do
		params[k] = v
	end
	for k, v in pairs(overrides or {}) do
		params[k] = v
	end
	return params
end

local function buildComponent(ctx, id, entry, overrides)
	local def = Registry.get(id or "")
	if not def or not def.build then
		return nil
	end
	local params = mergeParams(def, entry or {}, overrides)
	local ok, result = pcall(def.build, ctx, params, entry or {})
	if not ok then
		warn(("[CurseBody] %s failed to build: %s"):format(id, tostring(result)))
		return nil
	end
	return result
end

local SWAP = { R = "L", L = "R" }
local function mirroredSocketName(name)
	local base, suffix = string.match(name, "^(.-_?)([RL])$")
	if base and SWAP[suffix] then
		return base .. SWAP[suffix]
	end
	return nil
end

-- Build one entry of a multi slot at its socket (+ offset, rotation, scale, mirror).
local function buildEntry(ctx, entry)
	local def = Registry.get(entry.id or "")
	if not def then
		return
	end
	local function at(socketName)
		local anchor = ctx:socket(socketName)
		local cf = anchor.cf * ctx:with({ side = 1, scale = Vector3.one }, function()
			return ctx:localCF(entry.pos, entry.rot)
		end)
		local scale = Util.v3(entry.scale, Vector3.one)
		ctx:with({
			at = { part = anchor.part, cf = cf, side = anchor.side },
			side = anchor.side,
			sideName = anchor.side > 0 and "Right" or "Left",
			scale = scale,
			entry = entry,
		}, buildComponent, ctx, entry.id, entry)
	end
	local socketName = entry.socket or def.params.socket or "Chest"
	at(socketName)
	if entry.mirror then
		local other = mirroredSocketName(socketName)
		if other then
			at(other)
		end
	end
end
CurseBody.buildEntry = buildEntry

local function mainId(value, sideName)
	if type(value) == "table" then
		return value[sideName]
	end
	return value
end

local function torsoLocal(ctx, anchor)
	local torso = ctx.character.Torso
	return torso.CFrame:ToObjectSpace(anchor.part.CFrame * anchor.cf)
end

-- Limb slots -----------------------------------------------------------------

local AUTO_ARM_SOCKETS = { "FlankR", "FlankL", "BackR", "BackL", "ChestLowR", "ChestLowL", "ShoulderR", "ShoulderL" }
local AUTO_HEAD_SOCKETS = { "ShoulderR", "ShoulderL", "UpperBack", "BackR", "BackL", "ChestR", "ChestL" }

local LIMB_BUILDERS = {}

function LIMB_BUILDERS.ExtraArms(ctx, list, eff)
	for i, e in ipairs(list) do
		local socketName = e.socket or AUTO_ARM_SOCKETS[(i - 1) % #AUTO_ARM_SOCKETS + 1]
		local anchor = ctx:socket(socketName)
		local side = anchor.side
		local sideName = side > 0 and "Right" or "Left"
		local pos = torsoLocal(ctx, anchor).Position
		local tier = math.floor((i - 1) / 2)
		local limb = ctx:limb("Arm", "ExtraArm" .. i, side, pos, sideName .. " Shoulder", {
			splay = e.splay or (14 + 10 * tier),
			tilt = e.tilt or 0,
			delay = 0.08 + 0.06 * i,
			mirrorScale = e.mirrorScale or ((tier % 2 == 1) and -0.8 or 0.85),
		})
		ctx:with({ side = side, sideName = sideName, suffix = "E" .. i }, function()
			buildComponent(ctx, e.id or mainId(eff.Arms, sideName), { part = limb })
			buildComponent(ctx, e.hand or mainId(eff.Hands, sideName), { part = limb })
		end)
	end
end

function LIMB_BUILDERS.ExtraLegs(ctx, list, eff)
	for i, e in ipairs(list) do
		local side = (i % 2 == 1) and 1 or -1
		local sideName = side > 0 and "Right" or "Left"
		local tier = math.floor((i - 1) / 2) + 1
		local pos
		if e.socket then
			pos = torsoLocal(ctx, ctx:socket(e.socket)).Position
		else
			local hip = ctx.layout["hip" .. sideName]
			pos = hip + Vector3.new(side * 0.35 * tier, 0.25, 0.55 * tier)
		end
		local limb = ctx:limb("Leg", "ExtraLeg" .. i, side, pos, (tier % 2 == 1) and ((side > 0) and "Left Hip" or "Right Hip")
			or (sideName .. " Hip"), {
			splay = e.splay or (18 + 10 * tier),
			delay = 0.05 * tier,
			mirrorScale = e.mirrorScale or 0.9,
		})
		ctx:with({ side = side, sideName = sideName, suffix = "X" .. i }, function()
			buildComponent(ctx, e.id or mainId(eff.Legs, sideName), { part = limb, extra = true })
			buildComponent(ctx, e.foot or mainId(eff.Feet, sideName), { part = limb, extra = true })
		end)
	end
end

function LIMB_BUILDERS.ExtraHeads(ctx, list, eff)
	for i, e in ipairs(list) do
		local socketName = e.socket or AUTO_HEAD_SOCKETS[(i - 1) % #AUTO_HEAD_SOCKETS + 1]
		local anchor = ctx:socket(socketName)
		local side = anchor.side
		local pos = torsoLocal(ctx, anchor).Position + Vector3.new(0, -0.1, 0)
		local limb = ctx:limb("Head", "ExtraHead" .. i, 1, pos, "Neck", {
			yaw = e.yaw or (side * 25),
			tilt = e.tilt or 0,
			delay = 0.15 + 0.05 * i,
			mirrorScale = 0.6,
		})
		local headId = e.id or eff.Head
		local prefix = "H" .. i .. "_"
		ctx:with({ side = 1, sideName = nil, socketPrefix = prefix, scale = Util.v3(e.scale, Vector3.one) * 0.85 },
			function()
				buildComponent(ctx, headId, { part = limb })
				local def = Registry.get(headId)
				local features = {}
				for _, slotName in ipairs({ "Eyes", "Mouths", "HeadGrowths", "Horns" }) do
					local list2 = e[slotName] or (def and def.defaults and def.defaults[slotName])
					for _, fe in ipairs(Appearance.toList(list2)) do
						table.insert(features, fe)
					end
				end
				for _, fe in ipairs(features) do
					buildEntry(ctx, fe)
				end
			end)
	end
end

---------------------------------------------------------------------------- slot rebuild

local function regionFolder(state, region)
	local f = state.curse:FindFirstChild(region)
	if not f then
		f = Instance.new("Folder")
		f.Name = region
		f.Parent = state.curse
	end
	return f
end

local function clearSockets(state, owner)
	for name, s in pairs(state.sockets) do
		if s.owner == owner then
			local att = s.part and s.part:FindFirstChild("CurseSocket_" .. name)
			if att and att:GetAttribute("Owner") == owner then
				att:Destroy()
			end
			state.sockets[name] = nil
		end
	end
end

local function rebuildSlot(state, slot, growIn)
	local region = regionFolder(state, slot.region)
	local old = region:FindFirstChild(slot.folder)
	if old then
		old:Destroy()
	end
	clearSockets(state, slot.name)
	local value = state.effective[slot.name]
	if value == nil or (type(value) == "table" and #value == 0 and slot.kind ~= "sided") then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = slot.folder
	if growIn then
		folder:SetAttribute("GrowIn", true)
	end
	local ctx = Builder.new(state)
	ctx.folder = folder
	ctx.owner = slot.name
	if slot.kind == "single" then
		buildComponent(ctx, value, {})
	elseif slot.kind == "sided" then
		for _, sideName in ipairs({ "Right", "Left" }) do
			local s = sideName == "Right" and 1 or -1
			ctx:with({ side = s, sideName = sideName, suffix = string.sub(sideName, 1, 1) }, buildComponent, ctx,
				mainId(value, sideName), {})
		end
	elseif slot.kind == "multi" then
		for _, entry in ipairs(value) do
			buildEntry(ctx, entry)
		end
	elseif slot.kind == "limbs" then
		LIMB_BUILDERS[slot.name](ctx, value, state.effective)
	end
	folder.Parent = region
end

local function forEachComponent(eff, fn)
	for _, slot in ipairs(Slots.list) do
		local v = eff[slot.name]
		if slot.kind == "single" and v then
			local def = Registry.get(v)
			if def then
				fn(def, def.params, {}, nil)
			end
		elseif slot.kind == "sided" and v then
			for _, sideName in ipairs({ "Right", "Left" }) do
				local def = Registry.get(mainId(v, sideName) or "")
				if def then
					fn(def, def.params, {}, sideName)
				end
			end
		elseif slot.kind == "multi" and type(v) == "table" then
			for _, entry in ipairs(v) do
				local def = Registry.get(entry.id or "")
				if def then
					fn(def, mergeParams(def, entry), entry, nil)
				end
			end
		end
	end
end

local function resolveBody(eff)
	local body = BodyTypes.resolve(eff)
	for k, v in pairs(eff.Layout or {}) do
		body.layout[k] = (body.layout[k] or 0) + v
	end
	forEachComponent(eff, function(def, params, entry, sideName)
		if def.mutate then
			local ok, err = pcall(def.mutate, body, params, entry, sideName)
			if not ok then
				warn("[CurseBody] " .. def.id .. " mutate failed: " .. tostring(err))
			end
		end
	end)
	return body
end

local function refresh(state, opts)
	opts = opts or {}
	local character = state.character
	local eff, issues = Appearance.resolve(state.base, state.form, state.grade)
	local body = resolveBody(eff)
	local layout = Rig.computeLayout(body)
	local bodyKey = Util.serialize({ body.mass, body.side, body.layout, eff.Palette, eff.Seed })
	local full = opts.full or bodyKey ~= state.bodyKey

	local scale = character:GetScale()
	if math.abs(scale - 1) > 1e-3 then
		character:ScaleTo(1)
	end

	state.effective, state.body, state.layout, state.bodyKey = eff, body, layout, bodyKey
	state.palette = Palettes.resolve(eff.Palette)
	Rig.applyLayout(character, layout)
	if not RunService:IsRunning() then
		Rig.snap(character)
	end

	state.defaultSockets = {}
	for name, s in pairs(Rig.defaultSockets(body, layout)) do
		state.defaultSockets[name] = {
			part = character[s[1]],
			cf = CFrame.new(s[2]) * s[3],
			side = s[4] or 1,
			owner = "Rig",
		}
	end

	if full then
		for _, region in ipairs(state.curse:GetChildren()) do
			region:Destroy()
		end
		for name, s in pairs(state.sockets) do
			local att = s.part and s.part:FindFirstChild("CurseSocket_" .. name)
			if att then
				att:Destroy()
			end
		end
		state.sockets = {}
		state.built = {}
	end

	local dirty = {}
	for _, slot in ipairs(Slots.list) do
		local key = Util.serialize(eff[slot.name])
		if full or dirty[slot.name] or state.built[slot.name] ~= key then
			rebuildSlot(state, slot, opts.growIn)
			state.built[slot.name] = key
			for dep in pairs(Slots.dependentsOf(slot.name)) do
				dirty[dep] = true
			end
		end
	end

	if math.abs(eff.Height - 1) > 1e-3 then
		character:ScaleTo(eff.Height)
	end
	character:SetAttribute("CurseAppearance", HttpService:JSONEncode(eff))
	character:SetAttribute("CurseGrade", state.grade)
	character:SetAttribute("CurseForm", state.form)
	CollectionService:AddTag(character, "CurseBody")
	state.issues = issues
	return state, issues
end

---------------------------------------------------------------------------- public API

function CurseBody.apply(character, appearance, opts)
	opts = opts or {}
	local ok, err = Rig.isR6(character)
	if not ok then
		error("[CurseBody] " .. err, 2)
	end
	local state = states[character]
	if not state then
		state = {
			character = character,
			sockets = {},
			defaultSockets = {},
			built = {},
			form = "Base",
			buildComponent = buildComponent,
			buildEntry = buildEntry,
		}
		states[character] = state
	end
	state.grade = opts.grade or state.grade or "Grade4"
	state.form = opts.form or state.form or "Base"
	state.base = Appearance.sanitize(appearance, state.grade)
	state.curse = Rig.prepare(character, opts.hideBase)
	return refresh(state, { full = true })
end

function CurseBody.getState(character)
	return states[character]
end

function CurseBody.setForm(character, stage)
	local state = states[character]
	if not state then
		return false, "no curse body"
	end
	if not Grades.formStages[stage] then
		return false, "unknown stage " .. tostring(stage)
	end
	if not Grades.formAllowed(state.grade, stage) then
		return false, stage .. " is locked at " .. state.grade
	end
	if stage ~= "Base" and not state.base.Transformation and not state.base.Forms then
		return false, "no transformation equipped"
	end
	state.form = stage
	refresh(state, { growIn = true })
	return true
end

-- Replace a slot (or BodyType / Palette / Height / Scales / Transformation) in the base appearance.
function CurseBody.equip(character, key, value)
	local state = states[character]
	assert(state, "no curse body")
	local a = Util.deepCopy(state.base)
	a[key] = value
	state.base = Appearance.sanitize(a, state.grade)
	return refresh(state, { growIn = true })
end

function CurseBody.unequip(character, slotName, id)
	local state = states[character]
	assert(state, "no curse body")
	local slot = Slots.get(slotName)
	local a = Util.deepCopy(state.base)
	if slot and (slot.kind == "multi" or slot.kind == "limbs") then
		a = Appearance.applyOverride(a, { [slotName] = { remove = id or "all" } })
	else
		a[slotName] = nil
	end
	state.base = Appearance.sanitize(a, state.grade)
	return refresh(state, { growIn = true })
end

function CurseBody.setGrade(character, grade)
	local state = states[character]
	assert(state and Grades.valid(grade), "bad grade")
	state.grade = grade
	if not Grades.formAllowed(grade, state.form) then
		state.form = "Base"
	end
	state.base = Appearance.sanitize(state.base, grade)
	return refresh(state, { full = true })
end

function CurseBody.getAppearance(character)
	local state = states[character]
	return state and Util.deepCopy(state.base)
end

-- Make the current form permanent (merge its overrides into the base appearance).
function CurseBody.commitForm(character)
	local state = states[character]
	assert(state, "no curse body")
	local committed = Util.deepCopy(state.effective)
	committed.Transformation = state.base.Transformation
	committed.Forms = state.base.Forms
	state.base = committed
	state.form = "Base"
	return refresh(state, {})
end

function CurseBody.remove(character)
	local state = states[character]
	if state and state.curse then
		state.curse:Destroy()
	end
	states[character] = nil
	for _, name in ipairs(Rig.PARTS) do
		local p = character:FindFirstChild(name)
		if p then
			p.Transparency = 0
		end
	end
	CollectionService:RemoveTag(character, "CurseBody")
end

function CurseBody.createRig(name, cframe)
	return Rig.create(name, cframe)
end

return CurseBody
