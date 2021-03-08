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
-- The widget to do so is included in the game and detects these customparams auto-enables itself
-- and writes them to Spring/baked_defs
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


--[[ Sanitize to whole frames (plus leeways because float arithmetic is bonkers).
     The engine uses full frames for actual reload times, but forwards the raw
     value to LuaUI (so for example calculated DPS is incorrect without sanitisation). ]]
local function round_to_frames(name, wd, key)
	local original_value = wd[key]
	if not original_value then
		-- even reloadtime can be nil (shields, death explosions)
		return
	end

  local Game_gameSpeed = 30 --for mission editor backwards compat (engine 104.0.1-287)
  if Game and Game.gameSpeed then Game_gameSpeed = Game.gameSpeed end

	local frames = math.max(1, math.floor((original_value + 1E-3) * Game_gameSpeed))

	local sanitized_value = frames / Game_gameSpeed
	if math.abs (original_value - sanitized_value) > 1E-3 then
		--Spring.Echo(name.."."..key.. " = " .. original_value .. "  ->  " .. sanitized_value .. "  ingame!  difference: "..sanitized_value-original_value)
	end

	return sanitized_value-- + 1E-5
end

local function processWeapons(unitDefName, unitDef)
	local weaponDefs = unitDef.weapondefs
	if not weaponDefs then
		return
	end

	for weaponDefName, weaponDef in pairs (weaponDefs) do
		local fullWeaponName = unitDefName .. "." .. weaponDefName
		weaponDef.reloadtime = round_to_frames(fullWeaponName, weaponDef, "reloadtime")
		weaponDef.burstrate = round_to_frames(fullWeaponName, weaponDef, "burstrate")
	end
end

