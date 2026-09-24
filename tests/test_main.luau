--!nonstrict
-- Headless tests for the CurseBody framework (appended after the mock + bundle by tests/run.py).
-- Prints DUMP lines (parts to render) and PASS/FAIL lines.

local failures, checks = 0, 0
local function check(ok, msg)
	checks += 1
	if not ok then
		failures += 1
		print("FAIL\t" .. msg)
	end
end
local function takeWarnings()
	local w = table.clone(MOCK.warnings)
	table.clear(MOCK.warnings)
	return w
end

local RS = game:GetService("ReplicatedStorage")
local module = MOCK.mount(BUNDLE_TREE, RS)
local CurseBody = MOCK.require(module)
local Registry, Slots, Grades, Appearance = CurseBody.Registry, CurseBody.Slots, CurseBody.Grades, CurseBody.Appearance
check(#takeWarnings() == 0, "catalog loads without warnings")

local function countParts(model)
	local n = 0
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and d.Transparency < 1 then
			n += 1
		end
	end
	return n
end

local function dump(name, model)
	local parts, unattached = MOCK.dump(model)
	check(unattached == 0, name .. ": " .. unattached .. " visible parts not connected to the rig")
	print("DUMP\t" .. name .. "\t" .. MOCK.jsonEncode(parts))
	return #parts
end

local function newRig(name)
	local rig = CurseBody.createRig(name, CFrame.new(0, 3, 0))
	rig.Parent = workspace
	return rig
end

---------------------------------------------------------------- 1. presets + forms
local presetNames = {}
for name in pairs(CurseBody.Presets) do
	table.insert(presetNames, name)
end
table.sort(presetNames)
for _, name in ipairs(presetNames) do
	local preset = CurseBody.Presets[name]
	local rig = newRig(name)
	local state, issues = CurseBody.apply(rig, preset.appearance, { grade = preset.grade })
	check(#issues == 0, name .. ": sanitize issues: " .. table.concat(issues, "; "))
	local w = takeWarnings()
	check(#w == 0, name .. ": warnings: " .. table.concat(w, " | "))
	-- the six R6 joints are intact with their standard names
	for _, j in ipairs(CurseBody.Rig.JOINTS) do
		local m = rig[j[2]]:FindFirstChild(j[1])
		check(m ~= nil and m.Part1 == rig[j[3]], name .. ": R6 joint " .. j[1] .. " intact")
	end
	local n = dump(name, rig)
	print(("INFO\t%s\t%s\t%d parts"):format(name, preset.grade, n))
	for _, stage in ipairs({ "Partial", "Full" }) do
		if Grades.formAllowed(preset.grade, stage) and preset.appearance.Transformation then
			local ok, err = CurseBody.setForm(rig, stage)
			check(ok, name .. " setForm " .. stage .. ": " .. tostring(err))
			w = takeWarnings()
			check(#w == 0, name .. " " .. stage .. ": warnings: " .. table.concat(w, " | "))
			dump(name .. "_" .. stage, rig)
		end
	end
	CurseBody.setForm(rig, "Base")
	takeWarnings()
	rig:Destroy()
end

---------------------------------------------------------------- 2. every component builds in every slot
local base = { Seed = 3, BodyType = "Normal", Head = "HumanCurseHead", Torso = "NormalTorso" }
local built = 0
for id, def in pairs(Registry.all()) do
	for _, slotName in ipairs(def.slots) do
		local slot = Slots.get(slotName)
		local a = table.clone(base)
		if slot.kind == "multi" then
			a[slotName] = { { id = id } }
		else
			a[slotName] = id
		end
		if slotName == "Hands" then
			a.Arms = "NormalArm"
		end
		local rig = newRig("Component_" .. id)
		local _, issues = CurseBody.apply(rig, a, { grade = "SpecialGrade" })
		check(#issues == 0, id .. " in " .. slotName .. ": " .. table.concat(issues, "; "))
		local w = takeWarnings()
		check(#w == 0, id .. " in " .. slotName .. ": " .. table.concat(w, " | "))
		local _, unattached = MOCK.dump(rig)
		check(unattached == 0, id .. " in " .. slotName .. ": unattached parts")
		built += 1
		rig:Destroy()
	end
end
print("INFO\tcomponents\t" .. built .. " component/slot builds")

---------------------------------------------------------------- 3. grade gating
do
	local clean, issues = Appearance.sanitize(CurseBody.Presets.Amalgam.appearance, "Grade4")
	check(#issues > 0, "Amalgam at Grade4 reports issues")
	check(clean.Torso == "NormalTorso" and clean.Legs ~= "SerpentBody", "special-grade anatomy stripped at Grade4")
	check(#(clean.ExtraArms or {}) == 0 and #(clean.ExtraHeads or {}) == 0, "extra limbs stripped at Grade4")
	check(clean.BodyType == "Normal", "Massive body type locked at Grade4")
	check(clean.Height <= Grades.cap("Grade4", "HeightMax"), "height clamped at Grade4")
	local ok = CurseBody.setForm ~= nil
	check(ok, "setForm exists")
	local rig = newRig("GateForm")
	CurseBody.apply(rig, CurseBody.Presets.Grub.appearance, { grade = "Grade4" })
	local allowed = CurseBody.setForm(rig, "Full")
	check(not allowed, "Grade4 cannot transform")
	rig:Destroy()
	takeWarnings()
	-- caps: 10 horns at Grade3 → trimmed to the cap
	local many = {}
	for _ = 1, 10 do
		table.insert(many, "StubHorn")
	end
	local c2 = Appearance.sanitize({ Horns = many }, "Grade3")
	check(#c2.Horns == Grades.cap("Grade3", "Horns"), "horn cap enforced")
	-- aliases from hand-written data (the brief's example format)
	local c3 = Appearance.sanitize({ BodyType = "Heavy", Head = "OctopoidHead", Horns = "CurvedHorn", Eyes = { "Eye", "EyeCluster" },
		Arms = "MuscularArm", ExtraLimbs = 2, Hands = "ClawedHand", Legs = "DigitigradeLeg", Tail = "BoneTail",
		TorsoGrowth = "ChestCavity" }, "Grade1")
	check(#c3.ExtraArms == 2 and c3.Tails[1].id == "BoneTail" and c3.TorsoGrowths[1].id == "ChestCavity", "alias keys migrate")
end

---------------------------------------------------------------- 4. incremental rebuild only touches changed slots
do
	local rig = newRig("Diff")
	CurseBody.apply(rig, CurseBody.Presets.Grub.appearance, { grade = "Grade2" })
	local torsoFolder = rig.CurseBody.Torso.BaseTorso
	local legFolder = rig.CurseBody.Legs.LegVariant
	CurseBody.equip(rig, "Horns", { "HornPair" })
	check(rig.CurseBody.Torso.BaseTorso == torsoFolder, "equip Horns keeps the torso")
	check(rig.CurseBody.Legs.LegVariant == legFolder, "equip Horns keeps the legs")
	check(rig.CurseBody.Head.HornSet:GetAttribute("GrowIn") == true, "new horns are flagged to grow in")
	CurseBody.equip(rig, "Arms", "MuscularArm")
	check(rig.CurseBody.Legs.LegVariant == legFolder, "equip Arms keeps the legs")
	CurseBody.equip(rig, "BodyType", "Heavy")
	check(rig.CurseBody.Legs.LegVariant ~= legFolder, "body type change rebuilds everything")
	CurseBody.unequip(rig, "Horns")
	check(rig.CurseBody.Head:FindFirstChild("HornSet") == nil, "unequip removes horns")
	check(#takeWarnings() == 0, "diff rebuild without warnings")
	rig:Destroy()
end

---------------------------------------------------------------- 5. fuzz: random appearances at random grades
do
	local rng = Random.new(1234)
	local function pick(list)
		return list[rng:NextInteger(1, #list)]
	end
	local function ids(slotName)
		local out = {}
		for _, def in ipairs(Registry.list(slotName)) do
			table.insert(out, def.id)
		end
		return out
	end
	for i = 1, 40 do
		local grade = Grades.order[rng:NextInteger(1, #Grades.order)]
		local a = {
			Seed = i,
			BodyType = pick({ "Lean", "Normal", "Muscular", "Heavy", "Hunched", "Deformed", "Monstrous", "Massive" }),
			Palette = pick({ "Crimson", "Pale", "Ash", "Bruise", "Bile", "Void", "Flayed" }),
			Height = rng:NextNumber(0.7, 1.8),
			Head = pick(ids("Head")), Torso = pick(ids("Torso")),
			Arms = { Right = pick(ids("Arms")), Left = pick(ids("Arms")) }, Hands = pick(ids("Hands")),
			Legs = pick(ids("Legs")), Feet = pick(ids("Feet")),
			ExtraArms = rng:NextInteger(0, 4), ExtraLegs = rng:NextInteger(0, 2), ExtraHeads = rng:NextInteger(0, 2),
			Horns = { pick(ids("Horns")) }, Tails = { pick(ids("Tails")) }, Back = { pick(ids("Back")) },
			TorsoGrowths = { pick(ids("TorsoGrowths")) },
			Disfigurements = { { id = pick(ids("Disfigurements")), socket = pick({ "Hand_R", "ChestL", "Back", "Face", "Thigh_L" }) } },
			Transformation = pick(Registry.listTransformations()).id,
		}
		local rig = newRig("Fuzz" .. i)
		CurseBody.apply(rig, a, { grade = grade })
		if Grades.formAllowed(grade, "Full") then
			CurseBody.setForm(rig, "Full")
		end
		local w = takeWarnings()
		check(#w == 0, "fuzz " .. i .. " (" .. grade .. "): " .. table.concat(w, " | "))
		local _, unattached = MOCK.dump(rig)
		check(unattached == 0, "fuzz " .. i .. ": unattached parts")
		if i <= 8 then
			dump("Fuzz" .. i, rig)
		end
		rig:Destroy()
	end
end

print(("RESULT\t%d checks\t%d failures"):format(checks, failures))
