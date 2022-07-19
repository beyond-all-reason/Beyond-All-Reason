function gadget:GetInfo()
	return {
		name = "Control Victory",
		desc = "Enables a victory through capture and hold",
		author = "KDR_11k (David Becker), Smoth, Lurker, Forboding Angel, Floris",
		date = "2008-03-22 -- Major update July 11th, 2016",
		license = "Public Domain",
		layer = 1,
		enabled = true
	}
end

local modOptions = Spring.GetModOptions()
if modOptions.scoremode == "disabled" then
	return
end

local selectedScoreMode = modOptions.scoremode
local useMapConfig = modOptions.usemapconfig
local useMexConfig = false --modOptions.usemexconfig
local numberOfControlPoints = modOptions.numberofcontrolpoints
local captureRadius = modOptions.captureradius
local decapSpeed = modOptions.decapspeed
local startTime = modOptions.starttime
local metalPerPoint = modOptions.metalperpoint
local energyPerPoint = modOptions.energyperpoint
local tugofWarModifier = modOptions.tugofwarmodifier
local limitScore = modOptions.limitscore
local captureTime = modOptions.capturetime
local captureBonus = modOptions.capturebonus * 0.01 -- modoption number is percentage 0%-100%
local dominationScoreTime = modOptions.dominationscoretime
local dominationScore = modOptions.dominationscore

--[[
-------------------
Before implementing this gadget, read this!!!
This gadget relies on a few parts:
• control point config file which is located in luarules/configs/controlpoints/ , and it must have a filename of cv_<mapname>.lua. So, in the case of a map named "Iammas Prime -" with a version of "v01", then the name of my file would be "cv_Iammas Prime - v01.lua".
	PLEASE NOTE: If the map config file is not found and a capture mode is selected, the gadget will generate 7 points in a circle on the map automagically.

• config placed in luarules/configs/ called cv_nonCapturingUnits.lua -- What units are barred form being able to capture control points?
• config placed in luarules/configs/ called cv_buildableUnits.lua -- What units can be built inside control points?
	*-----------------*
	EXTREMELY IMPORTANT!
		In the "Buildable units"'s unitdefs, you need to add a building mask of 0. By default the building mask is 1. The control points use a building mask of 2.
		Use the unitdef tag:
			buildingMask = 0,

		BEWARE! Spring 103.0 allows for a bit field that works like this... 0 over 1, never 1 over 0. Normal ground is 1. Units are defaulted to 1.

	*-----------------*
]]
local useBuildingMask = false

--[[
The control point config is structured like this (cv_Iammas Prime - v01.lua):

////

return {
	points = {
		[1] = {x = 4608, y = 0, z = 3048},
		[2] = {x = 4265, y = 0, z = 1350},
		[3] = {x = 4950, y = 0, z = 4786},
		[4] = {x = 6641, y = 0, z = 858},
		[5] = {x = 2574, y = 0, z = 5271},
		[6] = {x = 2219, y = 0, z = 498},
		[7] = {x = 6993, y = 0, z = 5616},
	},
}

////

The nonCapturingUnits.lua config file is structured like this:
These are units that are not allowed to capture points.

////

local nonCapturingUnits = {
	"eairengineer",
	"efighter",
	"egunship2",
	"etransport",
	"edrone",
	"ebomber",
}

return nonCapturingUnits

]]--

local nonCapturingUnits = VFS.Include "LuaRules/Configs/cv_nonCapturingUnits.lua"

local pveEnabled = Spring.Utilities.Gametype.IsPvE()

if pveEnabled then
	Spring.Echo("[ControlVictory] Deactivated because Chickens or Scavengers are present!")
	return false
end

-- local moveSpeed = .5
local buildingMask = 2

local scoreModes = {
	disabled = { name = "Disabled" }, -- none (duh)
	countdown = { name = "Countdown" }, -- A point decreases all opponents' scores, zero means defeat
	tugofwar = { name = "Tug of War" }, -- A point steals enemy score, zero means defeat
	domination = { name = "Domination" }, -- Holding all points will grant 100 score, first to reach the score limit wins
}
local scoreMode = scoreModes[selectedScoreMode]

