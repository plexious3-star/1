--!nonstrict
--[[
	Arms, hands, legs, feet. Authored for the RIGHT side in the limb part's own frame
	(R6 limb: 1x2x1, top = joint end at y=+1, +X = outward for the right side); the
	builder mirrors them for the left. The same components build extra limbs: they
	receive entry.part (the extra limb part) and socket suffix E1/X1…

	Arms define Hand_<s> (and Elbow_, Forearm_, UpperArm_, Shoulder_); hands only build
	where an arm defined that socket. Legs define Foot_<s>; feet likewise.
]]

local A = require(script.Parent._Anatomy)

local function limbPart(ctx, entry, kind)
	return ctx:anchor(entry.part or ctx:basePart(ctx.sideName .. " " .. kind))
end

local function hasOwnSocket(ctx, base)
	return ctx.state.sockets[ctx:sided(base)] ~= nil
end

local function handY(ctx)
	return -1 - (ctx:m("ArmLength") - 1) * 2.2
end

local function armSockets(ctx, arm, shoulder, elbow, wrist, t, withHand)
	ctx:defineSocket(ctx:sided("Shoulder"), arm, A.add(shoulder, { 0, 0.15, 0 }), A.UP)
	ctx:defineSocket(ctx:sided("UpperArm"), arm, A.add(A.lerp(shoulder, elbow, 0.5), { 0.45 * t, 0, 0 }), A.RIGHT)
	ctx:defineSocket(ctx:sided("Elbow"), arm, A.add(elbow, { 0, 0, 0.4 * t }), A.BACK)
	ctx:defineSocket(ctx:sided("Forearm"), arm, A.add(A.lerp(elbow, wrist, 0.5), { 0.4 * t, 0, 0 }), A.RIGHT)
	if withHand ~= false then
		ctx:defineSocket(ctx:sided("Hand"), arm, wrist, A.DOWN)
		ctx:defineSocket(ctx:sided("Palm"), arm, A.add(wrist, { -0.3, -0.3, 0 }), { 0, 0, 90 })
	end
end

