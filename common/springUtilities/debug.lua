local function paramsEcho(...)
	local called_from = "Called from: " .. tostring(debug.getinfo(2).name) .. " args:"
	SpringShared.Echo(called_from)
	local args = { ... }
	SpringShared.Echo( table.toString(args) )
	return ...
end

local function traceEcho(...)
	local myargs = {...}
	local parts = {}
	local n = 0
	for i = 1, #myargs do
		n = n + 1; parts[n] = tostring(myargs[i])
		n = n + 1; parts[n] = "\t"
	end
	local infostr = n > 0 and (table.concat(parts) .. " ") or ""
	local functionstr = "Trace:["
	for i = 2, 10 do
		local info = debug.getinfo(i)
		if info then
			local funcName = info.name
			if funcName then
				functionstr = functionstr .. tostring(funcName) .. " <- "
			else break end
		else break end
	end
	functionstr = functionstr .. "]"
	local arguments = ""
	local info2 = debug and debug.getinfo(2)
	local funcName1 = (info2 and info2.name) or "??"
	if funcName1 ~= "??" then 
		for i = 1, 10 do
			local name, value = debug.getlocal(2, i)
			if not name then break end
			local sep = ((arguments == "") and "") or  "; "
			arguments = arguments .. sep .. ((name and tostring(name)) or "name?") .. "=" .. tostring(value)
		end
	end
	SpringShared.Echo(infostr .. functionstr .. " Args:(" .. arguments .. ")")
end

local function traceFullEcho(maxdepth, maxwidth, maxtableelements, ...)
    -- Call it at any point, and it will give you the name of each function on the stack (up to maxdepth), 
	-- all arguments and first #maxwidth local variables of that function
	-- if any of the values of the locals are tables, then it will try to shallow print + count them up to maxtablelements numbers. 
	-- It will also just print any args after the first 3. (the ... part)
	-- It will also try to print the source file+line of each function
	if (debug) then 
	else
		SpringShared.Echo("traceFullEcho needs debug to work, this seems to be missing or overwritten", debug)
		return
	end
	local tracedebug = false -- to debug itself
	local functionsource = true
	maxdepth = maxdepth or 16
	maxwidth = maxwidth or 10
    maxtableelements = maxtableelements or 6 -- max amount of elements to expand from table type values

    local function dbgt(t, maxtableelements)
        local count = 0
        local res = ''
        for k,v in pairs(t) do
            count = count + 1
            if count < maxtableelements then
				if tracedebug then SpringShared.Echo(count, k) end 
				if type(k) == "number" and type(v) == "function" then -- try to get function lists?
					local vinfo = debug.getinfo(v)
					if tracedebug then SpringShared.Echo(k,v, vinfo, vinfo.name) end  --debug.getinfo(v).short_src)?
                	res = res .. tostring(k) .. ':' .. ((vinfo and vinfo.name) or "<function>") ..', '
				else
                	res = res .. tostring(k) .. ':' .. tostring(v) ..', '
				end
            end
        end
        res = '{'..res .. '}[#'..count..']'
        return res
    end

	local myargs = {...}
	local infostr = "TraceFullEcho:["
	for i,v in ipairs(myargs) do
		infostr = infostr .. tostring(v) .. "\t"
	end
	infostr = infostr .. "]\n"
	local functionstr = "" -- "Trace:["
	for i = 2, maxdepth do
		local info = debug.getinfo(i)
		if info then
			local funcName = info.name
			if funcName then
				functionstr = functionstr .. tostring(i-1) .. ": " .. tostring(funcName) .. " "
				local arguments = ""
				if funcName ~= "??" then
					if functionsource and info.source then 
						local source = info.source 
						if string.len(source) > 128 then source = "sourcetoolong" end
						functionstr = functionstr .. " @" .. source
					end 
					if functionsource and info.linedefined then 
						functionstr = functionstr .. ":" .. tostring(info.linedefined) 
					end 
					for j = 1, maxwidth do
						local name, value = debug.getlocal(i, j)
						if not name then break end
						if tracedebug then SpringShared.Echo(i,j, funcName,name) end 
						local sep = ((arguments == "") and "") or  "; "
                        if tostring(name) == 'self'  then
    						arguments = arguments .. sep .. ((name and tostring(name)) or "name?") .. "=" .. tostring("??")
                        else
                            local newvalue
                            if maxtableelements > 0 and type({}) == type(value) then newvalue = dbgt(value, maxtableelements) else newvalue = value end 
    						arguments = arguments .. sep .. ((name and tostring(name)) or "name?") .. "=" .. tostring(newvalue)
                        end
					end
				end
				functionstr  = functionstr .. " Locals:(" .. arguments .. ")" .. "\n"
			else 
				functionstr = functionstr .. tostring(i-1) .. ": ??\n"
			end
		else break end
	end
	SpringShared.Echo(infostr .. functionstr)
end

return {
	ParamsEcho = paramsEcho,
	TraceEcho = traceEcho,
	TraceFullEcho = traceFullEcho,
}