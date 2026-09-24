--!nonstrict
--[[
	Builder context (`ctx`) — the only way components create geometry.

	Anchors: every call takes an ANCHOR = { part = BasePart, cf = CFrame, side = ±1 }
	(or a base part name / BasePart). Positions and rotations are relative to the anchor.
	While a sided component builds for the left side (ctx.side = -1), X positions and Y/Z
	rotations are mirrored automatically, so components are authored once (right side).
	ctx.scale (Vector3) multiplies positions and sizes (used for mass: arm thickness etc.).

	Every piece is Massless, non-colliding, welded (Weld.C0 = offset) to exactly one part.
]]

local CollectionService = game:GetService("CollectionService")

local Util = require(script.Parent.Util)
local Rig = require(script.Parent.Rig)
local BodyTypes = require(script.Parent.BodyTypes)

local Builder = {}
Builder.__index = Builder

local MIN_SIZE = 0.05

function Builder.new(state)
	local self = setmetatable({}, Builder)
	self.state = state
	self.character = state.character
	self.curse = state.curse
	self.body = state.body
	self.layout = state.layout
	self.palette = state.palette
	self.grade = state.grade
	self.appearance = state.effective
	self.side = 1
	self.sideName = nil -- "Right" / "Left" while building a sided component
	self.suffix = "R"
	self.scale = Vector3.one
	self.folder = nil
	self.owner = "Rig"
	self.count = 0
	self.random = Random.new(state.effective.Seed or 1)
	return self
end

---------------------------------------------------------------------------- state

function Builder:m(key)
	return BodyTypes.get(self.body, key, self.sideName)
end

function Builder:rand(a, b)
	return a + (b - a) * self.random:NextNumber()
end

function Builder:randInt(a, b)
	return self.random:NextInteger(a, b)
end

-- Run fn with temporary context fields (side, scale, …) and restore them after.
function Builder:with(fields, fn, ...)
	local saved = {}
	for k, v in pairs(fields) do
		saved[k] = self[k]
		self[k] = v
	end
	local results = table.pack(pcall(fn, ...))
	for k, v in pairs(saved) do
		self[k] = v
	end
	if not results[1] then
		error(results[2], 0)
	end
	return table.unpack(results, 2, results.n)
end

function Builder:look(role)
	return self.palette[role] or self.palette.Skin
end

---------------------------------------------------------------------------- anchors

function Builder:basePart(name)
	return self.character:FindFirstChild(name) or self.curse:FindFirstChild(name, true)
end

function Builder:anchor(target, cf, side)
	if typeof(target) ~= "Instance" and type(target) == "table" then
		return target -- already an anchor
	end
	local part = target
	if type(target) == "string" then
		part = self:basePart(target)
		assert(part, "no part named " .. target)
	end
	return { part = part, cf = cf or CFrame.identity, side = side or 1 }
end

-- anchor offset by a local position/rotation (mirrored for the left side)
function Builder:sub(target, pos, rot)
	local a = self:anchor(target)
	return { part = a.part, cf = a.cf * self:localCF(pos, rot), side = a.side }
end

function Builder:localCF(pos, rot)
	local s = self.scale
	local x, y, z = 0, 0, 0
	if pos then
		x, y, z = pos[1] * s.X, pos[2] * s.Y, pos[3] * s.Z
	end
	local rx, ry, rz = 0, 0, 0
	if rot then
		rx, ry, rz = rot[1] or 0, rot[2] or 0, rot[3] or 0
	end
	if self.side < 0 then
		x, ry, rz = -x, -ry, -rz
	end
	return CFrame.new(x, y, z) * CFrame.Angles(math.rad(rx), math.rad(ry), math.rad(rz))
end

function Builder:scaledSize(size)
	local v = Util.v3(size)
	local s = self.scale
	return Vector3.new(
		math.max(math.abs(v.X * s.X), MIN_SIZE),
		math.max(math.abs(v.Y * s.Y), MIN_SIZE),
		math.max(math.abs(v.Z * s.Z), MIN_SIZE)
	)
