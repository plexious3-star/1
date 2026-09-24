--!nonstrict
--[[
	Eyes, mouths and head growths. All of them are placed at a socket (ctx.at), so any
	of them can go anywhere: an eye on the chest, a mouth on a palm, an ear on a shoulder.
	Socket frame: +Y out of the surface, +X right, +Z "up the surface" (for front sockets).
]]

local A = require(script.Parent._Anatomy)

local FEATURE = { "Eyes", "Disfigurements" }
local MOUTH = { "Mouths", "Disfigurements" }
local GROWTH = { "HeadGrowths", "Disfigurements" }

-- one eye at an anchor (radius r)
local function eye(ctx, at, r, p)
	if p.ring ~= false then
		ctx:blob(at, { 0, -0.02, 0 }, { 2.3 * r, 0.9 * r, 2.1 * r }, nil, "SkinDeep")
	end
	ctx:blob(at, { 0, 0.02, 0 }, { 2 * r, 1.2 * r, 1.8 * r }, nil, p.role or "Eye")
	if p.pupil ~= false then
		ctx:blob(at, { 0, 0.55 * r, 0 }, { 0.45 * r, 0.25 * r, 0.9 * r }, nil, "Pupil")
	end
	if p.lid ~= false then
		ctx:blob(at, { 0, 0.15 * r, 0.75 * r }, { 2.4 * r, 1.0 * r, 0.9 * r }, { 10, 0, 0 }, "SkinDark")
	end
end

