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
local minimumbuilddistancerange = 155

local vehAdditionalTurnrate = 0
local vehTurnrateMultiplier = 1.0

local vehAdditionalAcceleration = 0.00
local vehAccelerationMultiplier = 1

local vehAdditionalVelocity = 0
local vehVelocityMultiplier = 1
local vehRSpeedFactor = 0.35

local kbotAdditionalTurnrate = 0
local kbotTurnrateMultiplier = 1.15

local kbotAdditionalAcceleration = 0
local kbotAccelerationMultiplier = 1.15
local kbotBrakerateMultiplier = 1.15

local oldUnitName = {	-- mostly duplicates
	armdecom = 'armcom',
	cordecom = 'corcom',
	armdf = 'armfus',
	corgantuw = 'corgant',
	armshltxuw = 'armshltx',
	armuwmmm = 'armfmmm',
	coruwmmm = 'corfmmm',
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
	if Spring.GetModOptions and (tonumber(Spring.GetModOptions().barmodels) or 0) ~= 0 or string.find(name, '_bar') then
		if string.find(name, '_bar') then
			name = string.gsub(name, '_bar', '')
			if uDef.buildoptions then
				for k, v in pairs(uDef.buildoptions) do
					uDef.buildoptions[k] = v..'_bar'
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
	else	-- normal BA

		if uDef.buildinggrounddecaltype ~= nil then
			local decalname = uDef.buildinggrounddecaltype
			if VFS.FileExists('unittextures/decals/'..decalname) then
				uDef.buildinggrounddecaltype = 'decals/'..decalname
			end
		end
	end


	if uDef.category and uDef.category['chicken'] ~= nil then	-- doesnt seem to work
		uDef.buildtime = uDef.buildtime * 1.5 -- because rezzing is too easy
	end
	
	if uDef.icontype and uDef.icontype == "sea" then
		if uDef.featuredefs and uDef.featuredefs.dead and uDef.featuredefs.dead.metal and uDef.buildcostmetal then
			uDef.featuredefs.dead.metal = uDef.buildcostmetal * 0.5
		end
		if uDef.featuredefs and uDef.featuredefs.heap and uDef.featuredefs.heap.metal and uDef.buildcostmetal then
			uDef.featuredefs.heap.metal = uDef.buildcostmetal * 0.25
		end
		if uDef.featuredefs and uDef.featuredefs.dead and uDef.featuredefs.dead.damage then
			uDef.featuredefs.dead.damage = uDef.featuredefs.dead.damage*2
		end
		if uDef.featuredefs and uDef.featuredefs.heap and uDef.featuredefs.heap.damage then
			uDef.featuredefs.heap.damage = uDef.featuredefs.heap.damage*2
		end
	end
	--Aircraft movements here:
	if uDef.canfly == true and not uDef.hoverattack == true then
		turn = (((uDef.turnrate)*0.16)/360)/30
		wingsurffactor = tonumber(uDef.customparams and uDef.customparams.wingsurface) or 1
		uDef.usesmoothmesh = true
		uDef.wingdrag = 0.07/2 + uDef.brakerate * 2
		uDef.wingangle = 0.08*3/4 + turn/4
		uDef.speedtofront = 0.07*(5/6 + wingsurffactor/6)
		uDef.turnradius = 64
		uDef.maxbank = 0.8
		uDef.maxpitch = 0.8/2 + 0.45/2
		uDef.maxaileron =0.015*3/4 + turn/4
		uDef.maxelevator =0.01*3/4 + turn/4
		uDef.maxrudder = 0.004*3/4 + turn/4
		uDef.maxacc = 0.065/2 + uDef.acceleration/2
	end
	-- Enable default Nanospray
	uDef.shownanospray = true

	-- vehicles
	if uDef.category and string.find(uDef.category, "TANK") then
		if uDef.turnrate ~= nil then
			uDef.turnrate = (uDef.turnrate + vehAdditionalTurnrate) * vehTurnrateMultiplier
		end
		
		if uDef.acceleration ~= nil then
			uDef.acceleration = (uDef.acceleration + vehAdditionalAcceleration) * vehAccelerationMultiplier
		end

		if uDef.maxvelocity ~= nil then
			uDef.maxvelocity = (uDef.maxvelocity + vehAdditionalVelocity) * vehVelocityMultiplier
		end
	end

	-- kbots
	if uDef.category and string.find(uDef.category, "KBOT") then
		if uDef.turnrate ~= nil then
			uDef.turnrate = (uDef.turnrate + kbotAdditionalTurnrate) * kbotTurnrateMultiplier
		end

		if uDef.acceleration ~= nil then
			uDef.acceleration = (uDef.acceleration + kbotAdditionalAcceleration) * kbotAccelerationMultiplier
		end

		if uDef.brakerate ~= nil then
			uDef.brakerate = uDef.brakerate * kbotBrakerateMultiplier
		end
		
		uDef.turninplace = true
		uDef.turninplaceanglelimit = 90
	end

	--Set a minimum for builddistance
	if uDef.builddistance ~= nil and uDef.builddistance < minimumbuilddistancerange then
		uDef.builddistance = minimumbuilddistancerange
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
	
  -- artificial Armordefs tree: Default < heavyunits < hvyboats, allows me to specify bonus damages towards ships
	if (not (wDef["damage"].hvyboats)) and (wDef["damage"].heavyunits) then 
		wDef["damage"].hvyboats = wDef["damage"].heavyunits 
	elseif (not (wDef["damage"].hvyboats)) and (not wDef["damage"].heavyunits) then 
		wDef["damage"].hvyboats = wDef["damage"].default
	end
  -- end of artificial ArmorDefs tree
 
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
