-- Builds the globals a module under test runs with, so a spec can stub Spring or VFS
-- without touching the real ones. Nested VFS.Include calls inherit the same env, so the
-- module's own dependencies load into it too.

local CHAINED = {
	Spring = true,
	Game = true,
	VFS = true,
	io = true,
	math = true,
	string = true,
	table = true,
}

local SpecEnv = {}

-- spec_helper seals the shared engine tables behind empty proxies, which pairs sees as empty.
local function behindSeal(value)
	local mt = debug.getmetatable(value)
	if mt and mt.__metatable == false and type(mt.__index) == "table" then
		return mt.__index
	end

	return value
end

-- Copied rather than only chained, so pairs over it finds the real fields too.
local function layered(real, overrides)
	local layer = {}
	for key, value in pairs(real) do
		layer[key] = value
	end
	for key, value in pairs(overrides or {}) do
		layer[key] = value
	end

	return setmetatable(layer, { __index = real })
end

---@param overrides table|nil  globals to place in the env, keyed by name. An
---`includes` key is not a global: it maps a path to what VFS.Include returns
---for it inside the env, either a value or a function called with the args.
---@return table
function SpecEnv.new(overrides)
	overrides = overrides or {}

	local env = setmetatable({}, { __index = _G })

	for name, value in pairs(overrides) do
		if name ~= "includes" then
			env[name] = value
		end
	end

	for name in pairs(CHAINED) do
		local real = behindSeal(_G[name])
		local value = overrides[name]
		if type(real) == "table" and (value == nil or type(value) == "table") then
			env[name] = layered(real, value)
		end
	end

	local includes = overrides.includes or {}
	local include = env.VFS.Include

	env.VFS.Include = function(path, childEnv, mode)
		local override = includes[path]
		if override ~= nil then
			if type(override) == "function" then
				return override(path, childEnv, mode)
			end

			return override
		end

		return include(path, childEnv or env, mode)
	end

	env._G = env

	return env
end

---@param env table
---@param path string
---@return any
function SpecEnv.include(env, path)
	return env.VFS.Include(path)
end

return SpecEnv