end

---------------------------------------------------------------------------- pieces

local function configure(p)
	p.Anchored = false
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
end

function Builder:attach(p, anchor, offset)
	configure(p)
	p.CFrame = anchor.part.CFrame * offset
	local weld = Instance.new("Weld")
	weld.Name = "CurseWeld"
	weld.Part0 = anchor.part
	weld.Part1 = p
	weld.C0 = offset
	weld.Parent = p
	p.Parent = self.folder
	return p
end

-- piece at an explicit offset (anchor space) with a final (already scaled) size
function Builder:_pieceAt(className, anchor, offset, size, role, name)
	local look = self:look(role or "Skin")
	local p = Instance.new(className)
	self.count += 1
	p.Name = name or (self.owner .. "_" .. self.count)
	p.Size = Vector3.new(math.max(size.X, MIN_SIZE), math.max(size.Y, MIN_SIZE), math.max(size.Z, MIN_SIZE))
	p.Color = look.Color
	p.Material = look.Material
	p.Transparency = look.Transparency
	p:SetAttribute("Role", role or "Skin")
	return self:attach(p, anchor, anchor.cf * offset)
end

function Builder:_piece(className, target, pos, size, rot, role, name)
	local anchor = self:anchor(target)
	return self:_pieceAt(className, anchor, self:localCF(pos, rot), self:scaledSize(size), role, name)
end

local function sphereMesh(p)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p
end

-- frame whose +Y runs from a to b (anchor-local, mirrored/scaled like positions)
function Builder:spanCF(a, b, roll)
	local pa, pb = self:localCF(a).Position, self:localCF(b).Position
	local dir = pb - pa
	local len = dir.Magnitude
	if len < 1e-4 then
		return nil, 0
	end
	local up = dir.Unit
	local ref = math.abs(up.Z) < 0.9 and Vector3.zAxis or Vector3.xAxis
	local right = up:Cross(ref).Unit
	local cf = CFrame.fromMatrix((pa + pb) / 2, right, up)
	if roll and roll ~= 0 then
		cf = cf * CFrame.Angles(0, math.rad(roll * self.side), 0)
	end
	return cf, len
end

--[[
	Ellipsoid spanning a → b (anchor space). radius: number or {rx, rz}.
	opts.stretch (default 1.2) lengthens it past the endpoints so chains overlap.
]]
function Builder:capsule(target, a, b, radius, role, opts)
	opts = opts or {}
	local anchor = self:anchor(target)
	local cf, len = self:spanCF(a, b, opts.roll)
	if not cf then
		return nil
	end
	local s = self.scale
	local rs = (math.abs(s.X) + math.abs(s.Z)) / 2
	local rx, rz = radius, radius
	if type(radius) == "table" then
		rx, rz = radius[1], radius[2]
	end
	local size = Vector3.new(2 * rx * rs, len * (opts.stretch or 1.2), 2 * rz * rs)
	local className = opts.shape == "box" and "Part" or opts.shape == "wedge" and "WedgePart" or "Part"
	local p = self:_pieceAt(className, anchor, cf, size, role, opts.name)
	if opts.shape == nil or opts.shape == "blob" then
		sphereMesh(p)
	end
	return p
end

--[[
	Tapered tube through a list of points with matching radii (numbers or {rx, rz}).
	roles: a role string or a function(i, n) → role. Used for horns, fingers, tendrils.
]]
function Builder:tube(target, points, radii, role, opts)
	opts = opts or {}
	local out = {}
	local n = #points - 1
	for i = 1, n do
		local r = radii[i]
		local rn = radii[i + 1] or r
		if type(r) == "number" and type(rn) == "number" then
			r = (r + rn) / 2
		end
		local rl = type(role) == "function" and role(i, n) or role
		out[i] = self:capsule(target, points[i], points[i + 1], r, rl, { stretch = opts.stretch or 1.3, roll = opts.roll })
	end
	return out
