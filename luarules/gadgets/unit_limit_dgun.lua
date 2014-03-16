--  author:  Andrea Piras, modified by Bluestone
--  Copyright (C) 2010,2013

-- Overrides the file of the same name in basecontent.
-- This version simply prevents firing dgun within enemy startboxes.


function gadget:GetInfo()
  return {
    name      = "Limit Dgun Use",
    desc      = "Re-implements limit dgun in Lua",
    author    = "Andrea Piras, Bluestone",
    date      = "August, 2010",
    license   = "GNU GPL, v2 or later",
    layer     = 1, --run after game_intial_spawn 
    enabled   = true  
  }
end



--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

if (tostring(Spring.GetModOptions().limitdgun) or "off") == "off" then
	gadgetHandler:RemoveGadget()
end

-----------------------------
if gadgetHandler:IsSyncedCode() then 
-----------------------------

local pointRadius = 450 -- radius of circle about enemy startpoints inside of which we can't dgun, in StartPoints mode

local spGetUnitPosition = Spring.GetUnitPosition
local spGetTeamInfo = Spring.GetTeamInfo
local CMD_MANUALFIRE = CMD.MANUALFIRE
local boxes = {} --format is boxes[allyTeamID]={x1,z1,x2,z2} with x1<x2 and z1<z2, contain only non-allyteam startboxes, doesn't include gaia
local points = {} --format is points[allyTeamID][pointID]={x,y,z}; the point at which that player spawned (pointID does not mean anything in relation to teamID or playerID)
local pointRadiusSqrd = pointRadius^2

local gaiaTeamID = Spring.GetGaiaTeamID()
local _,_,_,_,_,gaiaAllyTeamID,_ = Spring.GetTeamInfo(gaiaTeamID) 

local limitType = tostring(Spring.GetModOptions().limitdgun) or "Off"
-- can be "Off", "StartPoints" or "Startboxes"


-- set what type of dgun limit we will use 
if limitType == "startpoints" then
	usePoints = true
	useBoxes = false
elseif limitType == "startboxes" and Game.startPosType == 2 then -- choose startpoint in game mode
	usePoints = false
	useBoxes = true
else --should not happen
	--Spring.Echo(limitType, Game.startPosType)
	usePoints = false
	useBoxes = false
end

function gadget:Initialize()
	if useBoxes then
		-- list startboxes
		local allyTeamList = Spring.GetAllyTeamList()
		for _,allyTeamID in pairs(allyTeamList) do
			if allyTeamID ~= gaiaAllyTeamID then
				local x1,z1,x2,z2 = Spring.GetAllyTeamStartBox(allyTeamID)
				if x1 < x2 and z1 < z2 then
					boxes[allyTeamID] = {x1,z1,x2,z2}
				end
			end
		end
	end
end

