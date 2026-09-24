--!nonstrict
-- Base heads. Each defines the head sockets on its own skull/face (so horns, eyes and
-- mouths land on the real surface) and default features used when the appearance
-- leaves Eyes / Mouths / HeadGrowths unset.

local A = require(script.Parent._Anatomy)

local function facing(yaw)
	return { -90, 0, -(yaw or 0) } -- front, turned `yaw` degrees toward the right
end

--[[
	Define the standard head sockets from a compact table (right side; left mirrored).
	s = { crown=, top=, topTilt=, brow=, face=, eye=, eyeYaw=, mouth=, jaw=, cheek=, temple=, ear=, back= }
]]
local function headSockets(ctx, head, s)
	ctx:defineSocket("Crown", head, s.crown, s.crownRot or A.UP)
	ctx:defineSocketPair("Top", head, s.top, { s.topTiltX or 0, 0, -(s.topTilt or 30) })
	ctx:defineSocket("Brow", head, s.brow, s.browRot or { -60, 0, 0 })
	ctx:defineSocket("Face", head, s.face, A.FRONT)
	ctx:defineSocketPair("Eye", head, s.eye, facing(s.eyeYaw or 0))
	ctx:defineSocket("Mouth", head, s.mouth, A.FRONT)
	ctx:defineSocket("Jaw", head, s.jaw, A.DOWN)
	ctx:defineSocketPair("Cheek", head, s.cheek, facing(45))
	ctx:defineSocketPair("Temple", head, s.temple, A.RIGHT)
	ctx:defineSocketPair("Ear", head, s.ear, A.RIGHT)
	ctx:defineSocket("BackOfHead", head, s.back, A.BACK)
end

local function withHead(ctx, entry, fn)
	local part = entry.part or ctx:basePart("Head")
	local head = ctx:anchor(part)
	ctx:with({ scale = ctx.scale * ctx:m("Head") }, fn, head)
end

local PAIR_EYES = { { id = "Eye", socket = "EyeR" }, { id = "Eye", socket = "EyeL" } }

