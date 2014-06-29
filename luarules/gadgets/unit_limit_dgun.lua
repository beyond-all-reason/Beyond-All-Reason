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

local pointRadius = 525 -- radius of circle about enemy startpoints inside of which we can't dgun, in StartPoints mode

local spGetUnitPosition = Spring.GetUnitPosition
local spGetTeamInfo = Spring.GetTeamInfo
local CMD_MANUALFIRE = CMD.MANUALFIRE
local CMD_INSERT = CMD.INSERT
local boxes = {} --format is boxes[allyTeamID]={x1,z1,x2,z2} with x1<x2 and z1<z2, contain only non-allyteam startboxes, doesn't include gaia
local points = {} --format is points[allyTeamID][pointID]={x,y,z}; the point at which that player spawned (pointID does not mean anything in relation to teamID or playerID)
local pointRadiusSqrd = pointRadius^2

local gaiaTeamID = Spring.GetGaiaTeamID()
local _,_,_,_,_,gaiaAllyTeamID,_ = Spring.GetTeamInfo(gaiaTeamID) 

local limitType = tostring(Spring.GetModOptions().limitdgun) or "Off"
-- can be "Off", "StartPoints" or "Startboxes"

local teamsToCheck = {}


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
	
	-- send startboxes if needed
	if useBoxes then
		for allyTeamID, box in pairs(boxes) do
			SendToUnsynced("RecieveStartBox", allyTeamID, box[1], box[2], box[3], box[4])
		end
	end
	
	
	-- tell unsynced to make its gllist
	SendToUnsynced("RemakeDgunLimitList")
end


function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions, cmdTag, synced)
    if not (cmdID == CMD_MANUALFIRE or (cmdID==CMD_INSERT and cmdParams[2]==CMD_MANUALFIRE)) then --non-dgun commands
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
					Spring.SendMessageToTeam(teamID, "You cannot DGun inside an enemy start box!")
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
						Spring.SendMessageToTeam(teamID, "You cannot DGun near an enemy start point!")
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

	-- check if the allyTeam just died; if so then remove its startpoints 
	-- we have to wait until (one frame) after TeamDied was called to check if the allyteam is dead
	for i,teamID in ipairs(teamsToCheck) do
		local _,_,_,_,_,allyTeamID = Spring.GetTeamInfo(teamID)
		local died = true 
		local teamList = Spring.GetTeamList(allyTeamID)
	
		for _,tID in ipairs(teamList) do
			local _,_,isDead = Spring.GetTeamInfo(tID)
			if not isDead then  
				died = false 
				break
			end
		end
	
		if died then
			if usePoints then
				points[allyTeamID] = nil
			elseif useBoxes then
				boxes[allyTeamID] = nil				
			end
			SendToUnsynced("RemoveAllyTeam", allyTeamID)
		end
		
		teamsToCheck[i] = nil
	end

end

function gadget:TeamDied(teamID)
	teamsToCheck[#teamsToCheck+1] = teamID
end


-----------------------------
else -- begin unsynced section
-----------------------------

local spIsGUIHidden = Spring.IsGUIHidden
local spGetMyTeamID = Spring.GetMyTeamID
local spGetCameraPosition = Spring.GetCameraPosition

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
local boxes = {}

local dgunLimitList
local prevUpdateTime = 0
local curTime = 0  
local divLength = 5

local gy = Spring.GetGroundHeight(Game.mapSizeX/2, Game.mapSizeZ/2)
local prev_cy = 0

function DrawGroundLine(x1,z1,x2,z2)
	--draw a line 'on the ground' from (x1,z1) to (x2,z2)
	gl.BeginEnd(GL.LINE_STRIP, function()
		--first point
		local y = Spring.GetGroundHeight(x1,z1)
		local prevY = y
		gl.Vertex(x1,y+5,z1)
		--middle points
		local length = math.floor(math.sqrt( (x2-x1)*(x2-x1) + (z2-z1)*(z2-z1) ))
		local divs = math.max(0, (math.floor(length/divLength))-1) 
		local x = x1 
		local z = z1
		for i=1,divs do
			x = x + (x2-x1)/divs
			z = z + (z2-z1)/divs
			y = Spring.GetGroundHeight(x,z)
			if math.abs(y-prevY) > 2 then --only add in middle vertices when the ground changes height
				prevY = y
				gl.Vertex(x,y+5,z)
			end
		end
		--last point
		y = Spring.GetGroundHeight(x2,z2)
		gl.Vertex(x2,y+5,z2)
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

function CreateList(epicWTFparam, cy)
	--remove old list
	if dgunLimitList then
		gl.DeleteList(dgunLimitList)
	end
	
    --calculate opacity
    if not cy then
        cy = select(2,spGetCameraPosition())
    end
    local opacity = math.max(0.1, 0.5 - (cy-gy-3000) * (1/10000))
    
	--generate list
	if useBoxes then
		dgunLimitList = gl.CreateList(function()
			--show enemy's boxes in black
			gl.Color(0,0,0,opacity) 
			for allyTeamID,box in pairs(boxes) do
				if myAllyTeamID ~= allyTeamID and allyTeamID ~= gaiaAllyTeamID then
					DrawGroundBox(box[1],box[2],box[3],box[4])
				end
			end
			--show my own box in white
			gl.Color(1,1,1,opacity)
			local box = boxes[myAllyTeamID]
			if box then
				DrawGroundBox(box[1],box[2],box[3],box[4])
			end
		end)
	end
	
	if usePoints then
		dgunLimitList = gl.CreateList(function()
			--show enemy circles in black
			gl.Color(0,0,0,opacity)
			for allyTeamID,pointTable in pairs(points) do
				if allyTeamID ~= myAllyTeamID then
					for _,point in pairs(pointTable) do
						gl.DrawGroundCircle(point[1],point[2],point[3],pointRadius,120)
					end
				end
			end		
			--show my own allyTeams circles in white
			gl.Color(1,1,1,opacity)
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

function RecieveStartBox(epicWTFparam, allyTeamID, x1, z1, x2, z2)
	if not boxes[allyTeamID] then
			boxes[allyTeamID] = {}
	end
	boxes[allyTeamID][1] = x1
	boxes[allyTeamID][2] = z1
	boxes[allyTeamID][3] = x2
	boxes[allyTeamID][4] = z2
end

function RemoveAllyTeam(epicWTFparam, allyTeamID)
	if usePoints then
		points[allyTeamID] = nil
	elseif useBoxes then
		boxes[allyTeamID] = nil
	end
	CreateList()
end

function gadget:Initialize()
	gadgetHandler:AddSyncAction("RemakeDgunLimitList", CreateList)
	gadgetHandler:AddSyncAction("RecieveLimitType", RecieveLimitType)
	gadgetHandler:AddSyncAction("RecieveStartPoint", RecieveStartPoint)
	gadgetHandler:AddSyncAction("RecieveStartBox", RecieveStartBox)
	gadgetHandler:AddSyncAction("RemoveAllyTeam", RemoveAllyTeam)
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
		CreateList(_,select(2,spGetCameraPosition()))
	end
	
    -- remake list if cam height changed enough
    local _,cy,_ = spGetCameraPosition()
    if math.abs(cy-prev_cy) > 500 then
        prev_cy = cy
        CreateList(_,cy)
    end

	if dgunLimitList and not spIsGUIHidden() then
		gl.DepthTest(true)
		gl.CallList(dgunLimitList)
		gl.DepthTest(false)
	end
end



-----------------------------
end -- end unsynced section
-----------------------------
