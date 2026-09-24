--!nonstrict
--[[
	The R6 foundation. The six body parts, their sizes and the six Motor6D names
	never change, so the default Animate script and every R6 animation still work.
	Anatomy only moves joint C0s (posture) and Humanoid.HipHeight (leg length).
]]

local Util = require(script.Parent.Util)
local BodyTypes = require(script.Parent.BodyTypes)

local Rig = {}

Rig.PARTS = { "Head", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg" }
Rig.SIZES = {
	HumanoidRootPart = Vector3.new(2, 2, 1),
	Torso = Vector3.new(2, 2, 1),
	Head = Vector3.new(2, 1, 1),
	["Right Arm"] = Vector3.new(1, 2, 1),
	["Left Arm"] = Vector3.new(1, 2, 1),
	["Right Leg"] = Vector3.new(1, 2, 1),
	["Left Leg"] = Vector3.new(1, 2, 1),
}

-- standard R6 joint rotations
Rig.ROT = {
	root = CFrame.new(0, 0, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0),
	right = CFrame.new(0, 0, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0),
	left = CFrame.new(0, 0, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0),
}

-- name, Part0, Part1, default C0 position, C1 position, rotation
Rig.JOINTS = {
	{ "RootJoint", "HumanoidRootPart", "Torso", Vector3.new(0, 0, 0), Vector3.new(0, 0, 0), "root" },
	{ "Neck", "Torso", "Head", Vector3.new(0, 1, 0), Vector3.new(0, -0.5, 0), "root" },
	{ "Right Shoulder", "Torso", "Right Arm", Vector3.new(1, 0.5, 0), Vector3.new(-0.5, 0.5, 0), "right" },
	{ "Left Shoulder", "Torso", "Left Arm", Vector3.new(-1, 0.5, 0), Vector3.new(0.5, 0.5, 0), "left" },
	{ "Right Hip", "Torso", "Right Leg", Vector3.new(1, -1, 0), Vector3.new(0.5, 1, 0), "right" },
	{ "Left Hip", "Torso", "Left Leg", Vector3.new(-1, -1, 0), Vector3.new(-0.5, 1, 0), "left" },
}

-- Rotations that point a socket's +Y out of a surface.
Rig.FACING = {
	Up = CFrame.identity,
	Down = CFrame.Angles(math.pi, 0, 0),
	Front = CFrame.Angles(-math.pi / 2, 0, 0),
	Back = CFrame.Angles(math.pi / 2, 0, 0),
	Right = CFrame.Angles(0, 0, -math.pi / 2),
	Left = CFrame.Angles(0, 0, math.pi / 2),
}

function Rig.isR6(character)
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.RigType ~= Enum.HumanoidRigType.R6 then
		return false, "character is not an R6 Humanoid"
	end
	for _, name in ipairs(Rig.PARTS) do
		if not character:FindFirstChild(name) then
			return false, "missing R6 part " .. name
		end
	end
	return true
end

-- Build a fresh R6 rig (for NPCs, previews and StarterCharacter).
function Rig.create(name, cframe)
	local model = Instance.new("Model")
	model.Name = name or "Curse"
	for partName, size in pairs(Rig.SIZES) do
		local p = Instance.new("Part")
		p.Name = partName
		p.Size = size
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.CanCollide = partName == "Torso" or partName == "Head"
		p.Transparency = partName == "HumanoidRootPart" and 1 or 0
		p.Parent = model
	end
	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R6
	humanoid.Parent = model
	for _, j in ipairs(Rig.JOINTS) do
		local m = Instance.new("Motor6D")
		m.Name = j[1]
		m.Part0 = model[j[2]]
		m.Part1 = model[j[3]]
		m.C0 = CFrame.new(j[4]) * Rig.ROT[j[6]]
		m.C1 = CFrame.new(j[5]) * Rig.ROT[j[6]]
		m.MaxVelocity = 0.1
		m.Parent = model[j[2]]
	end
	model.PrimaryPart = model.HumanoidRootPart
	model.HumanoidRootPart.CFrame = cframe or CFrame.new(0, 3, 0)
	Rig.snap(model)
	return model
end

-- Place every part where its joints say (edit mode has no physics solver running).
function Rig.snap(character)
	for _, j in ipairs(Rig.JOINTS) do
		local p0 = character:FindFirstChild(j[2])
		local m = p0 and p0:FindFirstChild(j[1])
		if m and m.Part0 and m.Part1 then
			m.Part1.CFrame = m.Part0.CFrame * m.C0 * m.C1:Inverse()
		end
	end
end

-- Remove the human look: clothing, accessories, face, head mesh. Hide base parts.
function Rig.prepare(character, hideBase)
	for _, d in ipairs(character:GetDescendants()) do
		if d:IsA("Accessory") or d:IsA("Shirt") or d:IsA("Pants") or d:IsA("ShirtGraphic")
			or d:IsA("CharacterMesh") or d:IsA("BodyColors") then
			d:Destroy()
		elseif (d:IsA("Decal") or d:IsA("SpecialMesh")) and d.Parent and d.Parent.Name == "Head"
			and d.Parent.Parent == character then
			d:Destroy()
		end
	end
	if hideBase ~= false then
		for _, name in ipairs(Rig.PARTS) do
			character[name].Transparency = 1
		end
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	local curse = character:FindFirstChild("CurseBody")
	if not curse then
		curse = Instance.new("Model")
		curse.Name = "CurseBody"
		curse.Parent = character
	end
	return curse
end

--[[
	Joint layout from anatomy. The torso leans forward by `hunch` degrees around the
	pelvis; the neck and shoulders ride on that lean, so a hunched Curse carries its
	head low and forward and its arms hang in front, in every animation.
	Returns torso-local positions plus the "spine" frame torso components build in.
]]
function Rig.computeLayout(body, meshLayout)
	local m, L = body.mass, body.layout
	if meshLayout then
		-- Sculpted torsos carry their own joint positions (posture is part of the sculpt);
		-- they scale with the torso mesh.
		local W, H, D = Rig.meshScale(m.TorsoW), Rig.meshScale(m.TorsoH), Rig.meshScale(m.TorsoD)
		local function sc(v)
			return Vector3.new(v[1] * W, v[2] * H, v[3] * D)
		end
		local layout = {
			spine = CFrame.new(0, -1, 0),
			legExtra = (meshLayout.legExtra or 0) + L.legExtra,
			neck = sc(meshLayout.neck) + Vector3.new(0, -L.neckDrop, -L.neckForward),
			tailRoot = sc(meshLayout.tailRoot or { 0, -0.8, 0.45 }),
		}
		local sh, hip = meshLayout.shoulder, meshLayout.hip
		layout.shoulderRight = sc(sh) + Vector3.new(0, -L.shoulderDrop, -L.shoulderForward)
		layout.shoulderLeft = Vector3.new(-layout.shoulderRight.X, layout.shoulderRight.Y, layout.shoulderRight.Z)
		layout.hipRight = Vector3.new(hip[1] * W + L.hipSpread, hip[2], hip[3] * D)
		layout.hipLeft = Vector3.new(-layout.hipRight.X, hip[2], hip[3] * D)
		return layout
	end
	local spine = CFrame.new(0, -1, 0) * CFrame.Angles(math.rad(-L.hunch), 0, 0)
	local H = m.TorsoH
	local layout = { spine = spine, legExtra = L.legExtra }

	local neckBase = spine * Vector3.new(0, 2 * H - L.neckDrop, -0.1 * m.TorsoD)
	local headCenter = neckBase + Vector3.new(0, 0.5 * m.Head, -0.05 - L.neckForward)
	layout.neck = headCenter - Vector3.new(0, 0.5, 0)

	for _, sideName in ipairs({ "Right", "Left" }) do
		local s = sideName == "Right" and 1 or -1
		local armThick = BodyTypes.get(body, "ArmThick", sideName)
		local shoulder = BodyTypes.get(body, "Shoulder", sideName)
		local x = m.TorsoW + (armThick - 1) * 0.4 + (shoulder - 1) * 0.25
		local p = spine * Vector3.new(s * x, 2 * H - 0.5 - L.shoulderDrop, 0)
		layout["shoulder" .. sideName] = p + Vector3.new(0, 0, -L.shoulderForward)
		local legThick = BodyTypes.get(body, "LegThick", sideName)
		layout["hip" .. sideName] = Vector3.new(s * (1 + (legThick - 1) * 0.45 + L.hipSpread), -1, 0)
	end
	return layout
end

-- Mesh scale from body mass: sub-linear, so heavy builds stay anatomical instead of stretched.
function Rig.meshScale(mass)
	return (mass or 1) ^ 0.75
end

function Rig.applyLayout(character, layout)
	local torso = character.Torso
	local set = {
		Neck = layout.neck,
		["Right Shoulder"] = layout.shoulderRight,
		["Left Shoulder"] = layout.shoulderLeft,
		["Right Hip"] = layout.hipRight,
		["Left Hip"] = layout.hipLeft,
	}
	for _, j in ipairs(Rig.JOINTS) do
		local pos = set[j[1]]
		local m = torso:FindFirstChild(j[1])
		if pos and m then
			m.C0 = CFrame.new(pos) * Rig.ROT[j[6]]
			m.C1 = CFrame.new(j[5]) * Rig.ROT[j[6]]
		end
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	-- R6: HipHeight is an offset added to the leg length
	humanoid.HipHeight = layout.legExtra
end

--[[
	Fallback sockets on the base parts, defined before any component builds.
	Region components redefine them on their real surfaces.
	name → { part, position, facing, side }
]]
function Rig.defaultSockets(body, layout)
	local m = body.mass
	local spine = layout.spine
	local H, W, D = m.TorsoH, m.TorsoW, m.TorsoD
	local F = Rig.FACING
	local function sp(x, y, z)
		return spine * Vector3.new(x, y, z)
	end
	local s = {
		-- head
		Crown = { "Head", Vector3.new(0, 0.6, 0.05), F.Up },
		TopR = { "Head", Vector3.new(0.45, 0.5, 0), CFrame.Angles(0, 0, math.rad(-25)), 1 },
		TopL = { "Head", Vector3.new(-0.45, 0.5, 0), CFrame.Angles(0, 0, math.rad(25)), -1 },
		Brow = { "Head", Vector3.new(0, 0.3, -0.55), CFrame.Angles(math.rad(-55), 0, 0) },
		Face = { "Head", Vector3.new(0, 0, -0.6), F.Front },
		EyeR = { "Head", Vector3.new(0.3, 0.1, -0.55), F.Front, 1 },
		EyeL = { "Head", Vector3.new(-0.3, 0.1, -0.55), F.Front, -1 },
		Mouth = { "Head", Vector3.new(0, -0.25, -0.55), F.Front },
		Jaw = { "Head", Vector3.new(0, -0.5, -0.3), F.Down },
		CheekR = { "Head", Vector3.new(0.5, -0.1, -0.35), CFrame.Angles(0, math.rad(40), 0) * F.Front, 1 },
		CheekL = { "Head", Vector3.new(-0.5, -0.1, -0.35), CFrame.Angles(0, math.rad(-40), 0) * F.Front, -1 },
		TempleR = { "Head", Vector3.new(0.6, 0.2, 0), F.Right, 1 },
		TempleL = { "Head", Vector3.new(-0.6, 0.2, 0), F.Left, -1 },
		EarR = { "Head", Vector3.new(0.62, 0, 0.05), F.Right, 1 },
		EarL = { "Head", Vector3.new(-0.62, 0, 0.05), F.Left, -1 },
		BackOfHead = { "Head", Vector3.new(0, 0.2, 0.55), F.Back },
		-- torso (positions ride the hunched spine)
		Chest = { "Torso", sp(0, 1.45 * H, -0.55 * D), F.Front },
		ChestR = { "Torso", sp(0.55 * W, 1.5 * H, -0.5 * D), F.Front, 1 },
		ChestL = { "Torso", sp(-0.55 * W, 1.5 * H, -0.5 * D), F.Front, -1 },
		Belly = { "Torso", sp(0, 0.55 * H, -0.55 * D), F.Front },
		ChestLowR = { "Torso", sp(0.65 * W, 0.9 * H, -0.4 * D), F.Front, 1 },
		ChestLowL = { "Torso", sp(-0.65 * W, 0.9 * H, -0.4 * D), F.Front, -1 },
		UpperBack = { "Torso", sp(0, 1.6 * H, 0.6 * D), F.Back },
		Back = { "Torso", sp(0, 1.1 * H, 0.6 * D), F.Back },
		BackR = { "Torso", sp(0.55 * W, 1.45 * H, 0.55 * D), F.Back, 1 },
		BackL = { "Torso", sp(-0.55 * W, 1.45 * H, 0.55 * D), F.Back, -1 },
		LowerBack = { "Torso", sp(0, 0.45 * H, 0.55 * D), F.Back },
		TailRoot = { "Torso", Vector3.new(0, -0.8, 0.5 * D), F.Back },
		FlankR = { "Torso", sp(0.95 * W, 1.0 * H, 0), F.Right, 1 },
		FlankL = { "Torso", sp(-0.95 * W, 1.0 * H, 0), F.Left, -1 },
		ShoulderR = { "Torso", sp(0.85 * W, 2.05 * H, 0), F.Up, 1 },
		ShoulderL = { "Torso", sp(-0.85 * W, 2.05 * H, 0), F.Up, -1 },
		Neck = { "Torso", sp(0, 2.0 * H, 0.15), F.Up },
		HipR = { "Torso", Vector3.new(0.9 * W, -0.8, 0), F.Right, 1 },
		HipL = { "Torso", Vector3.new(-0.9 * W, -0.8, 0), F.Left, -1 },
	}
	for _, sideName in ipairs({ "Right", "Left" }) do
		local k, sx = string.sub(sideName, 1, 1), sideName == "Right" and 1 or -1
		local arm, leg = sideName .. " Arm", sideName .. " Leg"
		local len = BodyTypes.get(body, "ArmLength", sideName)
		local handY = -1 - (len - 1) * 2.2
		s["Shoulder_" .. k] = { arm, Vector3.new(0, 0.8, 0), F.Up, sx }
		s["UpperArm_" .. k] = { arm, Vector3.new(0.5 * sx, 0.3, 0), sx > 0 and F.Right or F.Left, sx }
		s["Elbow_" .. k] = { arm, Vector3.new(0, handY * 0.35, 0.5), F.Back, sx }
		s["Forearm_" .. k] = { arm, Vector3.new(0.5 * sx, handY * 0.6, 0), sx > 0 and F.Right or F.Left, sx }
		s["Hand_" .. k] = { arm, Vector3.new(0, handY, 0), F.Down, sx }
		s["Palm_" .. k] = { arm, Vector3.new(0, handY - 0.3, -0.3), F.Front, sx }
		s["Thigh_" .. k] = { leg, Vector3.new(0, 0.4, -0.5), F.Front, sx }
		s["Knee_" .. k] = { leg, Vector3.new(0, -0.2, -0.5), F.Front, sx }
		s["Shin_" .. k] = { leg, Vector3.new(0.45 * sx, -0.45, 0), sx > 0 and F.Right or F.Left, sx }
		s["Foot_" .. k] = { leg, Vector3.new(0, -1 - layout.legExtra, 0), F.Up, sx }
	end
	return s
end

Rig.util = Util
return Rig
