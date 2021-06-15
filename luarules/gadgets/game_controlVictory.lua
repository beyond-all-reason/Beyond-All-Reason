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
if modOptions == nil or modOptions.scoremode == nil or modOptions.scoremode == "disabled" then
	return
end

local useMapConfig = modOptions.usemapconfig or "enabled"
local numberOfControlPoints = modOptions.numberofcontrolpoints or 13
local captureRadius = modOptions.captureradius or 250
local decapSpeed = modOptions.decapspeed or 2
local startTime = modOptions.starttime or 0
local metalPerPoint = modOptions.metalperpoint or 0
local energyPerPoint = modOptions.energyperpoint or 0
local tugofWarModifier = modOptions.tugofwarmodifier or 2
local limitScore = modOptions.limitscore or 10000
local captureTime = modOptions.capturetime or 60
local captureBonus = (modOptions.capturebonus or 5) * 0.01 -- modoption number is percentage 0%-100%
local dominationScoreTime = modOptions.dominationscoretime or 30
local dominationScore = modOptions.dominationscore or 1000
local scoreModeName

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

////
!!!!THIS IS NOW DEPRECATED IN LEIU OF BUILDINGMASK!!!!
The code has, however, been kept (commented out) in case other game developers end up having a use for it.

The buildableUnits.lua config file is structured like this:
These are units that are allowed to be built within control points.

////

local buildableUnits = {
	"armamex",
	"armmex",
	"armmoho",
	"armuwmex",
	"armuwmme",
	"corexp",
	"cormex",
	"cormexp",
	"cormoho",
	"coruwmex",
	"coruwmme",
}

return buildableUnits

////

]]--

local nonCapturingUnits = VFS.Include "LuaRules/Configs/cv_nonCapturingUnits.lua"
--local buildableUnits = VFS.Include"LuaRules/Configs/cv_buildableUnits.lua"

--Make controlvictory exit if chickens are present
local chickensEnabled = false
local teams = Spring.GetTeamList()
for i = 1, #teams do
	local luaAI = Spring.GetTeamLuaAI(teams[i])
	if luaAI ~= "" then
		if luaAI == "Chicken: Very Easy" or
			luaAI == "Chicken: Easy" or
			luaAI == "Chicken: Normal" or
			luaAI == "Chicken: Hard" or
			luaAI == "Chicken: Very Hard" or
			luaAI == "Chicken: Epic!" or
			luaAI == "Chicken: Custom" or
			luaAI == "Chicken: Survival" or
			luaAI == "ScavengersAI" then
			chickensEnabled = true
		end
	end
end

if chickensEnabled then
	Spring.Echo("[ControlVictory] Deactivated because Chickens or Scavengers are present!")
	return false
end

-- local moveSpeed = .5
local buildingMask = 2

--Here we mitigate potential issues caused by wonky options settings

if numberOfControlPoints == 7 then
	limitScore = limitScore * 0.5
	captureRadius = captureRadius * 1.25
end

if numberOfControlPoints == 13 then
	limitScore = limitScore * 1
	captureRadius = captureRadius * 1
end

if numberOfControlPoints == 19 then
	limitScore = limitScore * 1.5
	captureRadius = captureRadius * 0.75
end

if numberOfControlPoints == 25 then
	limitScore = limitScore * 2
	captureRadius = captureRadius * 0.5
end

--Smaller than 250 gets really hard to see on the minimap
if captureRadius < 250 then
	captureRadius = 250
end

--End Mitigation of wonky options settings

local scoreModes = {
	disabled = 0, -- none (duh)
	countdown = 1, -- A point decreases all opponents' scores, zero means defeat
	tugofwar = 2, -- A point steals enemy score, zero means defeat
	domination = 3, -- Holding all points will grant 100 score, first to reach the score limit wins
}
local scoreMode = scoreModes[Spring.GetModOptions().scoremode or "countdown"]

--Lets add a pretty way to access scoremodes
if scoreMode == 0 then
	scoreModeName = "Disabled"
end
if scoreMode == 1 then
	scoreModeName = "Countdown"
end
if scoreMode == 2 then
	scoreModeName = "Tug of War"
end
if scoreMode == 3 then
	scoreModeName = "Domination"
end

local gaia = Spring.GetGaiaTeamID()
local mapx, mapz = Game.mapSizeX, Game.mapSizeZ

