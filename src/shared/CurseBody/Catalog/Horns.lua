--!nonstrict
--[[
	Horn / head-growth system. One procedural builder sweeps a tapered, ridged tube along
	a bending, optionally spiralling path out of a skull socket; every registered horn is
	a parameter set, and horn SETS place several horns on skull sockets.

	params
	  length thickness taper   size and tip radius (fraction of base)
	  curve                    total bend in degrees
	  curveDir {x, z}          initial bend direction in the socket plane (x = outward, z = back)
	  spiral                   degrees the bend direction twists around the horn (ram curls)
	  tilt {rx, rz}            initial lean of the horn out of the socket
	  segments                 smoothness
	  broken                   0..1 fraction snapped off (jagged end)
	  branches                 antler tines
	  ridges                   growth rings
	  role rootRole tipRole    palette roles (root = skin the horn erupts from)
	  mesh                     optional MeshId: use custom art instead of the procedural tube
	Every horn starts with a root blob in the SKIN role sunk into the socket, so it grows
	out of the head rather than sitting on it like an accessory.
]]

local A = require(script.Parent._Anatomy)

local function norm(v)
	local m = math.sqrt(v[1] ^ 2 + v[2] ^ 2 + v[3] ^ 2)
	return m > 0 and { v[1] / m, v[2] / m, v[3] / m } or { 0, 1, 0 }
end
local function cross(a, b)
	return { a[2] * b[3] - a[3] * b[2], a[3] * b[1] - a[1] * b[3], a[1] * b[2] - a[2] * b[1] }
end
local function sub(a, b)
	return { a[1] - b[1], a[2] - b[2], a[3] - b[3] }
end
local function dot(a, b)
	return a[1] * b[1] + a[2] * b[2] + a[3] * b[3]
end
-- rotate v around unit axis k by angle a (Rodrigues)
local function rotate(v, k, a)
	local c, s = math.cos(a), math.sin(a)
	local kxv, kdv = cross(k, v), dot(k, v)
	return {
		v[1] * c + kxv[1] * s + k[1] * kdv * (1 - c),
		v[2] * c + kxv[2] * s + k[2] * kdv * (1 - c),
		v[3] * c + kxv[3] * s + k[3] * kdv * (1 - c),
	}
end

-- sweep a horn path: returns points, radii, final direction
local function sweep(start, dir, bend, length, r0, taper, curve, spiral, n)
	local pts, radii = { start }, { r0 }
	local step = length / n
	local pos = start
	local a, sp = math.rad(curve / n), math.rad(spiral / n)
	for i = 1, n do
		-- bend: rotate dir toward the bend vector around their common normal
		local axis = cross(dir, bend)
		if math.sqrt(dot(axis, axis)) > 1e-5 then
			axis = norm(axis)
			dir = norm(rotate(dir, axis, a))
			bend = norm(rotate(bend, axis, a))
		end
		if sp ~= 0 then
			bend = norm(rotate(bend, dir, sp))
		end
		pos = A.add(pos, dir, step)
		table.insert(pts, pos)
		table.insert(radii, r0 * (1 + (taper - 1) * (i / n) ^ 0.8))
	end
	return pts, radii, dir
end