function UnitDef_Post(name, uDef)
	if not uDef.customparams then
		uDef.customparams = {}
	end

	-- Unit Restrictions
	if uDef.customparams then
		if not uDef.customparams.techlevel then uDef.customparams.techlevel = 0 end
		if not uDef.customparams.subfolder then uDef.customparams.subfolder = "none" end

		if Spring.GetModOptions and tonumber(Spring.GetModOptions().unit_restrictions_notech2) == 1 then
			if tonumber(uDef.customparams.techlevel) == 2 or tonumber(uDef.customparams.techlevel) == 3 then
				uDef.unitrestricted = 0
			end
		end

		if Spring.GetModOptions and tonumber(Spring.GetModOptions().unit_restrictions_notech3) == 1 then
			if tonumber(uDef.customparams.techlevel) == 3 then
				uDef.unitrestricted = 0
			end
		end

		if Spring.GetModOptions and tonumber(Spring.GetModOptions().unit_restrictions_noair) == 1 then
			if string.find(uDef.customparams.subfolder, "Aircraft") then
				uDef.unitrestricted = 0
			elseif uDef.canfly then
				uDef.unitrestricted = 0
			end
			local AircraftFactories = {
				armap = true,
				armaap = true,
				armplat = true,
				corap = true,
				coraap = true,
				corplat = true,
			}
			if AircraftFactories[name] then
				uDef.unitrestricted = 0
			end
		end

		if Spring.GetModOptions and tonumber(Spring.GetModOptions().unit_restrictions_noconverters) == 1 then
			if uDef.customparams.energyconv_capacity and uDef.customparams.energyconv_efficiency then
				uDef.unitrestricted = 0
			end
		end

		if Spring.GetModOptions and tonumber(Spring.GetModOptions().unit_restrictions_nonukes) == 1 then
			local Nukes = {
				armamd = true,
				armsilo = true,
				armscab = true,
				corfmd = true,
				corsilo = true,
				cormabm = true,
			}
			if Nukes[name] then
				uDef.unitrestricted = 0
			end
		end

		if Spring.GetModOptions and tonumber(Spring.GetModOptions().unit_restrictions_notacnukes) == 1 then
			local TacNukes = {
				armemp = true,
				cortron = true,
			}
			if TacNukes[name] then
				uDef.unitrestricted = 0
			end
		end
	end


	-- Add scav units to normal factories and builders
	if Spring.GetModOptions and Spring.GetModOptions().experimentalscavuniqueunits == "enabled" then
		if name == "armshltx" then
			local numBuildoptions = #uDef.buildoptions
			uDef.buildoptions[numBuildoptions+1] = "armrattet4"
			uDef.buildoptions[numBuildoptions+2] = "armsptkt4"
			uDef.buildoptions[numBuildoptions+3] = "armpwt4"
			uDef.buildoptions[numBuildoptions+4] = "armvadert4"
			uDef.buildoptions[numBuildoptions+5] = "armlunchbox"
			uDef.buildoptions[numBuildoptions+6] = "armmeatball"
			uDef.buildoptions[numBuildoptions+7] = "armassimilator"
			uDef.buildoptions[numBuildoptions+8] = "armrectrt4"
		elseif name == "armshltxuw" then
			local numBuildoptions = #uDef.buildoptions
			uDef.buildoptions[numBuildoptions+1] = "armrattet4"
			uDef.buildoptions[numBuildoptions+2] = "armpwt4"
			uDef.buildoptions[numBuildoptions+3] = "armvadert4"
			uDef.buildoptions[numBuildoptions+4] = "armmeatball"
		elseif name == "corgant" then
			local numBuildoptions = #uDef.buildoptions
			uDef.buildoptions[numBuildoptions+1] = "cordemont4"
			uDef.buildoptions[numBuildoptions+2] = "corkarganetht4"
			uDef.buildoptions[numBuildoptions+3] = "corgolt4"
		elseif name == "corgantuw" then
			local numBuildoptions = #uDef.buildoptions
			uDef.buildoptions[numBuildoptions+1] = "corgolt4"
		elseif name == "coravp" then
			local numBuildoptions = #uDef.buildoptions
			uDef.buildoptions[numBuildoptions+1] = "corgatreap"
		elseif name == "armaca" or name == "armack" or name == "armacv" then
			local numBuildoptions = #uDef.buildoptions
			uDef.buildoptions[numBuildoptions+1] = "armapt3"
			uDef.buildoptions[numBuildoptions+2] = "armminivulc"
		elseif name == "coraca" or name == "corack" or name == "coracv" then
			local numBuildoptions = #uDef.buildoptions
			uDef.buildoptions[numBuildoptions+1] = "corapt3"
			uDef.buildoptions[numBuildoptions+2] = "corminibuzz"
		end
	end

	if Spring.GetModOptions and uDef.builddistance then
		local x = tonumber(Spring.GetModOptions().experimentalbuildrange) or 1
		uDef.builddistance = uDef.builddistance*x
	end

	if Spring.GetModOptions and uDef.workertime then
		local x = tonumber(Spring.GetModOptions().experimentalbuildpower) or 1
		uDef.workertime = uDef.workertime*x
	end

	-- mass remove push resistance
	if uDef.pushresistant and uDef.pushresistant == true then
		uDef.pushresistant = false
		if not uDef.mass then
			Spring.Echo("Push Resistant Unit with no mass: "..uDef.name)
			uDef.mass = 4999
		end
	end

	-- vision range
	if Spring.GetModOptions and uDef.sightdistance then
		local x = tonumber(Spring.GetModOptions().experimentallosrange) or 1
		uDef.sightdistance = uDef.sightdistance*x
	end

	if Spring.GetModOptions and uDef.airsightdistance then
		local x = tonumber(Spring.GetModOptions().experimentallosrange) or 1
		uDef.airsightdistance = uDef.airsightdistance*x
	end

	if Spring.GetModOptions and uDef.radardistance then
		local x = tonumber(Spring.GetModOptions().experimentalradarrange) or 1
		uDef.radardistance = uDef.radardistance*x
	end

	--[[
	if uDef.buildcostmetal and uDef.maxdamage then
		uDef.mass = uDef.buildcostmetal
		if uDef.mass and uDef.name then
			Spring.Echo(uDef.name.."'s mass is:"..uDef.mass)
		end
	end
	]]
	if string.find(name, "chicken") and uDef.maxdamage then
		local chickHealth = uDef.maxdamage
		uDef.buildcostmetal = chickHealth*1
		uDef.buildcostenergy = chickHealth*10
		uDef.buildtime = chickHealth*10
	end

	if (uDef.buildpic and uDef.buildpic == "") or not uDef.buildpic then
		Spring.Echo("Missing Buildpic: ".. uDef.name)
	end

	--[[ Sanitize to whole frames (plus leeways because float arithmetic is bonkers).
         The engine uses full frames for actual reload times, but forwards the raw
         value to LuaUI (so for example calculated DPS is incorrect without sanitisation). ]]
	processWeapons(name, uDef)


	-- make los height a bit more forgiving	(20 is the default)
	uDef.losemitheight = (uDef.losemitheight and uDef.losemitheight or 20) + 20


	if uDef.name and uDef.name ~= "Commander" then
		if uDef.featuredefs and uDef.maxdamage then
			if uDef.featuredefs.dead then
				uDef.featuredefs.dead.damage = uDef.maxdamage
			end
		end

		if uDef.featuredefs and uDef.maxdamage then
			if uDef.featuredefs.heap then
				uDef.featuredefs.heap.damage = uDef.maxdamage
			end
		end
    end


	if uDef.maxslope then
		uDef.maxslope = math.floor((uDef.maxslope * 1.5) + 0.5)
	end

	--if Spring.GetModOptions and (tonumber(Spring.GetModOptions().airrebalance) or 0) ~= 0 then


		--if uDef.weapons then
		--	local aaMult = 1.05
		--	for weaponID, w in pairs(uDef.weapons) do
		--		if w.onlytargetcategory == 'VTOL' then
		--			local wdef = string.lower(w.def)
		--			if uDef.weapondefs[wdef] and uDef.weapondefs[wdef].range < 2000 then -- excluding mercury/screamer
		--				uDef.weapondefs[wdef].range = math.floor((uDef.weapondefs[wdef].range * aaMult) + 0.5)
		--				if uDef.weapondefs[wdef].flighttime then
		--					uDef.weapondefs[wdef].flighttime = uDef.weapondefs[wdef].flighttime * (aaMult-((aaMult-1)/3))
		--				end
		--			end
		--		end
		--	end
		--end

		if uDef.canfly then

			uDef.crashdrag = 0.01	-- default 0.005

			if not (string.find(name, "fepoch") or string.find(name, "fblackhy")) then--(string.find(name, "liche") or string.find(name, "crw") or string.find(name, "fepoch") or string.find(name, "fblackhy")) then
				if Spring.GetModOptions and Spring.GetModOptions().experimentalnoaircollisions == "disabled" then
					uDef.collide = false
				elseif Spring.GetModOptions and Spring.GetModOptions().experimentalnoaircollisions == "enabled" then
					uDef.collide = true
				end

				--local airmult = 1.3
				--if uDef.buildcostenergy then
				--	uDef.buildcostenergy = math.ceil(uDef.buildcostenergy*airmult)
				--end
				--
				--if uDef.buildtime then
				--	uDef.buildtime = math.ceil(uDef.buildtime*airmult)
				--end
				--
				--if uDef.buildcostmetal then
				--	uDef.buildcostmetal = math.ceil(uDef.buildcostmetal*airmult)
				--end
				--
				--if uDef.builder then
				--	uDef.workertime = math.floor((uDef.workertime*airmult) + 0.5)
				--end


				if uDef.customparams.fighter then

					--if uDef.maxdamage then
					--	uDef.maxdamage = math.ceil(uDef.maxdamage*1.8)
					--end
