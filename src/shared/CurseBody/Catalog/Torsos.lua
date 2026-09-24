--!nonstrict
-- Base torsos. Built in the leaned "spine" frame (origin at the pelvis) and scaled by
-- the body's TorsoW/H/D, so hunch and mass change every torso the same way.

local A = require(script.Parent._Anatomy)

return function(R)
	local function torso(def)
		def.slots = { "Torso" }
		R.register(def)
	end

	torso({
		id = "NormalTorso",
		grade = "Grade4",
		tags = { "humanoid" },
		build = function(ctx)
			local spine = A.spine(ctx)
			ctx:with({ scale = A.torsoScale(ctx) }, function()
				ctx:blob(spine, { 0, 1.45, 0 }, { 2.1, 1.25, 1.15 }, nil, "Skin")
				ctx:blob(spine, { 0, 1.95, 0.1 }, { 1.5, 0.5, 0.9 }, nil, "SkinLight")
				ctx:blob(spine, { 0, 0.8, -0.02 }, { 1.75, 1.2, 1.0 }, nil, "Skin")
				ctx:blob(spine, { 0.45, 1.5, -0.42 }, { 0.85, 0.6, 0.35 }, { 0, 0, 5 }, "SkinLight")
				ctx:blob(spine, { -0.45, 1.5, -0.42 }, { 0.85, 0.6, 0.35 }, { 0, 0, -5 }, "SkinLight")
				ctx:blob(spine, { 0, 1.35, -0.56 }, { 0.08, 0.8, 0.1 }, nil, "SkinDark")
				ctx:blob(spine, { 0, 0.95, 0.33 }, { 1.6, 1.3, 0.55 }, nil, "Skin")
				A.torsoSockets(ctx, spine, { front = 0.6, back = 0.58, width = 1.0 })
			end)
			A.pelvisAndNeck(ctx)
		end,
	})

	torso({
		id = "MuscularTorso",
		grade = "Grade4",
		tags = { "muscle" },
		build = function(ctx)
			local spine = A.spine(ctx)
			ctx:with({ scale = A.torsoScale(ctx) }, function()
				ctx:blob(spine, { 0, 1.4, 0 }, { 2.3, 1.35, 1.25 }, nil, "Skin")
				ctx:blob(spine, { 0, 2.0, 0.15 }, { 1.8, 0.75, 1.05 }, { 8, 0, 0 }, "SkinLight")
				for _, s in ipairs({ 1, -1 }) do
					ctx:blob(spine, { 0.5 * s, 1.5, -0.45 }, { 1.05, 0.8, 0.55 }, { 0, 0, 8 * s }, "SkinLight")
					ctx:blob(spine, { 0.95 * s, 1.25, 0.1 }, { 0.6, 1.35, 0.95 }, { 0, 0, 15 * s }, "Skin")
					ctx:blob(spine, { 0.72 * s, 0.6, -0.18 }, { 0.5, 0.85, 0.65 }, { 0, 0, -8 * s }, "Skin")
					for row, y in ipairs({ 1.02, 0.74, 0.46 }) do
						ctx:blob(spine, { 0.21 * s, y, -0.5 + row * 0.02 }, { 0.36, 0.26, 0.22 }, nil, "SkinLight")
					end
				end
				ctx:blob(spine, { 0, 0.75, -0.05 }, { 1.7, 1.1, 1.0 }, nil, "Skin")
				ctx:blob(spine, { 0, 1.2, 0.42 }, { 1.9, 1.5, 0.6 }, nil, "Skin")
				ctx:blob(spine, { 0, 1.2, 0.66 }, { 0.12, 1.3, 0.1 }, nil, "SkinDark")
				A.torsoSockets(ctx, spine, { front = 0.7, back = 0.72, width = 1.15, top = 2.2 })
			end)
			A.pelvisAndNeck(ctx)
		end,
	})

	torso({
		id = "EmaciatedTorso",
		grade = "Grade4",
		tags = { "thin", "bone" },
		build = function(ctx)
			local spine = A.spine(ctx)
			ctx:with({ scale = A.torsoScale(ctx, 0.85, 1, 0.85) }, function()
				ctx:blob(spine, { 0, 1.35, 0 }, { 1.7, 1.45, 0.95 }, nil, "SkinDark")
				ctx:blob(spine, { 0, 0.55, 0.05 }, { 1.15, 0.9, 0.62 }, nil, "SkinDeep")
				for i = 1, 5 do
					local y = 1.85 - i * 0.2
					for _, s in ipairs({ 1, -1 }) do
						ctx:tube(spine, { { 0.1 * s, y, -0.5 }, { 0.62 * s, y - 0.05, -0.36 }, { 0.84 * s, y - 0.12, 0.0 },
							{ 0.6 * s, y - 0.18, 0.4 } }, { 0.07, 0.065, 0.06, 0.05 }, "SkinLight")
					end
				end
				for i = 0, 6 do
					ctx:blob(spine, { 0, 0.3 + i * 0.27, 0.46 }, { 0.2, 0.16, 0.16 }, nil, "SkinLight")
				end
				for _, s in ipairs({ 1, -1 }) do
					ctx:tube(spine, { { 0.08 * s, 1.95, -0.38 }, { 0.8 * s, 2.02, -0.1 } }, { 0.08, 0.07 }, "SkinLight")
					ctx:blob(spine, { 0.66 * s, 0.15, -0.28 }, { 0.3, 0.35, 0.25 }, nil, "SkinLight")
				end
				A.torsoSockets(ctx, spine, { front = 0.52, back = 0.5, width = 0.88, top = 2.0, bellyFront = 0.35 })
			end)
			A.pelvisAndNeck(ctx, { pelvisRole = "SkinDark" })
		end,
	})

	-- The reference creature's torso: hump, neck wraps, exposed ribbed flesh on the front.
	torso({
		id = "HunchedTorso",
		grade = "Grade3",
		tags = { "hunched", "reference" },
		params = { fleshFront = true },
		build = function(ctx, params)
			local spine = A.spine(ctx)
			local sh = ctx:m("Shoulder") / 1.3
			-- authored at the Hunched body type's mass; normalize so it scales from there
			ctx:with({ scale = A.torsoScale(ctx, 0.8, 0.95, 0.8) }, function()
				ctx:blob(spine, { 0, 1.75, 0.4 }, { 2.8, 2.6, 2.3 }, { -2, 0, 0 }, "Skin")
				ctx:blob(spine, { 0.1, 2.4, 0.35 }, { 2.2, 1.3, 1.8 }, { -6, 0, 5 }, "SkinLight")
				ctx:blob(spine, { -0.3, 2.05, 0.95 }, { 1.6, 0.3, 1.2 }, { -14, 0, 10 }, "SkinDark")
				for _, s in ipairs({ 1, -1 }) do
					ctx:blob(spine, { 1.2 * s, 1.6, -0.15 }, { 1.45 * sh, 1.5 * sh, 1.8 }, { 0, 0, 22 * s }, "Skin")
					ctx:blob(spine, { 1.25 * s, 2.0, 0.1 }, { 1.0 * sh, 0.32, 1.4 }, { -10, 0, 30 * s }, "SkinLight")
					ctx:blob(spine, { 0.72 * s, 1.75, -0.7 }, { 1.1, 0.95, 1.15 }, { -20, 0, 30 * s }, "Skin")
					ctx:blob(spine, { 0.95 * s, 0.7, 0.15 }, { 0.7, 1.5, 1.2 }, { 0, 0, 5 * s }, "Skin")
				end
				if params.fleshFront then
					ctx:blob(spine, { 0.05, 1.1, -0.35 }, { 2.35, 2.0, 1.4 }, nil, "Flesh")
					ctx:blob(spine, { 0, 0.3, -0.3 }, { 2.0, 1.1, 1.3 }, nil, "Flesh")
					for _, s in ipairs({ 1, -1 }) do
						ctx:blob(spine, { 0.7 * s, 1.45, -0.75 }, { 1.0, 1.1, 0.65 }, { 0, 0, -10 * s }, "Flesh")
						for j, y in ipairs({ 1.75, 1.48, 1.21, 0.94 }) do
							ctx:blob(spine, { 0.78 * s, y, -0.98 }, { 0.6, 0.1, 0.22 }, { 0, 12 * s, (-12 + j * 3) * s }, "FleshDark")
						end
					end
					for j, y in ipairs({ 0.45, 0.2, -0.05 }) do
						ctx:blob(spine, { 0, y, -0.93 + j * 0.03 }, { 1.45 - j * 0.12, 0.09, 0.3 }, nil, "FleshDark")
					end
				end
				A.torsoSockets(ctx, spine, { front = 1.0, back = 1.4, width = 1.3, top = 2.9, chestY = 1.2 })
			end)
			A.pelvisAndNeck(ctx)
			if params.fleshFront then
				ctx:with({ scale = Vector3.one }, function()
					ctx:blob("Torso", { 0, -1.1, -0.28 }, { 1.1, 0.7, 1.0 }, nil, "Flesh")
				end)
			end
		end,
	})

	torso({
		id = "WideTorso",
		grade = "Grade3",
		tags = { "heavy" },
		build = function(ctx)
			local spine = A.spine(ctx)
			ctx:with({ scale = A.torsoScale(ctx, 1.25, 1, 1.15) }, function()
				ctx:blob(spine, { 0, 1.35, 0 }, { 2.6, 1.55, 1.35 }, nil, "Skin")
				ctx:blob(spine, { 0, 2.0, 0.1 }, { 2.2, 0.8, 1.1 }, nil, "SkinLight")
				ctx:blob(spine, { 0, 0.65, -0.1 }, { 2.2, 1.25, 1.3 }, nil, "Skin")
				ctx:blob(spine, { 0, 0.6, -0.55 }, { 1.4, 0.8, 0.5 }, nil, "SkinLight")
				for _, s in ipairs({ 1, -1 }) do
					ctx:blob(spine, { 0.55 * s, 1.55, -0.5 }, { 1.1, 0.75, 0.5 }, nil, "SkinLight")
					ctx:blob(spine, { 1.1 * s, 1.5, 0.05 }, { 0.8, 1.3, 1.1 }, { 0, 0, 12 * s }, "Skin")
				end
				A.torsoSockets(ctx, spine, { front = 0.72, back = 0.7, width = 1.25, top = 2.2 })
			end)
			A.pelvisAndNeck(ctx)
		end,
	})

	torso({
		id = "RibbedTorso",
		grade = "Grade2",
		tags = { "bone", "hollow" },
		build = function(ctx)
			local spine = A.spine(ctx)
			ctx:with({ scale = A.torsoScale(ctx, 0.95, 1, 0.95) }, function()
				ctx:blob(spine, { 0, 1.2, 0.05 }, { 1.35, 1.6, 0.85 }, nil, "Void")
				ctx:tube(spine, { { 0, 0.1, 0.35 }, { 0, 1.0, 0.42 }, { 0, 2.0, 0.3 } }, { 0.16, 0.15, 0.14 }, "Bone")
				for i = 0, 7 do
					ctx:blob(spine, { 0, 0.2 + i * 0.25, 0.5 }, { 0.26, 0.14, 0.22 }, nil, "BoneDark")
				end
				for i = 1, 6 do
					local y = 1.9 - i * 0.22
					for _, s in ipairs({ 1, -1 }) do
						ctx:tube(spine, { { 0.08 * s, y, 0.38 }, { 0.72 * s, y - 0.04, 0.18 }, { 0.86 * s, y - 0.12, -0.25 },
							{ 0.3 * s, y - 0.22, -0.56 } }, { 0.08, 0.075, 0.07, 0.06 }, "Bone")
					end
				end
				ctx:tube(spine, { { 0, 1.85, -0.58 }, { 0, 0.95, -0.55 } }, { 0.1, 0.08 }, "Bone")
				for _, s in ipairs({ 1, -1 }) do
					ctx:blob(spine, { 0.85 * s, 1.95, 0 }, { 0.95, 0.7, 1.0 }, { 0, 0, 20 * s }, "SkinDark")
				end
				ctx:blob(spine, { 0, 0.25, 0 }, { 1.5, 0.6, 0.9 }, nil, "SkinDark")
				A.torsoSockets(ctx, spine, { front = 0.6, back = 0.58, width = 0.95 })
			end)
			A.pelvisAndNeck(ctx, { pelvisRole = "SkinDark", neckRole = "SkinDark" })
		end,
	})

	-- Special Grade: the torso stops being a torso — a swollen orb of flesh.
	torso({
		id = "OrbTorso",
		grade = "SpecialGrade",
		tags = { "abnormal" },
		build = function(ctx)
			local spine = A.spine(ctx)
			ctx:with({ scale = A.torsoScale(ctx, 0.75, 0.8, 0.75) }, function()
				ctx:blob(spine, { 0, 1.25, 0.05 }, { 2.9, 2.7, 2.6 }, nil, "Skin")
				for i = 1, 5 do
					local a = i * 72
					ctx:blob(spine, { 0, 1.25, 0.05 }, { 2.95, 0.08, 2.65 }, { a * 0.4, a, 0 }, "SkinDark")
				end
				ctx:blob(spine, { 0, 2.35, 0.1 }, { 1.6, 0.8, 1.5 }, nil, "SkinLight")
				A.torsoSockets(ctx, spine, { front = 1.25, back = 1.3, width = 1.4, top = 2.55, chestY = 1.35 })
			end)
			A.pelvisAndNeck(ctx)
		end,
	})
end
