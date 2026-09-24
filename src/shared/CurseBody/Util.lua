--!nonstrict
-- Small helpers shared by the framework.

local Util = {}

function Util.deepCopy(value)
	if type(value) ~= "table" then
		return value
	end
	local out = {}
	for k, v in pairs(value) do
		out[k] = Util.deepCopy(v)
	end
	return out
end

-- Deterministic serialization (sorted keys) used to diff slot values.
function Util.serialize(value)
	local t = type(value)
	if t == "table" then
		local keys = {}
		for k in pairs(value) do
			table.insert(keys, k)
		end
		table.sort(keys, function(a, b)
			return tostring(a) < tostring(b)
		end)
		local parts = {}
		for _, k in ipairs(keys) do
			table.insert(parts, tostring(k) .. "=" .. Util.serialize(value[k]))
		end
		return "{" .. table.concat(parts, ",") .. "}"
	elseif t == "number" then
		return string.format("%.4f", value)
	end
	return tostring(value)
end

function Util.hash(str)
	local h = 5381
	for i = 1, #str do
		h = (h * 33 + string.byte(str, i)) % 2147483647
	end
	return h
end

function Util.v3(t, default)
	if t == nil then
		return default or Vector3.zero
	end
	if typeof(t) == "Vector3" then
		return t
	end
	if type(t) == "number" then
		return Vector3.new(t, t, t)
	end
	return Vector3.new(t[1] or 0, t[2] or 0, t[3] or 0)
end

function Util.angles(t)
	if t == nil then
		return CFrame.identity
	end
	return CFrame.Angles(math.rad(t[1] or 0), math.rad(t[2] or 0), math.rad(t[3] or 0))
end

function Util.merge(base, over)
	local out = Util.deepCopy(base or {})
	for k, v in pairs(over or {}) do
		out[k] = Util.deepCopy(v)
	end
	return out
end

function Util.isArray(t)
	return type(t) == "table" and (#t > 0 or next(t) == nil)
end

function Util.lerp(a, b, t)
	return a + (b - a) * t
end

return Util
