--!nonstrict
--[[
	Composite components built from library meshes, plus proportion mutations.
	  • horn sets / wing pairs / tendril clusters place several mesh components on sockets
	  • ChestCavity opens the torso (its sculpted "Open" variant: the cavity is carved INTO
	    the torso mesh, not stuck on top)
	  • mutators change the body before anything builds (swollen hand, elongated arm …)
]]

local function sideOf(entry)
	if entry.side == "Left" or entry.side == -1 then
		return "Left"
	elseif entry.side == "Right" or entry.side == 1 then
		return "Right"
	end
	return string.match(entry.socket or "", "L$") and "Left" or "Right"
end

return function(R)
	local function set(id, slot, grade, count, placements, tags)
		R.register({
			id = id,
			slots = { slot },
			grade = grade,
			tags = tags or { "set" },
			count = count,
			params = { socket = "Crown" },
			build = function(ctx, _, entry)
				local scale = { ctx.scale.X, ctx.scale.Y, ctx.scale.Z }
				for _, pl in ipairs(placements) do
					ctx.state.buildEntry(ctx, {
						id = pl.id, socket = pl.socket, pos = pl.pos, rot = pl.rot, scale = pl.scale and { pl.scale * scale[1], pl.scale * scale[2], pl.scale * scale[3] } or scale,
						params = entry.params,
					})
				end
			end,
		})
	end

	-- horns grow from skull sockets; left ones use the mirrored meshes automatically
	set("HornPair", "Horns", "Grade4", 2, { { id = "StraightHorn", socket = "TopR", scale = 0.8 }, { id = "StraightHorn", socket = "TopL", scale = 0.8 } }, { "horn", "set" })
	set("CurvedHorns", "Horns", "Grade3", 2, { { id = "CurvedHorn", socket = "TopR" }, { id = "CurvedHorn", socket = "TopL" } }, { "horn", "set" })
	set("RamHorns", "Horns", "Grade3", 2, { { id = "RamHorn", socket = "TopR" }, { id = "RamHorn", socket = "TopL" } }, { "horn", "set" })
	set("DemonHorns", "Horns", "Grade3", 2, { { id = "BackHorn", socket = "TopR" }, { id = "BackHorn", socket = "TopL" } }, { "horn", "set" })
	set("ThreeHorns", "Horns", "Grade3", 3, {
		{ id = "CurvedHorn", socket = "TopR", scale = 0.8 }, { id = "CurvedHorn", socket = "TopL", scale = 0.8 },
		{ id = "StraightHorn", socket = "Brow", scale = 0.7 },
	}, { "horn", "set" })
	set("UnicornHorn", "Horns", "Grade3", 1, { { id = "StraightHorn", socket = "Brow", scale = 1.3 } }, { "horn", "set" })
	set("AsymmetricHorns", "Horns", "Grade3", 2, { { id = "CurvedHorn", socket = "TopR", scale = 1.4 }, { id = "BrokenHorn", socket = "TopL" } }, { "horn", "set" })
	set("Antlers", "Horns", "Grade2", 2, { { id = "Antler", socket = "TopR" }, { id = "Antler", socket = "TopL" } }, { "horn", "set" })
	set("MassiveHorns", "Horns", "Grade2", 2, { { id = "MassiveHorn", socket = "TopR" }, { id = "MassiveHorn", socket = "TopL" } }, { "horn", "set" })
	R.register({
		id = "CrownOfHorns",
		slots = { "Horns" },
		grade = "Grade2",
		tags = { "horn", "set" },
		count = 6,
		params = { socket = "Crown" },
		build = function(ctx)
			local scale = { ctx.scale.X * 0.55, ctx.scale.Y * 0.55, ctx.scale.Z * 0.55 }
			for i = 1, 6 do
				local a = (i - 0.5) / 6 * math.pi * 2
				ctx.state.buildEntry(ctx, {
					id = "StraightHorn", socket = "Crown", scale = scale,
					pos = { math.cos(a) * 0.35, -0.05, math.sin(a) * 0.35 },
					rot = { math.deg(math.sin(a)) * 0.5, 0, -math.deg(math.cos(a)) * 0.5 },
				})
			end
		end,
	})

	set("Wings", "Back", "Grade2", 2, { { id = "Wing", socket = "BackR" }, { id = "Wing", socket = "BackL" } }, { "wing", "set" })
	set("BoneWings", "Back", "Grade1", 2, { { id = "BoneWing", socket = "BackR" }, { id = "BoneWing", socket = "BackL" } }, { "wing", "set" })
	set("Tendrils", "Back", "Grade2", 2, {
		{ id = "Tendril", socket = "UpperBack", pos = { 0.35, 0, 0 }, rot = { 0, 20, -25 } },
		{ id = "Tendril", socket = "UpperBack", pos = { -0.35, 0, 0 }, rot = { 0, -20, 25 } },
		{ id = "Tendril", socket = "UpperBack", pos = { 0.15, 0, -0.35 }, rot = { 10, 60, -10 }, scale = 0.8 },
		{ id = "Tendril", socket = "UpperBack", pos = { -0.15, 0, -0.35 }, rot = { 10, -60, 10 }, scale = 0.8 },
	}, { "tendril", "set" })
	set("BackEyes", "Back", "Grade2", 2, {
		{ id = "EyeCluster", socket = "BackR" }, { id = "EyeCluster", socket = "BackL" }, { id = "Eye", socket = "Back", scale = 1.4 },
	}, { "eye", "set" })

	-- the torso opens: its sculpted Open variant (cavity carved into the mesh)
	R.register({
		id = "ChestCavity",
		slots = { "TorsoGrowths" },
		grade = "Grade3",
		tags = { "void" },
		count = 1,
		mutate = function(body)
			body.flags.OpenChest = true
		end,
	})

	local function mutator(id, grade, socket, changes)
		R.register({
			id = id,
			slots = { "Disfigurements" },
			grade = grade,
			tags = { "mutation" },
			params = { socket = socket },
			mutate = function(body, _, entry)
				local side = body.side[sideOf(entry)]
				for key, mul in pairs(changes) do
					side[key] = (side[key] or 1) * mul
				end
			end,
		})
	end
	mutator("SwollenHand", "Grade3", "Hand_R", { Hand = 1.6 })
	mutator("ElongatedArm", "Grade3", "Shoulder_R", { ArmLength = 1.35 })
	mutator("ShrunkenArm", "Grade3", "UpperArm_R", { ArmThick = 0.6, ArmLength = 0.8, Hand = 0.7 })
	mutator("EnlargedMuscle", "Grade3", "UpperArm_R", { ArmThick = 1.35 })
	mutator("AsymmetricShoulder", "Grade3", "ShoulderR", { Shoulder = 1.7, ArmThick = 1.15 })
end