local function buildHorn(ctx, p, at)
	at = at or A.at(ctx)
	local r0, L = p.thickness, p.length
	local tilt = p.tilt or { 0, 0 }
	ctx:blob(at, { 0, -0.04, 0 }, { r0 * 3.4, r0 * 1.8, r0 * 3.4 }, nil, p.rootRole or "Skin")
	if p.mesh then
		ctx:mesh(at, { 0, L / 2, 0 }, { r0 * 2, L, r0 * 2 }, { tilt[1], 0, tilt[2] }, p.mesh, p.role or "Bone")
		return
	end
	local dir = norm(A.rot({ 0, 1, 0 }, tilt[1], tilt[2]))
	local cd = p.curveDir or { 0, 1 }
	local bend = norm({ cd[1], 0, cd[2] })
	-- keep bend perpendicular to the initial direction
	local d = dot(bend, dir)
	bend = norm({ bend[1] - dir[1] * d, bend[2] - dir[2] * d, bend[3] - dir[3] * d })
	local n = p.segments or 6
	local pts, radii = sweep({ 0, -0.02, 0 }, dir, bend, L, r0, p.taper or 0.15, p.curve or 0, p.spiral or 0, n)

	local keep = n + 1
	if (p.broken or 0) > 0 then
		keep = math.max(2, math.floor((n + 1) * (1 - p.broken)))
	end
	local mainPts, mainRadii = {}, {}
	for i = 1, keep do
		mainPts[i], mainRadii[i] = pts[i], radii[i]
	end
	ctx:tube(at, mainPts, mainRadii, function(i, total)
		if p.tipRole and i == total and keep == n + 1 then
			return p.tipRole
		end
		return i <= math.max(1, math.floor(total * 0.25)) and (p.baseRole or "BoneDark") or (p.role or "Bone")
	end)
	if p.ridges then
		for i = 2, keep - 1, 2 do
			local a, b = pts[i], pts[i + 1] or pts[i]
			local mid = A.lerp(a, b, 0.05)
			ctx:capsule(at, mid, A.lerp(a, b, 0.2), mainRadii[i] * 1.12, p.baseRole or "BoneDark", { stretch = 1 })
		end
	end
	if keep < n + 1 then
		-- snapped end: a few jagged shards
		local tip, r = pts[keep], radii[keep]
		for k = 1, 3 do
			local off = { math.cos(k * 2.1) * r * 0.5, 0, math.sin(k * 2.1) * r * 0.5 }
			ctx:capsule(at, A.add(tip, off), A.add(A.add(tip, off), { 0, r * (0.6 + k * 0.25), 0 }), r * 0.35, "BoneDark")
		end
	end
	for t = 1, (p.branches or 0) do
		local idx = math.clamp(math.floor(n * (0.3 + 0.5 * t / (p.branches + 0.5))), 2, keep)
		local origin = pts[idx]
		local bdir = norm(A.add(norm(sub(pts[idx], pts[idx - 1])), { 0, 0, (t % 2 == 0) and 0.9 or -0.9 }))
		local bpts, bradii = sweep(origin, bdir, { 0, 1, 0 }, L * 0.38, radii[idx] * 0.7, 0.2, 25, 0, 3)
		ctx:tube(at, bpts, bradii, p.role or "Bone")
	end
end

