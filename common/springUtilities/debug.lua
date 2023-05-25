local function paramsEcho(...)
    local called_from = "Called from: " .. debug.getinfo(2, "n").name .. " args:"
    Spring.Echo(called_from)
    local args = {...}
    Spring.Echo(table.concat(args, ", "))
    return ...
end

local function tableEcho(data, name, indent, tableChecked)
    name = name or "TableEcho"
    indent = indent or ""
    if not tableChecked and type(data) ~= "table" then
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
            Spring.Echo(newIndent .. name .. " = " .. tostring(v))
        elseif ty == "string" or ty == "number" then
            Spring.Echo(newIndent .. name .. " = " .. tostring(v))
        else
            Spring.Echo(newIndent .. name .. " = " .. tostring(v))
        end
    end
    Spring.Echo(indent .. "},")
end

local function traceEcho(...)
    local myargs = table.pack(...)
    local infostr = table.concat(myargs, "\t") .. " "
    local functionstr = "Trace:["
    for i = 2, 10 do
        local info = debug.getinfo(i, "nS")
        if info then
            local funcName = info.name or "?"
            functionstr = functionstr .. tostring(funcName) .. " <- "
        else
            break
        end
    end
    functionstr = functionstr .. "]"
    local arguments = ""
    local funcName1 = debug.getinfo(2, "n").name or "?"
    if funcName1 ~= "?" then
        for i = 1, 10 do
            local name, value = debug.getlocal(2, i)
            if not name then break end
            local sep = (arguments == "") and "" or "; "
            arguments = arguments .. sep .. (name or "name?") .. "=" .. tostring(value)
        end
    end
    Spring.Echo(infostr .. functionstr .. " Args:(" .. arguments .. ")")
end

local function traceFullEcho(maxdepth, maxwidth, maxtableelements, ...)
    if not debug then
        Spring.Echo("traceFullEcho needs debug to work, this seems to be missing or overwritten", debug)
        return
    end
    maxdepth = maxdepth or 16
    maxwidth = maxwidth or 10
    maxtableelements = maxtableelements or 6

    local function dbgt(t, maxtableelements)
        local count = 0
        local res = ""
        for k, v in pairs(t) do
            count = count + 1
            if count < maxtableelements then
                if type(k) == "number" and type(v) == "function" then
                    res = res .. tostring(k) .. ":" .. ((debug.getinfo(v) and debug.getinfo(v).name) or "<function>") .. ", "
                else
                    res = res .. tostring(k) .. ":" .. tostring(v) .. ", "
                end
            end
        end
        res = "{" .. res .. "}[#".. count .."]"
        return res
    end

    local myargs = table.pack(...)
    local infostr = "TraceFullEcho:["
    for i = 1, myargs.n do
        infostr = infostr .. tostring(myargs[i]) .. "\t"
    end
    infostr = infostr .. "]"

    local functionstr = ""
    for i = 2, maxdepth do
        local info = debug.getinfo(i, "nSl")
        if info then
            local funcName = info.name or "?"
            functionstr = functionstr .. tostring(i - 1) .. ": " .. tostring(funcName) .. " "
            if info.source and string.len(info.source) <= 128 then
                functionstr = functionstr .. "@" .. info.source
            end
            if info.linedefined then
                functionstr = functionstr .. ":" .. tostring(info.linedefined)
            end

            local arguments = ""
            if funcName ~= "?" then
                for j = 1, maxwidth do
                    local name, value = debug.getlocal(i, j)
                    if not name then break end
                    local sep = (arguments == "") and "" or "; "
                    if tostring(name) == "self" then
                        arguments = arguments .. sep .. (name or "name?") .. "=" .. tostring("??")
                    else
                        local newvalue = maxtableelements > 0 and type({}) == type(value) and dbgt(value, maxtableelements) or value
                        arguments = arguments .. sep .. (name or "name?") .. "=" .. tostring(newvalue)
                    end
                end
            end

            functionstr = functionstr .. " Locals:(" .. arguments .. ")\n"
        else
            break
        end
    end

    Spring.Echo(infostr .. functionstr)
end

return {
    ParamsEcho = paramsEcho,
    TableEcho = tableEcho,
    TraceEcho = traceEcho,
    TraceFullEcho = traceFullEcho,
}
