local enabled = (Spring.GetModOptions and (tonumber(Spring.GetModOptions().night) or 0) ~= 0)

function gadget:GetInfo()
	return {
		name      = "Dynamic Weather",
		desc      = "Yea, Dynamic Weather",
		author    = "Damgam",
		date      = "2020",
		layer     = 0,
		enabled   = enabled
	}
end

if not gadgetHandler:IsSyncedCode() then

	local defaultMapSunPos = {gl.GetSun("pos")}

	local MapMaxSunHeight = defaultMapSunPos[2]
	local MapMaxSunX = 2
	local MapMaxSunZ = 2
	local MapSunSpeed = 0.0005

	local nighttime = 10 -- higher = shorter

	local SunX = 0
	local SunZ = math.random(-5000,5000)/10000
	local SunY = 0.9999
	local SunHeightState = ""
	local cycle = "Day"
	local maxshadowopacity = gl.GetSun("shadowDensity")
	local defdiffr,defdiffg,defdiffb = gl.GetSun("diffuse")
	local defspecr,defspecg,defspecb = gl.GetSun("specular")
	local diffr = defdiffr
	local diffg = defdiffg
	local diffb = defdiffb
	local specr = defspecr
	local specg = defspecg
	local specb = defspecb
	local shadowopacity = maxshadowopacity

	-- this prevents widgets from adjusting settings to gain an optical advantage against other players (it will show an error)
	function gadget:SunChanged()
		if shadowopacity ~= gl.GetSun("shadowDensity") then
			Spring.SetSunLighting({groundShadowDensity = shadowopacity, modelShadowDensity = shadowopacity, groundDiffuseColor = {diffr,diffg,diffb}, modelDiffuseColor = {diffr,diffg,diffb}, groundSpecularColor = {specr,specg,specb}, modelSpecularColor = {specr,specg,specb}})
		end
		local newSunX,newSunY,newSunZ = gl.GetSun("pos")
		if newSunX ~= SunX  or  newSunY ~= SunY  or  newSunZ ~= SunZ then
			Spring.SetSunDirection(SunX,SunY,SunZ)
		end
	end

	function gadget:GameFrame(n)
			if n == 1 then
				Spring.SetSunLighting({groundShadowDensity = shadowopacity, modelShadowDensity = shadowopacity, groundDiffuseColor = {diffr,diffg,diffb}, modelDiffuseColor = {diffr,diffg,diffb}, groundSpecularColor = {specr,specg,specb}, modelSpecularColor = {specr,specg,specb}})
			end
			if n%5 == 0 then
				local oldSunX = SunX
				local oldSunY = SunY
				local oldSunZ = SunZ
				if cycle == "Day" then
					if SunX > -MapMaxSunX then
						SunX = oldSunX - MapSunSpeed
					elseif SunX <= -MapMaxSunX then
						Spring.SendCommands("TimeOfTheDay Nighttime")
						cycle = "Night"
					end
					if SunX >= MapMaxSunX - 0.5 then
						SunHeightState = "Sunrise"
					elseif SunX <= -MapMaxSunX+0.5 then
						SunHeightState = "Sunset"
					elseif SunX > -MapMaxSunX+0.5 and SunX < MapMaxSunX-0.5 then
						SunHeightState = "OHFUCKITSSOBRIGHT"
						shadowopacity = maxshadowopacity
					end

					if SunHeightState == "Sunrise" then
						SunY = oldSunY + (MapSunSpeed * 2.1)
						if SunY <= maxshadowopacity and SunY >= 0 then
							shadowopacity = SunY*(1/MapMaxSunHeight)
						end


						if SunY <= defdiffr and SunY >= 0 then
							diffr = SunY*(1/MapMaxSunHeight)
						end
						if SunY <= defdiffg and SunY >= 0 then
							diffg = SunY*(1/MapMaxSunHeight)
						end
						if SunY <= defdiffb and SunY >= 0 then
							diffb = SunY*(1/MapMaxSunHeight)
						end


						if SunY <= defspecr and SunY >= 0 then
							specr = SunY*(1/MapMaxSunHeight)
						end
						if SunY <= defspecg and SunY >= 0 then
							specg = SunY*(1/MapMaxSunHeight)
						end
						if SunY <= defspecb and SunY >= 0 then
							specb = SunY*(1/MapMaxSunHeight)
						end


						if SunY > MapMaxSunHeight then
							SunY = MapMaxSunHeight
						end
					elseif SunHeightState == "Sunset" then
						SunY = oldSunY - (MapSunSpeed * 2.1)
						if SunY <= maxshadowopacity and SunY >= 0 then
							shadowopacity = SunY*(1/MapMaxSunHeight)
						end


						if SunY <= defdiffr and SunY >= 0 then
							diffr = SunY*(1/MapMaxSunHeight)
						end
						if SunY <= defdiffg and SunY >= 0 then
							diffg = SunY*(1/MapMaxSunHeight)
						end
						if SunY <= defdiffb and SunY >= 0 then
							diffb = SunY*(1/MapMaxSunHeight)
						end


						if SunY <= defspecr and SunY >= 0 then
							specr = SunY*(1/MapMaxSunHeight)
						end
						if SunY <= defspecg and SunY >= 0 then
							specg = SunY*(1/MapMaxSunHeight)
						end
						if SunY <= defspecb and SunY >= 0 then
							specb = SunY*(1/MapMaxSunHeight)
						end


						if SunY < -0.1 then
							SunY = -0.1
						end
					elseif SunHeightState == "OHFUCKITSSOBRIGHT" then
						SunY = MapMaxSunHeight
					end
					Spring.SetSunLighting({groundShadowDensity = shadowopacity, modelShadowDensity = shadowopacity, groundDiffuseColor = {diffr,diffg,diffb}, modelDiffuseColor = {diffr,diffg,diffb}, groundSpecularColor = {specr,specg,specb}, modelSpecularColor = {specr,specg,specb}})
				elseif cycle == "Night" then
					shadowopacity = shadowopacity-(MapSunSpeed*10)
					if shadowopacity <= 0 then
						shadowopacity = 0
					end
					if SunX < MapMaxSunX then
						SunX = oldSunX + MapSunSpeed*nighttime
					elseif SunX >= MapMaxSunX then
						Spring.SendCommands("TimeOfTheDay Daytime")
						SunZ = SunZ + (math.random(-2000,2000)/10000)
						cycle = "Day"
						if SunZ > MapMaxSunZ then
							SunZ = MapMaxSunZ
						elseif SunZ < -MapMaxSunZ then
							SunZ = -MapMaxSunZ
						end
					end
					Spring.SetSunLighting({groundShadowDensity = 0, modelShadowDensity = 0, groundDiffuseColor = {0,0,0}, modelDiffuseColor = {0,0,0}, groundSpecularColor = {0,0,0}, modelSpecularColor = {0,0,0}})
				end
				--Spring.Echo("Sun Position: X: "..SunX.." Z: "..SunZ.." Y: "..SunY)
				--SunHeighToSynced = SunY
				Spring.SetSunDirection(SunX,SunY,SunZ)
			end
		end
else

	-- function gadget:GotChatMsg(msg, playerID)
		-- if string.find(msg, "TimeOfTheDay") then
			-- if string.find(msg, "Daytime") then
				-- SyncedTime = "Daytime"
				-- Spring.Echo("Daytime")
			-- elseif string.find(msg, "Nighttime") then
				-- SyncedTime = "Nighttime"
				-- Spring.Echo("Nighttime")
			-- end
		-- end
	-- end



	-- function gadget:Initialize()
		-- gadgetHandler:AddSyncAction("GetDayOrNight", timeoftheday)
	-- end

	-- function gadget:Shutdown()
		-- gadgetHandler:RemoveSyncAction("GetDayOrNight")
	-- end

	-- function gadget:GameFrame(n)
		-- if n%5 == 0 then
			-- if SunHeighToSynced < MapMaxSunHeight/5 then
				-- SyncedTime = "Nighttime"
				-- Spring.Echo("Nighttime")
			-- else
				-- SyncedTime = "Daytime"
				-- Spring.Echo("Daytime")
			-- end
		-- end
	-- end
end


