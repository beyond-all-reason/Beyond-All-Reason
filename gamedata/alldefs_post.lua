--------------------------
-- DOCUMENTATION
-------------------------

-- BAR contains weapondefs in its unitdef files
-- Standalone weapondefs are only loaded by Spring after unitdefs are loaded
-- So, if we want to do post processing and include all the unit+weapon defs, and have the ability to bake these changes into files, we must do it after both have been loaded
-- That means, ALL UNIT AND WEAPON DEF POST PROCESSING IS DONE HERE

-- What happens:
-- unitdefs_post.lua calls the _Post functions for unitDefs and any weaponDefs that are contained in the unitdef files
-- unitdefs_post.lua writes the corresponding unitDefs to customparams (if wanted)
-- weapondefs_post.lua fetches any weapondefs from the unitdefs, 
-- weapondefs_post.lua fetches the standlaone weapondefs, calls the _post functions for them, writes them to customparams (if wanted)
-- strictly speaking, alldefs.lua is a misnomer since this file does not handle armordefs, featuredefs or movedefs

-- Switch for when we want to save defs into customparams as strings (so as a widget can then write them to file)
-- The widget to do so can be found in 'etc/Lua/bake_unitdefs_post'
SaveDefsToCustomParams = false


-------------------------
-- DEFS POST PROCESSING
-------------------------

-- process unitdef
--local vehAdditionalTurnrate = 0
--local vehTurnrateMultiplier = 1.0
--
--local vehAdditionalAcceleration = 0.00
--local vehAccelerationMultiplier = 1
--
--local vehAdditionalVelocity = 0
--local vehVelocityMultiplier = 1



local function getFilePath(filename, path)
	local files = VFS.DirList(path, '*.lua')
	for i=1,#files do
		if path..filename == files[i] then
			return path
		end
	end
	local subdirs = VFS.SubDirs(path)
	for i=1,#subdirs do
		local result = getFilePath(filename, subdirs[i])
		if result then
			return result
		end
	end
	return false
end

local function lines(str)
	local t = {}
	local function helper(line) table.insert(t, line) return "" end
	helper((str:gsub("(.-)\r?\n", helper)))
	return t
end