end

-- Ellipsoid: the organic workhorse.
function Builder:blob(target, pos, size, rot, role, name)
	return sphereMesh(self:_piece("Part", target, pos, size, rot, role, name))
end

function Builder:box(target, pos, size, rot, role, name)
	return self:_piece("Part", target, pos, size, rot, role, name)
end

-- WedgePart: slope rises from the front-bottom edge to the back-top edge.
function Builder:wedge(target, pos, size, rot, role, name)
	return self:_piece("WedgePart", target, pos, size, rot, role, name)
end

-- Cylinder along its local X axis.
function Builder:cylinder(target, pos, size, rot, role, name)
	local p = self:_piece("Part", target, pos, size, rot, role, name)
	p.Shape = Enum.PartType.Cylinder
	return p
end

-- Custom art: a FileMesh (MeshId is settable at runtime on SpecialMesh).
function Builder:mesh(target, pos, size, rot, meshId, role, textureId, meshScale)
	local p = self:_piece("Part", target, pos, size, rot, role)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.FileMesh
	mesh.MeshId = meshId
	mesh.TextureId = textureId or ""
	mesh.Scale = Util.v3(meshScale, Vector3.one)
	mesh.Parent = p
	return p
end

-- Clone a MeshPart / Model from CurseBody/Assets and weld it (hand-made art).
function Builder:template(assetName, target, pos, rot, role)
	local assets = script.Parent:FindFirstChild("Assets")
	local source = assets and assets:FindFirstChild(assetName, true)
	if not source then
		warn("[CurseBody] missing asset " .. tostring(assetName))
		return nil
	end
	local anchor = self:anchor(target)
	local clone = source:Clone()
	local offset = anchor.cf * self:localCF(pos, rot)
	local parts = clone:IsA("BasePart") and { clone } or {}
	for _, d in ipairs(clone:GetDescendants()) do
		if d:IsA("BasePart") then
			table.insert(parts, d)
		end
	end
	local pivot = clone:IsA("Model") and clone:GetPivot() or clone.CFrame
	for _, p in ipairs(parts) do
		local rel = pivot:ToObjectSpace(p.CFrame)
		if role then
			local look = self:look(role)
			p.Color, p.Material = look.Color, look.Material
		end
		p.Parent = nil
		self:attach(p, anchor, offset * rel)
	end
	clone:Destroy()
	return parts
end

--[[
	Triangle between three points (anchor space, mirrored like positions) from two
	WedgeParts. Used for membranes, blades, fins and teeth.
]]
function Builder:triangle(target, a, b, c, role, thickness)
	local anchor = self:anchor(target)
	local function pt(v)
		local cf = self:localCF(v)
		return cf.Position
	end
	a, b, c = pt(a), pt(b), pt(c)
	local ab, ac, bc = b - a, c - a, c - b
	local abd, acd, bcd = ab:Dot(ab), ac:Dot(ac), bc:Dot(bc)
	if abd > acd and abd > bcd then
		c, a = a, c
	elseif acd > bcd and acd > abd then
		a, b = b, a
	end
	ab, ac, bc = b - a, c - a, c - b
	if ac:Cross(ab).Magnitude < 1e-4 then
		return
	end
	local right = ac:Cross(ab).Unit
	local up = bc:Cross(right).Unit
	local back = bc.Unit
	local height = math.abs(ab:Dot(up))
	local look = self:look(role or "Membrane")
	local t = thickness or 0.05
	local out = {}
	for i, spec in ipairs({
		{ Vector3.new(t, height, math.abs(ab:Dot(back))), CFrame.fromMatrix((a + b) / 2, right, up, back) },
		{ Vector3.new(t, height, math.abs(ac:Dot(back))), CFrame.fromMatrix((a + c) / 2, -right, up, -back) },
	}) do
		local w = Instance.new("WedgePart")
		self.count += 1
		w.Name = self.owner .. "_Tri" .. self.count .. "_" .. i
		w.Size = Vector3.new(math.max(spec[1].X, MIN_SIZE), math.max(spec[1].Y, MIN_SIZE), math.max(spec[1].Z, MIN_SIZE))
		w.Color, w.Material, w.Transparency = look.Color, look.Material, look.Transparency
		w:SetAttribute("Role", role or "Membrane")
		out[i] = self:attach(w, anchor, anchor.cf * spec[2])
	end
	return out
