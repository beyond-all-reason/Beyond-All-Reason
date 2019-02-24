--------------------------
-- DOCUMENTATION
-------------------------

-- BA contains weapondefs in its unitdef files
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
local vehAdditionalTurnrate = 0
local vehTurnrateMultiplier = 1.0

local vehAdditionalAcceleration = 0.00
local vehAccelerationMultiplier = 1

local vehAdditionalVelocity = 0
local vehVelocityMultiplier = 1



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

local oldUnitName = {	-- mostly duplicates
	armdecom = 'armcom',
	cordecom = 'corcom',
	armdf = 'armfus',
	corgantuw = 'corgant',
	armshltxuw = 'armshltx',
}


function getBarSound(name)
	if name == nil or name == '' then
		return name
	end
	local filename = 'bar_'..string.gsub(name, ".wav", "")
	if VFS.FileExists('sounds/BAR/ui/'..filename..".wav") then
		return filename
	elseif VFS.FileExists('sounds/BAR/replies/'..filename..".wav") then
		return filename
	elseif VFS.FileExists('sounds/BAR/weapons/'..filename..".wav") then
		return filename
	else
		return name
	end
end


function UnitDef_Post(name, uDef)
	-- load BAR stuff
	if (Spring.GetModOptions and (tonumber(Spring.GetModOptions().barmodels) or 0) ~= 0 or string.find(name, '_bar')) and not ((Spring.GetModOptions and (Spring.GetModOptions().unba or "disabled") == "enabled") and (name == "armcom" or name == "corcom" or name == "armcom_bar" or name == "corcom_bar"))  then
		if string.find(name, '_bar') then
			name = string.gsub(name, '_bar', '')
			if uDef.buildoptions then
				for k, v in pairs(uDef.buildoptions) do
					if UnitDefs[v..'_bar'] then
						uDef.buildoptions[k] = v..'_bar'
					end
				end
			end
		end
		-- BAR models
		local barUnitName = oldUnitName[name] and oldUnitName[name] or name
		if VFS.FileExists('objects3d/BAR/'..uDef.objectname..'.s3o') or VFS.FileExists('objects3d/BAR/'..barUnitName..'.s3o') then
			local object = barUnitName
			if VFS.FileExists('objects3d/BAR/'..uDef.objectname..'.s3o') then
				object = uDef.objectname
			end
			uDef.objectname = 'BAR/'..object..'.s3o'
			if uDef.featuredefs ~= nil then
				for fDefID,featureDef in pairs(uDef.featuredefs) do
					if featureDef.object ~= nil then
						local object = string.gsub(featureDef.object, ".3do", "")
						if VFS.FileExists('objects3d/BAR/'..object:lower()..".s3o") then
							uDef.featuredefs[fDefID].object = 'BAR/'..object:lower()..".s3o"
						end
					end
				end
			end
            if uDef.script ~= nil and VFS.FileExists('scripts/BAR/bar_'..uDef.script) then
                uDef.script = 'BAR/'..uDef.script
            elseif VFS.FileExists('scripts/BAR/bar_'..object..'.lua') then
                uDef.script = 'BAR/bar_'..object..'.lua'
			elseif VFS.FileExists('scripts/BAR/bar_'..object..'.cob') then
				uDef.script = 'BAR/bar_'..object..'.cob'
			end

			if uDef.buildinggrounddecaltype ~= nil then
				local decalname = oldUnitName[name] and string.gsub(uDef.buildinggrounddecaltype, name, object) or uDef.buildinggrounddecaltype
				decalname = string.gsub(decalname, 'decals/', '')
				if VFS.FileExists('unittextures/decals/BAR/'..decalname) then
					uDef.buildinggrounddecaltype = 'decals/BAR/'..decalname
			 	end
			end
			if uDef.buildpic ~= nil then
				local buildpicname = oldUnitName[name] and string.gsub(uDef.buildpic, name, object) or uDef.buildpic
				if VFS.FileExists('unitpics/BAR/'..buildpicname) then
					uDef.buildpic = 'BAR/'..buildpicname
				end
			end

			if string.find(name, 'arm') or string.find(name, 'cor') or string.find(name, 'chicken') then
				uDef.customparams.normalmaps = "yes"
				if string.find(name, 'arm') then
					uDef.customparams.normaltex = "unittextures/Arm_normals.dds"
				elseif string.find(name, 'cor') then
					uDef.customparams.normaltex = "unittextures/Core_normal.dds"
				elseif string.find(name, 'chicken') then
					uDef.customparams.normaltex = "unittextures/chicken_normal.tga"
				end
			end

			for paramName, paramValue in pairs(uDef.customparams) do
				if paramName:sub(1,4) == "bar_" then
					local param = string.sub(paramName, 5)
					if tonumber(param) then
						uDef[param] = tonumber(paramValue)
					else
						uDef[param] = paramValue
					end
				end
			end
		end

		-- BAR heap models
		if uDef.featuredefs then
			local faction = 'cor'
			if string.find(name, 'arm') then
				faction = 'arm'
			end
			if uDef.featuredefs.heap and uDef.featuredefs.heap.object and VFS.FileExists('objects3d/BAR/'..faction..uDef.featuredefs.heap.object..".s3o") then
				uDef.featuredefs.heap.object = 'BAR/'..faction..uDef.featuredefs.heap.object..".s3o"
			end

			for fname, params in pairs(uDef.featuredefs) do
				if params.object then
					if VFS.FileExists('objects3d/'..params.object) then

					elseif VFS.FileExists('objects3d/'..params.object..".3do") then

					elseif VFS.FileExists('objects3d/'..params.object..".s3o") then
						uDef.featuredefs[fname].object = params.object..'.s3o'
					else
						Spring.Echo('3d object does not exist:  unit: '..name..'   featurename: '..fname..'   object: '..uDef.featuredefs[fname].object)
						uDef.featuredefs[fname].object = ''
					end
				end
			end
		end

		-- BAR sounds
		if (tonumber(Spring.GetModOptions().barsounds) or 0) ~= 0 then
			if uDef.sounds and type(uDef.sounds) == 'table' then
				for sound, soundParams in pairs(uDef.sounds) do
					if type(soundParams) == 'string' then
						uDef.sounds[sound] = getBarSound(soundParams)
					elseif type(soundParams) == 'table' then
						for i, value in pairs(soundParams) do
							if type(value) == 'string' then
								uDef.sounds[sound][value] = getBarSound(value)
							elseif type(value) == 'table' then
								uDef.sounds[sound][value].file = getBarSound(value.file)
							end
						end
					end
				end
			end
		end
	end


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

	-- EdgeEffectiveness global buff to counterbalance smaller hitboxes
	wDef.edgeeffectiveness = (tonumber(wDef.edgeeffectiveness) or 0) + 0.15
	if wDef.edgeeffectiveness >= 1 then
	    wDef.edgeeffectiveness = 1
	end

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

	--Flare texture has been scaled down to half, so correcting the result of that a bit
	if wDef ~= nil and wDef.laserflaresize ~= nil and wDef.laserflaresize > 0 then
		wDef.laserflaresize = wDef.laserflaresize * 1.1
	end


	if Spring.GetModOptions and (tonumber(Spring.GetModOptions().barmodels) or 0) ~= 0 or string.find(name, '_bar') then
		if string.find(name, '_bar') then
			name = string.gsub(name, '_bar', '')
		end

		-- load BAR weapon model
		if wDef.customparams and wDef.customparams.bar_model then
			wDef.model = wDef.customparams.bar_model
		end

		-- load BAR alternative sound
		if (tonumber(Spring.GetModOptions().barsounds) or 0) ~= 0 then
			if wDef.soundstart ~= '' then
				wDef.soundstart = getBarSound(wDef.soundstart)
			end
			if wDef.soundhit ~= '' then
				wDef.soundhit = getBarSound(wDef.soundhit)
			end
			if wDef.soundhitdry ~= '' then
				wDef.soundhitdry = getBarSound(wDef.soundhitdry)
			end
			if wDef.soundhitwet ~= '' then
				wDef.soundhitwet = getBarSound(wDef.soundhitwet)
			end

			-- load bar alternative defs
			if wDef.customparams then
				for paramName, paramValue in pairs(wDef.customparams) do
					if paramName:sub(1,4) == "bar_" then
						local param = string.sub(paramName, 5)

						--if param == 'model' and VFS.FileExists('objects3d/'..paramValue) then
						--	wDef.model = 'objects3d/bar_'..paramValue
						--end
						if tonumber(param) then
							wDef[param] = tonumber(paramValue)
						else
							wDef[param] = paramValue
						end
					end
				end
			end
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
