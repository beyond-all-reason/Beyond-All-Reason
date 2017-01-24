-- could become mother of all types of explosions

local explosion = {

}




function tableMerge(t1, t2)
    for k,v in pairs(t2) do
    	if type(v) == "table" then
    		if type(t1[k] or false) == "table" then
    			tableMerge(t1[k] or {}, t2[k] or {})
    		else
    			t1[k] = v
    		end
    	else
    		t1[k] = v
    	end
    end
    return t1
end

function deepcopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[deepcopy(orig_key)] = deepcopy(orig_value)
        end
        setmetatable(copy, deepcopy(getmetatable(orig)))
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end


local definitions = {}
definitions['explotest'] = explosion



-- add different sizes
local types = {"genericshellgexplosion","genericunitexplosion","genericbuildingexplosion"}
local sizes = {
	tiny = {
		scale = 0.4,
	},
	small = {
		scale = 1,
	},
	medium = {
		scale = 2.5,
	},
	large = {
		scale = 5,
	},
	huge = {
		scale = 10,
	},
}

--for size, effects in pairs(sizes) do
--	definitions[root.."-"..size] = tableMerge(deepcopy(definitions[root.."-small"]), deepcopy(effects))
--end

-- add coloring
--local colors = {
--	--blue = {
--	--	groundflash = {
--	--		color = {0.15,0.15,1},
--	--	}
--	},
--}
--for color, effects in pairs(colors) do
--	for size, e in pairs(sizes) do
--		definitions[root.."-"..size.."-"..color] = tableMerge(deepcopy(definitions[root.."-"..size]), deepcopy(effects))
--	end
--end

return definitions