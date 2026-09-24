--!nonstrict
--[[
	Curse grades. The grade is progression (cursed energy, feats, level), NOT a count
	of cosmetic parts: `Grades.compute` reads the profile's stats, and anatomy only
	ever reads the grade. Higher grades unlock more of the catalog and larger caps.
]]

local Grades = {}

Grades.order = { "Grade4", "Grade3", "Grade2", "Grade1", "SpecialGrade" }
Grades.index = {}
for i, name in ipairs(Grades.order) do
	Grades.index[name] = i
end

Grades.displayName = {
	Grade4 = "Grade 4",
	Grade3 = "Grade 3",
	Grade2 = "Grade 2",
	Grade1 = "Grade 1",
	SpecialGrade = "Special Grade",
}

--            Grade4  Grade3  Grade2  Grade1  Special
local CAPS = {
	Horns = { 2, 3, 4, 6, 12 },
	Eyes = { 2, 4, 8, 16, 40 },
	Mouths = { 1, 2, 3, 5, 12 },
	HeadGrowths = { 1, 2, 4, 6, 12 },
	TorsoGrowths = { 1, 2, 3, 5, 10 },
	ExtraArms = { 0, 1, 2, 4, 8 },
	ExtraLegs = { 0, 0, 2, 4, 6 },
	ExtraHeads = { 0, 0, 0, 1, 4 },
	Tails = { 1, 1, 2, 3, 6 },
	Back = { 0, 1, 2, 4, 8 },
	Disfigurements = { 2, 4, 8, 14, 30 },
	-- max deviation of Appearance.Scales from 1
	ScaleRange = { 0.10, 0.20, 0.35, 0.60, 1.00 },
	HeightMin = { 0.90, 0.85, 0.80, 0.75, 0.60 },
	HeightMax = { 1.10, 1.20, 1.35, 1.60, 2.20 },
	-- 0 = no transformation, 1 = Partial, 2 = Full
	MaxFormStage = { 0, 1, 1, 2, 2 },
}

Grades.bodyTypes = {
	Grade4 = { "Lean", "Normal", "Muscular" },
	Grade3 = { "Hunched", "Heavy" },
	Grade2 = { "Deformed" },
	Grade1 = { "Monstrous" },
	SpecialGrade = { "Massive" },
}

Grades.formStages = { Base = 0, Partial = 1, Full = 2 }

function Grades.valid(grade)
	return Grades.index[grade] ~= nil
end

function Grades.rank(grade)
	return Grades.index[grade] or 1
end

function Grades.atLeast(grade, minimum)
	return Grades.rank(grade) >= Grades.rank(minimum or "Grade4")
end

function Grades.cap(grade, key)
	local row = CAPS[key]
	return row and row[Grades.rank(grade)] or math.huge
end

function Grades.bodyTypeAllowed(grade, bodyType)
	for i = 1, Grades.rank(grade) do
		for _, name in ipairs(Grades.bodyTypes[Grades.order[i]]) do
			if name == bodyType then
				return true
			end
		end
	end
	return false
end

function Grades.formAllowed(grade, stage)
	return (Grades.formStages[stage] or 99) <= Grades.cap(grade, "MaxFormStage")
end

--[[
	Replace with your game's progression. Stats are whatever the profile tracks;
	the default uses cursed energy and exorcisms/kills.
]]
Grades.thresholds = {
	{ grade = "SpecialGrade", cursedEnergy = 50000, feats = 500 },
	{ grade = "Grade1", cursedEnergy = 15000, feats = 150 },
	{ grade = "Grade2", cursedEnergy = 5000, feats = 50 },
	{ grade = "Grade3", cursedEnergy = 1000, feats = 10 },
}

function Grades.compute(profile)
	local stats = profile and profile.Stats or {}
	local ce, feats = stats.CursedEnergy or 0, stats.Feats or 0
	for _, t in ipairs(Grades.thresholds) do
		if ce >= t.cursedEnergy and feats >= t.feats then
			return t.grade
		end
	end
	return "Grade4"
end

return Grades
