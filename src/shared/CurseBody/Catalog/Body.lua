--!nonstrict
--[[
	Torso growths, back parts, tails and disfigurements. All placed at sockets (ctx.at).
	Back-facing socket frame: +Y = away from the back, +X = right, -Z = up.
]]

local A = require(script.Parent._Anatomy)

local TORSO = { "TorsoGrowths", "Disfigurements" }
local DISFIG = { "Disfigurements" }

return function(R)
	---------------------------------------------------------------- torso growths
	R.register({
		id = "ChestCavity",
		slots = TORSO,
		grade = "Grade3",
		tags = { "void", "reference" },
		params = { socket = "Chest", width = 1.3, height = 1.9, teeth = false, organs = false },
		build = function(ctx, p)
			local at, w, h = A.at(ctx), p.width, p.height
			ctx:blob(at, { 0, -0.04, 0 }, { w * 1.12, 0.36, h * 1.08 }, { 0, 0, 0 }, "VoidRim")
			ctx:blob(at, { 0, 0.03, 0 }, { w, 0.32, h }, nil, "Void")
			ctx:blob(at, { 0.05, 0.0, -h * 0.5 }, { w * 0.35, 0.24, h * 0.42 }, nil, "Void")
			if p.teeth then
				for i = 1, 12 do
					local a = i / 12 * math.pi * 2
					local ox, oz = math.cos(a) * w * 0.52, math.sin(a) * h * 0.5
					ctx:tube(at, { { ox, 0.05, oz }, { ox * 0.75, 0.22, oz * 0.75 }, { ox * 0.55, 0.18, oz * 0.55 } },
						{ 0.07, 0.05, 0.015 }, "Bone")
				end
			end
			if p.organs then
				ctx:blob(at, { -0.15 * w, 0.12, 0.2 * h }, { 0.4 * w, 0.25, 0.3 * h }, nil, "SkinLight")
				ctx:blob(at, { 0.2 * w, 0.1, 0.25 * h }, { 0.3 * w, 0.22, 0.35 * h }, nil, "FleshDark")
				local loops = {}
				for k = 0, 6 do
					table.insert(loops, { math.sin(k * 1.3) * 0.25 * w, 0.14, -0.05 * h - k * 0.05 * h })
				end
				ctx:tube(at, loops, { 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1 }, "Flesh")
			end
		end,
	})
	R.variant("ChestCavity", { id = "OpenChest", grade = "Grade2", params = { width = 1.5, height = 2.0, teeth = true } })
	R.variant("ChestCavity", { id = "ExposedOrgans", grade = "Grade2", params = { width = 1.2, height = 1.6, organs = true } })

	R.register({
		id = "BonePlating",
		slots = TORSO,
		grade = "Grade3",
		tags = { "bone", "armor" },
		params = { socket = "Chest" },
		build = function(ctx)
			local at = A.at(ctx)
			for row = 0, 2 do
				for col = -1, 1, 2 do
					ctx:blob(at, { col * 0.38, 0.08 + row * 0.02, 0.35 - row * 0.42 }, { 0.72, 0.16, 0.5 }, { 8, 0, col * 8 }, "Bone")
					ctx:blob(at, { col * 0.38, 0.1 + row * 0.02, 0.12 - row * 0.42 }, { 0.7, 0.1, 0.1 }, nil, "BoneDark")
				end
			end
			for _, name in ipairs({ "ShoulderR", "ShoulderL" }) do
				local s = ctx:socket(name)
				ctx:blob(s, { 0, 0.12, 0 }, { 1.0, 0.25, 0.9 }, nil, "Bone")
				ctx:blob(s, { 0.1, 0.2, 0.25 }, { 0.6, 0.15, 0.5 }, nil, "BoneDark")
			end
		end,
	})

	R.register({
		id = "OrganicArmor",
		slots = TORSO,
		grade = "Grade2",
		tags = { "armor", "insect" },
		params = { socket = "Chest" },
		build = function(ctx)
			local at = A.at(ctx)
			for row = 0, 4 do
				local w = 1.3 - math.abs(row - 1.5) * 0.18
				ctx:blob(at, { 0, 0.1, 0.45 - row * 0.3 }, { w, 0.14, 0.36 }, { 12, 0, 0 }, row % 2 == 0 and "SkinDark" or "SkinDeep")
			end
			local back = ctx:socket("Back")
			for row = 0, 3 do
				ctx:blob(back, { 0, 0.1, -0.5 + row * 0.35 }, { 1.4, 0.16, 0.42 }, { -10, 0, 0 }, "SkinDark")
			end
		end,
	})

	R.register({
		id = "RibGrowth",
		slots = TORSO,
		grade = "Grade3",
		tags = { "bone" },
		count = 2,
		params = { socket = "FlankR", ribs = 4, length = 0.8 },
		build = function(ctx, p)
			for _, name in ipairs({ "FlankR", "FlankL" }) do
				local s = ctx:socket(name)
				ctx:with({ side = s.side }, function()
					ctx:blob(s, { 0, 0, 0 }, { 0.4, 0.2, 1.1 }, nil, "SkinDeep")
					for i = 1, p.ribs do
						local z = (i - (p.ribs + 1) / 2) * 0.26
						ctx:tube(s, { { 0, 0, z }, { 0.05, p.length * 0.55, z - 0.12 }, { -0.1, p.length * 0.8, z - 0.45 },
							{ -0.35, p.length * 0.75, z - 0.7 } }, { 0.08, 0.07, 0.05, 0.02 }, "Bone")
					end
				end)
			end
		end,
	})

	R.register({
		id = "ShoulderGrowth",
		slots = TORSO,
		grade = "Grade3",
		tags = { "flesh", "growth" },
		params = { socket = "ShoulderR", size = 1.3, eyes = 2 },
		build = function(ctx, p)
			local at, s = A.at(ctx), p.size
			ctx:blob(at, { 0, 0.25 * s, 0 }, { 1.4 * s, 1.0 * s, 1.3 * s }, nil, "Skin")
			ctx:blob(at, { 0.3 * s, 0.55 * s, 0.2 * s }, { 0.8 * s, 0.6 * s, 0.7 * s }, nil, "SkinLight")
			ctx:blob(at, { -0.25 * s, 0.4 * s, -0.35 * s }, { 0.6 * s, 0.5 * s, 0.55 * s }, nil, "Flesh")
			for i = 1, p.eyes do
				local e = ctx:sub(at, { 0.15 * s * i - 0.2, 0.55 * s, -0.5 * s }, { -70, 0, 0 })
				ctx:blob(e, { 0, 0, 0 }, { 0.2, 0.12, 0.18 }, nil, "Eye")
				ctx:blob(e, { 0, 0.05, 0 }, { 0.06, 0.05, 0.1 }, nil, "Pupil")
			end
		end,
	})

	R.register({
		id = "SecondaryMass",
		slots = TORSO,
		grade = "Grade1",
		tags = { "abnormal", "flesh" },
		params = { socket = "BackR", size = 1 },
		build = function(ctx, p)
			local at, s = A.at(ctx), p.size
			ctx:blob(at, { 0, 0.5 * s, 0 }, { 1.7 * s, 1.3 * s, 1.9 * s }, nil, "Skin")
			ctx:blob(at, { 0.2 * s, 0.9 * s, -0.4 * s }, { 1.0 * s, 0.7 * s, 0.9 * s }, nil, "SkinLight")
			ctx:blob(at, { -0.3 * s, 0.85 * s, 0.3 * s }, { 0.9 * s, 0.4 * s, 0.7 * s }, nil, "Flesh")
			ctx:tube(at, { { 0.5 * s, 0.7 * s, 0.2 * s }, { 0.9 * s, 0.8 * s, 0.6 * s }, { 1.0 * s, 0.6 * s, 1.0 * s } },
				{ 0.25 * s, 0.2 * s, 0.14 * s }, "Skin")
			local e = ctx:sub(at, { 0, 1.15 * s, -0.2 * s })
			ctx:blob(e, { 0, 0, 0 }, { 0.3, 0.14, 0.26 }, nil, "Eye")
			ctx:blob(e, { 0, 0.06, 0 }, { 0.09, 0.06, 0.16 }, nil, "Pupil")
		end,
	})

	---------------------------------------------------------------- back
	local function wing(ctx, p, bones)
		local at = A.at(ctx)
		local root = ctx:chain(at, { 0, 0, 0 }, nil, { { 0.1, 0.1, { 0, 0, 0 } } },
			{ name = "Wing", flesh = false, sway = { amp = 7, speed = 0.7 } })[1].anchor
		local S = p.span
		local base = { 0, 0.05, 0 }
		local E, W = { 0.9 * S, 0.5 * S, -0.7 * S }, { 1.6 * S, 0.45 * S, -1.1 * S }
		local tips = { { 2.6 * S, 0.5 * S, -1.6 * S }, { 3.0 * S, 0.6 * S, -0.6 * S }, { 2.6 * S, 0.6 * S, 0.4 * S }, { 1.6 * S, 0.5 * S, 0.9 * S } }
		do
			ctx:blob(root, base, { 0.55, 0.5, 0.6 }, nil, "Skin")
			ctx:tube(root, { base, E, W }, { 0.16, 0.12, 0.1 }, bones and "Bone" or "SkinDark")
			for _, t in ipairs(tips) do
				ctx:tube(root, { W, A.lerp(W, t, 0.55), t }, { 0.08, 0.06, 0.02 }, bones and "Bone" or "SkinDark")
				if bones then
					ctx:tube(root, { t, A.add(t, { 0.25, 0.05, -0.1 }) }, { 0.05, 0.01 }, "BoneDark")
				end
			end
			if not bones then
				ctx:triangle(root, W, tips[1], tips[2], "Membrane", 0.04)
				ctx:triangle(root, W, tips[2], tips[3], "Membrane", 0.04)
				ctx:triangle(root, W, tips[3], tips[4], "Membrane", 0.04)
				ctx:triangle(root, base, W, tips[4], "Membrane", 0.04)
				ctx:triangle(root, base, E, W, "Membrane", 0.04)
			end
		end
	end

	for _, def in ipairs({
		{ id = "Wing", grade = "Grade2", bones = false },
		{ id = "BoneWing", grade = "Grade1", bones = true },
	}) do
		R.register({
			id = def.id,
			slots = { "Back" },
			grade = def.grade,
			tags = { "wing" },
			params = { socket = "BackR", span = 1 },
			build = function(ctx, p)
				wing(ctx, p, def.bones)
			end,
		})
	end
	for _, def in ipairs({ { id = "Wings", part = "Wing", grade = "Grade2" }, { id = "BoneWings", part = "BoneWing", grade = "Grade1" } }) do
		R.register({
			id = def.id,
			slots = { "Back" },
			grade = def.grade,
			tags = { "wing", "pair" },
			count = 2,
			params = { socket = "BackR", span = 1 },
			build = function(ctx, p)
				local scale = { ctx.scale.X, ctx.scale.Y, ctx.scale.Z }
				for _, socket in ipairs({ "BackR", "BackL" }) do
					ctx.state.buildEntry(ctx, { id = def.part, socket = socket, params = { span = p.span }, scale = scale })
				end
			end,
		})
	end

	R.register({
		id = "Tendrils",
		slots = { "Back" },
		grade = "Grade2",
		tags = { "tendril" },
		params = { socket = "UpperBack", count = 4, length = 2.4 },
		build = function(ctx, p)
			local at = A.at(ctx)
			for i = 1, p.count do
				local k = p.count == 1 and 0 or (i - 1) / (p.count - 1) * 2 - 1
				local segs = {}
				for s = 1, 6 do
					table.insert(segs, { p.length / 6, 0.16 * (1 - 0.13 * s), { s == 1 and 0 or -14, 0, s == 1 and 0 or k * 6 } })
				end
				ctx:chain(at, { k * 0.5, 0, 0.1 * math.abs(k) }, { 180 + 40, 0, k * 35 }, segs,
					{ name = "Tendril", sway = { amp = 10, speed = 1.0 + i * 0.1 } })
			end
		end,
	})

	R.register({
		id = "Spikes",
		slots = { "Back", "Disfigurements" },
		grade = "Grade3",
		tags = { "bone", "spine" },
		params = { socket = "UpperBack", count = 5, length = 0.7 },
		build = function(ctx, p)
			local top, low = ctx:socket("UpperBack"), ctx:socket("LowerBack")
			local torso = ctx.character.Torso
			for i = 1, p.count do
				local t = (i - 1) / math.max(1, p.count - 1)
				local cf = top.cf:Lerp(low.cf, t)
				local anchor = { part = torso, cf = cf, side = 1 }
				local L = p.length * (1 - 0.45 * t) * ctx.scale.Y
				ctx:blob(anchor, { 0, 0, 0 }, { 0.3, 0.15, 0.3 }, nil, "SkinDark")
				ctx:tube(anchor, { { 0, 0, 0 }, { 0, L * 0.6, -0.12 }, { 0, L, -0.3 } }, { 0.1, 0.06, 0.01 }, "Bone")
			end
		end,
	})

	R.register({
		id = "BackEyes",
		slots = { "Back" },
		grade = "Grade2",
		tags = { "eye" },
		count = 2,
		params = { socket = "Back", eyes = 5 },
		build = function(ctx, p)
			local scale = { ctx.scale.X, ctx.scale.Y, ctx.scale.Z }
			for _, socket in ipairs({ "BackR", "BackL", "Back" }) do
				ctx.state.buildEntry(ctx, { id = "EyeCluster", socket = socket, params = { count = p.eyes, spread = 0.35 }, scale = scale })
			end
		end,
	})

	R.variant("Tumor", { id = "OrganicGrowth", grade = "Grade3", slots = { "Back", "TorsoGrowths", "Disfigurements" },
		params = { socket = "BackL", size = 0.7, lumps = 7 } })

	R.register({
		id = "Shell",
		slots = { "Back" },
		grade = "Grade2",
		tags = { "armor", "shell" },
		params = { socket = "Back", size = 1 },
		build = function(ctx, p)
			local at, s = A.at(ctx), p.size * ctx:m("TorsoW")
			ctx:blob(at, { 0, 0.1, -0.2 }, { 2.3 * s, 0.9, 2.4 }, nil, "SkinDark")
			for row = 0, 3 do
				ctx:blob(at, { 0, 0.4 - row * 0.05, -1.0 + row * 0.55 }, { (2.1 - row * 0.2) * s, 0.35, 0.7 }, { -12, 0, 0 },
					row % 2 == 0 and "SkinDeep" or "SkinDark")
				ctx:blob(at, { 0, 0.52 - row * 0.05, -0.75 + row * 0.55 }, { (1.9 - row * 0.2) * s, 0.12, 0.15 }, nil, "BoneDark")
			end
		end,
	})

	---------------------------------------------------------------- tails
	R.register({
		id = "Tail",
		slots = { "Tails" },
		grade = "Grade4",
		tags = { "tail" },
		params = {
			socket = "TailRoot", segments = 6, length = 3.2, radius = 0.32, taper = 0.3, lift = 10, droop = 16,
			curl = -30, side = 0, underside = true, spikes = false, bone = false, blade = false, claw = false, sway = 8,
		},
		build = function(ctx, p)
			local at = A.at(ctx)
			local index = (ctx.folder:GetAttribute("TailCount") or 0) + 1
			ctx.folder:SetAttribute("TailCount", index)
			local yaw = (index == 1) and 0 or (index % 2 == 0 and 1 or -1) * 22 * math.floor(index / 2)
			local n = p.segments
			local segs = {}
			for i = 1, n do
				local k = (i - 1) / (n - 1)
				local rx = i == 1 and 0 or (i == n and p.curl or p.droop)
				table.insert(segs, { p.length / n, p.radius * (1 - (1 - p.taper) * k), { rx, 0, i == 1 and 0 or p.side } })
			end
			local chain = ctx:chain(at, { 0, -0.05, 0 }, { 180 - p.lift, yaw, 0 }, segs, {
				name = "Tail",
				sway = { amp = p.sway, speed = 1.2 },
				flesh = function(c, seg, i, len, r)
					if p.bone then
						c:blob(seg, { 0, 0, 0 }, { r * 1.5, len * 0.7, r * 1.5 }, nil, "Bone")
						c:blob(seg, { 0, len * 0.42, 0 }, { r * 2, len * 0.2, r * 2 }, nil, "BoneDark")
					else
						c:blob(seg, { 0, 0, 0 }, { r * 2, len * 1.35, r * 2 }, nil, i % 2 == 0 and "SkinLight" or "Skin")
						if p.underside then
							c:blob(seg, { 0, 0, r * 0.35 }, { r * 1.4, len * 1.2, r * 1.4 }, nil, "SkinDark")
						end
					end
					if p.spikes then
						c:tube(seg, { { 0, 0, -r * 0.8 }, { 0, -len * 0.1, -r * 1.6 }, { 0, -len * 0.25, -r * 2.2 } }, { r * 0.35, r * 0.2, 0.02 }, "Bone")
					end
				end,
			})
			local tip = chain[#chain]
			local e = { 0, -tip.length / 2, 0 }
			if p.blade then
				ctx:with({ side = 1, scale = Vector3.one }, function()
					ctx:triangle(tip.anchor, A.add(e, { 0, 0.2, -0.05 }), A.add(e, { 0, -0.9, 0 }), A.add(e, { 0, 0.1, -0.55 }), "Claw", 0.06)
					ctx:triangle(tip.anchor, A.add(e, { 0, 0.2, 0.05 }), A.add(e, { 0, -0.9, 0 }), A.add(e, { 0, 0.1, 0.55 }), "Claw", 0.06)
				end)
			elseif p.claw then
				ctx:with({ side = 1, scale = Vector3.one }, function()
					ctx:tube(tip.anchor, { e, A.add(e, { 0, -0.35, 0.02 }), A.add(e, { 0, -0.6, 0.12 }) }, { 0.1, 0.06, 0.015 }, "Claw")
					ctx:capsule(tip.anchor, A.add(e, { 0, -0.45, 0.06 }), A.add(e, { 0, -0.62, 0.13 }), 0.025, "Teeth")
				end)
			end
		end,
	})
	local function tail(id, grade, params)
		R.variant("Tail", { id = id, grade = grade, params = params, tags = { "tail" } })
	end
	tail("ThinTail", "Grade4", { radius = 0.17, length = 2.6, taper = 0.25 })
	tail("ThickTail", "Grade3", { radius = 0.55, length = 3.4, taper = 0.3, droop = 14, lift = 20 })
	tail("LongTail", "Grade3", { radius = 0.28, length = 5.2, segments = 9, droop = 10 })
	tail("BladeTail", "Grade2", { radius = 0.3, length = 3.6, blade = true, spikes = true, lift = 25, droop = 8, curl = 10 })
	tail("BoneTail", "Grade2", { radius = 0.25, length = 3.6, segments = 9, bone = true, spikes = true, underside = false, droop = 10 })
	tail("TendrilTail", "Grade3", { radius = 0.11, length = 4.2, segments = 10, taper = 0.3, droop = 9, curl = -20, sway = 14, underside = false })
	tail("CreatureTail", "Grade3", { radius = 0.46, length = 4.4, segments = 5, taper = 0.33, lift = 0, droop = 30, curl = -85, side = -14, claw = true }) -- the reference

	---------------------------------------------------------------- disfigurements
	R.register({
		id = "BoneProtrusion",
		slots = DISFIG,
		grade = "Grade3",
		tags = { "bone" },
		params = { socket = "Forearm_R", length = 0.7 },
		build = function(ctx, p)
			local at = A.at(ctx)
			ctx:blob(at, { 0, 0, 0 }, { 0.42, 0.18, 0.42 }, nil, "SkinDeep")
			ctx:blob(at, { 0, 0.02, 0 }, { 0.5, 0.1, 0.5 }, nil, "Flesh")
			ctx:tube(at, { { 0, -0.05, 0 }, { 0.04, p.length * 0.55, 0.06 }, { 0.12, p.length, 0.15 } }, { 0.13, 0.08, 0.015 }, "Bone")
		end,
	})

	R.variant("Tumor", { id = "Tumors", grade = "Grade2", slots = DISFIG, params = { socket = "Back", size = 0.55, lumps = 8 } })
	R.variant("Tumor", { id = "FleshGrowth", grade = "Grade3", slots = DISFIG, params = { socket = "ChestR", size = 0.5, lumps = 5 } })

	R.register({
		id = "ExposedBone",
		slots = DISFIG,
		grade = "Grade3",
		tags = { "bone", "wound" },
		params = { socket = "UpperArm_R", length = 0.6 },
		build = function(ctx, p)
			local at = A.at(ctx)
			ctx:blob(at, { 0, 0, 0 }, { 0.45, 0.12, p.length + 0.2 }, nil, "VoidRim")
			ctx:blob(at, { 0, 0.03, 0 }, { 0.35, 0.1, p.length + 0.05 }, nil, "SkinDeep")
			ctx:capsule(at, { 0, 0.07, -p.length / 2 }, { 0, 0.07, p.length / 2 }, 0.09, "Bone")
		end,
	})

	R.register({
		id = "ExposedTissue",
		slots = DISFIG,
		grade = "Grade4",
		tags = { "flesh", "wound" },
		params = { socket = "ChestL", size = 0.6 },
		build = function(ctx, p)
			local at, s = A.at(ctx), p.size
			ctx:blob(at, { 0, 0, 0 }, { s * 1.1, 0.14, s * 1.3 }, nil, "SkinDark")
			ctx:blob(at, { 0, 0.03, 0 }, { s, 0.12, s * 1.2 }, nil, "Flesh")
			for i = 1, 3 do
				ctx:blob(at, { 0, 0.07, (i - 2) * s * 0.3 }, { s * 0.8, 0.05, 0.06 }, nil, "FleshDark")
			end
		end,
	})

	R.register({
		id = "CrackedFlesh",
		slots = DISFIG,
		grade = "Grade3",
		tags = { "wound", "energy" },
		params = { socket = "ChestR", size = 0.7, cracks = 3 },
		build = function(ctx, p)
			local at, s = A.at(ctx), p.size
			for c = 1, p.cracks do
				local pts = { { ctx:rand(-0.2, 0.2) * s, 0.02, ctx:rand(-0.2, 0.2) * s } }
				local a = ctx:rand(0, math.pi * 2)
				for k = 1, 4 do
					a += ctx:rand(-0.9, 0.9)
					local prev = pts[#pts]
					table.insert(pts, { prev[1] + math.cos(a) * 0.18 * s, 0.02, prev[3] + math.sin(a) * 0.18 * s })
				end
				ctx:tube(at, pts, { 0.05, 0.045, 0.04, 0.03, 0.02 }, "VoidRim", { stretch = 1.1 })
				ctx:tube(at, pts, { 0.025, 0.022, 0.02, 0.015, 0.01 }, c % 2 == 0 and "Glow" or "Void", { stretch = 1.05 })
			end
		end,
	})

	R.register({
		id = "BlackenedFlesh",
		slots = DISFIG,
		grade = "Grade3",
		tags = { "necrotic" },
		params = { socket = "Back", size = 0.8, patches = 6 },
		build = function(ctx, p)
			local at, s = A.at(ctx), p.size
			local roles = { "SkinDeep", "Void", "Spot", "SkinDeep" }
			for i = 1, p.patches do
				local r = ctx:rand(0.25, 0.5) * s
				ctx:blob(at, { ctx:rand(-0.4, 0.4) * s, 0.02, ctx:rand(-0.4, 0.4) * s }, { r, 0.09, r * ctx:rand(0.7, 1.3) },
					{ 0, ctx:rand(0, 180), 0 }, roles[(i - 1) % #roles + 1])
			end
		end,
	})

	R.variant("Spikes", { id = "SpineGrowth", grade = "Grade2", slots = DISFIG, params = { count = 7, length = 0.5 } })

	R.register({
		id = "ExtraFinger",
		slots = DISFIG,
		grade = "Grade3",
		tags = { "hand" },
		params = { socket = "Hand_R", length = 0.5 },
		build = function(ctx, p)
			local at = A.at(ctx)
			local L = p.length * ctx:m("Hand")
			ctx:tube(at, { { 0.2, 0.3, -0.1 }, { 0.32, 0.3 + L * 0.5, -0.12 }, { 0.36, 0.3 + L, -0.05 } }, { 0.08, 0.07, 0.05 }, "SkinLight")
			ctx:capsule(at, { 0.36, 0.3 + L, -0.05 }, { 0.38, 0.45 + L, 0 }, 0.04, "Claw")
		end,
	})

	-- proportion mutators: they change the body before anything builds
	local function sideMutator(id, grade, socket, changes, geometry)
		R.register({
			id = id,
			slots = DISFIG,
			grade = grade,
			tags = { "mutation" },
			params = { socket = socket },
			mutate = function(body, _, entry)
				local side = body.side[A.sideOf(entry)]
				for key, mul in pairs(changes) do
					side[key] = (side[key] or 1) * mul
				end
			end,
			build = geometry,
		})
	end
	sideMutator("SwollenHand", "Grade3", "Hand_R", { Hand = 1.6 })
	sideMutator("ElongatedArm", "Grade3", "Shoulder_R", { ArmLength = 1.35 })
	sideMutator("ShrunkenArm", "Grade3", "UpperArm_R", { ArmThick = 0.6, ArmLength = 0.8, Hand = 0.7 })
	sideMutator("EnlargedMuscle", "Grade3", "UpperArm_R", { ArmThick = 1.35 })
	sideMutator("AsymmetricShoulder", "Grade3", "ShoulderR", { Shoulder = 1.7, ArmThick = 1.1 }, function(ctx)
		local at = A.at(ctx)
		ctx:blob(at, { 0, 0.3, 0 }, { 1.3, 0.8, 1.2 }, nil, "Skin")
		ctx:blob(at, { 0.2, 0.55, 0.1 }, { 0.8, 0.5, 0.7 }, nil, "SkinLight")
	end)

	R.register({
		id = "MissingFingers",
		slots = DISFIG,
		grade = "Grade4",
		tags = { "wound", "hand" },
		params = { socket = "Hand_R", count = 2 },
		mutate = function(body, p, entry)
			body.flags = body.flags or {}
			local key = "MissingFingers" .. A.sideOf(entry)
			body.flags[key] = (body.flags[key] or 0) + p.count
		end,
	})
end
