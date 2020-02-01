math.random()
math.random()
math.random()
math.random()

function widget:GetInfo()
  return {
    name      = "Dynamic Sun",
    desc      = "Yea, Dynamic Sun",
    author    = "Damgam",
    date      = "2020",
    license   = "What?",
    layer     = 0,
    enabled   = true  
  }
end
defaultMapSunPos = {gl.GetSun("pos")}


MapMaxSunHeight = defaultMapSunPos[2]
MapMaxSunX = 2
MapMaxSunZ = 2
MapSunSpeed = 0.0005

nighttime = 10 -- higher = shorter

SunX = 0
SunZ = math.random(-5000,5000)/10000
SunY = 0.9999
SunHeightState = ""
cycle = "Day"
daytimeshadow = gl.GetSun("shadowDensity")
shadowopacity = 0

function widget:GameFrame(n)
	if n%5 == 0 then
		oldSunX = SunX
		oldSunY = SunY
		oldSunZ = SunZ
		if cycle == "Day" then
			if SunX > -MapMaxSunX then 
				SunX = oldSunX - MapSunSpeed
			elseif SunX <= -MapMaxSunX then
				cycle = "Night"
			end
			if SunX >= MapMaxSunX - 0.5 then
				SunHeightState = "Sunrise"
			elseif SunX <= -MapMaxSunX+0.5 then
				SunHeightState = "Sunset"
			elseif SunX > -MapMaxSunX+0.5 and SunX < MapMaxSunX-0.5 then
				SunHeightState = "OHFUCKITSSOBRIGHT"
				shadowopacity = daytimeshadow
			end
			
			if SunHeightState == "Sunrise" then
				SunY = oldSunY + (MapSunSpeed * 2.1)
				if SunY <= daytimeshadow and SunY >= 0 then
					shadowopacity = SunY*(1/MapMaxSunHeight)
				end
				if SunY > MapMaxSunHeight then
					SunY = MapMaxSunHeight
				end
			elseif SunHeightState == "Sunset" then
				SunY = oldSunY - (MapSunSpeed * 2.1)
				if SunY < daytimeshadow and SunY >= 0 then
					shadowopacity = SunY*(1/MapMaxSunHeight)
				end
				if SunY < -0.1 then
					SunY = -0.1
				end
			elseif SunHeightState == "OHFUCKITSSOBRIGHT" then
				SunY = MapMaxSunHeight
			end
			Spring.SetSunLighting({groundShadowDensity = shadowopacity, modelShadowDensity = shadowopacity})
		elseif cycle == "Night" then
			shadowopacity = shadowopacity-(MapSunSpeed*10)
			if shadowopacity <= 0 then
				shadowopacity = 0
			end
			if SunX < MapMaxSunX then 
				SunX = oldSunX + MapSunSpeed*nighttime
			elseif SunX >= MapMaxSunX then
				SunZ = SunZ + (math.random(-2000,2000)/10000)
				cycle = "Day"
				if SunZ > MapMaxSunZ then
					SunZ = MapMaxSunZ
				elseif SunZ < -MapMaxSunZ then
					SunZ = -MapMaxSunZ
				end
			end
			Spring.SetSunLighting({groundShadowDensity = 0, modelShadowDensity = 0})
		end
		--Spring.Echo("Sun Position: X: "..SunX.." Z: "..SunZ.." Y: "..SunY)
		Spring.SetSunDirection(SunX,SunY,SunZ)
		
	end
end


