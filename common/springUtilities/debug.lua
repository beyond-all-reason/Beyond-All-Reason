local function paramsEcho(...)
	local called_from = "Called from: " .. tostring(debug.getinfo(2).name) .. " args:"
	Spring.Echo(called_from)
	local args = { ... }
	Spring.Echo( table.toString(args) )
	return ...
end

local function tableEcho(data, name, indent, tableChecked)
	name = name or "TableEcho"
	indent = indent or ""
	if (not tableChecked) and type(data) ~= "table" then
		Spring.Echo(indent .. name, data)
		return
	end
	Spring.Echo(indent .. name .. " = {")
	local newIndent = indent .. "    "
	for name, v in pairs(data) do
		local ty = type(v)
		if ty == "table" then
			tableEcho(v, name, newIndent, true)
		elseif ty == "boolean" then
			Spring.Echo(newIndent .. name .. " = " .. (v and "true" or "false"))
		elseif ty == "string" or ty == "number" then
			Spring.Echo(newIndent .. name .. " = " .. v)
		else
			Spring.Echo(newIndent .. name .. " = ", v)
		end
	end
	Spring.Echo(indent .. "},")
end

return {
	ParamsEcho = paramsEcho,
	TableEcho = tableEcho,
}