function GameStart()
	if usePoints then
		--make empty table for each allyTeam
		local allyTeamList = Spring.GetAllyTeamList()
		for _,allyTeamID in pairs(allyTeamList) do
			if allyTeamID ~= gaiaAllyTeamID then
				points[allyTeamID] = {}
			end
		end
		--list startpoints and send them to unsynced
		local teamStartPoints = GG.teamStartPoints
		local coopStartPoints = GG.coopStartPoints or {} 
		for teamID,startPoint in pairs(teamStartPoints) do
			local _,_,_,_,_,allyTeamID = Spring.GetTeamInfo(teamID)
			if allyTeamID ~= gaiaAllyTeamID then
				points[allyTeamID][(#points[allyTeamID])+1] = {startPoint[1],startPoint[2],startPoint[3]}
			end
		end
		for playerID,startPoint in pairs(coopStartPoints) do
			local _,_,_,_,allyTeamID = Spring.GetPlayerInfo(playerID)
			if allyTeamID ~= gaiaAllyTeamID then
				points[allyTeamID][(#points[allyTeamID])+1] = {startPoint[1],startPoint[2],startPoint[3]}
			end
		end
	end
	
	-- tell unsynced what type of dgun limit we are using
	SendToUnsynced("RecieveLimitType", useBoxes, usePoints, pointRadius)
	
	-- send startpoints if needed
	if usePoints then
		for allyTeamID, pointTable in pairs(points) do
			for pointID, startPoint in pairs(pointTable) do
				SendToUnsynced("RecieveStartPoint", allyTeamID, pointID, startPoint[1], startPoint[2], startPoint[3])
			end
		end
	end
	
	-- tell unsynced to make its gllist
	SendToUnsynced("RemakeDgunLimitList")
end


function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions, cmdTag, synced)
	if cmdID ~= CMD_MANUALFIRE then --non-dgun commands
		return true
	end

	local unitX, _, unitZ = spGetUnitPosition(unitID)
	if not unitX or not unitZ then --wtf
		return true
	end

	local _,_,_,_,_,unitAllyTeamID,_,_ = spGetTeamInfo(teamID) 

	if useBoxes then
		--don't allow dgun within anyone else's startbox
		for allyTeamID,box in pairs(boxes) do
			if unitAllyTeamID ~= allyTeamID then
				if (box[1] <= unitX) and (unitX <= box[3]) and (box[2] <= unitZ) and (unitZ <= box[4]) then 
					return false 
				end
			end
		end
	end
	
	if usePoints then
		--don't allow dgun within pointRadius range of a startpoint 
		for allyTeamID, pointTable in pairs(points) do
			if allyTeamID ~= unitAllyTeamID then
				for _,startPoint in pairs(pointTable) do
					if (unitX-startPoint[1])^2 + (unitZ-startPoint[3])^2 <= pointRadiusSqrd then
						return false
					end
				end
			end
		end
	end
	
	return true
end

function gadget:GameFrame(n) --TODO in 97: move this to unsynced
	if n==3 then
		GameStart()
	elseif n%90==0 then --update once every 3 game seconds
		SendToUnsynced("RemakeDgunLimitList")
	end
end

-----------------------------
else -- begin unsynced section
-----------------------------

local spIsGUIHidden = Spring.IsGUIHidden
local spGetMyTeamID = Spring.GetMyTeamID

local tID
local amISpec = Spring.GetSpectatingState()
local myTeamID = Spring.GetMyTeamID()
local myAllyTeamID = Spring.GetMyAllyTeamID()
local allyTeamList = Spring.GetAllyTeamList()
local gaiaTeamID = Spring.GetGaiaTeamID()
local _,_,_,_,_,gaiaAllyTeamID,_,_ = Spring.GetTeamInfo(gaiaTeamID) 

local useBoxes
local usePoints
local pointRadius
local points  = {}

local dgunLimitList
local prevUpdateTime = 0
local curTime = 0  
local divLength = 10

function DrawGroundLine(x1,z1,x2,z2)
	--draw a line 'on the ground' from (x1,z1) to (x2,z2)
	gl.BeginEnd(GL.LINE_STRIP, function()
		--first point
		local y = Spring.GetGroundHeight(x1,z1)
		local prevY = y
		gl.Vertex(x1,y,z1)
		--middle points
		local length = math.floor(math.sqrt( (x2-x1)*(x2-x1) + (z2-z1)*(z2-z1) ))
		local divs = math.max(0, (math.floor(length/divLength))-1) 
		local x = x1 
		local z = z1
		for i=1,divs do
			x = x + (x2-x1)/divs
			z = z + (z2-z1)/divs
			y = Spring.GetGroundHeight(x,z)
			if math.abs(y-prevY) > 5 then --only add in middle vertices when the ground changes height
				prevY = y
				gl.Vertex(x,y,z)
			end
		end
		--last point
		y = Spring.GetGroundHeight(x2,z2)
		gl.Vertex(x2,y,z2)
	end)
end

function DrawGroundBox(x1,z1,x2,z2)
	--draw the edges of the box {(x,z):x1<x<x2,z1<z<z2} 'on the ground', except where they coincide with map edge
	if x1 > 0 then
		DrawGroundLine(x1,z1,x1,z2)
	end
	if z2 < Game.mapSizeZ then
		DrawGroundLine(x1,z2,x2,z2)
	end
	if x2 < Game.mapSizeX then
		DrawGroundLine(x2,z2,x2,z1)
	end
	if z1 > 0 then
		DrawGroundLine(x2,z1,x1,z1)
	end
end

function CreateList()
	--remove old list
	if dgunLimitList then
		gl.DeleteList(dgunLimitList)
	end
	
	--generate list
	if useBoxes then
		dgunLimitList = gl.CreateList(function()
			--show enemy's boxes in black
			gl.Color(0,0,0,0.5) 
			for _,allyTeamID in pairs(allyTeamList) do
				if myAllyTeamID ~= allyTeamID and allyTeamID ~= gaiaAllyTeamID then
					local x1,z1,x2,z2 = Spring.GetAllyTeamStartBox(allyTeamID)
					if x1 < x2 and z1 < z2  then
						DrawGroundBox(x1,z1,x2,z2)
					end
				end
			end
			--show my own box in white
			gl.Color(1,1,1,0.5)
			local x1,z1,x2,z2 = Spring.GetAllyTeamStartBox(myAllyTeamID)
			if x1 < x2 and z1 < z2 then
				DrawGroundBox(x1,z1,x2,z2)
			end
		end)
	end
	
	if usePoints then
		dgunLimitList = gl.CreateList(function()
			--show enemy circles in black
			gl.Color(0,0,0,0.5)
			for allyTeamID,pointTable in pairs(points) do
				if allyTeamID ~= myAllyTeamID then
					for _,point in pairs(pointTable) do
						gl.DrawGroundCircle(point[1],point[2],point[3],pointRadius,120)
					end
				end
			end		
			--show my own allyTeams circles in white
			gl.Color(1,1,1,0.5)
			if points[myAllyTeamID] then
				for _,point in pairs(points[myAllyTeamID]) do
					gl.DrawGroundCircle(point[1],point[2],point[3],pointRadius,120)
				end
			end
		end)
	end	
end

function RecieveLimitType(epicWTFparam, useBoxesRec, usePointsRec, pointRadiusRec) --first param seems to be function name...
	useBoxes = useBoxesRec
	usePoints = usePointsRec
	pointRadius = pointRadiusRec
end

function RecieveStartPoint(epicWTFparam, allyTeamID, pointID, x, y, z)
	if not points[allyTeamID] then
		points[allyTeamID] = {}
	end
	points[allyTeamID][pointID] = {x,y,z}
end

function gadget:Initialize()
	gadgetHandler:AddSyncAction("RemakeDgunLimitList", CreateList)
	gadgetHandler:AddSyncAction("RecieveLimitType", RecieveLimitType)
	gadgetHandler:AddSyncAction("RecieveStartPoint", RecieveStartPoint)
	CreateList()
end

function gadget:GameOver()
	if dgunLimitsList then
		gl.DeleteList(dgunLimitList)
	end
	gadgetHandler:RemoveGadget()
end

function gadget:DrawWorldPreUnit() 
	-- check if we changed team (or if we changed which team we spec)
	tID = spGetMyTeamID()
	if myTeamID ~= tID then
		myTeamID = tID
		myAllyTeamID = Spring.GetMyAllyTeamID()
		CreateList()
	end
	
	if dgunLimitList and not spIsGUIHidden() then
		gl.DepthTest(GL.ALWAYS)
		gl.CallList(dgunLimitList)
		gl.DepthTest(false)
	end
end



-----------------------------
end -- end unsynced section
-----------------------------
