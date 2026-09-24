--!nonstrict
-- Shared anatomy helpers for catalog builders (not auto-registered: name starts with "_").

local A = {}

A.FRONT = { -90, 0, 0 }
A.BACK = { 90, 0, 0 }
A.RIGHT = { 0, 0, -90 }
A.UP = { 0, 0, 0 }
A.DOWN = { 180, 0, 0 }

-- torso "spine" anchor: origin at the pelvis, leaned forward by the body's hunch
function A.spine(ctx)
	return ctx:anchor("Torso", ctx.layout.spine)
end

function A.torsoScale(ctx, w, h, d)
	return Vector3.new(ctx:m("TorsoW") * (w or 1), ctx:m("TorsoH") * (h or 1), ctx:m("TorsoD") * (d or 1))
end

--[[
	Define the torso sockets on a torso's actual surface (spine space, current scale).
	s.front / s.back = surface depth, s.width = flank x, s.top = shoulder-top y
]]
function A.torsoSockets(ctx, spine, s)
	local front, back, width, top = s.front or 0.6, s.back or 0.6, s.width or 1.0, s.top or 2.05
	ctx:defineSocket("Chest", spine, { 0, s.chestY or 1.45, -front }, A.FRONT)
	ctx:defineSocketPair("Chest", spine, { 0.5 * width, 1.5, -front * 0.92 }, { -90, 0, 0 })
	ctx:defineSocket("Belly", spine, { 0, s.bellyY or 0.7, -(s.bellyFront or front * 0.95) }, A.FRONT)
	ctx:defineSocketPair("ChestLow", spine, { 0.62 * width, 0.95, -front * 0.8 }, { -90, 0, 0 })
	ctx:defineSocket("UpperBack", spine, { 0, 1.6, back }, A.BACK)
	ctx:defineSocket("Back", spine, { 0, 1.1, back * 0.95 }, A.BACK)
	ctx:defineSocketPair("Back", spine, { 0.55 * width, 1.45, back * 0.9 }, A.BACK)
	ctx:defineSocket("LowerBack", spine, { 0, 0.45, back * 0.85 }, A.BACK)
	ctx:defineSocketPair("Flank", spine, { width, 1.0, 0 }, A.RIGHT)
	ctx:defineSocketPair("Shoulder", spine, { 0.8 * width, top, 0 }, A.UP)
	ctx:defineSocket("Neck", spine, { 0, top - 0.05, 0.1 }, A.UP)
end

-- pelvis + neck + tail root/hip sockets (on the Torso itself; they do not lean)
function A.pelvisAndNeck(ctx, opts)
	opts = opts or {}
	local W, D = ctx:m("TorsoW"), ctx:m("TorsoD")
	local neck = ctx.layout.neck
	local nm = ctx:m("Neck")
	ctx:with({ scale = Vector3.one }, function()
		ctx:blob("Torso", { 0, -0.72, 0.02 }, { 1.95 * W, 0.9, 1.15 * D }, { 6, 0, 0 }, opts.pelvisRole or "Skin")
		ctx:blob("Torso", { neck.X, neck.Y - 0.1, neck.Z + 0.12 }, { 0.95 * nm, 1.0, 0.9 * nm }, { -10, 0, 0 },
			opts.neckRole or "Skin")
		ctx:defineSocket("TailRoot", "Torso", { 0, -0.85, 0.5 * D }, A.BACK)
		ctx:defineSocketPair("Hip", "Torso", { 0.95 * W, -0.8, 0 }, A.RIGHT)
	end)
end

-- side of an entry: explicit entry.side, else from its socket name (…R / …_R), else Right
function A.sideOf(entry)
	if entry.side == "Left" or entry.side == -1 then
		return "Left"
	elseif entry.side == "Right" or entry.side == 1 then
		return "Right"
	end
	local socket = entry.socket or ""
	if string.match(socket, "L$") then
		return "Left"
	end
	return "Right"
end

-- evenly spread points on a disc (socket space, +Y out of the surface), seeded
function A.scatter(ctx, count, radius)
	local out = {}
	for i = 1, count do
		local a = i * 2.39996 + ctx:rand(-0.3, 0.3)
		local r = radius * math.sqrt((i - 0.5) / count)
		table.insert(out, { math.cos(a) * r, 0, math.sin(a) * r })
	end
	return out
end

-- rotate a {x,y,z} vector about the X then Z axes (degrees)
function A.rot(v, rx, rz)
	local x, y, z = v[1], v[2], v[3]
	local a = math.rad(rx or 0)
	y, z = y * math.cos(a) - z * math.sin(a), y * math.sin(a) + z * math.cos(a)
	local b = math.rad(rz or 0)
	x, y = x * math.cos(b) - y * math.sin(b), x * math.sin(b) + y * math.cos(b)
	return { x, y, z }
end

function A.add(a, b, k)
	k = k or 1
	return { a[1] + b[1] * k, a[2] + b[2] * k, a[3] + b[3] * k }
end

function A.lerp(a, b, t)
	return { a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t }
end

-- the anchor a multi-slot entry was placed at (socket + offset); falls back to a socket
function A.at(ctx, fallbackSocket)
	return ctx.at or ctx:socket(fallbackSocket or "Chest")
end

return A