if (gadgetHandler:IsSyncedCode()) then
	------------
	-- SYNCED --
	------------

	local points = {}
	local score = {}

	local dom = {
		dominator = nil,
		dominationTime = nil,
	}

	local function Loser(team)
		if team == gaia then
			return
		end
		for _, u in ipairs(Spring.GetAllUnits()) do
			if team == Spring.GetUnitAllyTeam(u) then
				Spring.DestroyUnit(u)
			end
		end
	end

	local function Winner(team)
		for _, a in ipairs(Spring.GetAllyTeamList()) do
			if a ~= team and a ~= gaia then
				Loser(a)
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

	-- local function gBuildableUnits()
	-- 	return buildableUnits or {}
	-- end

	local function gCaptureRadius()
		return captureRadius or 0
	end

	-- end global-registered functions

	function gadget:Initialize()
		gadgetHandler:RegisterGlobal('ControlPoints', gControlPoints)
		gadgetHandler:RegisterGlobal('NonCapturingUnits', gNonCapturingUnits)
		-- gadgetHandler:RegisterGlobal('BuildableUnits', gBuildableUnits)
		gadgetHandler:RegisterGlobal('CaptureRadius', gCaptureRadius)

		for _, a in ipairs(Spring.GetAllyTeamList()) do
			if scoreMode ~= 3 then
				score[a] = limitScore
			else
				score[a] = 0
			end
		end

		score[gaia] = 0

		if scoreModeName == "Domination" then
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

			if useMapConfig == "enabled" then
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
			if not mapConfigExists then
				if numberOfControlPoints == 7 then
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

				if numberOfControlPoints == 13 then
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

				if numberOfControlPoints == 19 then
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

				if numberOfControlPoints == 25 then
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
					local metalPerPoint = Spring.GetModOptions().metalperpoint
					local energyPerPoint = Spring.GetModOptions().energyperpoint
					if Spring.GetModOptions().metalperpoint == nil then
						metalPerPoint = 0
					end
					if Spring.GetModOptions().energyperpoint == nil then
						energyPerPoint = 0
					end
					Spring.AddTeamResource(ateams[i], "metal", owned[allyTeamID] * metalPerPoint) -- adjust the 5
					Spring.AddTeamResource(ateams[i], "energy", owned[allyTeamID] * energyPerPoint) -- adjust the 5
				end
			end

			if scoreMode == 1 then
				-- Countdown
				for owner, count in pairs(owned) do
					for _, allyTeamID in ipairs(Spring.GetAllyTeamList()) do
						if allyTeamID ~= owner and score[allyTeamID] > 0 then
							score[allyTeamID] = score[allyTeamID] - count
						end
					end
				end
				for allyTeamID, teamScore in pairs(score) do
					if teamScore <= 0 then
						Loser(allyTeamID)
					end
				end
			elseif scoreMode == 2 then
				-- Tug of War
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
						Loser(allyTeamID)
					end
				end
			elseif scoreMode == 3 then
				-- Domination
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
						score[dom.dominator] = score[dom.dominator] + Spring.GetModOptions().dominationscore
						if score[dom.dominator] >= limitScore then
							Winner(dom.dominator)
							Spring.Echo([[-------------------------------]])
							Spring.Echo([[A domination has been scored!!!]])
							Spring.Echo([[-------------------------------]])
						end
					end
				end
			end
		end
	end

	-- Allow units listed in the buildableUnits config to be built in control points
	-- This is deprecated in leiu of buildingMask
	-- local allowedBuildableUnits = {}
	-- for i = 1, #buildableUnits do
	-- if UnitDefNames[buildableUnits[i]] then
	-- allowedBuildableUnits[UnitDefNames[buildableUnits[i]].id] = true
	-- end
	-- end

	-- function gadget:AllowUnitCreation(unit, builder, team, x, y, z)
	-- if allowedBuildableUnits[unit] then
	-- return true
	-- end
	-- for _, p in pairs(points) do
	-- if x and math.sqrt((x - p.x) * (x - p.x) + (z - p.z) * (z - p.z)) < captureRadius then
	-- Spring.SendMessageToPlayer(team, "This unit is not allowed to be built in Control Points")
	-- return false
	-- end
	-- end
	-- return true
	-- end

