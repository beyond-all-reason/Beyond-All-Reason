assert(Spring.Utilities, "Spring.Utilities must be initialized before loading debug functions")

local function paramsEcho(...)
	local called_from = "Called from: " .. tostring(debug.getinfo(2).name) .. " args:"
	Spring.Echo(called_from)
	local args = { ... }
	Spring.Echo( Spring.Utilities.TableToString(args) )
	return ...
end

return {
	ParamsEcho = paramsEcho,
}