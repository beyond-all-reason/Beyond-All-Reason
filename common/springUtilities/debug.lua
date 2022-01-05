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

local function traceEcho(...)
	local myargs = {...}
	infostr = ""
	for i,v in ipairs(myargs) do
		infostr = infostr .. tostring(v) .. "\t"
	end
	if infostr ~= "" then infostr = infostr .. " " end 
	local functionstr = "Trace:["
	for i = 2, 10 do
		if debug.getinfo(i) then
			local funcName = (debug and debug.getinfo(i) and debug.getinfo(i).name)
			if funcName then
				functionstr = functionstr .. tostring(funcName) .. " <- "
			else break end
		else break end
	end
	functionstr = functionstr .. "]"
	local arguments = ""
	local funcName1 = (debug and debug.getinfo(2) and debug.getinfo(2).name) or "??"
	if funcName1 ~= "??" then 
		for i = 1, 10 do
			local name, value = debug.getlocal(2, i)
			if not name then break end
			local sep = ((arguments == "") and "") or  "; "
			arguments = arguments .. sep .. ((name and tostring(name)) or "name?") .. "=" .. tostring(value)
		end
	end
	Spring.Echo(infostr .. functionstr .. " Args:(" .. arguments .. ")")
end

return {
	ParamsEcho = paramsEcho,
	TableEcho = tableEcho,
	TraceEcho = traceEcho,
}