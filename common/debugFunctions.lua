assert(Spring.Utilities, "Spring.Utilities must be initialized before loading debug functions")

local function paramsEcho(...)
	local called_from = "Called from: " .. tostring(debug.getinfo(2).name) .. " args:"
	Spring.Echo(called_from)
	for i,v in ipairs(arg) do
		Spring.Echo(tostring(i) .. ": ".. Spring.Utilities.TableToString(v))
	end
	return ...
end

Debug = {
	ParamsEcho = paramsEcho,
}