return function(R)
	---------------------------------------------------------------------------- arms
	R.register({
		id = "NormalArm",
		slots = { "Arms" },
		grade = "Grade4",
		tags = { "arm" },
		params = { upper = 0.42, fore = 0.38, deltoid = 1, biceps = 0, flesh = false, ridge = false, lumps = 0, veins = false },
		build = function(ctx, p, entry)
			local arm = limbPart(ctx, entry, "Arm")
			-- girth grows sub-linearly with mass so heavy bodies stay readable
			local t = ctx:m("ArmThick") ^ 0.75
			local hy = handY(ctx)
			local S, E, W = { 0, 0.72, 0 }, { 0.03, 0.72 + (hy - 0.72) * 0.47, 0.08 }, { 0, hy + 0.15, -0.06 }
			ctx:blob(arm, { 0.05, 0.78, 0 }, { 1.2 * t * p.deltoid, 0.9 * t * p.deltoid, 1.2 * t * p.deltoid }, { 0, 0, 10 }, "SkinLight")
			ctx:capsule(arm, S, E, p.upper * t, "Skin")
			if p.biceps > 0 then
				ctx:blob(arm, A.add(A.lerp(S, E, 0.45), { 0, 0, -0.2 * t }), { 0.8 * t, 0.9 * p.biceps * 2, 0.6 * t }, nil, "SkinLight")
			end
			ctx:blob(arm, A.add(E, { 0.02, 0, 0.12 }), { 0.9 * p.fore / 0.38 * t, 0.6, 0.85 * t }, nil, "SkinDark")
			ctx:capsule(arm, E, W, { p.fore * t, p.fore * t * 0.9 }, "Skin")
			if p.flesh then
				ctx:capsule(arm, A.add(E, { -0.32 * t, -0.1, -0.12 }), A.add(W, { -0.3 * t, 0.2, -0.12 }), { 0.2 * t, 0.36 * t }, "Flesh")
				for k = 1, 4 do
					local q = A.lerp(E, W, k / 5)
					ctx:blob(arm, A.add(q, { -0.46 * t, 0, -0.18 }), { 0.16, 0.07, 0.55 * t }, nil, "FleshDark")
				end
			end
			if p.ridge then
				ctx:capsule(arm, A.add(E, { 0.42 * t, -0.2, 0 }), A.add(W, { 0.38 * t, 0.35, 0 }), { 0.14 * t, 0.28 * t }, "SkinLight")
			end
			if p.veins then
				for k = 1, 3 do
					local a = A.lerp(S, W, 0.2 + k * 0.2)
					ctx:capsule(arm, A.add(a, { 0.1, 0.25, -p.upper * t }), A.add(a, { -0.05, -0.25, -p.upper * t * 0.95 }), 0.035, "SkinDark")
				end
			end
			for _ = 1, p.lumps do
				local q = A.lerp(S, W, ctx:rand(0.1, 0.9))
				local r = ctx:rand(0.25, 0.5) * t
				ctx:blob(arm, A.add(q, { ctx:rand(-0.3, 0.4) * t, 0, ctx:rand(-0.3, 0.3) * t }), { r * 1.3, r * 1.5, r * 1.2 }, nil,
					ctx:rand(0, 1) > 0.5 and "SkinLight" or "Flesh")
			end
			armSockets(ctx, arm, S, E, W, t)
		end,
	})

	local function arm(id, grade, params, extra)
		local def = { id = id, grade = grade, params = params, tags = { "arm" } }
		for k, v in pairs(extra or {}) do
			def[k] = v
		end
		R.variant("NormalArm", def)
	end
	arm("MuscularArm", "Grade4", { upper = 0.5, fore = 0.46, deltoid = 1.1, biceps = 0.45, veins = true })
	arm("ThinArm", "Grade4", { upper = 0.22, fore = 0.2, deltoid = 0.6 })
	arm("HeavyArm", "Grade3", { upper = 0.52, fore = 0.5, deltoid = 0.95, flesh = true, ridge = true }) -- the reference
	arm("EnlargedForearm", "Grade3", { upper = 0.36, fore = 0.72, deltoid = 0.9, ridge = true })
	arm("DeformedArm", "Grade2", { upper = 0.45, fore = 0.5, lumps = 6, flesh = true })
	arm("LongArm", "Grade3", { upper = 0.34, fore = 0.32, deltoid = 0.85 }, {
		mutate = function(body, _, _, sideName)
			if sideName then
				body.side[sideName].ArmLength = (body.side[sideName].ArmLength or 1) * 1.4
			end
		end,
	})
	arm("ShortArm", "Grade3", { upper = 0.45, fore = 0.42 }, {
		mutate = function(body, _, _, sideName)
			if sideName then
				body.side[sideName].ArmLength = (body.side[sideName].ArmLength or 1) * 0.72
			end
		end,
	})

	R.register({
		id = "BoneArm",
		slots = { "Arms" },
		grade = "Grade2",
		tags = { "arm", "bone" },
		build = function(ctx, _, entry)
			local arm = limbPart(ctx, entry, "Arm")
			local t = ctx:m("ArmThick")
			local hy = handY(ctx)
			local S, E, W = { 0, 0.72, 0 }, { 0.03, 0.72 + (hy - 0.72) * 0.47, 0.08 }, { 0, hy + 0.15, -0.06 }
			ctx:blob(arm, { 0.05, 0.8, 0 }, { 1.0 * t, 0.8 * t, 1.0 * t }, nil, "SkinDark")
			ctx:capsule(arm, S, E, 0.14 * t, "Bone")
			ctx:capsule(arm, A.add(E, { 0.07, 0, 0 }), A.add(W, { 0.07, 0, 0 }), 0.09 * t, "Bone")
			ctx:capsule(arm, A.add(E, { -0.07, 0, -0.05 }), A.add(W, { -0.07, 0, -0.05 }), 0.08 * t, "BoneDark")
			ctx:blob(arm, E, { 0.35 * t, 0.3, 0.35 * t }, nil, "BoneDark")
			ctx:blob(arm, W, { 0.3 * t, 0.2, 0.3 * t }, nil, "BoneDark")
			for k = 1, 3 do
				local a = ({ 0.2, -0.2, 0.05 })[k]
				ctx:capsule(arm, A.add(S, { a, -0.1, 0.1 }), A.add(A.lerp(E, W, 0.4), { a * 0.6, 0, -0.1 }), 0.04, "SkinDark")
			end
			armSockets(ctx, arm, S, E, W, t)
		end,
	})

	R.register({
		id = "TentacleArm",
		slots = { "Arms" },
		grade = "Grade2",
		tags = { "arm", "tentacle" },
		params = { segments = 6, radius = 0.4, hand = false },
		build = function(ctx, p, entry)
			local arm = limbPart(ctx, entry, "Arm")
			local t = ctx:m("ArmThick")
			local reach = 1.7 - handY(ctx)
			local segs = {}
			for i = 1, p.segments do
				local k = (i - 1) / (p.segments - 1)
				table.insert(segs, { reach / p.segments, p.radius * t * (1 - 0.7 * k), { i == 1 and 0 or 6, 0, i == 1 and 5 or -4 } })
			end
			ctx:blob(arm, { 0.05, 0.75, 0 }, { 1.2 * t, 0.9 * t, 1.2 * t }, nil, "SkinLight")
			local chain = ctx:chain(arm, { 0, 0.8, 0 }, nil, segs, {
				name = "Tentacle",
				sway = { amp = 9, speed = 1.1 },
				flesh = function(c, seg, i, len, r)
					c:blob(seg, { 0, 0, 0 }, { r * 2, len * 1.35, r * 2 }, nil, i % 2 == 0 and "SkinLight" or "Skin")
					c:blob(seg, { 0, 0, -r * 0.55 }, { r * 1.1, len * 0.9, r * 0.9 }, nil, "Flesh")
				end,
			})
			if p.hand then
				local tip = chain[#chain]
				ctx:defineSocket(ctx:sided("Hand"), tip.anchor, { 0, -tip.length / 2, 0 }, A.DOWN)
			end
		end,
	})

	R.register({
		id = "MultiJointArm",
		slots = { "Arms" },
		grade = "Grade1",
		tags = { "arm", "abnormal" },
		params = { joints = 3, radius = 0.26 },
		build = function(ctx, p, entry)
			local arm = limbPart(ctx, entry, "Arm")
			local t = ctx:m("ArmThick")
			local reach = 1.8 - handY(ctx)
			local segs = {}
			for i = 1, p.joints do
				table.insert(segs, { reach / p.joints * 1.08, p.radius * t * (1 - 0.15 * i), { i == 1 and -10 or 22, 0, i == 1 and 6 or -8 } })
			end
			ctx:blob(arm, { 0.05, 0.78, 0 }, { 1.1 * t, 0.85 * t, 1.1 * t }, nil, "SkinLight")
			local chain = ctx:chain(arm, { 0, 0.8, 0 }, nil, segs, {
				name = "Joint",
				sway = { amp = 4, speed = 0.8 },
				flesh = function(c, seg, i, len, r)
					c:capsule(seg, { 0, len / 2, 0 }, { 0, -len / 2, 0 }, r, "Skin", { stretch = 1.05 })
					c:blob(seg, { 0, -len / 2, 0.05 }, { r * 2.4, r * 2.2, r * 2.4 }, nil, "SkinDark")
				end,
			})
			local tip = chain[#chain]
			ctx:defineSocket(ctx:sided("Hand"), tip.anchor, { 0, -tip.length / 2, 0 }, A.DOWN)
		end,
	})

	R.register({
		id = "ScytheArm",
		slots = { "Arms" },
		grade = "Grade2",
		tags = { "arm", "blade", "insect" },
		params = { blade = 1.6 },
		build = function(ctx, p, entry)
			local arm = limbPart(ctx, entry, "Arm")
			local t = ctx:m("ArmThick")
			local hy = handY(ctx)
			local S, E, W = { 0, 0.72, 0 }, { 0.03, 0.72 + (hy - 0.72) * 0.45, 0.1 }, { 0, hy + 0.2, -0.1 }
			ctx:capsule(arm, S, E, 0.26 * t, "SkinDark")
			ctx:capsule(arm, E, W, 0.22 * t, "Skin")
			ctx:blob(arm, E, { 0.4 * t, 0.35, 0.4 * t }, nil, "SkinDark")
			local tip = A.add(W, { 0, -p.blade * 0.35, -p.blade * 0.55 })
			ctx:triangle(arm, W, A.add(W, { 0, 0.35, 0.05 }), tip, "Claw", 0.08)
			ctx:triangle(arm, W, tip, A.add(W, { 0, -0.2, -0.25 }), "Claw", 0.08)
			for k = 1, 4 do
				local q = A.lerp(W, tip, k / 5)
				ctx:capsule(arm, q, A.add(q, { 0, 0.12, 0.05 }), 0.03, "Teeth")
			end
			armSockets(ctx, arm, S, E, W, t, false)
		end,
	})

	---------------------------------------------------------------------------- hands
	R.register({
		id = "Hand",
		slots = { "Hands" },
		grade = "Grade4",
		tags = { "hand" },
		params = { size = 1, fingers = 4, fingerLen = 0.42, fingerThick = 0.085, curl = 0.35, claw = 0, blade = 0,
			thumb = true, fist = false, stumps = 0 },
		build = function(ctx, p)
			if not hasOwnSocket(ctx, "Hand") then
				return
			end
			local hand = ctx:socket(ctx:sided("Hand"))
			local h = ctx:m("Hand") * p.size
			local flags = ctx.body.flags or {}
			local missing = (ctx.suffix == "R" or ctx.suffix == "L") and (flags["MissingFingers" .. ctx.sideName] or 0) or 0
			local n = math.max(0, p.fingers - missing)
			p = table.clone(p)
			p.stumps += p.fingers - n
			if p.fist then
				ctx:blob(hand, { 0, 0.32 * h, -0.02 }, { 0.72 * h, 0.62 * h, 0.66 * h }, nil, "Skin")
			else
				ctx:blob(hand, { 0, 0.26 * h, 0 }, { 0.42 * h, 0.55 * h, 0.62 * h }, nil, "Skin")
			end
			for i = 1, n + p.stumps do
				local z = n + p.stumps == 1 and 0 or ((i - 1) / (n + p.stumps - 1) - 0.5) * 0.5 * h
				local r = p.fingerThick * h * (1 - math.abs(z) * 0.4)
				if i > n then
					ctx:blob(hand, { -0.04, 0.55 * h, z }, { r * 2.2, r * 1.6, r * 2.2 }, nil, "SkinDark")
				elseif p.fist then
					ctx:blob(hand, { -0.2 * h, 0.52 * h, z * 1.2 }, { r * 3, r * 3.2, r * 2.4 }, nil, "SkinLight")
				else
					local L = p.fingerLen * h * (1 - math.abs(z) * 0.5)
					local c = p.curl
					local pts = { { 0, 0.48 * h, z }, { -0.06 * c, 0.48 * h + L * 0.5, z }, { -0.22 * c, 0.48 * h + L * 0.9, z } }
					ctx:tube(hand, pts, { r, r * 0.9, r * 0.75 }, "Skin")
					local tip, dir = pts[3], A.lerp({ -0.1 * c, 1, 0 }, { -1, 0.4, 0 }, c * 0.5)
					if p.claw > 0 then
						ctx:tube(hand, { tip, A.add(tip, dir, p.claw * 0.6 * h), A.add(A.add(tip, dir, p.claw * h), { -0.12 * p.claw, 0, 0 }) },
							{ r * 0.8, r * 0.45, r * 0.1 }, "Claw")
					end
					if p.blade > 0 then
						local e = A.add(tip, { -0.05, p.blade * h, 0 })
						ctx:triangle(hand, A.add(tip, { 0, 0, -r }), A.add(tip, { 0, 0, r }), e, "Claw", 0.05)
					end
				end
			end
			if p.thumb then
				local a, b = { -0.12 * h, 0.2 * h, 0.3 * h }, { -0.28 * h, 0.42 * h, 0.34 * h }
				ctx:tube(hand, { a, b, A.add(b, { -0.05, 0.12 * h, 0.02 }) }, { p.fingerThick * h * 1.2, p.fingerThick * h, p.fingerThick * h * 0.8 }, "Skin")
				if p.claw > 0 then
					ctx:capsule(hand, A.add(b, { -0.05, 0.12 * h, 0.02 }), A.add(b, { -0.12, 0.12 * h + p.claw * 0.6 * h, 0 }), p.fingerThick * h * 0.6, "Claw")
				end
			end
		end,
	})

	local function hand(id, grade, params)
		R.variant("Hand", { id = id, grade = grade, params = params, tags = { "hand" } })
	end
	hand("Fist", "Grade4", { fist = true, size = 1.15 })
	hand("ClawedHand", "Grade3", { claw = 0.28, curl = 0.5 })
	hand("BladedFingers", "Grade2", { blade = 1.1, fingerThick = 0.065, curl = 0, fingerLen = 0.3 })
	hand("TalonHand", "Grade3", { fingers = 3, fingerLen = 0.7, claw = 0.35, curl = 0.65, fingerThick = 0.09 })
	hand("OversizedHand", "Grade3", { size = 1.65, claw = 0.12, curl = 0.45 })
	hand("ExtraFingersHand", "Grade3", { fingers = 7, fingerThick = 0.07, curl = 0.4 })
	hand("MissingFingersHand", "Grade4", { fingers = 2, stumps = 2, curl = 0.3 })

	---------------------------------------------------------------------------- legs
	local function legBottom(ctx)
		return -1 - ctx.layout.legExtra
	end

	R.register({
		id = "NormalLeg",
		slots = { "Legs" },
		grade = "Grade4",
		tags = { "leg" },
		params = { thigh = 0.5, shin = 0.4, flesh = false, calf = 0.3 },
		build = function(ctx, p, entry)
			local leg = limbPart(ctx, entry, "Leg")
			local t = ctx:m("LegThick")
			local bottom = legBottom(ctx)
			local H, K, An = { 0.03, 0.78, 0.03 }, { 0, 0.8 + (bottom - 0.8) * 0.5, -0.1 }, { 0, bottom + 0.25, 0.06 }
			ctx:capsule(leg, H, K, { p.thigh * t, p.thigh * t * 1.02 }, "Skin", { stretch = 1.3 })
			if p.flesh then
				ctx:capsule(leg, A.add(H, { -0.12 * t, 0, -0.3 * t }), A.add(K, { -0.1 * t, 0.15, -0.28 * t }), { 0.42 * t, 0.36 * t }, "Flesh")
				for k = 1, 3 do
					local q = A.lerp(H, K, k / 4)
					ctx:blob(leg, A.add(q, { -0.12 * t, 0, -0.62 * t }), { 0.6 * t, 0.07, 0.18 }, nil, "FleshDark")
				end
				ctx:capsule(leg, A.add(K, { -0.28 * t, -0.1, 0.05 }), A.add(An, { -0.22 * t, 0.2, 0.05 }), { 0.16 * t, 0.26 * t }, "Flesh")
			end
			ctx:blob(leg, A.add(K, { 0, 0.02, -0.05 }), { 0.85 * t, 0.62, 0.8 * t }, nil, "SkinLight")
			ctx:capsule(leg, K, An, { p.shin * t, p.shin * t * 1.05 }, "Skin")
			if p.calf > 0 then
				ctx:blob(leg, A.add(A.lerp(K, An, 0.3), { 0, 0, 0.18 * t }), { 0.7 * t, 0.8, p.calf * 2 * t }, nil, "Skin")
			end
			ctx:blob(leg, An, { 0.62 * t, 0.4, 0.66 * t }, nil, "SkinDark")
			ctx:defineSocket(ctx:sided("Thigh"), leg, A.add(A.lerp(H, K, 0.5), { 0, 0, -p.thigh * t }), A.FRONT)
			ctx:defineSocket(ctx:sided("Knee"), leg, A.add(K, { 0, 0, -0.4 * t }), A.FRONT)
			ctx:defineSocket(ctx:sided("Shin"), leg, A.add(A.lerp(K, An, 0.5), { p.shin * t, 0, 0 }), A.RIGHT)
			ctx:defineSocket(ctx:sided("Foot"), leg, { 0, bottom, 0 }, A.UP)
		end,
	})
	local function leg(id, grade, params, extra)
		local def = { id = id, grade = grade, params = params, tags = { "leg" } }
		for k, v in pairs(extra or {}) do
			def[k] = v
		end
		R.variant("NormalLeg", def)
	end
	leg("MassiveLeg", "Grade3", { thigh = 0.72, shin = 0.58, calf = 0.45 })
	leg("ThinLeg", "Grade4", { thigh = 0.27, shin = 0.21, calf = 0.1 })
	leg("HuskLeg", "Grade3", { thigh = 0.55, shin = 0.42, flesh = true }) -- the reference
	leg("LongLeg", "Grade3", { thigh = 0.42, shin = 0.34 }, {
		mutate = function(body)
			body.layout.legExtra += 0.4
		end,
	})
	leg("ShortLeg", "Grade3", { thigh = 0.55, shin = 0.48 }, {
		mutate = function(body)
			body.layout.legExtra -= 0.25
		end,
	})

	R.register({
		id = "DigitigradeLeg",
		slots = { "Legs" },
		grade = "Grade2",
		tags = { "leg", "beast" },
		mutate = function(body)
			body.layout.legExtra += 0.2
		end,
		build = function(ctx, _, entry)
			local leg = limbPart(ctx, entry, "Leg")
			local t = ctx:m("LegThick")
			local bottom = legBottom(ctx)
			local span = 0.8 - bottom
			local H, K = { 0.03, 0.78, 0.05 }, { 0, 0.8 - span * 0.33, -0.38 }
			local Hk, B = { 0, bottom + span * 0.33, 0.42 }, { 0, bottom + 0.14, -0.18 }
			ctx:capsule(leg, H, K, 0.52 * t, "Skin", { stretch = 1.3 })
			ctx:blob(leg, K, { 0.7 * t, 0.55, 0.7 * t }, nil, "SkinLight")
			ctx:capsule(leg, K, Hk, { 0.3 * t, 0.26 * t }, "Skin")
			ctx:blob(leg, Hk, { 0.42 * t, 0.42, 0.5 * t }, nil, "SkinDark")
			ctx:capsule(leg, Hk, B, 0.19 * t, "SkinDark")
			ctx:defineSocket(ctx:sided("Thigh"), leg, A.add(A.lerp(H, K, 0.5), { 0, 0, -0.5 * t }), A.FRONT)
			ctx:defineSocket(ctx:sided("Knee"), leg, A.add(K, { 0, 0, -0.35 * t }), A.FRONT)
			ctx:defineSocket(ctx:sided("Shin"), leg, A.add(A.lerp(K, Hk, 0.5), { 0.3 * t, 0, 0 }), A.RIGHT)
			ctx:defineSocket(ctx:sided("Foot"), leg, { 0, bottom, -0.18 }, A.UP)
		end,
	})

	R.register({
		id = "ReverseJointLeg",
		slots = { "Legs" },
		grade = "Grade2",
		tags = { "leg", "bird" },
		build = function(ctx, _, entry)
			local leg = limbPart(ctx, entry, "Leg")
			local t = ctx:m("LegThick")
			local bottom = legBottom(ctx)
			local H, K, An = { 0.03, 0.78, 0 }, { 0, 0.8 + (bottom - 0.8) * 0.45, 0.42 }, { 0, bottom + 0.22, -0.08 }
			ctx:capsule(leg, H, K, 0.45 * t, "Skin", { stretch = 1.3 })
			ctx:blob(leg, K, { 0.55 * t, 0.5, 0.6 * t }, nil, "SkinDark")
			ctx:capsule(leg, A.add(K, { 0, 0, 0.15 }), A.add(K, { 0, 0.25, 0.55 }), { 0.1, 0.1 }, "Bone")
			ctx:capsule(leg, K, An, 0.26 * t, "SkinDark")
			ctx:blob(leg, An, { 0.4 * t, 0.3, 0.45 * t }, nil, "SkinDark")
			ctx:defineSocket(ctx:sided("Thigh"), leg, A.add(A.lerp(H, K, 0.5), { 0, 0, -0.4 * t }), A.FRONT)
			ctx:defineSocket(ctx:sided("Knee"), leg, A.add(K, { 0, 0, 0.35 * t }), A.BACK)
			ctx:defineSocket(ctx:sided("Shin"), leg, A.add(A.lerp(K, An, 0.5), { 0.3 * t, 0, 0 }), A.RIGHT)
			ctx:defineSocket(ctx:sided("Foot"), leg, { 0, bottom, -0.08 }, A.UP)
		end,
	})

	R.register({
		id = "InsectLeg",
		slots = { "Legs" },
		grade = "Grade2",
		tags = { "leg", "insect" },
		build = function(ctx, _, entry)
			local leg = limbPart(ctx, entry, "Leg")
			local t = ctx:m("LegThick")
			local bottom = legBottom(ctx)
			local H, J, T, tip = { 0, 0.8, 0 }, { 0.55, 0.55, -0.1 }, { 0.45, bottom + 0.5, -0.15 }, { 0.3, bottom, -0.2 }
			ctx:capsule(leg, H, J, 0.2 * t, "SkinDark")
			ctx:blob(leg, J, { 0.3 * t, 0.3, 0.3 * t }, nil, "Skin")
			ctx:capsule(leg, J, T, 0.14 * t, "SkinDark")
			ctx:blob(leg, T, { 0.22 * t, 0.22, 0.22 * t }, nil, "Skin")
			ctx:tube(leg, { T, A.lerp(T, tip, 0.6), tip }, { 0.1 * t, 0.06, 0.02 }, "Claw")
		end,
	})

	-- Special Grade: no legs — a coiling serpent body carries the torso.
	R.register({
		id = "SerpentBody",
		slots = { "Legs" },
		grade = "SpecialGrade",
		tags = { "abnormal", "serpent" },
		params = { segments = 9, radius = 0.95 },
		build = function(ctx, p)
			if ctx.side < 0 then
				return -- one body, built once
			end
			local W = ctx:m("TorsoW")
			local segs = {}
			local bends = { 0, 25, 45, 40, 25, 30, 35, 35, 40, 40 }
			for i = 1, p.segments do
				table.insert(segs, { 0.95, p.radius * W * (1 - 0.72 * (i - 1) / p.segments), { i <= 3 and -bends[i] or -12, 0, i > 3 and 28 or 0 } })
			end
			ctx:with({ side = 1 }, function()
				ctx:chain("Torso", { 0, -1.05, 0.15 }, { -8, 0, 0 }, segs, {
					name = "Serpent",
					sway = { amp = 3, speed = 0.6 },
					flesh = function(c, seg, i, len, r)
						c:blob(seg, { 0, 0, 0 }, { r * 2, len * 1.4, r * 2 }, nil, i % 2 == 0 and "SkinLight" or "Skin")
						c:blob(seg, { 0, 0, -r * 0.62 }, { r * 1.3, len * 1.1, r * 0.8 }, nil, "Flesh")
						c:blob(seg, { 0, len * 0.3, r * 0.75 }, { r * 0.8, len * 0.3, r * 0.4 }, nil, "SkinDark")
					end,
				})
			end)
		end,
	})

	R.register({
		id = "TendrilMass",
		slots = { "Legs" },
		grade = "Grade1",
		tags = { "abnormal", "tendril" },
		params = { tendrils = 4 },
		build = function(ctx, p, entry)
			local leg = limbPart(ctx, entry, "Leg")
			local t = ctx:m("LegThick")
			local bottom = legBottom(ctx)
			local span = 0.8 - bottom
			ctx:blob(leg, { 0, 0.7, 0 }, { 1.2 * t, 0.9, 1.2 * t }, nil, "Skin")
			for i = 1, p.tendrils do
				local a = i / p.tendrils * math.pi * 2
				local segs = {}
				for k = 1, 4 do
					table.insert(segs, { span / 4 * 1.1, 0.2 * t * (1 - 0.18 * k), { k == 1 and math.cos(a) * 15 or 4, 0, k == 1 and -math.sin(a) * 15 or 0 } })
				end
				ctx:chain(leg, { math.sin(a) * 0.25 * t, 0.6, math.cos(a) * 0.25 * t }, nil, segs,
					{ name = "LegTendril", sway = { amp = 6, speed = 1.3 } })
			end
		end,
	})

	---------------------------------------------------------------------------- feet
	R.register({
		id = "Foot",
		slots = { "Feet" },
		grade = "Grade4",
		tags = { "foot" },
		params = { size = 1, length = 1.1, width = 0.8, toes = 4, toeLen = 0.25, claw = 0, backToe = false, hoof = false, lumps = 0 },
		build = function(ctx, p)
			if not hasOwnSocket(ctx, "Foot") then
				return
			end
			local foot = ctx:socket(ctx:sided("Foot"))
			local f = ctx:m("Foot") * p.size
			if p.hoof then
				ctx:blob(foot, { 0, 0.55 * f, 0.02 }, { 0.62 * f, 0.6 * f, 0.66 * f }, nil, "SkinDark")
				ctx:capsule(foot, { 0, 0.02, 0 }, { 0, 0.42 * f, 0 }, { 0.36 * f, 0.4 * f }, "Claw", { stretch = 1.05 })
				ctx:blob(foot, { 0, 0.22 * f, -0.36 * f }, { 0.05, 0.4 * f, 0.1 }, nil, "Void")
				return
			end
			ctx:blob(foot, { 0, 0.18 * f, 0.18 * f }, { 0.55 * f, 0.36 * f, 0.55 * f }, nil, "SkinDark")
			ctx:blob(foot, { 0, 0.18 * f, -0.35 * p.length * f }, { p.width * f, 0.36 * f, p.length * f }, nil, "Skin")
			for i = 1, p.toes do
				local x = p.toes == 1 and 0 or ((i - 1) / (p.toes - 1) - 0.5) * p.width * 0.8 * f
				local spread = x * 0.35
				local base = { x, 0.12 * f, -0.75 * p.length * f }
				local tip = { x + spread, 0.1 * f, base[3] - p.toeLen * f }
				ctx:capsule(foot, base, tip, 0.1 * f, i % 2 == 0 and "SkinLight" or "Skin", { stretch = 1.35 })
				if p.claw > 0 then
					ctx:tube(foot, { tip, A.add(tip, { spread * 0.3, -0.02, -p.claw * 0.6 * f }), A.add(tip, { spread * 0.4, -0.08, -p.claw * f }) },
						{ 0.08 * f, 0.05 * f, 0.02 }, "Claw")
				end
			end
			if p.backToe then
				ctx:tube(foot, { { 0, 0.1 * f, 0.3 * f }, { 0, 0.06 * f, 0.6 * f }, { 0, 0.02, 0.75 * f } }, { 0.09 * f, 0.07 * f, 0.03 }, "Claw")
			end
			for _ = 1, p.lumps do
				local r = ctx:rand(0.15, 0.3) * f
				ctx:blob(foot, { ctx:rand(-0.3, 0.3) * f, 0.3 * f, ctx:rand(-0.6, 0.2) * f }, { r, r, r }, nil, "SkinLight")
			end
		end,
	})
	local function foot(id, grade, params)
		R.variant("Foot", { id = id, grade = grade, params = params, tags = { "foot" } })
	end
	foot("EnlargedFoot", "Grade3", { length = 1.25, width = 0.9, toes = 4, toeLen = 0.65, claw = 0.2 }) -- the reference
	foot("ClawedFoot", "Grade3", { toes = 3, toeLen = 0.35, claw = 0.3 })
	foot("HoofFoot", "Grade3", { hoof = true })
	foot("TalonFoot", "Grade2", { toes = 3, toeLen = 0.8, claw = 0.35, width = 0.6, length = 0.7, backToe = true })
	foot("DeformedFoot", "Grade2", { toes = 5, toeLen = 0.2, width = 1.0, lumps = 4 })
end
