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

---@param overrides table|nil  globals to place in the env, keyed by name. An
---`includes` key is not a global: it maps a path to what VFS.Include returns
---for it inside the env, either a value or a function called with the args.
---@return table
function SpecEnv.new(overrides)
	overrides = overrides or {}

	local env = setmetatable({}, { __index = _G })

	for name, value in pairs(overrides) do
		if name ~= "includes" then
			if CHAINED[name] and type(value) == "table" and type(_G[name]) == "table" then
				env[name] = setmetatable(value, { __index = _G[name] })
			else
				env[name] = value
			end
		end
	end

	-- rawget, because reading env[name] would find the real global through the
	-- __index above and leave the env writing straight to it.
	for name in pairs(CHAINED) do
		if rawget(env, name) == nil and type(_G[name]) == "table" then
			env[name] = setmetatable({}, { __index = _G[name] })
		end
	end

	local includes = overrides.includes or {}
	local realInclude = VFS.Include

	env.VFS.Include = function(path, childEnv, mode)
		local override = includes[path]
		if override ~= nil then
			if type(override) == "function" then
				return override(path, childEnv, mode)
			end

			return override
		end

		return realInclude(path, childEnv or env, mode)
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