return function(R)
	---------------------------------------------------------------- eyes
	R.register({
		id = "Eye",
		slots = FEATURE,
		grade = "Grade4",
		tags = { "eye" },
		params = { size = 0.14, socket = "Face" },
		build = function(ctx, p)
			eye(ctx, A.at(ctx), p.size, p)
		end,
	})

	R.register({
		id = "GiantEye",
		slots = FEATURE,
		grade = "Grade3",
		tags = { "eye" },
		params = { size = 0.42, socket = "Face" },
		build = function(ctx, p)
			local at, r = A.at(ctx), p.size
			ctx:blob(at, { 0, -0.05, 0 }, { 2.4 * r, 1.0 * r, 2.3 * r }, nil, "SkinDeep")
			ctx:blob(at, { 0, 0.05, 0 }, { 2 * r, 1.25 * r, 2 * r }, nil, "Eye")
			ctx:blob(at, { 0, 0.52 * r, 0 }, { 1.05 * r, 0.3 * r, 1.05 * r }, nil, "Glow")
			ctx:blob(at, { 0, 0.62 * r, 0 }, { 0.45 * r, 0.25 * r, 0.75 * r }, nil, "Pupil")
			ctx:blob(at, { 0, 0.2 * r, 0.85 * r }, { 2.5 * r, 1.0 * r, 0.8 * r }, { 12, 0, 0 }, "SkinDark")
			ctx:blob(at, { 0, 0.15 * r, -0.9 * r }, { 2.3 * r, 0.8 * r, 0.6 * r }, { -12, 0, 0 }, "SkinDark")
			for i = 1, 4 do
				local a = i * 1.4
				ctx:capsule(at, { math.cos(a) * 0.95 * r, 0.25 * r, math.sin(a) * 0.9 * r },
					{ math.cos(a) * 0.6 * r, 0.45 * r, math.sin(a) * 0.55 * r }, 0.03, "SkinLight")
			end
		end,
	})

	R.register({
		id = "EyeCluster",
		slots = FEATURE,
		grade = "Grade3",
		tags = { "eye" },
		params = { count = 5, spread = 0.4, size = 0.1, socket = "Face" },
		count = function(p)
			return p.count
		end,
		build = function(ctx, p)
			local at = A.at(ctx)
			for _, pt in ipairs(A.scatter(ctx, p.count, p.spread)) do
				local r = p.size * ctx:rand(0.6, 1.4)
				eye(ctx, ctx:sub(at, pt, { 0, ctx:rand(0, 360), 0 }), r, { lid = ctx:rand(0, 1) > 0.5 })
			end
		end,
	})

	R.register({
		id = "EyeStalk",
		slots = FEATURE,
		grade = "Grade2",
		tags = { "eye", "tendril" },
		params = { length = 0.9, size = 0.12, socket = "Crown" },
		build = function(ctx, p)
			local at = A.at(ctx)
			local seg = p.length / 3
			local chain = ctx:chain(at, { 0, 0, 0 }, { 180 + ctx:rand(-20, 20), 0, ctx:rand(-25, 25) }, {
				{ seg, 0.07, { 0, 0, 0 } }, { seg, 0.06, { 15, 0, 0 } }, { seg, 0.05, { 15, 0, 0 } },
			}, { name = "EyeStalk", sway = { amp = 12, speed = 0.9 } })
			local tip = chain[#chain]
			eye(ctx, ctx:sub(tip.anchor, { 0, -tip.length / 2, 0 }, { 180, 0, 0 }), p.size, { lid = false })
		end,
	})

	R.register({
		id = "CompoundEye",
		slots = FEATURE,
		grade = "Grade3",
		tags = { "eye", "insect" },
		params = { size = 0.3, socket = "Face" },
		build = function(ctx, p)
			local at, r = A.at(ctx), p.size
			ctx:blob(at, { 0, 0, 0 }, { 1.7 * r, 1.4 * r, 2.0 * r }, nil, "Void")
			for i = 1, 7 do
				local a = i * 2.4
				local d = 0.45 * r * math.sqrt(i / 7)
				ctx:blob(at, { math.cos(a) * d, 0.62 * r, math.sin(a) * d * 1.2 }, { 0.22 * r, 0.12 * r, 0.22 * r }, nil, "Eye")
			end
		end,
	})

	R.register({
		id = "MissingEye",
		slots = FEATURE,
		grade = "Grade4",
		tags = { "eye", "wound" },
		params = { size = 0.16, socket = "Face" },
		count = 0,
		build = function(ctx, p)
			local at, r = A.at(ctx), p.size
			ctx:blob(at, { 0, 0, 0 }, { 2.3 * r, 0.8 * r, 2.0 * r }, nil, "SkinDark")
			ctx:blob(at, { 0, 0.12 * r, 0 }, { 1.5 * r, 0.6 * r, 1.3 * r }, nil, "Void")
			ctx:capsule(at, { -1.4 * r, 0.3 * r, 1.6 * r }, { 1.2 * r, 0.3 * r, -1.5 * r }, 0.025, "SkinLight")
		end,
	})

	R.register({
		id = "SlitEye",
		slots = FEATURE,
		grade = "Grade3",
		tags = { "eye" },
		params = { size = 0.18, socket = "Face" },
		build = function(ctx, p)
			local at, r = A.at(ctx), p.size
			ctx:blob(at, { 0, 0, 0 }, { 2.2 * r, 0.7 * r, 1.0 * r }, nil, "SkinDark")
			ctx:blob(at, { 0, 0.3 * r, 0 }, { 1.8 * r, 0.3 * r, 0.25 * r }, nil, "Glow")
		end,
	})

	---------------------------------------------------------------- mouths
	R.register({
		id = "SlitMouth",
		slots = MOUTH,
		grade = "Grade4",
		tags = { "mouth" },
		params = { width = 0.5, socket = "Mouth" },
		build = function(ctx, p)
			local at, w = A.at(ctx), p.width
			ctx:blob(at, { 0, 0, 0 }, { w * 1.15, 0.14, 0.17 }, nil, "SkinDark")
			ctx:blob(at, { 0, 0.04, 0 }, { w, 0.1, 0.06 }, nil, "Void")
			for i = 0, 5 do
				local x = (i / 5 - 0.5) * w * 0.8
				ctx:blob(at, { x, 0.07, 0.015 }, { 0.045, 0.04, 0.05 }, nil, "Teeth")
			end
		end,
	})

	R.register({
		id = "GrinMouth",
		slots = MOUTH,
		grade = "Grade3",
		tags = { "mouth", "teeth" },
		params = { width = 0.85, teeth = 11, socket = "Mouth" },
		build = function(ctx, p)
			local at, w, n = A.at(ctx), p.width, p.teeth
			local function curve(x)
				return 0.14 * (2 * x / w) ^ 2
			end
			for i = 0, 6 do
				local x = (i / 6 - 0.5) * w
				ctx:blob(at, { x, 0, curve(x) }, { w / 5, 0.12, 0.22 }, nil, "Void")
			end
			for i = 0, n - 1 do
				local x = (i / (n - 1) - 0.5) * w * 0.95
				local z = curve(x)
				ctx:capsule(at, { x, 0.05, z + 0.09 }, { x, 0.07, z - 0.01 }, 0.035, "Teeth")
				ctx:capsule(at, { x + 0.03, 0.05, z - 0.09 }, { x + 0.03, 0.07, z + 0.0 }, 0.032, "Teeth")
			end
			ctx:tube(at, { { -w * 0.55, 0.0, curve(w * 0.55) }, { 0, 0.02, 0.13 }, { w * 0.55, 0.0, curve(w * 0.55) } },
				{ 0.05, 0.06, 0.05 }, "SkinDark")
		end,
	})

	R.register({
		id = "Maw",
		slots = MOUTH,
		grade = "Grade2",
		tags = { "mouth", "teeth" },
		params = { size = 0.55, teeth = 14, socket = "Chest" },
		build = function(ctx, p)
			local at, s = A.at(ctx), p.size
			ctx:blob(at, { 0, -0.05, 0 }, { 1.7 * s, 0.45 * s, 2.2 * s }, nil, "SkinDark")
			ctx:blob(at, { 0, 0.05, 0 }, { 1.35 * s, 0.4 * s, 1.85 * s }, nil, "Void")
			for i = 1, p.teeth do
				local a = i / p.teeth * math.pi * 2
				local ox, oz = math.cos(a) * 0.68 * s, math.sin(a) * 0.92 * s
				ctx:capsule(at, { ox, 0.15 * s, oz }, { ox * 0.62, 0.2 * s, oz * 0.62 }, 0.05 * s / 0.55, "Teeth")
			end
		end,
	})

	R.register({
		id = "LampreyMouth",
		slots = MOUTH,
		grade = "Grade2",
		tags = { "mouth", "teeth" },
		params = { size = 0.45, socket = "Mouth" },
		build = function(ctx, p)
			local at, s = A.at(ctx), p.size
			ctx:blob(at, { 0, -0.05, 0 }, { 2 * s, 0.6 * s, 2 * s }, nil, "SkinDark")
			ctx:blob(at, { 0, 0.08, 0 }, { 1.6 * s, 0.5 * s, 1.6 * s }, nil, "Void")
			for ring, rr in ipairs({ 0.72, 0.5, 0.3 }) do
				local n = 14 - ring * 3
				for i = 1, n do
					local a = (i + ring * 0.5) / n * math.pi * 2
					ctx:capsule(at, { math.cos(a) * rr * s, 0.18 * s, math.sin(a) * rr * s },
						{ math.cos(a) * (rr - 0.16) * s, 0.24 * s, math.sin(a) * (rr - 0.16) * s }, 0.035, "Teeth")
				end
			end
		end,
	})

	R.register({
		id = "Mandibles",
		slots = MOUTH,
		grade = "Grade3",
		tags = { "mouth", "insect" },
		params = { length = 0.7, socket = "Mouth" },
		build = function(ctx, p)
			local at, L = A.at(ctx), p.length
			ctx:blob(at, { 0, 0, 0 }, { 0.35, 0.15, 0.2 }, nil, "Void")
			for _, s in ipairs({ 1, -1 }) do
				local pts = { { 0.18 * s, 0, 0 }, { 0.42 * s, 0.35 * L, -0.12 * L }, { 0.38 * s, 0.75 * L, -0.35 * L },
					{ 0.1 * s, 0.95 * L, -0.5 * L } }
				ctx:tube(at, pts, { 0.1, 0.08, 0.06, 0.02 }, function(i)
					return i == 3 and "Claw" or "SkinDark"
				end)
				for k = 1, 3 do
					local q = A.lerp(pts[2], pts[3], k / 4)
					ctx:capsule(at, q, { q[1] - 0.1 * s, q[2] + 0.02, q[3] }, 0.025, "Teeth")
				end
			end
		end,
	})

	R.register({
		id = "TongueMouth",
		slots = MOUTH,
		grade = "Grade2",
		tags = { "mouth", "tendril" },
		params = { width = 0.5, length = 1.2, socket = "Mouth" },
		build = function(ctx, p)
			local at = A.at(ctx)
			ctx:blob(at, { 0, 0, 0 }, { p.width * 1.2, 0.2, 0.3 }, nil, "SkinDark")
			ctx:blob(at, { 0, 0.05, 0 }, { p.width, 0.15, 0.2 }, nil, "Void")
			local seg = p.length / 4
			ctx:chain(at, { 0, 0.05, 0 }, { 110, 0, 0 }, {
				{ seg, 0.09, { 0, 0, 0 } }, { seg, 0.08, { 12, 0, 0 } }, { seg, 0.07, { 12, 0, 5 } }, { seg, 0.05, { 10, 0, 5 } },
			}, { name = "Tongue", role = "Flesh", sway = { amp = 10, speed = 1.4 } })
		end,
	})

	R.register({
		id = "HangingJaw",
		slots = MOUTH,
		grade = "Grade2",
		tags = { "mouth", "jaw" },
		params = { width = 0.7, socket = "Jaw" },
		build = function(ctx, p)
			local at, w = A.at(ctx), p.width
			ctx:blob(at, { 0, 0.25, 0.1 }, { w, 0.5, 0.7 }, nil, "SkinDark")
			ctx:blob(at, { 0, 0.35, -0.2 }, { w * 0.8, 0.35, 0.3 }, nil, "Void")
			for i = 0, 6 do
				local x = (i / 6 - 0.5) * w * 0.8
				ctx:capsule(at, { x, 0.35, -0.35 }, { x, 0.12, -0.42 }, 0.035, "Teeth")
			end
		end,
	})

	---------------------------------------------------------------- head growths
	R.register({
		id = "ExtraEar",
		slots = GROWTH,
		grade = "Grade4",
		tags = { "growth" },
		params = { size = 1, socket = "TempleR" },
		build = function(ctx, p)
			local at, s = A.at(ctx), p.size
			ctx:blob(at, { 0, 0.05, 0 }, { 0.3 * s, 0.14 * s, 0.45 * s }, nil, "SkinDark")
			ctx:blob(at, { 0, 0.1, 0 }, { 0.18 * s, 0.08 * s, 0.3 * s }, nil, "SkinDeep")
		end,
	})

	R.register({
		id = "ExtraNose",
		slots = GROWTH,
		grade = "Grade4",
		tags = { "growth" },
		params = { size = 1, socket = "CheekR" },
		build = function(ctx, p)
			local at, s = A.at(ctx), p.size
			ctx:capsule(at, { 0, 0, 0.12 * s }, { 0, 0.22 * s, -0.08 * s }, 0.1 * s, "SkinLight")
			for _, x in ipairs({ -0.05, 0.05 }) do
				ctx:blob(at, { x * s, 0.2 * s, -0.12 * s }, { 0.05 * s, 0.04 * s, 0.05 * s }, nil, "Void")
			end
		end,
	})

	R.register({
		id = "BoneSpur",
		slots = { "HeadGrowths", "Disfigurements", "TorsoGrowths" },
		grade = "Grade4",
		tags = { "bone" },
		params = { length = 0.45, thickness = 0.09, socket = "BackOfHead" },
		build = function(ctx, p)
			local at, L, r = A.at(ctx), p.length, p.thickness
			ctx:blob(at, { 0, 0, 0 }, { r * 3, r * 1.4, r * 3 }, nil, "SkinDark")
			ctx:tube(at, { { 0, 0, 0 }, { 0.02, L * 0.5, 0.03 }, { 0.06, L, 0.08 } }, { r, r * 0.6, r * 0.1 }, "Bone")
		end,
	})

	R.register({
		id = "FacePlate",
		slots = GROWTH,
		grade = "Grade3",
		tags = { "bone", "armor" },
		params = { size = 1, socket = "Brow" },
		build = function(ctx, p)
			local at, s = A.at(ctx), p.size
			ctx:blob(at, { 0, 0.02, 0 }, { 0.9 * s, 0.14 * s, 0.7 * s }, nil, "Bone")
			ctx:blob(at, { 0, 0.0, -0.3 * s }, { 0.95 * s, 0.1 * s, 0.2 * s }, nil, "BoneDark")
		end,
	})

	R.register({
		id = "Tumor",
		slots = { "HeadGrowths", "Disfigurements", "TorsoGrowths", "Back" },
		grade = "Grade4",
		tags = { "growth", "flesh" },
		params = { size = 0.35, lumps = 4, socket = "TempleR" },
		build = function(ctx, p)
			local at = A.at(ctx)
			local roles = { "SkinLight", "Flesh", "SkinDark", "Skin" }
			for i = 1, p.lumps do
				local r = p.size * ctx:rand(0.45, 1)
				ctx:blob(at, { ctx:rand(-1, 1) * p.size * 0.6, r * 0.2, ctx:rand(-1, 1) * p.size * 0.6 },
					{ r, r * ctx:rand(0.6, 0.9), r * ctx:rand(0.8, 1.1) }, { 0, ctx:rand(0, 180), 0 },
					roles[(i - 1) % #roles + 1])
			end
		end,
	})

	R.register({
		id = "Crest",
		slots = GROWTH,
		grade = "Grade3",
		tags = { "bone", "spine" },
		params = { spines = 5, height = 0.45, socket = "Crown" },
		build = function(ctx, p)
			local at = A.at(ctx)
			for i = 1, p.spines do
				local z = (i - 1) * 0.2 - 0.15
				local h = p.height * (1 - (i - 1) / (p.spines + 1))
				ctx:tube(at, { { 0, -0.05, z }, { 0, h * 0.6, z + 0.08 }, { 0, h, z + 0.2 } }, { 0.07, 0.04, 0.01 }, "BoneDark")
			end
			ctx:triangle(at, { 0, 0, -0.15 }, { 0, p.height, 0.05 }, { 0, 0, (p.spines - 1) * 0.2 + 0.1 }, "Membrane", 0.03)
		end,
	})

	R.register({
		id = "Antennae",
		slots = GROWTH,
		grade = "Grade3",
		tags = { "insect", "tendril" },
		params = { length = 1.2, socket = "Brow" },
		build = function(ctx, p)
			local at = A.at(ctx)
			local seg = p.length / 4
			for _, s in ipairs({ 1, -1 }) do
				ctx:chain(at, { 0.15 * s, 0, 0 }, { 150, 0, 25 * s }, {
					{ seg, 0.04, { 0, 0, 0 } }, { seg, 0.035, { -15, 0, 0 } }, { seg, 0.03, { -15, 0, 0 } }, { seg, 0.02, { -10, 0, 0 } },
				}, { name = "Antenna", role = "SkinDark", sway = { amp = 8, speed = 1.3 } })
			end
		end,
	})

	R.register({
		id = "FaceDistortion",
		slots = GROWTH,
		grade = "Grade3",
		tags = { "deformed", "flesh" },
		params = { size = 0.4, socket = "CheekR" },
		build = function(ctx, p)
			local at, s = A.at(ctx), p.size
			ctx:blob(at, { 0, 0, -0.3 * s }, { 0.9 * s, 0.45 * s, 1.4 * s }, { 10, 0, 0 }, "SkinDark")
			ctx:blob(at, { 0.1 * s, 0.05, -0.8 * s }, { 0.6 * s, 0.35 * s, 0.8 * s }, nil, "Skin")
			ctx:blob(at, { -0.15 * s, 0.1, -1.1 * s }, { 0.35 * s, 0.25 * s, 0.4 * s }, nil, "SkinLight")
		end,
	})

	R.register({
		id = "HeadGrowth",
		slots = GROWTH,
		grade = "Grade3",
		tags = { "growth", "flesh" },
		params = { size = 0.8, socket = "Crown" },
		build = function(ctx, p)
			local at, s = A.at(ctx), p.size
			ctx:blob(at, { 0, 0.15 * s, 0 }, { 1.1 * s, 0.8 * s, 1.0 * s }, nil, "SkinLight")
			ctx:blob(at, { 0.2 * s, 0.35 * s, 0.1 * s }, { 0.6 * s, 0.5 * s, 0.55 * s }, nil, "Flesh")
			for i = 1, 3 do
				local a = i * 2.1
				ctx:capsule(at, { math.cos(a) * 0.5 * s, 0.1 * s, math.sin(a) * 0.45 * s },
					{ math.cos(a) * 0.15 * s, 0.5 * s, math.sin(a) * 0.1 * s }, 0.035, "SkinDeep")
			end
		end,
	})
end
