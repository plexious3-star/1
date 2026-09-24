--!nonstrict
-- Minimal Roblox API mock: enough of Vector3 / CFrame / Instance / services to run
-- the CurseBody framework headless and dump what it builds. Not a Roblox emulator:
-- physics, rendering and replication are out of scope.

local MOCK = {}
local WARNINGS = {}
MOCK.warnings = WARNINGS

local rawtypeof = typeof
function typeof(v)
	local mt = getmetatable(v)
	if type(mt) == "table" and mt.__type then
		return mt.__type
	end
	return rawtypeof(v)
end

function warn(...)
	local parts = {}
	for i = 1, select("#", ...) do
		parts[i] = tostring((select(i, ...)))
	end
	local msg = table.concat(parts, " ")
	table.insert(WARNINGS, msg)
end

---------------------------------------------------------------------------- Vector3
local V3 = { __type = "Vector3" }
Vector3 = {}
local function v3(x, y, z)
	return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, V3)
end
Vector3.new = v3
Vector3.zero = v3(0, 0, 0)
Vector3.one = v3(1, 1, 1)
Vector3.xAxis = v3(1, 0, 0)
Vector3.yAxis = v3(0, 1, 0)
Vector3.zAxis = v3(0, 0, 1)
V3.__add = function(a, b)
	return v3(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
end
V3.__sub = function(a, b)
	return v3(a.X - b.X, a.Y - b.Y, a.Z - b.Z)
end
V3.__unm = function(a)
	return v3(-a.X, -a.Y, -a.Z)
end
V3.__mul = function(a, b)
	if type(a) == "number" then
		return v3(b.X * a, b.Y * a, b.Z * a)
	elseif type(b) == "number" then
		return v3(a.X * b, a.Y * b, a.Z * b)
	end
	return v3(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
V3.__div = function(a, b)
	if type(b) == "number" then
		return v3(a.X / b, a.Y / b, a.Z / b)
	end
	return v3(a.X / b.X, a.Y / b.Y, a.Z / b.Z)
end
V3.__eq = function(a, b)
	return a.X == b.X and a.Y == b.Y and a.Z == b.Z
end
V3.__tostring = function(a)
	return string.format("%g, %g, %g", a.X, a.Y, a.Z)
end
local V3methods = {
	Dot = function(a, b)
		return a.X * b.X + a.Y * b.Y + a.Z * b.Z
	end,
	Cross = function(a, b)
		return v3(a.Y * b.Z - a.Z * b.Y, a.Z * b.X - a.X * b.Z, a.X * b.Y - a.Y * b.X)
	end,
	Lerp = function(a, b, t)
		return a + (b - a) * t
	end,
	Abs = function(a)
		return v3(math.abs(a.X), math.abs(a.Y), math.abs(a.Z))
	end,
}
V3.__index = function(a, k)
	if k == "Magnitude" then
		return math.sqrt(a.X * a.X + a.Y * a.Y + a.Z * a.Z)
	elseif k == "Unit" then
		local m = math.sqrt(a.X * a.X + a.Y * a.Y + a.Z * a.Z)
		return m > 0 and v3(a.X / m, a.Y / m, a.Z / m) or v3(0, 0, 0)
	end
	local f = V3methods[k]
	if f then
		return f
	end
	error("Vector3 has no member " .. tostring(k), 2)
end

---------------------------------------------------------------------------- CFrame
local CFm = { __type = "CFrame" }
CFrame = {}
local function cf(x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22)
	return setmetatable({
		x = x, y = y, z = z,
		r00 = r00, r01 = r01, r02 = r02,
		r10 = r10, r11 = r11, r12 = r12,
		r20 = r20, r21 = r21, r22 = r22,
	}, CFm)
end
function CFrame.new(a, b, c, ...)
	if a == nil then
		return cf(0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1)
	end
	if typeof(a) == "Vector3" then
		return cf(a.X, a.Y, a.Z, 1, 0, 0, 0, 1, 0, 0, 0, 1)
	end
	local rest = { ... }
	if #rest == 9 then
		return cf(a, b, c, table.unpack(rest))
	end
	return cf(a, b, c, 1, 0, 0, 0, 1, 0, 0, 0, 1)
end
CFrame.identity = CFrame.new()
local function mulR(A, B)
	return A.r00 * B.r00 + A.r01 * B.r10 + A.r02 * B.r20, A.r00 * B.r01 + A.r01 * B.r11 + A.r02 * B.r21,
		A.r00 * B.r02 + A.r01 * B.r12 + A.r02 * B.r22, A.r10 * B.r00 + A.r11 * B.r10 + A.r12 * B.r20,
		A.r10 * B.r01 + A.r11 * B.r11 + A.r12 * B.r21, A.r10 * B.r02 + A.r11 * B.r12 + A.r12 * B.r22,
		A.r20 * B.r00 + A.r21 * B.r10 + A.r22 * B.r20, A.r20 * B.r01 + A.r21 * B.r11 + A.r22 * B.r21,
		A.r20 * B.r02 + A.r21 * B.r12 + A.r22 * B.r22
end
local function rot(c, v)
	return c.r00 * v.X + c.r01 * v.Y + c.r02 * v.Z, c.r10 * v.X + c.r11 * v.Y + c.r12 * v.Z,
		c.r20 * v.X + c.r21 * v.Y + c.r22 * v.Z
end
function CFrame.Angles(rx, ry, rz)
	local cx, sx, cy, sy, cz, sz = math.cos(rx), math.sin(rx), math.cos(ry), math.sin(ry), math.cos(rz), math.sin(rz)
	local X = cf(0, 0, 0, 1, 0, 0, 0, cx, -sx, 0, sx, cx)
	local Y = cf(0, 0, 0, cy, 0, sy, 0, 1, 0, -sy, 0, cy)
	local Z = cf(0, 0, 0, cz, -sz, 0, sz, cz, 0, 0, 0, 1)
	return X * Y * Z
end
CFrame.fromEulerAnglesXYZ = CFrame.Angles
function CFrame.fromMatrix(pos, vx, vy, vz)
	vz = vz or vx:Cross(vy).Unit
	return cf(pos.X, pos.Y, pos.Z, vx.X, vy.X, vz.X, vx.Y, vy.Y, vz.Y, vx.Z, vy.Z, vz.Z)
end
function CFrame.lookAt(at, target, up)
	up = up or Vector3.yAxis
	local look = (target - at).Unit
	local right = look:Cross(up).Unit
	local up2 = right:Cross(look).Unit
	return CFrame.fromMatrix(at, right, up2, -look)
end
CFm.__mul = function(a, b)
	if typeof(b) == "Vector3" then
		local x, y, z = rot(a, b)
		return v3(x + a.x, y + a.y, z + a.z)
	end
	local x, y, z = rot(a, v3(b.x, b.y, b.z))
	return cf(x + a.x, y + a.y, z + a.z, mulR(a, b))
end
CFm.__add = function(a, v)
	return cf(a.x + v.X, a.y + v.Y, a.z + v.Z, a.r00, a.r01, a.r02, a.r10, a.r11, a.r12, a.r20, a.r21, a.r22)
end
CFm.__sub = function(a, v)
	return cf(a.x - v.X, a.y - v.Y, a.z - v.Z, a.r00, a.r01, a.r02, a.r10, a.r11, a.r12, a.r20, a.r21, a.r22)
end
local CFmethods = {}
function CFmethods.Inverse(c)
	-- rotation is orthonormal: inverse = transpose
	local t = cf(0, 0, 0, c.r00, c.r10, c.r20, c.r01, c.r11, c.r21, c.r02, c.r12, c.r22)
	local x, y, z = rot(t, v3(c.x, c.y, c.z))
	t.x, t.y, t.z = -x, -y, -z
	return t
end
function CFmethods.ToObjectSpace(a, b)
	return a:Inverse() * b
end
function CFmethods.ToWorldSpace(a, b)
	return a * b
end
function CFmethods.PointToWorldSpace(a, v)
	return a * v
end
function CFmethods.PointToObjectSpace(a, v)
	return a:Inverse() * v
end
function CFmethods.VectorToWorldSpace(a, v)
	return v3(rot(a, v))
end
function CFmethods.GetComponents(c)
	return c.x, c.y, c.z, c.r00, c.r01, c.r02, c.r10, c.r11, c.r12, c.r20, c.r21, c.r22
end
function CFmethods.Lerp(a, b, t)
	-- good enough for the mock (position + normalized linear rotation blend)
	local function l(p, q)
		return p + (q - p) * t
	end
	return cf(l(a.x, b.x), l(a.y, b.y), l(a.z, b.z), l(a.r00, b.r00), l(a.r01, b.r01), l(a.r02, b.r02),
		l(a.r10, b.r10), l(a.r11, b.r11), l(a.r12, b.r12), l(a.r20, b.r20), l(a.r21, b.r21), l(a.r22, b.r22))
end
CFm.__index = function(c, k)
	if k == "Position" or k == "p" then
		return v3(c.x, c.y, c.z)
	elseif k == "X" then
		return c.x
	elseif k == "Y" then
		return c.y
	elseif k == "Z" then
		return c.z
	elseif k == "RightVector" or k == "XVector" then
		return v3(c.r00, c.r10, c.r20)
	elseif k == "UpVector" or k == "YVector" then
		return v3(c.r01, c.r11, c.r21)
	elseif k == "LookVector" then
		return v3(-c.r02, -c.r12, -c.r22)
	elseif k == "ZVector" then
		return v3(c.r02, c.r12, c.r22)
	elseif k == "Rotation" then
		return cf(0, 0, 0, c.r00, c.r01, c.r02, c.r10, c.r11, c.r12, c.r20, c.r21, c.r22)
	end
	local f = CFmethods[k]
	if f then
		return f
	end
	error("CFrame has no member " .. tostring(k), 2)
end

---------------------------------------------------------------------------- Color3
local C3 = { __type = "Color3" }
C3.__index = {
	ToHex = function(c)
		return string.format("%02X%02X%02X", math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5),
			math.floor(c.B * 255 + 0.5))
	end,
	Lerp = function(a, b, t)
		return Color3.new(a.R + (b.R - a.R) * t, a.G + (b.G - a.G) * t, a.B + (b.B - a.B) * t)
	end,
}
Color3 = {}
function Color3.new(r, g, b)
	return setmetatable({ R = r or 0, G = g or 0, B = b or 0 }, C3)
end
function Color3.fromRGB(r, g, b)
	return Color3.new(r / 255, g / 255, b / 255)
end
function Color3.fromHex(hex)
	hex = string.gsub(hex, "#", "")
	assert(#hex == 6, "bad hex " .. hex)
	return Color3.fromRGB(tonumber(string.sub(hex, 1, 2), 16), tonumber(string.sub(hex, 3, 4), 16),
		tonumber(string.sub(hex, 5, 6), 16))
end

---------------------------------------------------------------------------- Enum
local enumTypes = {}
Enum = setmetatable({}, {
	__index = function(_, typeName)
		if not enumTypes[typeName] then
			local items = {}
			enumTypes[typeName] = setmetatable({}, {
				__index = function(_, itemName)
					if not items[itemName] then
						items[itemName] = setmetatable({ Name = itemName, EnumType = typeName },
							{ __type = "EnumItem", __tostring = function()
								return "Enum." .. typeName .. "." .. itemName
							end })
					end
					return items[itemName]
				end,
			})
		end
		return enumTypes[typeName]
	end,
})

---------------------------------------------------------------------------- Random
Random = {}
function Random.new(seed)
	local state = math.floor(math.abs(seed or 1)) % 2147483646 + 1
	local r = {}
	local function nxt()
		state = (state * 48271) % 2147483647
		return state / 2147483647
	end
	function r:NextNumber(a, b)
		a, b = a or 0, b or 1
		return a + (b - a) * nxt()
	end
	function r:NextInteger(a, b)
		return a + math.floor(nxt() * (b - a + 1))
	end
	return r
end

---------------------------------------------------------------------------- Instance
local CLASS = {
	Part = { base = "BasePart", props = { Shape = Enum.PartType.Block } },
	WedgePart = { base = "BasePart", props = {} },
	MeshPart = { base = "BasePart", props = {} },
	SpecialMesh = { base = "DataModelMesh", props = { MeshType = Enum.MeshType.Head, Scale = Vector3.one, MeshId = "", TextureId = "" } },
	Weld = { base = "JointInstance", props = {} },
	Motor6D = { base = "JointInstance", props = { MaxVelocity = 0, Transform = CFrame.identity } },
	Attachment = { base = "Instance", props = { CFrame = CFrame.identity } },
	Folder = { base = "Instance", props = {} },
	Model = { base = "PVInstance", props = { PrimaryPart = false } },
	Humanoid = { base = "Instance", props = { RigType = Enum.HumanoidRigType.R15, HipHeight = 0,
		DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer, BreakJointsOnDeath = true } },
	ModuleScript = { base = "LuaSourceContainer", props = {} },
	Script = { base = "LuaSourceContainer", props = { Source = "", RunContext = Enum.RunContext.Legacy } },
	LocalScript = { base = "LuaSourceContainer", props = { Source = "" } },
	Decal = { base = "Instance", props = {} },
	Accessory = { base = "Instance", props = {} },
	BodyColors = { base = "Instance", props = {} },
	RemoteEvent = { base = "Instance", props = {} },
	RemoteFunction = { base = "Instance", props = {} },
}
local BASEPART_PROPS = {
	Size = Vector3.new(4, 1, 2), CFrame = CFrame.identity, Color = Color3.new(0.64, 0.64, 0.64),
	Material = Enum.Material.Plastic, Transparency = 0, Anchored = false, CanCollide = true, CanTouch = true,
	CanQuery = true, Massless = false, TopSurface = Enum.SurfaceType.Studs, BottomSurface = Enum.SurfaceType.Inlet,
	CastShadow = true, Reflectance = 0,
}
local JOINT_PROPS = { Part0 = false, Part1 = false, C0 = CFrame.identity, C1 = CFrame.identity, Enabled = true }
local ISA = {
	BasePart = { "BasePart", "PVInstance" },
	JointInstance = { "JointInstance" },
	DataModelMesh = { "DataModelMesh" },
	LuaSourceContainer = { "LuaSourceContainer" },
	PVInstance = { "PVInstance" },
	Instance = {},
}

local Inst = { __type = "Instance" }
local methods = {}
local instanceCount = 0

local function isA(self, className)
	if className == "Instance" or self.ClassName == className then
		return true
	end
	local def = CLASS[self.ClassName]
	for _, name in ipairs(def and ISA[def.base] or {}) do
		if name == className then
			return true
		end
	end
	return false
end

Instance = {}
function Instance.new(className, parent)
	local def = CLASS[className]
	assert(def, "mock: unknown class " .. tostring(className))
	instanceCount += 1
	local data = {
		ClassName = className, Name = className, Parent = nil,
		_children = {}, _attributes = {}, _props = {}, _id = instanceCount,
	}
	local obj = setmetatable({ _data = data }, Inst)
	local function copyProps(src)
		for k, v in pairs(src) do
			data._props[k] = v
		end
	end
	if def.base == "BasePart" then
		copyProps(BASEPART_PROPS)
	elseif def.base == "JointInstance" then
		copyProps(JOINT_PROPS)
	end
	copyProps(def.props)
	if parent then
		obj.Parent = parent
	end
	return obj
end

Inst.__index = function(self, k)
	local d = rawget(self, "_data")
	if k == "Name" or k == "ClassName" or k == "Parent" then
		return d[k]
	end
	local p = d._props[k]
	if p ~= nil then
		if p == false and (k == "Part0" or k == "Part1" or k == "PrimaryPart") then
			return nil
		end
		return p
	end
	if methods[k] then
		return methods[k]
	end
	for _, child in ipairs(d._children) do
		if child.Name == k then
			return child
		end
	end
	error(("%s is not a valid member of %s \"%s\""):format(tostring(k), d.ClassName, d.Name), 2)
end
Inst.__newindex = function(self, k, v)
	local d = rawget(self, "_data")
	if k == "Parent" then
		if d.Parent then
			local siblings = rawget(d.Parent, "_data")._children
			for i, c in ipairs(siblings) do
				if c == self then
					table.remove(siblings, i)
					break
				end
			end
		end
		d.Parent = v
		if v then
			table.insert(rawget(v, "_data")._children, self)
		end
	elseif k == "Name" then
		d.Name = v
	elseif d._props[k] ~= nil or k == "Shape" or k == "Source" then
		if v == nil and (k == "Part0" or k == "Part1" or k == "PrimaryPart") then
			v = false
		end
		d._props[k] = v
	else
		-- permissive: unknown properties are stored (the mock does not know every class)
		d._props[k] = v
	end
end
Inst.__tostring = function(self)
	return rawget(self, "_data").Name
end

function methods.GetChildren(self)
	return table.clone(rawget(self, "_data")._children)
end
function methods.GetDescendants(self)
	local out = {}
	local function walk(o)
		for _, c in ipairs(rawget(o, "_data")._children) do
			table.insert(out, c)
			walk(c)
		end
	end
	walk(self)
	return out
end
function methods.FindFirstChild(self, name, recursive)
	local list = recursive and self:GetDescendants() or rawget(self, "_data")._children
	for _, c in ipairs(list) do
		if c.Name == name then
			return c
		end
	end
	return nil
end
function methods.WaitForChild(self, name)
	local c = self:FindFirstChild(name)
	assert(c, "mock WaitForChild: missing " .. name)
	return c
end
function methods.FindFirstChildOfClass(self, className)
	for _, c in ipairs(rawget(self, "_data")._children) do
		if c.ClassName == className then
			return c
		end
	end
	return nil
end
function methods.FindFirstChildWhichIsA(self, className, recursive)
	local list = recursive and self:GetDescendants() or rawget(self, "_data")._children
	for _, c in ipairs(list) do
		if isA(c, className) then
			return c
		end
	end
	return nil
end
methods.IsA = isA
function methods.IsDescendantOf(self, other)
	local p = self.Parent
	while p do
		if p == other then
			return true
		end
		p = p.Parent
	end
	return false
end
function methods.Destroy(self)
	for _, c in ipairs(self:GetChildren()) do
		c:Destroy()
	end
	self.Parent = nil
	rawget(self, "_data").destroyed = true
end
function methods.ClearAllChildren(self)
	for _, c in ipairs(self:GetChildren()) do
		c:Destroy()
	end
end
function methods.Clone(self)
	local d = rawget(self, "_data")
	local o = Instance.new(d.ClassName)
	o.Name = d.Name
	for k, v in pairs(d._props) do
		rawget(o, "_data")._props[k] = v
	end
	for k, v in pairs(d._attributes) do
		rawget(o, "_data")._attributes[k] = v
	end
	for _, c in ipairs(d._children) do
		c:Clone().Parent = o
	end
	return o
end
function methods.SetAttribute(self, k, v)
	rawget(self, "_data")._attributes[k] = v
end
function methods.GetAttribute(self, k)
	return rawget(self, "_data")._attributes[k]
end
function methods.GetAttributes(self)
	return table.clone(rawget(self, "_data")._attributes)
end
function methods.GetFullName(self)
	local names, o = {}, self
	while o do
		table.insert(names, 1, o.Name)
		o = o.Parent
	end
	return table.concat(names, ".")
end
function methods.GetPivot(self)
	if self.PrimaryPart then
		return self.PrimaryPart.CFrame
	end
	local p = self:FindFirstChildWhichIsA("BasePart", true)
	return p and p.CFrame or CFrame.identity
end
function methods.GetScale(self)
	return rawget(self, "_data")._scale or 1
end
local function scaleCF(c, f)
	return cf(c.x * f, c.y * f, c.z * f, c.r00, c.r01, c.r02, c.r10, c.r11, c.r12, c.r20, c.r21, c.r22)
end
function methods.ScaleTo(self, s)
	local d = rawget(self, "_data")
	local f = s / (d._scale or 1)
	d._scale = s
	local pivot = self:GetPivot()
	for _, o in ipairs(self:GetDescendants()) do
		if o:IsA("BasePart") then
			o.Size = o.Size * f
			local rel = pivot:ToObjectSpace(o.CFrame)
			o.CFrame = pivot * scaleCF(rel, f)
		elseif o:IsA("JointInstance") then
			o.C0 = scaleCF(o.C0, f)
			o.C1 = scaleCF(o.C1, f)
		elseif o.ClassName == "Attachment" then
			o.CFrame = scaleCF(o.CFrame, f)
		elseif o.ClassName == "Humanoid" then
			o.HipHeight = o.HipHeight * f
		end
	end
end

---------------------------------------------------------------------------- services
game = Instance.new("Model")
game.Name = "game"
local services = {}
local function service(name, className)
	local s = Instance.new(className or "Folder")
	s.Name = name
	s.Parent = game
	services[name] = s
	return s
end
workspace = service("Workspace")
service("ReplicatedStorage")
service("ServerScriptService")
service("Players")

local tags = {}
local CollectionService = {}
function CollectionService:AddTag(inst, tag)
	tags[tag] = tags[tag] or {}
	tags[tag][inst] = true
end
function CollectionService:RemoveTag(inst, tag)
	if tags[tag] then
		tags[tag][inst] = nil
	end
end
function CollectionService:HasTag(inst, tag)
	return tags[tag] ~= nil and tags[tag][inst] == true
end
function CollectionService:GetTagged(tag)
	local out = {}
	for inst in pairs(tags[tag] or {}) do
		if not rawget(inst, "_data").destroyed then
			table.insert(out, inst)
		end
	end
	return out
end
services.CollectionService = CollectionService

local function jsonEncode(v)
	local t = typeof(v)
	if t == "table" then
		if #v > 0 or next(v) == nil then
			local parts = {}
			for _, x in ipairs(v) do
				table.insert(parts, jsonEncode(x))
			end
			return "[" .. table.concat(parts, ",") .. "]"
		end
		local keys = {}
		for k in pairs(v) do
			table.insert(keys, tostring(k))
		end
		table.sort(keys)
		local parts = {}
		for _, k in ipairs(keys) do
			table.insert(parts, string.format("%q", k) .. ":" .. jsonEncode(v[k]))
		end
		return "{" .. table.concat(parts, ",") .. "}"
	elseif t == "string" then
		return string.format("%q", v)
	elseif t == "number" then
		if v ~= v or v == math.huge or v == -math.huge then
			return "null"
		end
		return string.format("%.5g", v)
	elseif t == "boolean" then
		return tostring(v)
	elseif t == "nil" then
		return "null"
	end
	error("JSONEncode: cannot encode " .. t)
end
MOCK.jsonEncode = jsonEncode
services.HttpService = {
	JSONEncode = function(_, v)
		return jsonEncode(v)
	end,
}
services.RunService = {
	IsRunning = function()
		return false
	end,
	IsServer = function()
		return true
	end,
	IsClient = function()
		return false
	end,
	IsStudio = function()
		return true
	end,
}
services.TweenService = {
	Create = function()
		return { Play = function() end }
	end,
}
function methods.GetService(self, name)
	local s = services[name]
	assert(s, "mock: no service " .. name)
	return s
end

task = {
	wait = function()
		return 0
	end,
	spawn = function(f, ...)
		f(...)
	end,
	defer = function(f, ...)
		f(...)
	end,
	delay = function() end,
}

---------------------------------------------------------------------------- modules
-- MOCK.mount(tree, parent): tree = { name =, fn = function(script, require) | nil, children = {…} }
local moduleFns, moduleCache = {}, {}
local function mockRequire(module)
	if moduleCache[module] ~= nil then
		return moduleCache[module]
	end
	local fn = moduleFns[module]
	assert(fn, "mock require: not a module " .. tostring(module))
	local result = fn(module, mockRequire)
	moduleCache[module] = result
	return result
end
MOCK.require = mockRequire

function MOCK.mount(tree, parent)
	local inst = Instance.new(tree.fn and "ModuleScript" or "Folder")
	inst.Name = tree.name
	if tree.fn then
		moduleFns[inst] = tree.fn
	end
	for _, child in ipairs(tree.children or {}) do
		MOCK.mount(child, inst)
	end
	inst.Parent = parent
	return inst
end

---------------------------------------------------------------------------- dump
-- Solve world CFrames through the joint graph (as Roblox would) and serialize parts.
function MOCK.dump(model)
	local root = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart")
	local world = { [root] = root.CFrame }
	local edges = {}
	for _, j in ipairs(model:GetDescendants()) do
		if j:IsA("JointInstance") and j.Enabled and j.Part0 and j.Part1 then
			table.insert(edges, j)
		end
	end
	local changed = true
	while changed do
		changed = false
		for _, j in ipairs(edges) do
			local p0, p1 = j.Part0, j.Part1
			if world[p0] and not world[p1] then
				local t = j.ClassName == "Motor6D" and j.Transform or CFrame.identity
				world[p1] = world[p0] * j.C0 * t * j.C1:Inverse()
				changed = true
			elseif world[p1] and not world[p0] then
				local t = j.ClassName == "Motor6D" and j.Transform or CFrame.identity
				world[p0] = world[p1] * j.C1 * t:Inverse() * j.C0:Inverse()
				changed = true
			end
		end
	end
	local out, unattached = {}, 0
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") and p.Transparency < 1 then
			local w = world[p]
			if not w then
				unattached += 1
				w = p.CFrame
			end
			local mesh = p:FindFirstChildOfClass("SpecialMesh")
			local shape = "Block"
			if p.ClassName == "WedgePart" then
				shape = "Wedge"
			elseif mesh and mesh.MeshType.Name == "Sphere" then
				shape = "Ball"
			elseif p.Shape.Name == "Cylinder" then
				shape = "Cylinder"
			elseif mesh then
				shape = "Mesh"
			end
			local s = p.Size
			table.insert(out, {
				n = p.Name, s = shape, sz = { s.X, s.Y, s.Z }, cf = { w:GetComponents() },
				c = { p.Color.R, p.Color.G, p.Color.B }, m = p.Material.Name, t = p.Transparency,
			})
		end
	end
	return out, unattached
end

return MOCK