return function(R)
	local function headDef(def)
		def.slots = { "Head" }
		local build = def.build
		def.build = function(ctx, params, entry)
			withHead(ctx, entry, function(head)
				build(ctx, params, head)
			end)
		end
		R.register(def)
	end

	headDef({
		id = "HumanCurseHead",
		grade = "Grade4",
		tags = { "humanoid" },
		defaults = { Eyes = PAIR_EYES, Mouths = { { id = "SlitMouth", socket = "Mouth" } } },
		build = function(ctx, params, head)
			ctx:blob(head, { 0, 0.15, 0.05 }, { 1.25, 1.35, 1.35 }, nil, "Skin")
			ctx:blob(head, { 0, 0.25, -0.5 }, { 1.05, 0.25, 0.4 }, { -10, 0, 0 }, "SkinLight")
			ctx:blob(head, { 0, -0.38, -0.2 }, { 0.95, 0.55, 0.95 }, nil, "Skin")
			ctx:blob(head, { 0, -0.55, -0.5 }, { 0.4, 0.25, 0.25 }, nil, "SkinLight")
			ctx:blob(head, { 0, 0.02, -0.66 }, { 0.18, 0.3, 0.2 }, { -15, 0, 0 }, "SkinLight")
			for _, s in ipairs({ 1, -1 }) do
				ctx:blob(head, { 0.38 * s, -0.02, -0.45 }, { 0.35, 0.25, 0.3 }, nil, "SkinLight")
				ctx:blob(head, { 0.64 * s, 0.02, 0.05 }, { 0.12, 0.35, 0.25 }, nil, "SkinDark")
			end
			-- a curse is never quite symmetrical
			local lx = ctx:rand(-0.4, 0.4)
			ctx:blob(head, { lx, 0.62, ctx:rand(-0.2, 0.3) }, { 0.45, 0.25, 0.4 }, nil, "SkinLight")
			headSockets(ctx, head, {
				crown = { 0, 0.82, 0.05 }, top = { 0.35, 0.7, 0 }, brow = { 0, 0.4, -0.58 }, face = { 0, 0.05, -0.68 },
				eye = { 0.25, 0.12, -0.58 }, mouth = { 0, -0.3, -0.6 }, jaw = { 0, -0.62, -0.25 },
				cheek = { 0.5, -0.12, -0.35 }, temple = { 0.6, 0.3, -0.05 }, ear = { 0.66, 0, 0.05 },
				back = { 0, 0.25, 0.68 },
			})
		end,
	})

	headDef({
		id = "AnimalHead",
		grade = "Grade4",
		tags = { "beast" },
		defaults = {
			Eyes = { { id = "Eye", socket = "EyeR" }, { id = "Eye", socket = "EyeL" } },
			Mouths = { { id = "GrinMouth", socket = "Mouth", scale = 0.8 } },
		},
		build = function(ctx, params, head)
			ctx:blob(head, { 0, 0.2, 0.2 }, { 1.1, 1.05, 1.2 }, nil, "Skin")
			ctx:capsule(head, { 0, -0.02, -0.15 }, { 0, -0.2, -1.05 }, { 0.38, 0.3 }, "Skin")
			ctx:capsule(head, { 0, -0.3, -0.2 }, { 0, -0.42, -0.95 }, { 0.3, 0.22 }, "SkinDark")
			ctx:blob(head, { 0, -0.1, -1.12 }, { 0.36, 0.24, 0.22 }, nil, "SkinDeep")
			ctx:blob(head, { 0, 0.22, -0.45 }, { 0.8, 0.3, 0.6 }, { -20, 0, 0 }, "SkinLight")
			for _, s in ipairs({ 1, -1 }) do
				ctx:tube(head, { { 0.33 * s, 0.6, 0.25 }, { 0.45 * s, 0.9, 0.32 }, { 0.52 * s, 1.15, 0.42 } },
					{ 0.16, 0.1, 0.03 }, "SkinDark")
			end
			headSockets(ctx, head, {
				crown = { 0, 0.75, 0.2 }, top = { 0.3, 0.65, 0.1 }, topTilt = 25, brow = { 0, 0.45, -0.3 },
				face = { 0, 0.05, -0.9 }, eye = { 0.33, 0.28, -0.32 }, eyeYaw = 30, mouth = { 0, -0.32, -0.95 },
				jaw = { 0, -0.55, -0.6 }, cheek = { 0.4, -0.05, -0.4 }, temple = { 0.55, 0.3, 0.15 },
				ear = { 0.55, 0.35, 0.3 }, back = { 0, 0.3, 0.8 },
			})
		end,
	})

	headDef({
		id = "OversizedHead",
		grade = "Grade3",
		tags = { "abnormal" },
		defaults = { Eyes = PAIR_EYES, Mouths = { { id = "SlitMouth", socket = "Mouth", scale = 0.7 } } },
		build = function(ctx, params, head)
			ctx:blob(head, { 0, 0.6, 0.15 }, { 1.95, 1.95, 2.05 }, nil, "Skin")
			for i = 1, 4 do
				local a = i * 1.7
				ctx:blob(head, { math.cos(a) * 0.6, 1.0 + math.sin(a) * 0.3, 0.2 + math.sin(a * 2) * 0.4 },
					{ 0.8, 0.6, 0.8 }, nil, "SkinLight")
			end
			ctx:blob(head, { 0, -0.25, -0.62 }, { 0.9, 0.7, 0.6 }, nil, "Skin")
			ctx:blob(head, { 0, -0.5, -0.45 }, { 0.6, 0.4, 0.5 }, nil, "SkinDark")
			headSockets(ctx, head, {
				crown = { 0, 1.55, 0.15 }, top = { 0.6, 1.3, 0.1 }, topTilt = 35, brow = { 0, 0.3, -0.85 },
				face = { 0, -0.1, -0.9 }, eye = { 0.22, 0.02, -0.88 }, mouth = { 0, -0.4, -0.88 },
				jaw = { 0, -0.7, -0.4 }, cheek = { 0.45, -0.2, -0.6 }, temple = { 0.95, 0.6, 0 },
				ear = { 0.98, 0.3, 0.1 }, back = { 0, 0.7, 1.15 },
			})
		end,
	})

	headDef({
		id = "SmallHead",
		grade = "Grade4",
		tags = { "abnormal" },
		defaults = { Eyes = PAIR_EYES, Mouths = { { id = "SlitMouth", socket = "Mouth", scale = 0.6 } } },
		build = function(ctx, params, head)
			ctx:blob(head, { 0, -0.05, -0.1 }, { 0.75, 0.8, 0.8 }, nil, "Skin")
			ctx:blob(head, { 0, -0.3, -0.25 }, { 0.55, 0.35, 0.55 }, nil, "SkinDark")
			headSockets(ctx, head, {
				crown = { 0, 0.33, -0.1 }, top = { 0.2, 0.28, -0.1 }, brow = { 0, 0.15, -0.42 },
				face = { 0, -0.05, -0.5 }, eye = { 0.15, 0.03, -0.46 }, mouth = { 0, -0.22, -0.46 },
				jaw = { 0, -0.45, -0.2 }, cheek = { 0.3, -0.12, -0.35 }, temple = { 0.37, 0.05, -0.1 },
				ear = { 0.38, -0.05, -0.05 }, back = { 0, 0.02, 0.3 },
			})
		end,
	})

	headDef({
		id = "FacelessHead",
		grade = "Grade4",
		tags = { "faceless" },
		defaults = { Eyes = {}, Mouths = {} },
		build = function(ctx, params, head)
			ctx:blob(head, { 0, 0.15, 0 }, { 1.2, 1.5, 1.3 }, nil, "Skin")
			ctx:blob(head, { 0, 0.02, -0.52 }, { 0.95, 0.95, 0.3 }, nil, "SkinLight")
			headSockets(ctx, head, {
				crown = { 0, 0.9, 0 }, top = { 0.33, 0.78, 0 }, brow = { 0, 0.45, -0.55 }, face = { 0, 0.05, -0.68 },
				eye = { 0.25, 0.15, -0.64 }, mouth = { 0, -0.25, -0.64 }, jaw = { 0, -0.6, -0.15 },
				cheek = { 0.45, -0.1, -0.4 }, temple = { 0.58, 0.3, 0 }, ear = { 0.6, 0.05, 0.05 },
				back = { 0, 0.3, 0.65 },
			})
		end,
	})

	-- The reference creature's head: bulbous crown, folds, speckles, hanging face tendrils.
	headDef({
		id = "OctopoidHead",
		grade = "Grade2",
		tags = { "reference", "tentacle" },
		params = { tendrils = 5 },
		defaults = {
			Eyes = {
				{ id = "Eye", socket = "EyeR", params = { size = 0.2, lid = false } },
				{ id = "Eye", socket = "EyeL", params = { size = 0.2, lid = false } },
			},
			Mouths = {},
		},
		build = function(ctx, params, head)
			ctx:blob(head, { 0, 0.40, 0.30 }, { 1.95, 1.75, 2.35 }, { 38, 0, 0 }, "Skin")
			ctx:blob(head, { 0.05, 0.85, 0.75 }, { 1.55, 1.15, 1.45 }, { 25, 0, 6 }, "SkinLight")
			ctx:blob(head, { 0, -0.10, -0.50 }, { 1.65, 1.25, 1.15 }, { -12, 0, 0 }, "Skin")
			ctx:blob(head, { 0, -0.35, -0.85 }, { 1.20, 0.80, 0.70 }, { -25, 0, 0 }, "SkinLight")
			ctx:blob(head, { 0.05, 0.30, -0.72 }, { 1.50, 0.38, 0.62 }, { -30, 0, 4 }, "Skin")
			ctx:blob(head, { 0.05, 0.50, -0.55 }, { 1.10, 0.12, 0.40 }, { -30, 0, 4 }, "SkinDark")
			ctx:blob(head, { 0.82, 0.40, 0.15 }, { 0.34, 0.30, 1.50 }, { 38, 0, -10 }, "SkinLight")
			ctx:blob(head, { 0.78, 0.00, 0.10 }, { 0.30, 0.22, 1.30 }, { 30, 0, -18 }, "SkinDark")
			ctx:blob(head, { -0.84, 0.48, 0.25 }, { 0.34, 0.32, 1.60 }, { 40, 0, 12 }, "SkinLight")
			ctx:blob(head, { -0.80, 0.05, 0.05 }, { 0.30, 0.22, 1.20 }, { 28, 0, 20 }, "SkinDark")
			ctx:blob(head, { 0, 1.15, 0.45 }, { 1.10, 0.22, 0.70 }, { 35, 0, 0 }, "SkinDark")
			for _, spot in ipairs({
				{ 0.25, 1.22, 0.05, 0.26 }, { -0.15, 1.30, 0.35, 0.3 }, { 0.5, 1.02, 0.45, 0.2 },
				{ -0.42, 1.10, -0.02, 0.18 }, { 0.05, 1.05, -0.28, 0.16 }, { 0.35, 1.32, 0.55, 0.14 },
			}) do
				ctx:blob(head, { spot[1], spot[2], spot[3] }, { spot[4], spot[4] * 0.45, spot[4] }, { 30, 0, 0 }, "Spot")
			end
			for _, s in ipairs({ 1, -1 }) do
				ctx:blob(head, { 0.70 * s, 0.05, -0.62 }, { 0.40, 0.36, 0.30 }, { 0, -50 * s, 0 }, "SkinDeep")
			end
			local n = math.max(1, params.tendrils)
			for i = 1, n do
				local t = n == 1 and 0 or (i - 1) / (n - 1) * 2 - 1
				local len = 0.75 - math.abs(t) * 0.22
				ctx:chain(head, { t * 0.42, -0.62, -0.9 }, { -8, 0, -t * 10 }, {
					{ len * 0.55, 0.15, { 0, 0, 0 } },
					{ len * 0.55, 0.11, { -4, 0, -t * 8 } },
				}, { name = "FaceTendril", sway = { amp = 5, speed = 1.1 }, role = i % 2 == 0 and "SkinLight" or "Skin" })
			end
			headSockets(ctx, head, {
				crown = { 0, 1.3, 0.3 }, crownRot = { 30, 0, 0 }, top = { 0.55, 1.1, 0.2 }, topTiltX = 20,
				brow = { 0, 0.5, -0.65 }, browRot = { -50, 0, 0 }, face = { 0, -0.1, -1.0 },
				eye = { 0.76, 0.05, -0.68 }, eyeYaw = 50, mouth = { 0, -0.55, -0.95 }, jaw = { 0, -0.8, -0.7 },
				cheek = { 0.6, -0.3, -0.6 }, temple = { 0.9, 0.4, 0.2 }, ear = { 0.9, 0.1, 0.2 },
				back = { 0, 0.9, 1.2 },
			})
		end,
	})

	headDef({
		id = "SplitJawHead",
		grade = "Grade2",
		tags = { "maw", "transformation" },
		defaults = {
			Eyes = { { id = "EyeCluster", socket = "Crown", params = { count = 4, spread = 0.35 } } },
			Mouths = {},
		},
		build = function(ctx, params, head)
			ctx:blob(head, { 0, 0.4, 0.15 }, { 1.3, 0.95, 1.35 }, nil, "Skin")
			ctx:blob(head, { 0, -0.35, -0.15 }, { 0.85, 1.25, 1.0 }, nil, "Void")
			for _, s in ipairs({ 1, -1 }) do
				ctx:blob(head, { 0.55 * s, -0.45, -0.15 }, { 0.62, 1.15, 1.15 }, { 0, 0, 28 * s }, "Skin")
				ctx:blob(head, { 0.38 * s, -0.4, -0.55 }, { 0.2, 1.0, 0.25 }, { 0, 0, 28 * s }, "SkinDeep")
				for k = 0, 5 do
					local y = 0.05 - k * 0.2
					local x = (0.3 + k * 0.1) * s
					ctx:capsule(head, { x, y, -0.55 }, { x - 0.2 * s, y - 0.06, -0.6 }, 0.05, "Teeth")
				end
			end
			for k = 0, 4 do
				ctx:capsule(head, { -0.24 + k * 0.12, 0.02, -0.55 }, { -0.24 + k * 0.12, -0.2, -0.62 }, 0.05, "Teeth")
			end
			headSockets(ctx, head, {
				crown = { 0, 0.85, 0.15 }, top = { 0.4, 0.75, 0.1 }, brow = { 0, 0.55, -0.5 }, face = { 0, 0.3, -0.6 },
				eye = { 0.3, 0.45, -0.52 }, mouth = { 0, -0.4, -0.65 }, jaw = { 0, -1.0, -0.15 },
				cheek = { 0.75, -0.2, -0.3 }, temple = { 0.65, 0.45, 0 }, ear = { 0.66, 0.3, 0.1 },
				back = { 0, 0.4, 0.8 },
			})
		end,
	})

	headDef({
		id = "ExtendedJawHead",
		grade = "Grade3",
		tags = { "jaw" },
		defaults = { Eyes = PAIR_EYES, Mouths = {} },
		build = function(ctx, params, head)
			ctx:blob(head, { 0, 0.25, 0.05 }, { 1.2, 1.1, 1.25 }, nil, "Skin")
			ctx:blob(head, { 0, -0.5, -0.4 }, { 0.65, 1.0, 0.45 }, { -15, 0, 0 }, "Void")
			ctx:capsule(head, { 0, -0.25, -0.05 }, { 0, -1.35, -0.55 }, { 0.42, 0.32 }, "Skin")
			ctx:blob(head, { 0, -1.45, -0.62 }, { 0.5, 0.3, 0.45 }, nil, "SkinLight")
			for k = 0, 5 do
				local x = -0.28 + k * 0.112
				ctx:capsule(head, { x, -0.2, -0.55 }, { x, -0.5, -0.6 }, 0.045, "Teeth")
				ctx:capsule(head, { x * 0.9, -1.2 + k % 2 * 0.05, -0.8 }, { x * 0.9, -0.85, -0.72 }, 0.045, "Teeth")
			end
			headSockets(ctx, head, {
				crown = { 0, 0.8, 0.05 }, top = { 0.35, 0.72, 0 }, brow = { 0, 0.45, -0.55 }, face = { 0, 0.15, -0.63 },
				eye = { 0.26, 0.28, -0.55 }, mouth = { 0, -0.6, -0.72 }, jaw = { 0, -1.6, -0.6 },
				cheek = { 0.5, -0.05, -0.35 }, temple = { 0.6, 0.35, 0 }, ear = { 0.62, 0.1, 0.05 },
				back = { 0, 0.3, 0.65 },
			})
		end,
	})

	headDef({
		id = "MandibleHead",
		grade = "Grade3",
		tags = { "insect" },
		defaults = {
			Eyes = { { id = "CompoundEye", socket = "EyeR" }, { id = "CompoundEye", socket = "EyeL" } },
			Mouths = { { id = "Mandibles", socket = "Mouth" } },
		},
		build = function(ctx, params, head)
			ctx:capsule(head, { 0, 0.35, 0.4 }, { 0, -0.1, -0.55 }, { 0.55, 0.5 }, "SkinDark")
			ctx:blob(head, { 0, 0.5, 0.05 }, { 1.0, 0.35, 1.15 }, { 10, 0, 0 }, "Skin")
			ctx:blob(head, { 0, 0.25, -0.62 }, { 0.5, 0.3, 0.3 }, { -30, 0, 0 }, "Skin")
			ctx:blob(head, { 0, -0.25, -0.62 }, { 0.45, 0.3, 0.35 }, nil, "SkinDeep")
			headSockets(ctx, head, {
				crown = { 0, 0.72, 0.1 }, top = { 0.3, 0.65, 0 }, brow = { 0, 0.45, -0.55 }, face = { 0, 0.1, -0.78 },
				eye = { 0.42, 0.25, -0.3 }, eyeYaw = 60, mouth = { 0, -0.35, -0.75 }, jaw = { 0, -0.5, -0.4 },
				cheek = { 0.45, -0.1, -0.45 }, temple = { 0.5, 0.35, 0.1 }, ear = { 0.5, 0.2, 0.25 },
				back = { 0, 0.35, 0.85 },
			})
		end,
	})

	headDef({
		id = "MaskedHead",
		grade = "Grade3",
		tags = { "mask", "bone" },
		defaults = {
			Eyes = {
				{ id = "Eye", socket = "EyeR", params = { size = 0.12, role = "Glow", lid = false, ring = false } },
				{ id = "Eye", socket = "EyeL", params = { size = 0.12, role = "Glow", lid = false, ring = false } },
			},
			Mouths = {},
		},
		build = function(ctx, params, head)
			ctx:blob(head, { 0, 0.15, 0.1 }, { 1.25, 1.35, 1.3 }, nil, "SkinDark")
			ctx:blob(head, { 0, 0.08, -0.55 }, { 1.2, 1.35, 0.3 }, { -5, 0, 0 }, "Bone")
			ctx:blob(head, { 0, 0.55, -0.6 }, { 1.0, 0.25, 0.25 }, { -20, 0, 0 }, "Bone")
			for _, s in ipairs({ 1, -1 }) do
				ctx:blob(head, { 0.25 * s, 0.18, -0.68 }, { 0.3, 0.18, 0.1 }, { 0, 0, -10 * s }, "Void")
			end
			ctx:blob(head, { 0, -0.3, -0.68 }, { 0.5, 0.06, 0.08 }, nil, "Void")
			ctx:capsule(head, { 0.15, 0.7, -0.58 }, { 0.05, 0.3, -0.7 }, 0.025, "BoneDark")
			ctx:capsule(head, { 0.05, 0.3, -0.7 }, { 0.18, -0.1, -0.7 }, 0.025, "BoneDark")
			headSockets(ctx, head, {
				crown = { 0, 0.85, 0.1 }, top = { 0.36, 0.72, 0.05 }, brow = { 0, 0.5, -0.65 }, face = { 0, 0.05, -0.74 },
				eye = { 0.25, 0.18, -0.66 }, mouth = { 0, -0.3, -0.7 }, jaw = { 0, -0.6, -0.2 },
				cheek = { 0.5, -0.1, -0.4 }, temple = { 0.62, 0.3, 0.05 }, ear = { 0.64, 0.05, 0.1 },
				back = { 0, 0.25, 0.72 },
			})
		end,
	})

	headDef({
		id = "AsymmetricHead",
		grade = "Grade3",
		tags = { "deformed" },
		defaults = {
			Eyes = { { id = "Eye", socket = "EyeR", scale = 0.7 }, { id = "Eye", socket = "EyeL", scale = 1.6 } },
			Mouths = { { id = "SlitMouth", socket = "Mouth", rot = { 0, 0, 14 } } },
		},
		build = function(ctx, params, head)
			ctx:blob(head, { -0.05, 0.1, 0.05 }, { 1.2, 1.3, 1.3 }, nil, "Skin")
			ctx:blob(head, { 0.45, 0.35, 0.05 }, { 0.95, 1.1, 1.05 }, { 0, 0, -10 }, "SkinLight")
			ctx:blob(head, { -0.42, -0.38, -0.32 }, { 0.5, 0.55, 0.42 }, nil, "SkinDark")
			ctx:blob(head, { 0.05, -0.42, -0.2 }, { 0.95, 0.5, 0.9 }, { 0, 0, 12 }, "Skin")
			ctx:blob(head, { 0.6, 0.75, 0.1 }, { 0.4, 0.3, 0.45 }, nil, "SkinLight")
			headSockets(ctx, head, {
				crown = { 0.15, 0.85, 0.05 }, top = { 0.4, 0.8, 0 }, brow = { 0, 0.35, -0.58 }, face = { 0, 0, -0.66 },
				eye = { 0.3, 0.18, -0.6 }, mouth = { -0.05, -0.32, -0.6 }, jaw = { 0, -0.62, -0.2 },
				cheek = { 0.55, -0.1, -0.4 }, temple = { 0.85, 0.35, 0 }, ear = { 0.9, 0.1, 0.05 },
				back = { 0, 0.3, 0.68 },
			})
		end,
	})

	headDef({
		id = "SkullHead",
		grade = "Grade2",
		tags = { "bone" },
		defaults = {
			Eyes = {
				{ id = "Eye", socket = "EyeR", params = { size = 0.09, role = "Glow", lid = false, ring = false } },
				{ id = "Eye", socket = "EyeL", params = { size = 0.09, role = "Glow", lid = false, ring = false } },
			},
			Mouths = {},
		},
		build = function(ctx, params, head)
			ctx:blob(head, { 0, 0.2, 0.05 }, { 1.15, 1.2, 1.25 }, nil, "Bone")
			ctx:blob(head, { 0, -0.1, -0.35 }, { 0.95, 0.7, 0.7 }, nil, "Bone")
			for _, s in ipairs({ 1, -1 }) do
				ctx:blob(head, { 0.25 * s, 0.12, -0.55 }, { 0.32, 0.3, 0.2 }, nil, "Void")
				ctx:blob(head, { 0.42 * s, -0.12, -0.38 }, { 0.3, 0.2, 0.35 }, nil, "BoneDark")
			end
			ctx:blob(head, { 0, -0.08, -0.66 }, { 0.14, 0.2, 0.1 }, nil, "Void")
			ctx:blob(head, { 0, -0.52, -0.18 }, { 0.85, 0.32, 0.85 }, nil, "BoneDark")
			for k = 0, 7 do
				local x = -0.3 + k * 0.086
				ctx:blob(head, { x, -0.34, -0.6 + math.abs(x) * 0.25 }, { 0.07, 0.16, 0.07 }, nil, "Teeth")
				ctx:blob(head, { x * 0.95, -0.46, -0.56 + math.abs(x) * 0.25 }, { 0.07, 0.14, 0.07 }, nil, "Teeth")
			end
			headSockets(ctx, head, {
				crown = { 0, 0.8, 0.05 }, top = { 0.35, 0.68, 0 }, brow = { 0, 0.4, -0.55 }, face = { 0, 0.05, -0.7 },
				eye = { 0.25, 0.12, -0.54 }, mouth = { 0, -0.4, -0.64 }, jaw = { 0, -0.68, -0.2 },
				cheek = { 0.48, -0.12, -0.35 }, temple = { 0.57, 0.3, 0 }, ear = { 0.58, 0.05, 0.05 },
				back = { 0, 0.25, 0.66 },
			})
		end,
	})

	-- Special Grade: no head at all. Its face lives on the torso.
	headDef({
		id = "Headless",
		grade = "SpecialGrade",
		tags = { "abnormal" },
		defaults = {
			Eyes = { { id = "EyeCluster", socket = "Chest", params = { count = 6, spread = 0.55 } } },
			Mouths = { { id = "Maw", socket = "Belly" } },
		},
		build = function(ctx, params, head)
			ctx:blob(head, { 0, -0.45, 0 }, { 0.85, 0.35, 0.85 }, nil, "SkinDeep")
			ctx:blob(head, { 0, -0.5, 0 }, { 1.0, 0.25, 1.0 }, nil, "SkinDark")
			headSockets(ctx, head, {
				crown = { 0, -0.3, 0 }, top = { 0.3, -0.35, 0 }, brow = { 0, -0.35, -0.35 }, face = { 0, -0.4, -0.45 },
				eye = { 0.2, -0.35, -0.4 }, mouth = { 0, -0.45, -0.45 }, jaw = { 0, -0.55, 0 },
				cheek = { 0.35, -0.4, -0.3 }, temple = { 0.45, -0.4, 0 }, ear = { 0.45, -0.45, 0 },
				back = { 0, -0.4, 0.45 },
			})
		end,
	})
end