--
					--if uDef.weapondefs then
					--	local reloadtimeMult = 1.8
					--	for weaponDefName, weaponDef in pairs (uDef.weapondefs) do
					--		uDef.weapondefs[weaponDefName].reloadtime = uDef.weapondefs[weaponDefName].reloadtime * reloadtimeMult
					--		for category, damage in pairs (weaponDef.damage) do
					--			uDef.weapondefs[weaponDefName].damage[category] = math.floor((damage * reloadtimeMult) + 0.5)
					--		end
					--	end
					--end
					--
					--uDef.maxvelocity = uDef.maxvelocity*1.15
					--
					--uDef.maxacc = uDef.maxacc*1.3
					--
					---- turn speeds x,y,z
					--local movementMult = 1.1
					--uDef.maxelevator = uDef.maxelevator*movementMult
					--uDef.maxrudder  = uDef.maxrudder*movementMult
					--uDef.maxaileron = uDef.maxaileron*movementMult
					--
					--uDef.turnradius = uDef.turnradius*0.9
					--
					--uDef.maxbank = uDef.maxbank*movementMult
					--uDef.maxpitch = uDef.maxpitch*movementMult
					--
					--uDef.maxbank = uDef.maxbank*movementMult
					--uDef.maxpitch = uDef.maxpitch*movementMult

				else 	-- not fighters

					--local rangeMult = 0.65
					--if uDef.airsightdistance then
					--	uDef.airsightdistance = math.floor((uDef.airsightdistance*rangeMult) + 0.5)
					--end
					--
					--if uDef.maxdamage then
					--	uDef.maxdamage = math.floor((uDef.maxdamage*airmult) + 0.5)
					--end
					--
					--if uDef.weapondefs then
					--	for weaponDefName, weaponDef in pairs (uDef.weapondefs) do
					--		uDef.weapondefs[weaponDefName].range = math.floor((uDef.weapondefs[weaponDefName].range * rangeMult) + 0.5)
					--		for category, damage in pairs (weaponDef.damage) do
					--			uDef.weapondefs[weaponDefName].damage[category] = math.floor((damage * airmult) + 0.5)
					--		end
					--	end
					--end
				end
			end
		end
	--end

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

	-- add model vertex displacement
	local vertexDisplacement = 5.5 + ((uDef.footprintx + uDef.footprintz) / 12)
	if vertexDisplacement > 10 then
		vertexDisplacement = 10
	end
	uDef.customparams.vertdisp = 1.0 * vertexDisplacement
	uDef.customparams.healthlookmod = 0

	-- scavengers
	if string.find(name, '_scav') then
		--name = string.gsub(name, '_scav', '')
		VFS.Include("gamedata/scavengers/unitdef_post.lua")
		uDef = scav_Udef_Post(name, uDef)
	else

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
end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local function ProcessSoundDefaults(wd)
	local forceSetVolume = not wd.soundstartvolume or not wd.soundhitvolume or not wd.soundhitwetvolume
	if not forceSetVolume then
		return
	end

	local defaultDamage = wd.damage and wd.damage.default
	if not defaultDamage or defaultDamage <= 50 then
		wd.soundstartvolume = 5
		wd.soundhitvolume = 5
		wd.soundhitwetvolume = 5
		return
	end

	local soundVolume = math.sqrt(defaultDamage * 0.5)
	if wd.weapontype == "LaserCannon" then
		soundVolume = soundVolume*0.5
	end

	if not wd.soundstartvolume then
		wd.soundstartvolume = soundVolume
	end
	if not wd.soundhitvolume then
		wd.soundhitvolume = soundVolume
	end
		if not wd.soundhitwetvolume then
			if wd.weapontype == "LaserCannon" or "BeamLaser" then
				wd.soundhitwetvolume = soundVolume * 0.3
		else
			wd.soundhitwetvolume = soundVolume
		end
	end