local gaia = Spring.GetGaiaTeamID()
local _,_,_,_,_,gaia = Spring.GetTeamInfo(gaia)
local mapx, mapz = Game.mapSizeX, Game.mapSizeZ

if gadgetHandler:IsSyncedCode() then
	------------
	-- SYNCED --
	------------

	local points = {}
	local score = {}

	local dom = {
		dominator = nil,
		dominationTime = nil,
	}

	local function declareLoser(team)
		if team == gaia then
			return
		end
		local losingPlayers = Spring.GetTeamList(team)
		for i = 1,#losingPlayers do
			Spring.KillTeam(losingPlayers[i])
		end
	end

	local function declareWinner(team)
		for _, a in ipairs(Spring.GetAllyTeamList()) do
			if a ~= team and a ~= gaia then
				declareLoser(a)
			end
		end
	end

	-- functions to be registered as globals

	local function gControlPoints()
		return points or {}
	end

	local function gNonCapturingUnits()
		return nonCapturingUnits or {}
	end

	local function gCaptureRadius()
		return captureRadius or 0
	end

	-- end global-registered functions

	function gadget:Initialize()
		gadgetHandler:RegisterGlobal('ControlPoints', gControlPoints)
		gadgetHandler:RegisterGlobal('NonCapturingUnits', gNonCapturingUnits)
		gadgetHandler:RegisterGlobal('CaptureRadius', gCaptureRadius)

		-- Create table of metal spots.
		local metalSpots = GG.metalSpots
		local metalPoints = {}
		if metalSpots then
			for i = 1, #metalSpots do
				local spot = metalSpots[i]
				table.insert(metalPoints, {x = spot.x, y = 0, z = spot.z})
			end
		end

		if scoreMode == scoreModes.domination then
			local angle = math.random() * math.pi * 2
			points = {}
			for i = 1, 3 do
				local angle = angle + i * math.pi * 1 / 1.5
				points[i] = {
					x = mapx / 2 + mapx * .12 * math.sin(angle),
					y = 0,
					z = mapz / 2 + mapz * .12 * math.cos(angle),
					--We can make them move around if we want to by uncommenting these lines and the ones below
					--velx=moveSpeed * 10 * -1 * math.cos(angle),
					--velz=moveSpeed * 10 * math.sin(angle),
					owner = nil,
					aggressor = nil,
					capture = 0,
				}
			end
		else
			local mapConfigExists = false
			if useMapConfig then
				local configfile, _ = string.gsub(Game.mapName, ".smf$", ".lua")
				configfile = "LuaRules/Configs/ControlPoints/cv_" .. configfile .. ".lua"
				Spring.Echo("[ControlVictory] Attempting to load map config file" .. configfile)
				if VFS.FileExists(configfile) then
					local config = VFS.Include(configfile)
					mapConfigExists = true
					points = config.points
					for _, p in pairs(points) do
						p.capture = 0
					end
					-- moveSpeed = 0
				end
			end
			if (not mapConfigExists) and useMexConfig and #metalPoints > 7 then
				points = {}
				for i = 1,#metalPoints do
					points[i] = {
						x = metalPoints[i].x,
						y = metalPoints[i].y,
						z = metalPoints[i].z,
						owner = nil,
						aggressor = nil,
						capture = 0,
					}
				end
			elseif not mapConfigExists then
				if numberOfControlPoints == "7" then
					--Since no config file is found, we create 7 points spaced out in a circle on the map
					local angle = math.random() * math.pi * 2
					points = {}
					for i = 2, 7 do
						local angle = angle + i * math.pi * 2 / 6
						points[i] = {
							x = mapx / 2 + mapx * .4 * math.sin(angle),
							y = 0,
							z = mapz / 2 + mapz * .4 * math.cos(angle),
							--We can make them move around if we want to by uncommenting these lines and the ones below
							--velx=moveSpeed * 10 * -1 * math.cos(angle),
							--velz=moveSpeed * 10 * math.sin(angle),
							owner = nil,
							aggressor = nil,
							capture = 0,
						}
					end
				end

				if numberOfControlPoints == "13" then
					local angle = math.random() * math.pi * 2
					points = {}
					for i = 2, 7 do
						local angle = angle + i * math.pi * 2 / 6
						points[i] = {
							x = mapx / 2 + mapx * .2 * math.sin(angle),
							y = 0,
							z = mapz / 2 + mapz * .2 * math.cos(angle),
							--We can make them move around if we want to by uncommenting these lines and the ones below
							--velx=moveSpeed * 10 * -1 * math.cos(angle),
							--velz=moveSpeed * 10 * math.sin(angle),
							owner = nil,
							aggressor = nil,
							capture = 0,
						}
					end

					for i = 8, 13 do
						local angle = angle + i * math.pi * 2 / 6 + 9
						points[i] = {
							x = mapx / 2 + mapx * .4 * math.sin(angle),
							y = 0,
							z = mapz / 2 + mapz * .4 * math.cos(angle),
							--We can make them move around if we want to by uncommenting these lines and the ones below
							--velx=moveSpeed * 10 * -1 * math.cos(angle),
							--velz=moveSpeed * 10 * math.sin(angle),
							owner = nil,
							aggressor = nil,
							capture = 0,
						}
					end

				end

				if numberOfControlPoints == "19" then
					local angle = math.random() * math.pi * 2
					points = {}
					for i = 2, 7 do
						local angle = angle + i * math.pi * 2 / 6
						points[i] = {
							x = mapx / 2 + mapx * .18 * math.sin(angle),
							y = 0,
							z = mapz / 2 + mapz * .18 * math.cos(angle),
							--We can make them move around if we want to by uncommenting these lines and the ones below
							--velx=moveSpeed * 10 * -1 * math.cos(angle),
							--velz=moveSpeed * 10 * math.sin(angle),
							owner = nil,
							aggressor = nil,
							capture = 0,
						}
					end

					for i = 8, 13 do
						local angle = angle + i * math.pi * 2 / 6 + 9
						points[i] = {
							x = mapx / 2 + mapx * .3 * math.sin(angle),
							y = 0,
							z = mapz / 2 + mapz * .3 * math.cos(angle),
							--We can make them move around if we want to by uncommenting these lines and the ones below
							--velx=moveSpeed * 10 * -1 * math.cos(angle),
							--velz=moveSpeed * 10 * math.sin(angle),
							owner = nil,
							aggressor = nil,
							capture = 0,
						}
					end

					for i = 14, 19 do
						local angle = angle + i * math.pi * 2 / 6 + 18
						points[i] = {
							x = mapx / 2 + mapx * .4 * math.sin(angle),
							y = 0,
							z = mapz / 2 + mapz * .4 * math.cos(angle),
							--We can make them move around if we want to by uncommenting these lines and the ones below
							--velx=moveSpeed * 10 * -1 * math.cos(angle),
							--velz=moveSpeed * 10 * math.sin(angle),
							owner = nil,
							aggressor = nil,
							capture = 0,
						}
					end
				end

				if numberOfControlPoints == "25" then
					local angle = math.random() * math.pi * 2
					points = {}
					for i = 2, 7 do
						local angle = angle + i * math.pi * 2 / 6
						points[i] = {
							x = mapx / 2 + mapx * .16 * math.sin(angle),
							y = 0,
							z = mapz / 2 + mapz * .16 * math.cos(angle),
							--We can make them move around if we want to by uncommenting these lines and the ones below
							--velx=moveSpeed * 10 * -1 * math.cos(angle),
							--velz=moveSpeed * 10 * math.sin(angle),
							owner = nil,
							aggressor = nil,
							capture = 0,
						}
					end

					for i = 8, 13 do
						local angle = angle + i * math.pi * 2 / 6 + 9
						points[i] = {
							x = mapx / 2 + mapx * .26 * math.sin(angle),
							y = 0,
							z = mapz / 2 + mapz * .26 * math.cos(angle),
							--We can make them move around if we want to by uncommenting these lines and the ones below
							--velx=moveSpeed * 10 * -1 * math.cos(angle),
							--velz=moveSpeed * 10 * math.sin(angle),
							owner = nil,
							aggressor = nil,
							capture = 0,
						}
					end

					for i = 14, 19 do
						local angle = angle + i * math.pi * 2 / 6 + 20
						points[i] = {
							x = mapx / 2 + mapx * .29 * math.sin(angle),
							y = 0,
							z = mapz / 2 + mapz * .29 * math.cos(angle),
							--We can make them move around if we want to by uncommenting these lines and the ones below
							--velx=moveSpeed * 10 * -1 * math.cos(angle),
							--velz=moveSpeed * 10 * math.sin(angle),
							owner = nil,
							aggressor = nil,
							capture = 0,
						}
					end

					for i = 20, 25 do
						local angle = angle + i * math.pi * 2 / 6 + 36
						points[i] = {
							x = mapx / 2 + mapx * .4 * math.sin(angle),
							y = 0,
							z = mapz / 2 + mapz * .4 * math.cos(angle),
							--We can make them move around if we want to by uncommenting these lines and the ones below
							--velx=moveSpeed * 10 * -1 * math.cos(angle),
							--velz=moveSpeed * 10 * math.sin(angle),
							owner = nil,
							aggressor = nil,
							capture = 0,
						}
					end
				end
				points[1] = {
					x = mapx / 2,
					y = 0,
					z = mapz / 2,
					owner = nil,
					aggressor = nil,
					capture = 0,
				}
			end
		end

		for _, a in ipairs(Spring.GetAllyTeamList()) do
			if scoreMode ~= scoreModes.domination then
				score[a] = limitScore*#points
			else
				score[a] = 0
			end
		end
		score[gaia] = 0

		_G.points = points
		_G.score = score
		_G.dom = dom

		-- Set building masks for control points
		if useBuildingMask == true then
			for _, capturePoint in pairs(points) do
				local r = captureRadius
				local mask = buildingMask
				local r2 = r * r
				local step = Game.squareSize * 2
				for z = 0, 2 * r, step do
					-- top to bottom diameter
					local lineLength = math.sqrt(r2 - (r - z) ^ 2)
					for x = -lineLength, lineLength, step do
						local squareX, squareZ = (capturePoint.x + x) / step, (capturePoint.z + z - r) / step
						if squareX > 0 and squareZ > 0 and squareX < Game.mapSizeX / step and squareZ < Game.mapSizeZ / step then
							Spring.SetSquareBuildingMask(squareX, squareZ, mask)
							--Spring.MarkerAddPoint((cx + x), 0, (cz + z - r))
						end
					end
				end
			end
		end

	end

	-------------
	function gadget:GameFrame(f)
		-- This causes the points to move around, windows screensaver style :-)
		--[[   for _,p in pairs(points) do
			if p.velx then
				 p.velx = p.velx / moveSpeed + .03 * (0.5 - math.random())
				 p.velz = p.velz / moveSpeed + .03 * (0.5 - math.random())
				 local vel = (p.velx^2 + p.velz^2)^0.5
				 local velmult = math.max(1 - .1^(math.max(1, math.min(3, math.log(vel / moveSpeed)))), (vel * 1^.01)^.99 / vel) * moveSpeed
				 p.velx = p.velx * velmult
				 p.velz = p.velz * velmult
				 if p.x + p.velx < captureRadius or p.x + p.velx > mapx - captureRadius then p.velx = -1 * p.velx end
				 if p.z + p.velz < captureRadius or p.z + p.velz > mapz - captureRadius then p.velz = -1 * p.velz end
				 p.x = p.x + p.velx
				 p.x = p.x + p.velx
				 p.z = p.z + p.velz
				 p.z = p.z + p.velz
			  end
		   end ]]--

		if f % 30 < .1 and f / 30 > startTime then
			local owned = {}
			for _, allyTeamID in ipairs(Spring.GetAllyTeamList()) do
				owned[allyTeamID] = 0
			end
			for _, capturePoint in pairs(points) do
				local aggressor = nil
				local owner = capturePoint.owner
				local count = 0
				for _, u in ipairs(Spring.GetUnitsInCylinder(capturePoint.x, capturePoint.z, captureRadius)) do
					local validUnit = true
					for _, i in ipairs(nonCapturingUnits) do
						if UnitDefs[Spring.GetUnitDefID(u)].name == i then
							validUnit = false
						end
					end
					if validUnit then
						local unitOwner = Spring.GetUnitAllyTeam(u)
						if unitOwner ~= gaia then
							if owner then
								if owner == unitOwner then
									count = 0
									break
								else
									count = count + 1
								end
							else
								if aggressor then
									if aggressor == unitOwner then
										count = count + 1
									else
										aggressor = nil
										break
									end
								else
									aggressor = unitOwner
									count = count + 1
								end
							end
						end
					end
				end
				if owner then
					if count > 0 then
						capturePoint.aggressor = nil
						capturePoint.capture = capturePoint.capture + (1 + captureBonus * (count - 1)) * decapSpeed
					else
						capturePoint.capture = capturePoint.capture - decapSpeed
						if capturePoint.capture < 0 then
							capturePoint.capture = 0
						end
					end
				elseif aggressor then
					if capturePoint.aggressor == aggressor then
						capturePoint.capture = capturePoint.capture + 1 + captureBonus * (count - 1)
					else
						capturePoint.aggressor = aggressor
						capturePoint.capture = 1 + captureBonus * (count - 1)
					end
				end
				if capturePoint.capture > captureTime then
					capturePoint.owner = capturePoint.aggressor
					capturePoint.capture = 0
				end
				if capturePoint.owner then
					owned[capturePoint.owner] = owned[capturePoint.owner] + 1
				end
			end

			-- resources granted to each play on an allyteam that captures a point
			for _, allyTeamID in ipairs(Spring.GetAllyTeamList()) do
				local ateams = Spring.GetTeamList(allyTeamID)
				for i = 1, #ateams do
					Spring.AddTeamResource(ateams[i], "metal", owned[allyTeamID] * metalPerPoint) -- adjust the 5
					Spring.AddTeamResource(ateams[i], "energy", owned[allyTeamID] * energyPerPoint) -- adjust the 5
				end
			end

			if scoreMode == scoreModes.countdown then
				for owner, count in pairs(owned) do
					for _, allyTeamID in ipairs(Spring.GetAllyTeamList()) do
						if allyTeamID ~= owner and score[allyTeamID] > 0 then
							score[allyTeamID] = score[allyTeamID] - count
						end
					end
				end
				for allyTeamID, teamScore in pairs(score) do
					if teamScore <= 0 then
						declareLoser(allyTeamID)
					end
				end
			elseif scoreMode == scoreModes.tugofwar then
				for owner, count in pairs(owned) do
					for _, a in ipairs(Spring.GetAllyTeamList()) do
						if a ~= owner and score[a] > 0 then
							score[a] = score[a] - count * tugofWarModifier
							score[owner] = score[owner] + count * tugofWarModifier
						end
					end
				end
				for allyTeamID, teamScore in pairs(score) do
					if teamScore <= 0 then
						declareLoser(allyTeamID)
					end
				end
			elseif scoreMode == scoreModes.domination then
				local prevDominator = dom.dominator
				dom.dominator = nil
				for owner, count in pairs(owned) do
					if count == #points then
						dom.dominator = owner
						if prevDominator ~= owner or not dom.dominationTime then
							dom.dominationTime = f + 30 * dominationScoreTime
							Spring.Echo([[--------------------------------------------]])
							Spring.Echo([[A domination will be scored in 30 seconds!!!]])
							Spring.Echo([[--------------------------------------------]])
						end
						break
					end
				end
				if dom.dominator then
					if dom.dominationTime <= f then
						for _, capturePoint in pairs(points) do
							capturePoint.owner = nil
							capturePoint.capture = 0
						end
						score[dom.dominator] = score[dom.dominator] + dominationScore
						if score[dom.dominator] >= limitScore then
							declareWinner(dom.dominator)
							Spring.Echo([[-------------------------------]])
							Spring.Echo([[A domination has been scored!!!]])
							Spring.Echo([[-------------------------------]])
						end
					end
				end
			end
		end
	end

else
	--------------
	-- UNSYNCED
	--------------

	function gadget:GameFrame()
		if Spring.GetGameFrame() % 15 == 1 then
			if Script.LuaUI("GadgetControlVictoryUpdate") then
				Script.LuaUI.GadgetControlVictoryUpdate(SYNCED.score, SYNCED.points, SYNCED.dom)
			end
		end
	end

end