else
	--------------
	-- UNSYNCED --
	--------------

	local pieces = math.floor(captureRadius / 20)
	local OPTIONS = {
		circlePieces = pieces,
		circlePieceDetail = math.floor(pieces / 4),
		circleSpaceUsage = 0.85,
		circleInnerOffset = 0,
		rotationSpeed = 0.3,
	}
	pieces = nil

	local exampleImage = ":n:LuaRules/Images/controlpoints.png"
	local showGameModeInfo = true
	local controlPointList
	local controlPointPromptPlayed = false

	local scoreboardRelX = 0.87
	local scoreboardRelY = 0.76
	local scoreboardWidth = 100
	local scoreboardHeight = 100
	local scoreboardX, scoreboardY
	local draggingScoreboard = false
	
	local bgMargin = 6
	local vsx, vsy = Spring.GetViewGeometry()
	local uiScale = 1
	local ui_scale = Spring.GetConfigFloat("ui_scale", 1)
	
	local closeButtonSize = 30
	local screenHeight = 212 - bgMargin - bgMargin
	local screenWidth = 1050 - bgMargin - bgMargin
	local screenX = (vsx * 0.5) - (screenWidth / 2)
	local screenY = (vsy * 0.5) + (screenHeight / 2)
	local titleRect, elementRect
	local infoList, scoreboardList, mouseoverScoreboardList

	local fontfile = "fonts/" .. Spring.GetConfigString("bar_font2", "Exo2-SemiBold.otf")
	local fontfileScale = (0.5 + (vsx * vsy / 5700000))
	local fontfileSize = 32
	local fontfileOutlineSize = 10
	local fontfileOutlineStrength = 1.4
	local font = gl.LoadFont(fontfile, fontfileSize * fontfileScale, fontfileOutlineSize * fontfileScale, fontfileOutlineStrength)


	local Text = gl.Text
	local Color = gl.Color
	local PushMatrix = gl.PushMatrix
	local PopMatrix = gl.PopMatrix
	local Translate = gl.Translate
	local BeginEnd = gl.BeginEnd
	local CreateList = gl.CreateList
	local CallList = gl.CallList
	local Scale = gl.Scale
	local Rotate = gl.Rotate
	local Vertex = gl.Vertex
	local QUADS = GL.QUADS
	local TRIANGLE_FAN = GL.TRIANGLE_FAN
	local PolygonOffset = gl.PolygonOffset
	local playerListEntry = {}
	local capturePoints = {}
	local controlPointSolidList = {}

	local floor = math.floor

	local prevTimer = Spring.GetTimer()
	local currentRotationAngle = 0

	local ringThickness = 3.5
	local capturePieParts = 4 + floor(captureRadius / 8)

	local RectRound = Spring.FlowUI.Draw.RectRound
	local UiElement = Spring.FlowUI.Draw.Element
	local elementCorner = Spring.FlowUI.elementCorner

	-----------------------------------------------------------------------------------------
	-- creates initial player listing
	-----------------------------------------------------------------------------------------
	local function createPlayerList()
		local playerEntries = {}
		for allyTeamID, teamScore in spairs(SYNCED.score) do
			if allyTeamID ~= gaia then
				--does this allyteam have a table? if not, make one
				if playerEntries[allyTeamID] == nil then
					playerEntries[allyTeamID] = {}
				end

				for _, teamId in pairs(Spring.GetTeamList(allyTeamID)) do
					local playerList = Spring.GetPlayerList(teamId, true)
					-- does this team have an entry? if not, make one!
					if playerEntries[allyTeamID][teamId] == nil then
						playerEntries[allyTeamID][teamId] = {}
					end
					local r, g, b = Spring.GetTeamColor(teamId)
					local playerTeamColor = string.char("255", r * 255, g * 255, b * 255)
					for k, v in pairs(playerList) do
						-- does this player have an entry? if not, make one!
						if playerEntries[allyTeamID][teamId][v] == nil then
							playerEntries[allyTeamID][teamId][v] = {}
						end

						playerEntries[allyTeamID][teamId][v]["name"] = Spring.GetPlayerInfo(v)
						playerEntries[allyTeamID][teamId][v]["color"] = playerTeamColor
					end -- end playerId
				end -- end teamId
			end -- allyTeamID
		end -- gaia exclusion
		return playerEntries
	end

	local function DrawCircleLine(innersize, outersize)
		BeginEnd(QUADS, function()
			local detailPartWidth, a1, a2, a3, a4
			local width = OPTIONS.circleSpaceUsage
			local detail = OPTIONS.circlePieceDetail

			local radstep = (2.0 * math.pi) / OPTIONS.circlePieces
			for i = 1, OPTIONS.circlePieces do
				for d = 1, detail do

					detailPartWidth = ((width / detail) * d)
					a1 = ((i + detailPartWidth - (width / detail)) * radstep)
					a2 = ((i + detailPartWidth) * radstep)
					a3 = ((i + OPTIONS.circleInnerOffset + detailPartWidth - (width / detail)) * radstep)
					a4 = ((i + OPTIONS.circleInnerOffset + detailPartWidth) * radstep)

					--outer (fadein)
					Vertex(math.sin(a4) * innersize, 0, math.cos(a4) * innersize)
					Vertex(math.sin(a3) * innersize, 0, math.cos(a3) * innersize)
					--outer (fadeout)
					Vertex(math.sin(a1) * outersize, 0, math.cos(a1) * outersize)
					Vertex(math.sin(a2) * outersize, 0, math.cos(a2) * outersize)
				end
			end
		end)
	end

	function DrawCircleSolid(size, pieces, drawPieces, innercolor, outercolor, revert)
		BeginEnd(TRIANGLE_FAN, function()
			local radstep = (2.0 * math.pi) / pieces
			local a1
			if (innercolor) then
				Color(innercolor)
			end
			Vertex(0, 0, 0)
			if (outercolor) then
				Color(outercolor)
			end
			for i = 0, drawPieces do
				if revert then
					a1 = -(i * radstep)
				else
					a1 = (i * radstep)
				end
				Vertex(math.sin(a1) * size, 0, math.cos(a1) * size)
			end
		end)
	end

	local function viewResize(force)
		local vsx2, vsy2 = Spring.GetViewGeometry()
		if force or vsx2 ~= vsy or vsx2 ~= vsy then
			vsx, vsy = vsx2, vsy2
			ui_scale = Spring.GetConfigFloat("ui_scale", 1)
			uiScale = (0.75 + (vsx * vsy / 7500000)) * ui_scale

			screenX = (vsx * 0.5) - (screenWidth / 2)
			screenY = (vsy * 0.5) + (screenHeight / 2)

			elementCorner = Spring.FlowUI.elementCorner

			scoreboardX = floor(vsx * scoreboardRelX)
			scoreboardY = floor(vsy * scoreboardRelY)

			if infoList then
				gl.DeleteList(infoList)
			end
			infoList = CreateList(drawGameModeInfo)
		end
	end

	function gadget:Initialize()
		playerListEntry = createPlayerList()

		viewResize(true)

		controlPointList = CreateList(DrawCircleLine, captureRadius - ringThickness, captureRadius)
		if Spring.GetGameFrame() > 0 then
			showGameModeInfo = false
		end

		for i, capturePoint in spairs(SYNCED.points) do
			if capturePoints[i] == nil then
				capturePoints[i] = {}
				capturePoints[i].color = { 1, 1, 1 }
				capturePoints[i].aggressorColor = { 1, 1, 1 }
				capturePoints[i].x = capturePoint.x
				capturePoints[i].y = Spring.GetGroundHeight(capturePoint.x, capturePoint.z) + 2
				capturePoints[i].z = capturePoint.z
			end
			if capturePoint.owner and capturePoint.owner ~= gaia then
				capturePoints[i].color[1], capturePoints[i].color[2], capturePoints[i].color[3] = Spring.GetTeamColor(Spring.GetTeamList(capturePoint.owner)[1])
			else
				capturePoints[i].color = { 1, 1, 1 }
			end
			if capturePoint.aggressor and capturePoint.aggressor ~= gaia then
				capturePoints[i].aggressorColor[1], capturePoints[i].aggressorColor[2], capturePoints[i].aggressorColor[3] = Spring.GetTeamColor(Spring.GetTeamList(capturePoint.aggressor)[1])
			else
				capturePoints[i].aggressorColor = { 1, 1, 1 }
			end
			capturePoints[i].capture = capturePoint.capture
		end
	end

	function gadget:DrawInMiniMap()
		PushMatrix()
		gl.LoadIdentity()
		Translate(0, 1, 0)
		Scale(1 / Game.mapSizeX, 1 / Game.mapSizeZ, 0)
		Rotate(90, 1, 0, 0)
		DrawPoints(true)
		PopMatrix()
	end

	function gadget:Update()
		local clockDifference = Spring.DiffTimers(Spring.GetTimer(), prevTimer)
		prevTimer = Spring.GetTimer()

		-- animate rotation
		if OPTIONS.rotationSpeed > 0 then
			local angleDifference = (OPTIONS.rotationSpeed) * (clockDifference * 5)
			currentRotationAngle = currentRotationAngle + (angleDifference * 0.6)
			if currentRotationAngle > 360 then
				currentRotationAngle = currentRotationAngle - 360
			end
		end
	end

	function gadget:GameFrame()

		for i, capturePoint in spairs(SYNCED.points) do
			if capturePoints[i] == nil then
				capturePoints[i] = {}
				capturePoints[i].color = { 1, 1, 1 }
				capturePoints[i].aggressorColor = { 1, 1, 1 }
				capturePoints[i].x = capturePoint.x
				capturePoints[i].y = Spring.GetGroundHeight(capturePoint.x, capturePoint.z) + 2
				capturePoints[i].z = capturePoint.z
			end
			if capturePoint.owner and capturePoint.owner ~= gaia then
				capturePoints[i].color[1], capturePoints[i].color[2], capturePoints[i].color[3] = Spring.GetTeamColor(Spring.GetTeamList(capturePoint.owner)[1])
			else
				capturePoints[i].color = { 1, 1, 1 }
			end
			if capturePoint.aggressor and capturePoint.aggressor ~= gaia then
				capturePoints[i].aggressorColor[1], capturePoints[i].aggressorColor[2], capturePoints[i].aggressorColor[3] = Spring.GetTeamColor(Spring.GetTeamList(capturePoint.aggressor)[1])
			else
				capturePoints[i].aggressorColor = { 1, 1, 1 }
			end
			capturePoints[i].capture = capturePoint.capture
		end
	end

	function DrawPoints(simplified)
		local capturedAlpha, capturingAlpha, prefix, parts
		if simplified then
			-- for minimap
			capturedAlpha = 0.6
			capturingAlpha = 0.9
			prefix = 'm_'        -- so it uses different displaylists
			parts = math.ceil((OPTIONS.circlePieces * OPTIONS.circlePieceDetail) / 2)
		else
			capturedAlpha = 0.3
			capturingAlpha = 0.6
			prefix = ''
			parts = (OPTIONS.circlePieces * OPTIONS.circlePieceDetail)
		end
		for i, point in pairs(capturePoints) do
			PushMatrix()
			Translate(point.x, point.y, point.z)
			-- owner circle backgroundcolor
			if controlPointSolidList[prefix .. point.color[1] .. '_' .. point.color[2] .. '_' .. point.color[3]] == nil then
				controlPointSolidList[prefix .. point.color[1] .. '_' .. point.color[2] .. '_' .. point.color[3]] = CreateList(DrawCircleSolid, captureRadius + ringThickness, parts, parts, { 0, 0, 0, 0 }, { point.color[1], point.color[2], point.color[3], capturedAlpha })
			end
			CallList(controlPointSolidList[prefix .. point.color[1] .. '_' .. point.color[2] .. '_' .. point.color[3]])

			-- captured percentage
			if point.capture > 0 then
				local revert = false
				if point.aggressorColor[1] .. '_' .. point.aggressorColor[2] .. '_' .. point.aggressorColor[3] == '1_1_1' then
					revert = true
				end
				local piesize = floor(((point.capture / captureTime) / (1 / capturePieParts)) + 0.5)
				if controlPointSolidList[prefix .. point.aggressorColor[1] .. '_' .. point.aggressorColor[2] .. '_' .. point.aggressorColor[3] .. '_' .. piesize] == nil then
					controlPointSolidList[prefix .. point.aggressorColor[1] .. '_' .. point.aggressorColor[2] .. '_' .. point.aggressorColor[3] .. '_' .. piesize] = CreateList(DrawCircleSolid, (captureRadius - ringThickness * 2), capturePieParts, piesize, { 0, 0, 0, 0 }, { point.aggressorColor[1], point.aggressorColor[2], point.aggressorColor[3], capturingAlpha }, revert)
				end
				CallList(controlPointSolidList[prefix .. point.aggressorColor[1] .. '_' .. point.aggressorColor[2] .. '_' .. point.aggressorColor[3] .. '_' .. piesize])
			end
			if not simplified then
				-- not for minimap
				--ring
				Rotate(currentRotationAngle, 0, 1, 0)
				Color(1, 1, 1, 0.6)
				CallList(controlPointList)
			end
			PopMatrix()
		end
	end

	function gadget:DrawWorldPreUnit()
		PolygonOffset(-10000, -1)  -- draw on top of water/map - sideeffect: will shine through terrain/mountains
		DrawPoints(false)        -- Todo: use DrawWorldPreUnit make it so that it colorizes the map/ground
		PolygonOffset(false)
	end

	function gadget:Shutdown()
		if Script.LuaUI("GuishaderRemoveRect") then
			Script.LuaUI.GuishaderRemoveRect('cv_scoreboard')
			Script.LuaUI.GuishaderRemoveRect('cv_scoreboardtitle')
		end
		gl.DeleteFont(font)
	end

	function drawGameModeInfo()
		local white = "\255\255\255\255"
		local offwhite = "\255\210\210\210"
		local yellow = "\255\255\255\0"
		local orange = "\255\255\135\0"
		local green = "\255\0\255\0"
		local red = "\255\255\0\0"
		local skyblue = "\255\136\197\226"

		PushMatrix()
		Translate(-(vsx * (uiScale - 1)) / 2, -(vsy * (uiScale - 1)) / 2, 0)
		Scale(uiScale, uiScale, 1)

		-- background
		local infoRect = {screenX - bgMargin, screenY - screenHeight - bgMargin, screenX + screenWidth + bgMargin, screenY + bgMargin}
		UiElement(infoRect[1], infoRect[2], infoRect[3], infoRect[4], 0,1,1,1, 1,1,1,1, Spring.GetConfigFloat("ui_opacity", 0.6) + 0.2)

		-- close button
		local size = closeButtonSize * 0.7
		local width = size * 0.055
		Color(1, 1, 1, 1)
		PushMatrix()
		Translate(screenX + screenWidth - (closeButtonSize / 2), screenY - (closeButtonSize / 2), 0)
		gl.Rotate(-45, 0, 0, 1)
		gl.Rect(-width, size / 2, width, -size / 2)
		gl.Rotate(90, 0, 0, 1)
		gl.Rect(-width, size / 2, width, -size / 2)
		PopMatrix()

		-- title
		local title = offwhite .. [[Area Capture Mode    ]] .. yellow .. scoreModeName
		local titleFontSize = 18
		Color(0, 0, 0, 0.8)
		titleRect = { screenX - bgMargin, screenY + bgMargin, screenX + (gl.GetTextWidth(title) * titleFontSize) + 27 - bgMargin, screenY + 37 }
		RectRound(titleRect[1], titleRect[2], titleRect[3], titleRect[4], elementCorner, 1, 1, 0, 0)

		font:Begin()
		font:SetTextColor(1, 1, 1, 1)
		font:SetOutlineColor(0, 0, 0, 0.4)
		font:Print(title, screenX- bgMargin + (titleFontSize * 0.75), screenY + bgMargin + 8, titleFontSize, "on")
		font:End()

		-- image of minimap showing controlpoints
		local imageSize = 200
		Color(1, 1, 1, 1)
		gl.Texture(exampleImage)
		gl.TexRect(screenX, screenY, screenX + imageSize, screenY - imageSize)
		gl.Texture(false)

		-- textarea

		local infotext = offwhite .. [[Controlpoints are spread across the map. They can be captured by moving units into the circles.
Note that you can only build certain units inside them (e.g. Metal Extractors/Resource Node Generators).

There are 3 modes (Current mode is ]] .. yellow .. scoreModeName .. offwhite .. [[):
- Countdown:  Your score counts down until zero based upon how many points your enemy owns.
- Tug of War: Score is transferred between teams. Score transferred is multiplied by ]] .. yellow .. tugofWarModifier .. offwhite .. [[.
- Domination: Capture all controlpoints on the map for ]] .. yellow .. dominationScoreTime .. offwhite .. [[ seconds in order to gain ]] .. yellow .. dominationScore .. offwhite .. [[ score. Goal ]] .. yellow .. limitScore .. offwhite .. [[.

You will also gain ]] .. white .. [[+]] .. skyblue .. metalPerPoint .. offwhite .. [[ metal and ]] .. white .. [[+]] .. yellow .. energyPerPoint .. offwhite .. [[ energy for each controlpoint you own.

There are various options available in the lobby bsettings (use ]] .. yellow .. [[!list bsettings]] .. offwhite .. [[ in the lobby chat)]]

		Text(infotext, screenX + imageSize + 15, screenY - 25, 16, "no")

		PopMatrix()
	end

	function drawMouseoverScoreboard()
		-- background
		Color(0, 0, 0, 0.75)
		RectRound(elementRect[1], elementRect[2], elementRect[3], elementRect[4], elementCorner, 0, 1, 1, 1)

		-- text
		Text("\255\200\200\200Middlemouse\nto move", scoreboardX, scoreboardY + 7, 15*uiScale, "co")
	end

	function drawScoreboard()
		PushMatrix()
		local maxWidth = scoreboardWidth
		local maxHeight = scoreboardHeight

		-- background
		elementRect = {scoreboardX - floor((bgMargin + (scoreboardWidth/2))*uiScale), scoreboardY - floor(((scoreboardHeight/2) + bgMargin)*uiScale), scoreboardX + floor(((scoreboardWidth/2) + bgMargin)*uiScale), scoreboardY + floor((bgMargin + (scoreboardHeight/2))*uiScale)}
		UiElement(elementRect[1], elementRect[2], elementRect[3], elementRect[4], 0,1,1,1, 1,1,1,1, Spring.GetConfigFloat("ui_opacity", 0.6) + 0.2)
		if Script.LuaUI("GuishaderInsertRect") then
			Script.LuaUI.GuishaderInsertRect(elementRect[1], elementRect[2], elementRect[3], elementRect[4], 'cv_scoreboard')
		end

		-- title
		local title = "\255\255\255\255" .. scoreModeName
		local titleFontSize = 18
		Color(0, 0, 0, 0.8)
		titleRect = { scoreboardX - floor((bgMargin + (scoreboardWidth/2))*uiScale), scoreboardY + floor((bgMargin + (scoreboardHeight/2))*uiScale), scoreboardX - floor(((scoreboardWidth/2) - (gl.GetTextWidth(title) * titleFontSize) - 27 + bgMargin)*uiScale), scoreboardY + floor(((scoreboardHeight/2) + 37)*uiScale) }
		RectRound(titleRect[1], titleRect[2], titleRect[3], titleRect[4], elementCorner, 1, 1, 0, 0)
		if Script.LuaUI("GuishaderInsertRect") then
			Script.LuaUI.GuishaderInsertRect(titleRect[1], titleRect[2], titleRect[3], titleRect[4], 'cv_scoreboardtitle')
		end

		font:Begin()
		font:SetTextColor(1, 1, 1, 1)
		font:SetOutlineColor(0, 0, 0, 0.4)
		font:Print(title, scoreboardX - ((bgMargin + (scoreboardWidth/2) - (titleFontSize * 0.75))*uiScale), scoreboardY + ((bgMargin + (scoreboardHeight/2) + 8)*uiScale), titleFontSize*uiScale, "on")
		font:End()

		local n = 1
		local dominator = SYNCED.dom.dominatorwa
		local dominationTime = SYNCED.dom.dominationTime
		local white = string.char("255", "255", "255", "255")
		local allyCounter = 0

		-- for all the scores with a team.
		for allyTeamID, allyScore in spairs(SYNCED.score) do
			local allyTeamMembers = Spring.GetTeamList(allyTeamID)
			if allyTeamID ~= gaia and allyTeamMembers and (#allyTeamMembers > 0) then
				local allyFound = false
				local name = "Some Bot"
				local team = allyTeamMembers[1]

				for _, teamId in pairs(Spring.GetTeamList(allyTeamID)) do
					local playerList = Spring.GetPlayerList(teamId)
					for _, playerId in pairs(playerList) do
						local _, _, spectator = Spring.GetPlayerInfo(playerId)
						if not spectator and not allyFound then
							name = Spring.GetPlayerInfo(playerId)
							team = teamId
							allyFound = true
						end
					end -- end playerId
				end -- end teamId

				if allyFound == false then
					if Spring.GetTeamLuaAI(team) == "" then
						name = "Evil Machine"
					else
						name = Spring.GetTeamLuaAI(team)
						if not name then
							name = "AI Team"
						end
					end
					--get AI info?
				end
				local r, g, b = Spring.GetTeamColor(team)
				local color = string.char("255", r * 255, g * 255, b * 255)
				Text(color .. name .. "'s team", scoreboardX - (((scoreboardWidth/2) - 10)*uiScale), scoreboardY + (((scoreboardHeight/2) - 22 - (55 * allyCounter - 1))*uiScale), 16*uiScale, "lo")
				Text(white .. "\255\200\200\200Score: \255\255\255\255" .. allyScore, scoreboardX - (((scoreboardWidth/2) - 10)*uiScale), scoreboardY + (((scoreboardHeight/2) - 42 - (55 * allyCounter - 1))*uiScale), 16*uiScale, "lo")

				local textwidth = 20 + gl.GetTextWidth(name .. "'s team") * 16
				if textwidth > maxWidth then
					maxWidth = textwidth
				end
				maxHeight = 42 + (55 * allyCounter - 1) + 13
				allyCounter = allyCounter + 1
			end -- not gaia
		end -- end allyTeamID

		if dominator and dominationTime > Spring.GetGameFrame() then
			--	Text( playerListEntry[dominator]["color"] .. "<" .. playerListEntry[dominator] .. "> will score a --Domination in " ..
			--		math.floor((dominationTime - Spring.GetGameFrame()) / 30) ..
			--		" seconds!", vsx *.5, vsy *.7, 24, "oc")
		end
		scoreboardWidth = floor(maxWidth / 2) * 2
		scoreboardHeight = floor(maxHeight / 2) * 2
		PopMatrix()
	end

	function gadget:DrawScreen(vsx, vsy)
		local mouseoverScoreboard = false

		viewResize()

		if showGameModeInfo then
			if infoList == nil then
				infoList = CreateList(drawGameModeInfo)
			end
			CallList(infoList)
		end

		local frame = Spring.GetGameFrame()
		if frame / 30 > startTime then
			if controlPointPromptPlayed ~= true then
				Spring.PlaySoundFile("sounds/ui/controlpointscanbecaptured.wav", 1)
				Spring.Echo([[Control Points may now be captured!]])
				controlPointPromptPlayed = true
			end
			if scoreboardList == nil or frame % 15 == 0 then
				if scoreboardList ~= nil then
					gl.DeleteList(scoreboardList)
				end
				scoreboardList = CreateList(drawScoreboard)
			end
			CallList(scoreboardList)

			local x, y = Spring.GetMouseState()
			if elementRect and IsOnRect(x, y, elementRect[1], elementRect[2], elementRect[3], elementRect[4]) then
				if not mouseoverScoreboard then
					mouseoverScoreboard = true
					if mouseoverScoreboardList ~= nil then
						gl.DeleteList(mouseoverScoreboardList)
					end
					mouseoverScoreboardList = CreateList(drawMouseoverScoreboard)
				end
			else
				mouseoverScoreboard = false
			end

			if mouseoverScoreboard then
				CallList(mouseoverScoreboardList)
			end
		else
			Text("Capturing points begins in:", vsx - 280, vsy * .58, 18, "lo")
			local timeleft = startTime - frame / 30
			timeleft = timeleft - timeleft % 1
			Text(timeleft .. " seconds", vsx - 280, vsy * .58 - 25, 18, "lo")
		end
	end

	function IsOnRect(x, y, BLcornerX, BLcornerY, TRcornerX, TRcornerY)

		-- check if the mouse is in a rectangle
		return x >= BLcornerX and x <= TRcornerX
			and y >= BLcornerY
			and y <= TRcornerY
	end

	function gadget:MouseMove(x, y, dx, dy)
		if draggingScoreboard then
			scoreboardRelX = scoreboardRelX + (dx / vsx)
			scoreboardRelY = scoreboardRelY + (dy / vsy)
			if scoreboardList ~= nil then
				gl.DeleteList(scoreboardList)
			end
			scoreboardList = CreateList(drawScoreboard)

			if mouseoverScoreboardList ~= nil then
				gl.DeleteList(mouseoverScoreboardList)
			end
			mouseoverScoreboardList = CreateList(drawMouseoverScoreboard)
		end
	end

	function gadget:MousePress(x, y, button)
		return mouseEvent(x, y, button, false)
	end

	function gadget:MouseRelease(x, y, button)
		return mouseEvent(x, y, button, true)
	end

	function mouseEvent(x, y, button, release)
		if Spring.IsGUIHidden() then
			return false
		end
		if release and draggingScoreboard then
			draggingScoreboard = false
		end
		if not release and Spring.GetGameFrame() > 0 then
			if button == 2 and elementRect and (IsOnRect(x, y, elementRect[1], elementRect[2], elementRect[3], elementRect[4]) or IsOnRect(x, y, titleRect[1], titleRect[2], titleRect[3], titleRect[4])) then
				draggingScoreboard = true
				return true
			end
		end
		if showGameModeInfo then
			-- on window
			local rectX1 = ((screenX - bgMargin) * uiScale) - ((vsx * (uiScale - 1)) / 2)
			local rectY1 = ((screenY + bgMargin) * uiScale) - ((vsy * (uiScale - 1)) / 2)
			local rectX2 = ((screenX + screenWidth + bgMargin) * uiScale) - ((vsx * (uiScale - 1)) / 2)
			local rectY2 = ((screenY - screenHeight - bgMargin) * uiScale) - ((vsy * (uiScale - 1)) / 2)
			if IsOnRect(x, y, rectX1, rectY2, rectX2, rectY1) then

				-- on close button
				local brectX1 = rectX2 - ((closeButtonSize + bgMargin + bgMargin) * uiScale)
				local brectY2 = rectY1 - ((closeButtonSize + bgMargin + bgMargin) * uiScale)
				if IsOnRect(x, y, brectX1, brectY2, rectX2, rectY1) then
					if release then
						showGameModeInfo = false
					end
					return true
				end
			end
		end
	end

end
