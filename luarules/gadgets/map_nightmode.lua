local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Map NightMode",
		desc = "Responsible for tuning lighting for night mode lighting ",
		author = "Beherith",
		date = "2022.12.16",
		license = "GNU GPL, v2 or later",
		layer = -100,
		enabled = true,
	}
end

-- ok how will this work, needs some thought and docs
-- A widget (or user command) needs to 'request' a nightlight
-- This nightlight should always be prepped from the true lighting (e.g. initial_atmosphere_lighting)
-- TODO LIST
	-- Maybe fuck with shadowdensity?
	-- Needs a callin for widgets on sunchange!
	-- Minimap slowly updates only
	-- Water Does not update correctly - Ask ivand for some uniforms into bumpwater
	-- Spring.SendCommands("luarules updatesun") - check if widget/devshit changed the sun!
	-- skybox darkening
	
-- Effects needing fixing/info on sunchange
	-- Map edge extension - DONE
	-- Map Grass - DONE
	-- Decals - Fine as is!
	-- Features brightness - DONE
	-- Creep shader - DONE
	-- Lava
	-- Fog
	-- snow?
	-- volclouds
	

-- Configuration options:
	-- Definition of a nightmode is:
		--Nightfactor RGBA
		--nightsun azimuth altitude
			-- since sun is always best behind, this is non trivial
			-- Azimuth - defined in radians, and will rotate to the opposite direction of current sun X
			-- altitude - defined as a ratio of nightheight/Dayheight (original) 

	-- Single triggers
	-- Periodic changes to nightmode should be defined as:
		-- Nightfactor rgba tuple
		-- azimuth -- how much to rotate the sun around, in radians
		-- altitude  -- how much to increase/decrease sun height relative to original sun height
		-- dayDuration - how long the day is, in integer seconds
		-- nightDuration -- how long the night is, in seconds
		-- transitionDuration -- how long each transition takes
		-- Repeats: X times
		-- Fromtime : nil for now 
	-- NO CONFLICTING CONFIGS ALLOWED YET! 
		-- cant have periodic + single being active at the same time!


local currentMapname = Game.mapName:lower()
local mapList = VFS.DirList("luarules/configs/Atmosphereconfigs/", "*.lua")

--Spring.Echo("[Map NightMode] Current map: "..currentMapname)
local mapFileName = ''	-- (Include at bottom of this file)
for i = 1,#mapList+1 do
	if i == #mapList+1 then
		--Spring.Echo("[Map NightMode] No map config found. Turning off the gadget")
	end
	if string.find(currentMapname, mapFileName) then
		mapFileName = string.sub(mapList[i], 36, string.len(mapList[i])-4):lower()
		--Spring.Echo("[Map NightMode] Success! Map names match!: " ..mapFileName)
		break
	end
end