return function(R)
	R.register({
		id = "Horn",
		slots = { "Horns", "HeadGrowths", "Disfigurements" },
		grade = "Grade4",
		tags = { "horn", "bone" },
		params = {
			socket = "Crown", length = 0.9, thickness = 0.12, taper = 0.12, curve = 40, curveDir = { 0, 1 },
			spiral = 0, tilt = { 0, 0 }, segments = 6, broken = 0, branches = 0, ridges = true,
			role = "Bone", baseRole = "BoneDark", rootRole = "Skin",
		},
		build = function(ctx, p)
			buildHorn(ctx, p)
		end,
	})

	local function horn(id, grade, params)
		R.variant("Horn", { id = id, grade = grade, params = params, slots = { "Horns", "HeadGrowths", "Disfigurements" } })
	end
	horn("StubHorn", "Grade4", { length = 0.35, thickness = 0.11, curve = 10, segments = 3, taper = 0.3 })
	horn("StraightHorn", "Grade4", { length = 1.0, thickness = 0.11, curve = 6, segments = 5 })
	horn("CurvedHorn", "Grade3", { length = 1.3, thickness = 0.13, curve = 85, curveDir = { 1, 0.6 }, tilt = { 0, -10 }, segments = 8 })
	horn("BackHorn", "Grade3", { length = 1.4, thickness = 0.13, curve = 70, curveDir = { 0, 1 }, tilt = { 35, 0 }, segments = 8 })
	horn("ForwardHorn", "Grade3", { length = 1.1, thickness = 0.12, curve = 60, curveDir = { 0, -1 }, tilt = { -20, 0 } })
	horn("RamHorn", "Grade3", {
		length = 2.3, thickness = 0.17, taper = 0.25, curve = 330, curveDir = { 0.25, 1 }, spiral = 90, tilt = { 20, -15 },
		segments = 14,
	})
	horn("Antler", "Grade2", {
		length = 1.6, thickness = 0.09, taper = 0.35, curve = 35, curveDir = { 1, 0.4 }, branches = 3, ridges = false,
		role = "BoneDark", baseRole = "BoneDark", rootRole = "SkinDark", segments = 7,
	})
	horn("BrokenHorn", "Grade3", { length = 1.3, thickness = 0.14, curve = 60, curveDir = { 1, 0.5 }, broken = 0.5, segments = 8 })
	horn("MassiveHorn", "Grade2", {
		length = 2.5, thickness = 0.3, taper = 0.08, curve = 95, curveDir = { 1, 0.25 }, tilt = { 0, -15 }, segments = 11,
		tipRole = "Claw",
	})

	-- Horn sets: several horns placed on skull sockets. `count` counts against the grade cap.
	local function hornSet(id, grade, count, placements, tags)
		R.register({
			id = id,
			slots = { "Horns" },
			grade = grade,
			tags = tags or { "horn", "set" },
			count = count,
			params = { socket = "Crown" },
			build = function(ctx, p, entry)
				local scale = { ctx.scale.X, ctx.scale.Y, ctx.scale.Z }
				local list = type(placements) == "function" and placements(p) or placements
				for _, pl in ipairs(list) do
					local params = table.clone(pl.params or {})
					for k, v in pairs(entry.params or {}) do
						params[k] = v
					end
					ctx.state.buildEntry(ctx, {
						id = pl.id, socket = pl.socket, pos = pl.pos, rot = pl.rot, params = params, scale = scale,
					})
				end
			end,
		})
	end

	hornSet("HornPair", "Grade4", 2, {
		{ id = "StraightHorn", socket = "TopR", params = { length = 0.8, curve = 25, curveDir = { 1, 0.3 } } },
		{ id = "StraightHorn", socket = "TopL", params = { length = 0.8, curve = 25, curveDir = { 1, 0.3 } } },
	})
	hornSet("ThreeHorns", "Grade3", 3, {
		{ id = "CurvedHorn", socket = "TopR", params = { length = 1.0 } },
		{ id = "CurvedHorn", socket = "TopL", params = { length = 1.0 } },
		{ id = "StraightHorn", socket = "Brow", params = { length = 0.7, curve = 30, curveDir = { 0, 1 } } },
	})
	hornSet("RamHorns", "Grade3", 2, {
		{ id = "RamHorn", socket = "TopR" },
		{ id = "RamHorn", socket = "TopL" },
	})
	hornSet("DemonHorns", "Grade3", 2, {
		{ id = "BackHorn", socket = "TopR", params = { tipRole = "Claw", curveDir = { 0.35, 1 } } },
		{ id = "BackHorn", socket = "TopL", params = { tipRole = "Claw", curveDir = { 0.35, 1 } } },
	})
	hornSet("UnicornHorn", "Grade3", 1, {
		{ id = "StraightHorn", socket = "Brow", params = { length = 1.4, thickness = 0.12, curve = 12, curveDir = { 0, 1 } } },
	})
	hornSet("AsymmetricHorns", "Grade3", 2, {
		{ id = "CurvedHorn", socket = "TopR", params = { length = 1.9, thickness = 0.17 } },
		{ id = "BrokenHorn", socket = "TopL", params = { length = 1.0, broken = 0.65 } },
	})
	hornSet("Antlers", "Grade2", 2, {
		{ id = "Antler", socket = "TopR" },
		{ id = "Antler", socket = "TopL" },
	})
	R.register({
		id = "CrownOfHorns",
		slots = { "Horns" },
		grade = "Grade2",
		tags = { "horn", "set" },
		params = { socket = "Crown", count = 6, radius = 0.42, length = 0.6 },
		count = function(p)
			return p.count
		end,
		build = function(ctx, p)
			local at = A.at(ctx)
			for i = 1, p.count do
				local a = (i - 0.5) / p.count * math.pi * 2
				local x, z = math.cos(a) * p.radius, math.sin(a) * p.radius
				local anchor = ctx:sub(at, { x, -0.05, z }, { math.deg(math.sin(a)) * 0.45, 0, -math.deg(math.cos(a)) * 0.45 })
				buildHorn(ctx, {
					length = p.length * (0.8 + 0.4 * ((i % 3) / 2)), thickness = 0.08, taper = 0.1, curve = 10,
					curveDir = { x, z }, segments = 4, ridges = false, role = "Bone", baseRole = "BoneDark", rootRole = "Skin",
				}, anchor)
			end
		end,
	})
end