local function Split(s, separator)
	local results = {}
	for part in s:gmatch("[^"..separator.."]+") do
		results[#results + 1] = part
	end
	return results
end


function UnitDef_Post(name, uDef)

    -- vehicles
    --if uDef.category and string.find(uDef.category, "TANK") then
    --	if uDef.turnrate ~= nil then
    --		uDef.turnrate = (uDef.turnrate + vehAdditionalTurnrate) * vehTurnrateMultiplier
    --	end
    --    	if uDef.acceleration ~= nil then
    --		uDef.acceleration = (uDef.acceleration + vehAdditionalAcceleration) * vehAccelerationMultiplier
    --	end
    --    	if uDef.maxvelocity ~= nil then
    --		uDef.maxvelocity = (uDef.maxvelocity + vehAdditionalVelocity) * vehVelocityMultiplier
    --	end
    --end



	-- import csv unitdef changes
	--local file = VFS.LoadFile("modelauthors.csv")
	--if file then
	--	local fileLines = lines(file)
	--	local found = false
	--	for i, line in ipairs(fileLines) do
	--		local t = Split(line, ';')
	--		if t[1] and t[2] and t[3] then
	--			if t[1] == name then
	--				if uDef.customparams == nil then
	--					uDef.customparams = {}
	--				end
	--				uDef.customparams.model_author = t[3]
	--				Spring.Echo('imported:  '..t[1]..':  '..t[2]..'  ,  '..t[3])
	--				found = true
	--				break
	--			end
	--		end
	--	end
	--	if not found then
	--		for i, line in ipairs(fileLines) do
	--			local t = Split(line, ';')
	--			if t[1] and t[2] and t[3] then
	--				if t[2] == uDef.name then
	--					if uDef.customparams == nil then
	--						uDef.customparams = {}
	--					end
	--					uDef.customparams.model_author = t[3]
	--					Spring.Echo('imported2:  '..t[1]..':  '..t[2]..'  ,  '..t[3])
	--					found = true
	--					break
	--				end
	--			end
	--		end
	--	end
	--end

	--local filename = "unitlist_checked.csv"
	--local file = VFS.LoadFile(filename)
	--if file then
	--	local fileLines = lines(file)
	--	for i, line in ipairs(fileLines) do
	--		local t = Split(line, ';')
	--		if t[1] and t[2] and t[3] and name == t[1] then
	--			uDef.buildcostmetal = tonumber(t[2])
	--			uDef.buildcostenergy = tonumber(t[3])
	--			Spring.Echo('imported:  '..t[1]..':  '..t[2]..'  ,  '..t[3])
	--		end
	--	end
	--else
	--	Spring.Echo('import file not found: '..filename)
	--end

	-- usable when baking ... keeping subfolder structure
	if SaveDefsToCustomParams then
		local filepath = getFilePath(name..'.lua', 'units/')
		if filepath then
			if not uDef.customparams then
				uDef.customparams = {}
			end
			uDef.customparams.subfolder = string.sub(filepath, 7, #filepath-1)
		end
	end
end


-- process weapondef
function WeaponDef_Post(name, wDef)

	--Use targetborderoverride in weapondef customparams to override this global setting
	--Controls whether the weapon aims for the center or the edge of its target's collision volume. Clamped between -1.0 - target the far border, and 1.0 - target the near border.
	if wDef.customparams and wDef.customparams.targetborderoverride == nil then
		wDef.targetborder = 0.75 --Aim for just inside the hitsphere
	elseif wDef.customparams and wDef.customparams.targetborderoverride ~= nil then
		wDef.targetborder = tonumber(wDef.customparams.targetborderoverride)
	end

	wDef.cratermult = (wDef.cratermult or 1) * 0.3 -- modify cratermult cause Spring v103 made too big craters

	-- Target borders of unit hitboxes rather than center (-1 = far border, 0 = center, 1 = near border)
	-- wDef.targetborder = 1.0


	if wDef.weapontype == "Cannon" then
		if wDef.stages == nil then
			wDef.stages = 10
			if wDef.damage ~= nil and wDef.damage.default ~= nil and wDef.areaofeffect ~= nil then
				wDef.stages = math.floor(7.5 + math.min(wDef.damage.default * 0.0033, wDef.areaofeffect * 0.13))
				wDef.alphadecay = 1 - ((1/wDef.stages)/1.5)
				wDef.sizedecay = 0.4 / wDef.stages
			end
		end
	end

	if wDef.damage ~= nil then
		wDef.damage.indestructable = 0
	end

	if wDef.weapontype == "BeamLaser" then
		if wDef.beamttl == nil then
			wDef.beamttl = 3
			wDef.beamdecay = 0.7
		end
	end
end

-- process effects
function ExplosionDef_Post(name, eDef)
	--[[
    -- WIP on #645
    Spring.Echo(name)
    for k,v in pairs(eDef) do
        Spring.Echo(" ", k, v, type(k), type(v))
        if type(v)=="table" then
            for k1,v1 in pairs(v) do
                Spring.Echo("  ", k1,v1)
            end
        end
    end
    if eDef.usedefaultexplosions=="1" then

    end
    ]]
end



--------------------------
-- MODOPTIONS
-------------------------

-- process modoptions (last, because they should not get baked)
function ModOptions_Post (UnitDefs, WeaponDefs)
	if (Spring.GetModOptions) then
	local modOptions = Spring.GetModOptions() or {}
	local map_tidal = modOptions and modOptions.map_tidal
		if map_tidal and map_tidal ~= "unchanged" then
			for id, unitDef in pairs(UnitDefs) do
				if unitDef.tidalgenerator == 1 then
					unitDef.tidalgenerator = 0
					if map_tidal == "low" then
						unitDef.energymake = 13
					elseif map_tidal == "medium" then
						unitDef.energymake = 18
					elseif map_tidal == "high" then
						unitDef.energymake = 23
					end
				end
			end
		end

		-- transporting enemy coms
		if (modOptions.transportenemy == "notcoms") then
			for name,ud in pairs(UnitDefs) do  
				if (name == "armcom" or name == "corcom" or name == "armdecom" or name == "cordecom") then
					ud.transportbyenemy = false
				end
			end
		elseif (modOptions.transportenemy == "none") then
			for name, ud in pairs(UnitDefs) do  
				ud.transportbyenemy = false
			end
		end
	end

	--[[
	-- Make BeamLasers do their damage up front instead of over time
	-- Do this at the end so that we don't mess up any magic math
	for id,wDef in pairs(WeaponDefs) do
		-- Beamlasers do damage up front
		if wDef.beamtime ~= nil then
			beamTimeInFrames = wDef.beamtime * 30
			--Spring.Echo(wDef.name)
			--Spring.Echo(beamTimeInFrames)
			wDef.beamttl = beamTimeInFrames
			--Spring.Echo(wDef.beamttl)
			wDef.beamtime = 0.01		
		end
	end
	]]--
end
