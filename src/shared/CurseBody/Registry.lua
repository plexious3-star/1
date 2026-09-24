--!nonstrict
--[[
	Component registry. Every body part, horn, growth and transformation is a
	table registered here; the core never hardcodes a component.

	Component fields
	  id        unique string
	  slots     list of slot names that accept it
	  grade     minimum grade (default "Grade4")
	  tags      free-form list (for UI filters)
	  params    default parameters (overridable per appearance entry)
	  defaults  (heads) default Eyes/Mouths/HeadGrowths when the appearance leaves them nil
	  count     number or function(params) → how many units it uses against the slot cap
	  build     function(ctx, params, entry)   – creates geometry
	  mutate    function(body, params, entry)  – optional, changes proportions before building

	Catalog modules return an array of component tables, or a function(Registry).
	Modules whose name starts with "_" are helpers and are not auto-loaded.
]]

local Grades = require(script.Parent.Grades)
local Slots = require(script.Parent.Slots)

local Registry = {}

local components = {}
local transformations = {}
local loaded = false

function Registry.register(def)
	assert(type(def) == "table" and type(def.id) == "string", "component needs an id")
	assert(type(def.slots) == "table" and #def.slots > 0, def.id .. ": component needs slots")
	for _, slotName in ipairs(def.slots) do
		assert(Slots.get(slotName), def.id .. ": unknown slot " .. tostring(slotName))
	end
	assert(def.build or def.mutate, def.id .. ": component needs build or mutate")
	def.grade = def.grade or "Grade4"
	assert(Grades.valid(def.grade), def.id .. ": bad grade " .. tostring(def.grade))
	def.params = def.params or {}
	def.tags = def.tags or {}
	if components[def.id] then
		warn("[CurseBody] component " .. def.id .. " registered twice; replacing")
	end
	components[def.id] = def
	return def
end

local pendingVariants = {}
local loading = false

-- Register a variant of an existing component with different default params.
-- While the catalog loads, variants of components from later modules are deferred.
function Registry.variant(baseId, def)
	local base = components[baseId]
	if not base and loading then
		table.insert(pendingVariants, { baseId, def })
		return def
	end
	assert(base, "variant of unknown component " .. tostring(baseId))
	local params = table.clone(base.params)
	for k, v in pairs(def.params or {}) do
		params[k] = v
	end
	local out = table.clone(base)
	for k, v in pairs(def) do
		out[k] = v
	end
	out.params = params
	out.base = baseId
	return Registry.register(out)
end

function Registry.registerTransformation(def)
	assert(type(def.id) == "string" and type(def.stages) == "table", "transformation needs id + stages")
	def.grade = def.grade or "Grade3"
	transformations[def.id] = def
	return def
end

function Registry.get(id)
	return components[id]
end

function Registry.getTransformation(id)
	return transformations[id]
end

function Registry.accepts(def, slotName)
	if not def then
		return false
	end
	for _, s in ipairs(def.slots) do
		if s == slotName then
			return true
		end
	end
	return false
end

-- Components usable in a slot (optionally only those the grade unlocks), sorted by id.
function Registry.list(slotName, grade)
	local out = {}
	for _, def in pairs(components) do
		if Registry.accepts(def, slotName) and (grade == nil or Grades.atLeast(grade, def.grade)) then
			table.insert(out, def)
		end
	end
	table.sort(out, function(a, b)
		return a.id < b.id
	end)
	return out
end

function Registry.listTransformations(grade)
	local out = {}
	for _, def in pairs(transformations) do
		if grade == nil or Grades.atLeast(grade, def.grade) then
			table.insert(out, def)
		end
	end
	table.sort(out, function(a, b)
		return a.id < b.id
	end)
	return out
end

function Registry.all()
	return components
end

function Registry.units(def, params)
	local c = def.count
	if type(c) == "function" then
		return c(params)
	end
	return c or 1
end

function Registry.loadModule(module)
	local result = require(module)
	if type(result) == "function" then
		result(Registry)
	elseif type(result) == "table" then
		for _, def in ipairs(result) do
			if def.stages then
				Registry.registerTransformation(def)
			else
				Registry.register(def)
			end
		end
	end
end

function Registry.loadCatalog(folder)
	if loaded then
		return
	end
	loaded = true
	local modules = {}
	for _, child in ipairs(folder:GetChildren()) do
		if child:IsA("ModuleScript") and string.sub(child.Name, 1, 1) ~= "_" then
			table.insert(modules, child)
		end
	end
	table.sort(modules, function(a, b)
		return a.Name < b.Name
	end)
	loading = true
	for _, module in ipairs(modules) do
		Registry.loadModule(module)
	end
	loading = false
	-- resolve deferred variants (a variant may itself be the base of another)
	local progress = true
	while #pendingVariants > 0 and progress do
		progress = false
		local still = {}
		for _, v in ipairs(pendingVariants) do
			if components[v[1]] then
				Registry.variant(v[1], v[2])
				progress = true
			else
				table.insert(still, v)
			end
		end
		pendingVariants = still
	end
	for _, v in ipairs(pendingVariants) do
		warn("[CurseBody] variant " .. tostring(v[2].id) .. " of unknown component " .. tostring(v[1]))
	end
end

return Registry
