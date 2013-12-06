--  author:  Andrea Piras, modified by Bluestone
--  Copyright (C) 2010,2013

-- Overrides the file of the same name in basecontent.
-- This version simply prevents firing dgun within enemy startboxes.


function gadget:GetInfo()
  return {
    name      = "Limit Dgun",
    desc      = "Re-implements limit dgun in Lua",
    author    = "Andrea Piras, Bluestone",
    date      = "August, 2010",
    license   = "GNU GPL, v2 or later",
    layer     = 0, 
    enabled   = true  
  }
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local enabled = tonumber(Spring.GetModOptions().limitdgun) or 0
if (enabled == 0) or Game.startPosType ~= 2 then 
  return false
end



-----------------------------
if gadgetHandler:IsSyncedCode() then --begin synced section
-----------------------------

local GetUnitPosition = Spring.GetUnitPosition
local CMD_MANUALFIRE = CMD.MANUALFIRE
local boxes = {} --format is boxes[allyTeamID]={x1,z1,x2,z2} with x1<x2 and z1<z2, contain only non-allyteam startboxes, doesn't include gaia

local gaiaTeamID = Spring.GetGaiaTeamID()
local _,_,_,_,_,gaiaAllyTeamID,_ = Spring.GetTeamInfo(gaiaTeamID) 


function gadget:Initialize()
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


function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions, cmdTag, synced)
	if cmdID ~= CMD_MANUALFIRE then --non-dgun commands
		return true
	end

	local unitX, unitY, unitZ = GetUnitPosition(unitID)
	if not unitX or not unitZ then --wtf
		return true
	end

	--don't allow dgun within anyone else's startbox
	local _,_,_,_,_,unitAllyTeamID,_,_ = Spring.GetTeamInfo(teamID) --fixme
	for allyTeamID,box in pairs(boxes) do
		if unitAllyTeamID ~= allyTeamID then
			if (box[1] <= unitX) and (unitX <= box[3]) and (box[2] <= unitZ) and (unitZ <= box[4]) then 
				return false 
			end
		end
	end
	
	return true
end

function gadget:GameFrame(n)
	if n%90==0 then --update once every 3 game seconds
		SendToUnsynced("RemakeDgunLimitList")
	end
end


-----------------------------
else -- begin unsynced section
-----------------------------

local spIsGUIHidden = Spring.IsGUIHidden

local myAllyTeamID = Spring.GetMyAllyTeamID()
local allyTeamList = Spring.GetAllyTeamList()
local gaiaTeamID = Spring.GetGaiaTeamID()
local _,_,_,_,_,gaiaAllyTeamID,_,_ = Spring.GetTeamInfo(gaiaTeamID) 

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

function gadget:Initialize()
	gadgetHandler:AddSyncAction("RemakeDgunLimitList", CreateList)
	CreateList()
end

function gadget:GameOver()
	if dgunLimitsList then
		gl.DeleteList(dgunLimitList)
	end
	gadgetHandler:RemoveGadget()
end

function gadget:DrawWorldPreUnit() 
	if dgunLimitList and not spIsGUIHidden() then
		gl.DepthTest(GL.ALWAYS)
		gl.CallList(dgunLimitList)
		gl.DepthTest(false)
	end
end



-----------------------------
end -- end unsynced section
-----------------------------