end


-- process weapondef
function WeaponDef_Post(name, wDef)

	if not SaveDefsToCustomParams then


		-------------- EXPERIMENTAL MODOPTIONS
		---- SHIELD CHANGES
		if Spring.GetModOptions and Spring.GetModOptions() and Spring.GetModOptions().experimentalshields == "absorbplasma" then
			if wDef.shield and wDef.shield.repulser and wDef.shield.repulser ~= false then
				wDef.shield.repulser = false
			end
		elseif Spring.GetModOptions and Spring.GetModOptions() and Spring.GetModOptions().experimentalshields == "absorbeverything" then
			if wDef.shield and wDef.shield.repulser and wDef.shield.repulser ~= false then
				wDef.shield.repulser = false
			end
			if (not wDef.interceptedbyshieldtype) or wDef.interceptedbyshieldtype ~= 1 then
				wDef.interceptedbyshieldtype = 1
			end
		elseif Spring.GetModOptions and Spring.GetModOptions() and Spring.GetModOptions().experimentalshields == "bounceeverything" then
			if wDef.shield then
				wDef.shield.repulser = true
			end
			if (not wDef.interceptedbyshieldtype) or wDef.interceptedbyshieldtype ~= 1 then
				wDef.interceptedbyshieldtype = 1
			end
		end

		if Spring.GetModOptions and Spring.GetModOptions() and Spring.GetModOptions().experimentalshieldpower then
			if wDef.shield then
				local multiplier = tonumber(Spring.GetModOptions().experimentalshieldpower)
				if wDef.shield.power then
					wDef.shield.power = wDef.shield.power*multiplier
				end
				if wDef.shield.powerregen then
					wDef.shield.powerregen = wDef.shield.powerregen*multiplier
				end
				if wDef.shield.powerregenenergy then
					wDef.shield.powerregenenergy = wDef.shield.powerregenenergy*multiplier
				end
				if wDef.shield.startingpower then
					wDef.shield.startingpower = wDef.shield.startingpower*multiplier
				end
			end
		end
		----------------------------------------







		--Use targetborderoverride in weapondef customparams to override this global setting
		--Controls whether the weapon aims for the center or the edge of its target's collision volume. Clamped between -1.0 - target the far border, and 1.0 - target the near border.
		if wDef.customparams and wDef.customparams.targetborderoverride == nil then
			wDef.targetborder = 1 --Aim for just inside the hitsphere
		elseif wDef.customparams and wDef.customparams.targetborderoverride ~= nil then
			wDef.targetborder = tonumber(wDef.customparams.targetborderoverride)
		end

		if wDef.craterareaofeffect then
			wDef.cratermult = (wDef.cratermult or 0) + wDef.craterareaofeffect/2000
			--Spring.Echo(name..'  '..wDef.cratermult)
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
			if wDef.corethickness then
				wDef.corethickness = wDef.corethickness * 1.21
			end
			if wDef.thickness then
				wDef.thickness = wDef.thickness * 1.27
			end
			if wDef.laserflaresize then
				wDef.laserflaresize = wDef.laserflaresize * 1.15		-- note: thickness affects this too
			end
			wDef.texture1 = "largebeam"		-- The projectile texture
			--wDef.texture2 = ""		-- The end-of-beam texture for #LaserCannon, #BeamLaser
			wDef.texture3 = "flare2"	-- Flare texture for #BeamLaser
			wDef.texture4 = "flare2"	-- Flare texture for #BeamLaser with largeBeamLaser = true
		end

		-- scavengers
		if string.find(name, '_scav') then
			VFS.Include("gamedata/scavengers/weapondef_post.lua")
			wDef = scav_Wdef_Post(name, wDef)
		end

		ProcessSoundDefaults(wDef)
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
	if Spring.GetModOptions then
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
		if modOptions.transportenemy == "notcoms" then
			for name,ud in pairs(UnitDefs) do
				if name == "armcom" or name == "corcom" or name == "armdecom" or name == "cordecom" then
					ud.transportbyenemy = false
				end
			end
		elseif modOptions.transportenemy == "none" then
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
