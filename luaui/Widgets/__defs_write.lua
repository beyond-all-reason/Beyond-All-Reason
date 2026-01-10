local customparamDefsDetected = false
for _,def in pairs(UnitDefs) do
    if def.customParams and def.customParams.__def ~= nil then
        customparamDefsDetected = true
        break
    end
end

if customparamDefsDetected then

    local excludeScavengers = true

    local widget = widget ---@type Widget

    function widget:GetInfo()
        return {
            name      = "Write customparam.__def to files",
            desc      = "",
            author    = "Bluestone",
            date      = "-1",
            license   = "GNU GPL, v2 or later",
            layer     = 0,
            enabled   = true
        }
    end


-- Localized Spring API for performance
local spEcho = Spring.Echo

	local savedTables = {}

	-- Modified version of table.save, which rounds numbers to avoid lua stupidity 0=0.00000000234876 & various similar stuff

	--------------------------------------------------------------------------------
	--------------------------------------------------------------------------------
	--
	--  file:    savetable.lua
	--  brief:   a human friendly table writer
	--  author:  Dave Rodgers
	--
	--  Copyright (C) 2007.
	--  Licensed under the terms of the GNU GPL, v2 or later.
	--
	--------------------------------------------------------------------------------
	-----

	local indentString = '\t'

	-- setup a lua keyword map
	local keyWords = {
		"and", "break", "do", "else", "elseif", "end", "false", "for", "function",
		"if", "in", "local", "nil", "not", "or", "repeat", "return", "then", "true",
		"until", "while"
	}
	local keyWordSet = {}
	for _,w in ipairs(keyWords) do
		keyWordSet[w] = true
	end
	keyWords = nil  -- don't need the array anymore

	local function encloseStr(s)
		return string.format('%q', s)
	end


	local function encloseKey(s)
		local wrap = not (string.find(s, '^%a[_%a%d]*$'))
		if (not wrap) then
			if (string.len(s) <= 0) then wrap = true end
		end
		if (not wrap) then
			if (keyWordSet[s]) then wrap = true end
		end

		if (wrap) then
			return string.format('[%q]', s)
		else
			return s
		end
	end


	local keyTypes = {
		['string']  = true,
		['number']  = true,
		['boolean'] = true,
	}

	local valueTypes = {
		['string']  = true,
		['number']  = true,
		['boolean'] = true,
		['table']   = true,
	}


	local function CompareKeys(kv1, kv2)
		local k1, v1 = kv1[1], kv1[2]
		local k2, v2 = kv2[1], kv2[2]

		local ktype1 = type(k1)
		local ktype2 = type(k2)
		if (ktype1 ~= ktype2) then
			return (ktype1 > ktype2)
		end

		local vtype1 = type(v1)
		local vtype2 = type(v2)
		if ((vtype1 == 'table') and (vtype2 ~= 'table')) then
			return false
		end
		if ((vtype1 ~= 'table') and (vtype2 == 'table')) then
			return true
		end

		return (k1 < k2)
	end


	local function MakeSortedTable(t)
		local st = {}
		for k,v in pairs(t) do
			if (keyTypes[type(k)] and valueTypes[type(v)]) then
				table.insert(st, { k, v })
			end
		end
		table.sort(st, CompareKeys)
		return st
	end

	local function SaveTable(t, file, indent)
		local indent = indent .. indentString

		local st = MakeSortedTable(t)

		for _,kv in ipairs(st) do
			local k, v = kv[1], kv[2]
			local ktype = type(k)
			local vtype = type(v)
			-- output the key
			if (ktype == 'string') then
				file:write(indent..encloseKey(k)..' = ')
			else
				file:write(indent..'['..tostring(k)..'] = ')
			end
			-- output the value
			if vtype == 'string' then
				file:write(encloseStr(v)..',\n')
			elseif vtype == 'number' then
				if v == math.huge then
					file:write('math.huge,\n')
				elseif (v == -math.huge) then
					file:write('-math.huge,\n')
				else
					if k=="buildcostmetal" or k=="buildcostenergy" or k=="metalpershot" or k=="energypershot" then
						-- round to integer
						v = string.format("%.0f", v)
					else
						-- round to 5dp, convert to string, then remove trailing 0s after decimal point
						v = string.format("%.5f", v)
						local a,b = string.find(v,".")
						if a~= nil then
							v = string.reverse(v)
							while (string.sub(v,1,1)=="0") do
								v = string.sub(v,2)
							end
							if string.sub(v,1,1)=="." then v = string.sub(v,2) end --remove the decimal point, if needed
							v = string.reverse(v)
						end
					end
					file:write(tostring(v)..',\n')
				end
			elseif vtype == 'boolean' then
				file:write(tostring(v)..',\n')
			elseif vtype == 'table' then
				if savedTables[v] then
					error("table.save() does not support recursive tables")
				end
				if next(v) then
					savedTables[t] = true
					file:write('{\n')
					SaveTable(v, file, indent)
					file:write(indent..'},\n')
					savedTables[t] = nil
				else
					file:write('{},\n') -- empty table
				end
			end
		end
	end

    -- second half of a tool for baking unitdefs_post into unitdef files, see readme.txt
    local had_failed = false

	function save2(t, filename, header)
		local file = io.open(filename, 'w')
		if file == nil then
			return
		end
		if header then
			file:write(header..'\n')
		end
		file:write('return {\n')
		if type(t)=="table" or type(t)=="metatable" then SaveTable(t, file, '') end
		file:write('}\n')
		file:close()
		for k,v in pairs(savedTables) do
			savedTables[k] = nil
		end
	end

    function WriteDefToFile (folder, v)
        if not v.customParams or not v.customParams.__def then
            spEcho("Warning: Could not find customparams.__def for " .. v.name)
            return false
        end
        if v.customParams.__def=="omitted" then
            return true -- for omitting weapondefs that are inside the units file, so don't need to be witten into their own file
        end

        local def_string = v.customParams.__def --from table.tostring in post_save_to_customparams
        def_string = "return { " .. v.name .. " = " .. def_string .. "}"
        local f = loadstring(def_string)
        if not f then
            spEcho("Failed to load __def string as table: " .. v.name, def_string)
            return false
        end

        local ud_table = f()
        for k,_ in pairs(ud_table) do -- remove the customParams table if it is empty (note: lower case here!)
            local isEmpty = true
            for k2,_ in pairs(ud_table[k].customparams) do
                isEmpty = false
                break
            end
            if isEmpty then ud_table[k].customparams=nil end
        end

        local subfolder = ''
        if folder == "baked_defs/units" and v.customParams and v.customParams.subfolder then
            subfolder = v.customParams.subfolder .. "/"
            Spring.CreateDir(folder.."/"..subfolder)
        end

        save2(ud_table, folder .. "/" .. subfolder .. v.name .. ".lua")
        return true
    end

    function HandleDefs(Defs, folder)
        local failures = 0

        spEcho("Processing Defs for " .. folder)
        for _,v in pairs(Defs) do
            if not excludeScavengers or not v.name or not string.find(v.name, '_scav') then
                if failures >=3 then break end
                local success = WriteDefToFile("baked_defs/" .. folder, v)
                if (not success) then failures = failures + 1 end
            end
        end

        if failures>0 then
            had_failed = true
            spEcho("Skipping remaining " .. folder .. " defs - too many errors")
        end
        return (failures>0)
    end

    function widget:Initialize()

        -- make folder if does not already exist
        Spring.CreateDir("baked_defs/units")
        Spring.CreateDir("baked_defs/weapons")
        --Spring.CreateDir("baked_defs/features")
        --Spring.CreateDir("baked_defs/armordefs")
        --Spring.CreateDir("baked_defs/movedefs")
        --Spring.CreateDir("baked_defs/effects")

        -- handle the def tables
        HandleDefs(UnitDefs, "units")
        HandleDefs(WeaponDefs, "weapons")
        --HandleDefs(UnitDefs, units)
        --HandleDefs(UnitDefs, units)
        --HandleDefs(UnitDefs, units)
        --HandleDefs(ExplosionDefs, "effects")

        -- warn on failure
        if had_failed==true then
            spEcho("Some unit/weapon __defs failed to be written to file, see errors above")
        elseif had_failed==false then
            spEcho("Wrote all unit/weapon __defs to files")
        end

        -- handle standalone weapondefs
        -- TODO

        widgetHandler:RemoveWidget()
    end


end