end

---------------------------------------------------------------------------- sockets

function Builder:sideName(side)
	return (side or self.side) > 0 and "Right" or "Left"
end

-- Name for a sided socket: "Hand" → "Hand_R" / "Hand_L" / "Hand_E1" (extra limbs)
function Builder:sided(base)
	return base .. "_" .. self.suffix
end

function Builder:defineSocket(name, target, pos, rot)
	name = (self.socketPrefix or "") .. name
	local anchor = self:anchor(target)
	local cf = anchor.cf * self:localCF(pos, rot)
	local socket = { part = anchor.part, cf = cf, side = self.side * (anchor.side or 1), owner = self.owner }
	self.state.sockets[name] = socket
	local attName = "CurseSocket_" .. name
	local old = anchor.part:FindFirstChild(attName)
	if old then
		old:Destroy()
	end
	local att = Instance.new("Attachment")
	att.Name = attName
	att.CFrame = cf
	att:SetAttribute("Owner", self.owner)
	att.Parent = anchor.part
	return socket
end

-- Define a right socket at pos and its mirrored left twin (names + "R" / "L").
function Builder:defineSocketPair(base, target, pos, rot)
	self:with({ side = 1 }, function()
		self:defineSocket(base .. "R", target, pos, rot)
	end)
	self:with({ side = -1 }, function()
		self:defineSocket(base .. "L", target, pos, rot)
	end)
end

function Builder:hasSocket(name)
	local sockets, defaults = self.state.sockets, self.state.defaultSockets
	return sockets[(self.socketPrefix or "") .. name] ~= nil or sockets[name] ~= nil or defaults[name] ~= nil
end

-- Resolve a socket to an anchor. Unknown names fall back to `fallback` then "Chest".
function Builder:socket(name, fallback)
	local sockets = self.state.sockets
	local s = (self.socketPrefix and sockets[self.socketPrefix .. name]) or sockets[name] or self.state.defaultSockets[name]
	if not s and fallback then
		s = self.state.sockets[fallback] or self.state.defaultSockets[fallback]
	end
	if not s then
		s = self.state.sockets.Chest or self.state.defaultSockets.Chest
	end
	return { part = s.part, cf = s.cf, side = s.side or 1 }
end

---------------------------------------------------------------------------- chains