if not gadgetHandler:IsSyncedCode() then
	--[[
		Spring.SetSunLighting({ groundAmbientColor = { transitionred * gar, transitiongreen * gag, transitionblue * gab } })
		Spring.SetSunLighting({ unitAmbientColor = { transitionred * uar, transitiongreen * uag, transitionblue * uab } })
		Spring.SetSunLighting({ groundDiffuseColor = { transitionred * gdr, transitiongreen * gdg, transitionblue * gdb } })
		Spring.SetSunLighting({ unitDiffuseColor = { transitionred * udr, transitiongreen * udg, transitionblue * udb } })
		Spring.SetSunLighting({ groundSpecularColor = { transitionred * gsr, transitiongreen * gsg, transitionblue * gsb } })
		Spring.SetSunLighting({ unitSpecularColor = { transitionred * usr, transitiongreen * usg, transitionblue * usb } })

		Spring.SetAtmosphere({ skyColor = { transitionred * skycr, transitiongreen * skycg, transitionblue * skycb } })
		Spring.SetAtmosphere({ sunColor = { transitionred * suncr, transitiongreen * suncg, transitionblue * suncb } })
		Spring.SetAtmosphere({ cloudColor = { transitionred * clocr, transitiongreen * clocg, transitionblue * clocb } })
		Spring.SetAtmosphere({ fogColor = { transitionred * fogcr, transitiongreen * fogcg, transitionblue * fogcb } })

		Spring.SetSunLighting({ groundShadowDensity = transition * shadowdensity, modelShadowDensity = transition * shadowdensity })
	]]--
	

	local function tablecopy(t)
		local copy = {}
		for key, value in pairs(t) do
			if type(value) == "table" then
				copy[key] = tablecopy(value)
			else
				copy[key] = value
			end
		end
		return copy
	end

	local function EchoSun(l)
		local function quicktablestring(t) 
			local tuple = ''
			for _,v2 in ipairs(t) do 
				tuple = tuple  .. string.format('%.3f, ',v2) 
			end
			return tuple
		end
		
		for _,s in ipairs({'lighting','atmosphere'}) do 
			Spring.Echo(s)
			for k,v in pairs(l[s]) do 
				if type(v) == 'table' then 
					Spring.Echo(string.format("  %s = {%s},", k, quicktablestring(v)))
				else
					Spring.Echo(string.format("  %s = %s,", k, tostring(v)))
				end
			end
		end
		Spring.Echo('sunDir = '..quicktablestring(l['sunDir']))
	end

	local function GetLightingAndAtmosphere()  -- returns a table of the common parameters
		local res =  {
			lighting = {
				groundAmbientColor =  {gl.GetSun("ambient")},
				groundDiffuseColor =  {gl.GetSun("diffuse")},
				groundSpecularColor =  {gl.GetSun("specular")},
				
				unitAmbientColor =  {gl.GetSun("ambient","unit")},
				unitDiffuseColor =  {gl.GetSun("diffuse","unit")},
				unitSpecularColor =  {gl.GetSun("specular","unit")},
				
				groundShadowDensity = gl.GetSun("shadowDensity"),
				modelShadowDensity = gl.GetSun("shadowDensity","unit"),
			},
			atmosphere = {
				skyColor = {gl.GetAtmosphere("skyColor")},
				sunColor = {gl.GetAtmosphere("sunColor")},
				cloudColor = {gl.GetAtmosphere("cloudColor")},
				fogColor = {gl.GetAtmosphere("fogColor")},
				fogColor = {gl.GetAtmosphere("fogColor")},
				fogStart = gl.GetAtmosphere("fogStart"),
				fogEnd = gl.GetAtmosphere("fogEnd"),
			},
			water = {
				ambientFactor = gl.GetWaterRendering("ambientFactor"),
				diffuseFactor = gl.GetWaterRendering("diffuseFactor"),
				specularFactor = gl.GetWaterRendering("specularFactor"),
			},
			sunDir = {gl.GetSun("pos")},
			nightFactor = {red = 1, green = 1, blue = 1, shadow = 1, altitude = 1},
		}

		return res
	end	
	
	local currentNightFactor = {red = 1, green = 1, blue = 1, shadow = 1, altitude = 1}
	GG['NightFactor'] = currentNightFactor
	
	
	local function SetLightingAndAtmosphere(lightandatmos)
		for k,_ in pairs(currentNightFactor) do 
			GG['NightFactor'][k] = lightandatmos.nightFactor[k]
		end
		
		if Script.LuaUI("NightFactorChanged") then 
			Script.LuaUI.NightFactorChanged(lightandatmos.nightFactor.red, lightandatmos.nightFactor.green, lightandatmos.nightFactor.blue, lightandatmos.nightFactor.shadow, lightandatmos.nightFactor.altitude)
		end
		
		-- This is disabled because these are all #defined params, so they cant be changed without recompiling the bumpwater shader
		-- The bumpwaterUseUniforms was deprecated in 2022.10 by ivand
		--if lightandatmos.water then Spring.SetWaterParams(lightandatmos.water) end 
		
		if lightandatmos.lighting then Spring.SetSunLighting(lightandatmos.lighting) end
		if lightandatmos.sunDir then Spring.SetSunDirection(lightandatmos.sunDir[1], lightandatmos.sunDir[2], lightandatmos.sunDir[3] ) end
		if lightandatmos.atmosphere then Spring.SetAtmosphere(lightandatmos.atmosphere) end
		--if lightandatmos.lighting then Spring.SetSunLighting({groundShadowDensity = lightandatmos.lighting.groundShadowDensity}) end -- for some godforsaken reason, this needs to be set TWICE!
		if lightandatmos.lighting then Spring.SetSunLighting({}) end -- for some godforsaken reason, this needs to be set TWICE!

		--gadgetHandler:SetGlobal("NightModeParams", {r=1, g=1, b=1, s=1, a= 1})
	end

	local atmosphere_lighting = {"atmosphere","lighting"}
	local atan2 = math.atan2
	local diag = math.diag
	local mix = math.mix
	local sin = math.sin
	local cos = math.cos
	
	-- Mix everything specified in A into B, if not specified in B, then replace with A
	-- If target is not specified, target is B
	-- Returns aworldrot in radians where if sun is to the right (x>0)
	-- aworldrot is 0 when sun points to x=0 z=1
	-- aworldrot increases to +pi as sun moves counterclockwise right
	-- aworldrot decreases to -pi as sun moves clockwise left
	-- 	-2.36 -2.68 -3.14 2.68 2.36
	--	-2.03 -2.36 -3.14 2.36 2.03
	--	-1.57 -1.57 -0.00 1.57 1.57   Z
	--	-1.11 -0.79 -0.00 0.79 1.11
	--	-0.79 -0.46 -0.00 0.46 0.79 
	--				  X
	
	local function SunDirToAzimuthHeight(sunDir)
		local alength = 1.0 / diag(sunDir[1], sunDir[2], sunDir[3])
		local aworldrot = atan2(sunDir[1]*alength, sunDir[3]*alength) --https://en.wikipedia.org/wiki/Atan2
		local aheight =   atan2(sunDir[2]*alength, diag(sunDir[1]*alength, sunDir[3]*alength))
		return aworldrot, aheight
	end
	
	local function SunAzimuthHeightToDir(azimuth, height, result)
		if result == nil then result = {0,1,0} end 
		result[1] = sin(azimuth) * cos(height) 
		result[2] = sin(height) 
		result[3] = cos(azimuth) * cos(height)
		return result
	end
	
	local function MixLightingAndAtmosphere(a, b, mixfactor, target)
		if target == nil then target = b end
		for _,k in ipairs(atmosphere_lighting) do 
			if a[k] and b[k] then
				local aa = a[k]
				local bb = b[k] 
				for ka, va in pairs(aa) do
					if bb[ka] == nil then target[ka] = aa[ka] 
					else
						if type(va) == 'table' then 
							for i=1,#va do 
								--Spring.Echo(k, ka, i, aa[ka][i],bb[ka][i], mixfactor )
								target[k][ka][i] = mix(aa[ka][i], bb[ka][i], mixfactor) 
							end
						else
							target[k][ka] = mix(aa[ka], bb[ka], mixfactor) 
						end
					end
				end
			end
		end
		if a['sunDir'] and b['sunDir'] then 
			local asun = a['sunDir'] 
			local bsun = b['sunDir'] 
			
			local aworldrot, aheight  = SunDirToAzimuthHeight(a['sunDir'] )
			local bworldrot, bheight  = SunDirToAzimuthHeight(b['sunDir'] )			
			--Spring.Echo(("Arot = %.2f, Brot = %.2f"):format(aworldrot, bworldrot))

			-- if close to 180 degrees, then rotate clockwise
			if (aworldrot - bworldrot) > math.pi - 0.01 then
				bworldrot = bworldrot + 2 * math.pi
			end
			
			if (bworldrot - aworldrot) > math.pi - 0.01 then
				bworldrot = bworldrot - 2 * math.pi
			end
			
			local targetrot = mix(aworldrot, bworldrot, mixfactor)
			local targetheight = mix(aheight, bheight, mixfactor)
			
			SunAzimuthHeightToDir(targetrot, targetheight, target['sunDir'])
			--Spring.Echo("sunDir", mixfactor, "targetrot",targetrot, "targetheight", targetheight, aworldrot ,  bworldrot)
		end
		if a.nightFactor and b.nightFactor then 
			for k,_ in pairs(currentNightFactor) do 
				target.nightFactor[k] = mix(a.nightFactor[k], b.nightFactor[k], mixfactor)
			end
		end
		return target
	end
	
	local initial_atmosphere_lighting = GetLightingAndAtmosphere()
	
	local initlight
	local endlight
	local mixedlight
	
	local function GetNightLight(fromlight, nightfactor, azimuth, altitude)
		if fromlight == nil then 
			fromlight = tablecopy(initial_atmosphere_lighting)
		end 
		local endlight = tablecopy(fromlight)
		for _,atmlight in ipairs(atmosphere_lighting) do
			for k2, v2 in pairs(endlight[atmlight]) do
				if string.find(k2, "Color", nil, true) then 
					local unitmod = 0
					if string.find(k2, "unit", nil, true) then unitmod = 0.66 end 
					for i =1, #v2 do 
						endlight[atmlight][k2][i] = endlight[atmlight][k2][i] * math.mix(nightfactor[i], 1.0, unitmod)
					end
				elseif string.find(k2, "ShadowDensity", nil, true) then 
					-- New shadow factor is a product of old and nightfactor[4]
					endlight[atmlight][k2] = endlight[atmlight][k2] * (nightfactor[4] or 1)
				end
			end
		end

		-- Also adjust the water parameters
		local waterFactor = (nightfactor[1] + nightfactor[2] + nightfactor[3]) / 3.0
		for waterkey, watervalue in ipairs(fromlight.water) do
			endlight.water[waterkey] = watervalue * waterFactor
		end

		-- New sun height is weighted factor of old sun height
		endlight.sunDir[2] = fromlight.sunDir[2] * altitude
		
		local fromazimuth, fromheight = SunDirToAzimuthHeight(fromlight.sunDir)
		-- if the original sun is to the right, then we need to turn it left
		--Spring.Echo("Setting azimuth from", fromazimuth)
		local toazimuth = 0
		if fromazimuth > 0 then
			toazimuth = fromazimuth + azimuth
			if toazimuth > math.pi then toazimuth = toazimuth - 2 * math.pi end 
		else -- turn it right
			toazimuth = fromazimuth - azimuth
			if toazimuth < -1 * math.pi then toazimuth = toazimuth + 2 * math.pi end 
		end
		SunAzimuthHeightToDir(toazimuth, fromheight * altitude, endlight.sunDir)
		endlight.nightFactor = {red = nightfactor[1], green = nightfactor[2], blue =  nightfactor[3], shadow = nightfactor[4], altitude = altitude}
		return endlight
	end
	
	local transitionenabled = false
	local nightModeConfig = {
		{
			nightFactor = {0.15, 0.15, 0.18, 0.5},
			azimuth = 1.5,
			altitude = 0.5,
			dayDuration = 180,
			nightDuration = 180, 
			transitionDuration = 120, 
			repeats = 10000, 
			startTime = 5, 
			endLight = nil, -- this will be filled in on initialize!
			period = nil, -- init: nightConf.dayDuration + nightConf.nightDuration + 2 * nightConf.transitionDuration
		}
	}

	
	local function SetNightMode(cmd, line, words, playerID)
		-- line is the full line
		-- words is a table here, of each of the words AFTER /luarules NightMode a b c -> {a,b,c}
		Spring.Echo("SetNightMode",cmd, line, words, playerID)
		if #words <= 1 then 
			Spring.Echo("Resetting Lighting")
			SetLightingAndAtmosphere(initial_atmosphere_lighting)
			return
		end
		
		Spring.Echo("Expecting /luarules NightMode nightR nightG nightB azimuth altitude shadowfactor")
		local nightR = (words[1] and tonumber(words[1])) or 1
		local nightG = (words[2] and tonumber(words[2])) or 1
		local nightB = (words[3] and tonumber(words[3])) or 1
		local azimuth = (words[4] and tonumber(words[4])) or 0
		local altitude = (words[5] and tonumber(words[5])) or 1
		local shadowfactor = (words[6] and tonumber(words[6])) or 1
		
		local newNightLight = GetNightLight(nil, { nightR, nightG,nightB,shadowfactor}, azimuth, altitude)
		Spring.Echo(newNightLight)
		-- If this command is recieved, immediately stop any existing nightModeConfig
		transitionenabled = false
		SetLightingAndAtmosphere(newNightLight)
	end
	
	local function NightModeToggle(cmd, line, words, playerID)
		transitionenabled = not transitionenabled
	end
	
	
	local function PrintSun(cmd, line, words, playerID)
		Spring.Echo("Current sun settings are")
		local sun = GetLightingAndAtmosphere()
		EchoSun(sun)
	end
	

	function gadget:GameFrame(n)
		if transitionenabled == false then return end
		for i, nc in ipairs(nightModeConfig) do 
			local currentseconds = n / 30 - nc.startTime

			-- see if this light can still have an effct
			if currentseconds < nc.repeats * (nc.period) then 
				--calculate phase:
				local phase = math.fmod(currentseconds, nc.period)
				if phase < nc.dayDuration then 
					-- still day, dont do shit
				elseif phase > nc.dayDuration + nc.transitionDuration and 
					   phase <  nc.dayDuration + nc.transitionDuration + nc.nightDuration then
					-- still night, dont do shit
				else
					-- we are in transition
					if nc.mixedlight == nil then nc.mixedlight = tablecopy(nc.endLight) end 
					
					local transitionfactor = 0 
					if phase <= nc.dayDuration + nc.transitionDuration then -- moving to night
						mixfac = math.smoothstep(nc.dayDuration,nc.dayDuration + nc.transitionDuration,phase);
					else
						mixfac = 1.0 - math.smoothstep(nc.dayDuration + nc.transitionDuration + nc.nightDuration, nc.period,phase);
					end
					--Spring.Echo(mixfac, nc.mixedlight, initial_atmosphere_lighting, nc.endLight)
					MixLightingAndAtmosphere(initial_atmosphere_lighting, nc.endLight, mixfac, nc.mixedlight)
					if nc.mixedlight == nil then return end
					SetLightingAndAtmosphere(nc.mixedlight)

				end
				
			end
		end
	end
	
	local lastSunChanged = -1 
	function gadget:SunChanged() -- Note that map_nightmode.lua gadget has to change sun twice in a single draw frame to update all
		local df = Spring.GetDrawFrame()
		if df == lastSunChanged then return end
		lastSunChanged = df
	end

	local function isAuthorizedWrapper(func)
		return function(cmd, line, words, playerID)
			-- TODO: add some way for non admin users to authorize themselves in multiplier?
			if GG.isAuthorized(playerID) then
				func(cmd, line, words, playerID)
			end
		end
	end

	function gadget:Initialize()
		initial_atmosphere_lighting = GetLightingAndAtmosphere()
		for i, nightConf in ipairs(nightModeConfig) do 
			nightConf.endLight = GetNightLight(initial_atmosphere_lighting, nightConf.nightFactor, nightConf.azimuth, nightConf.altitude)
			nightConf.period = nightConf.dayDuration + nightConf.nightDuration + 2 * nightConf.transitionDuration
		end
		gadgetHandler:AddSyncAction("GetLightingAndAtmosphere", GetLightingAndAtmosphere)
		gadgetHandler:AddSyncAction("SetLightingAndAtmosphere", SetLightingAndAtmosphere)
		gadgetHandler:AddSyncAction("MixLightingAndAtmosphere", MixLightingAndAtmosphere)
		gadgetHandler:AddChatAction("NightMode", isAuthorizedWrapper(SetNightMode))
		gadgetHandler:AddChatAction("NightModeToggle", isAuthorizedWrapper(NightModeToggle))
		gadgetHandler:AddChatAction("PrintSun", isAuthorizedWrapper(PrintSun))
		gadgetHandler:RegisterGlobal("NightModeParams", {r=1, g=1, b=1, s=1, a= 1})
	end

	function gadget:Shutdown()
		gadgetHandler:RemoveSyncAction("SetLightingAndAtmosphere")
		gadgetHandler:RemoveSyncAction("GetLightingAndAtmosphere")
		gadgetHandler:RemoveSyncAction("MixLightingAndAtmosphere")
		gadgetHandler:RemoveChatAction('NightMode')
		gadgetHandler:RemoveChatAction('NightModeToggle')
		SetLightingAndAtmosphere(initial_atmosphere_lighting)
	end
end