--[[
	Motor6D chain for tails, tendrils, tentacles, stalks, wing bones.
	segments: { { length, radius, {rx, ry, rz} }, … } — each segment hangs along -Y
	from the end of the previous one, rotated by its angles.
	opts: name, lengthScale, radiusScale, role, flesh (false | function(ctx, anchor, i, len, r, n)),
	      sway = { amp = degrees, speed = hz } (procedural motion on clients), mirror joint etc.
	Returns { { anchor =, length =, radius = }, … }
]]
function Builder:chain(target, pos, rot, segments, opts)
	opts = opts or {}
	local anchor = self:anchor(target)
	local parentPart = anchor.part
	local c0First = anchor.cf * self:localCF(pos, rot)
	self.count += 1
	local baseName = (opts.name or (self.owner .. "Chain")) .. self.count
	local ls, rs = opts.lengthScale or 1, opts.radiusScale or 1
	local out, prevLen = {}, nil
	local n = #segments
	for i, seg in ipairs(segments) do
		local len, r = seg[1] * ls, seg[2] * rs
		local jp = Instance.new("Part")
		jp.Name = baseName .. "_" .. i
		jp.Size = Vector3.new(math.max(r * 2, MIN_SIZE), math.max(len, MIN_SIZE), math.max(r * 2, MIN_SIZE))
		jp.Transparency = 1
		configure(jp)
		local segRot = self:localCF(nil, seg[3])
		local c0 = (i == 1 and c0First or CFrame.new(0, -prevLen / 2, 0)) * segRot
		local c1 = CFrame.new(0, len / 2, 0)
		jp.CFrame = parentPart.CFrame * c0 * c1:Inverse()
		local motor = Instance.new("Motor6D")
		motor.Name = baseName .. "_Joint" .. i
		motor.Part0, motor.Part1, motor.C0, motor.C1 = parentPart, jp, c0, c1
		motor.Parent = jp -- lives (and dies) with its slot folder
		if opts.sway ~= false then
			local sway = opts.sway or {}
			motor:SetAttribute("SwayAmp", (sway.amp or 6) * (0.6 + 0.4 * i / n))
			motor:SetAttribute("SwaySpeed", sway.speed or 1.6)
			motor:SetAttribute("SwayPhase", i * (sway.phase or 0.6) + self.count)
			CollectionService:AddTag(motor, "CurseSway")
		end
		jp.Parent = self.folder
		local segAnchor = { part = jp, cf = CFrame.identity, side = self.side }
		out[i] = { anchor = segAnchor, length = len, radius = r }
		if opts.flesh ~= false then
			self:with({ scale = Vector3.one, side = 1 }, function()
				if opts.flesh then
					opts.flesh(self, segAnchor, i, len, r, n)
				else
					self:blob(segAnchor, { 0, 0, 0 }, { r * 2, len * 1.35, r * 2 }, nil,
						opts.role or (i % 2 == 0 and "SkinLight" or "Skin"))
				end
			end)
		end
		parentPart, prevLen = jp, len
	end
	return out
end

---------------------------------------------------------------------------- limbs

--[[
	Extra R6-style limb driven by its own Motor6D from the Torso.
	kind "Arm" | "Leg" | "Head". The client mirrors `mirrorJoint`'s animation onto it
	(attributes MirrorJoint / MirrorDelay / MirrorScale) unless an animation keys it.
]]
function Builder:limb(kind, name, side, c0pos, mirrorJoint, opts)
	opts = opts or {}
	local torso = self.character.Torso
	local size = kind == "Head" and Vector3.new(2, 1, 1) or Vector3.new(1, 2, 1)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Transparency = 1
	configure(p)
	local rot = kind == "Head" and Rig.ROT.root or (side > 0 and Rig.ROT.right or Rig.ROT.left)
	local c1pos = kind == "Arm" and Vector3.new(-0.5 * side, 0.5, 0)
		or kind == "Leg" and Vector3.new(0.5 * side, 1, 0)
		or Vector3.new(0, -0.5, 0)
	local splay = CFrame.Angles(math.rad(opts.tilt or 0), math.rad(opts.yaw or 0), math.rad((opts.splay or 0) * side))
	local motor = Instance.new("Motor6D")
	motor.Name = name .. "Joint"
	motor.Part0 = torso
	motor.Part1 = p
	motor.C0 = CFrame.new(c0pos) * splay * rot
	motor.C1 = CFrame.new(c1pos) * rot
	motor.MaxVelocity = 0.1
	motor:SetAttribute("MirrorJoint", mirrorJoint)
	motor:SetAttribute("MirrorDelay", opts.delay or 0.12)
	motor:SetAttribute("MirrorScale", opts.mirrorScale or 1)
	CollectionService:AddTag(motor, "CurseMirror")
	p.CFrame = torso.CFrame * motor.C0 * motor.C1:Inverse()
	motor.Parent = p
	p.Parent = self.folder
	return p
end

---------------------------------------------------------------------------- composition

-- Build another component inline (horn sets build horns, extra arms build arms …).
function Builder:build(id, entry, overrides)
	return self.state.buildComponent(self, id, entry or {}, overrides)
end

return Builder
