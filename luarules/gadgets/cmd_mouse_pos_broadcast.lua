--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--	Copyright (C) 2007.
--	Licensed under the terms of the GNU GPL, v2 or later.
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function gadget:GetInfo()
	return {
		name	= "Cursor Broadcast",
		desc	= "Shows the mouse pos of allied players",
		author	= "jK,TheFatController",
		date	= "Apr,2009",
		license	= "GNU GPL, v2 or later",
		layer	= 0,
		enabled = true,
	}
end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

-- configs

local sendPacketEvery	= 0.8
local numMousePos		= 2 --//num mouse pos in 1 packet

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

-- locals

local GetMouseState		= Spring.GetMouseState
local TraceScreenRay	= Spring.TraceScreenRay
local SendLuaRulesMsg	= Spring.SendLuaRulesMsg
local GetMyPlayerID		= Spring.GetMyPlayerID
local GetSpectatingState= Spring.GetSpectatingState
local GetPlayerInfo		= Spring.GetPlayerInfo
local GetLastUpdateSeconds= Spring.GetLastUpdateSeconds


local PackU16			= VFS.PackU16
local UnpackU16			= VFS.UnpackU16

local floor				= math.floor
local tanh				= math.tanh
local abs				= math.abs


--------------------------------------------------------------------------------

local updateTimer = 0
local poshistory = {}

local saveEach = sendPacketEvery/numMousePos
local updateTick = saveEach


local lastx,lastz = 0,0
local n = 0
local lastclick = 0

if gadgetHandler:IsSyncedCode() then
	function gadget:RecvLuaMsg(msg, playerID)
		if msg:sub(1,2)=="£" then
			local xz = msg:sub(4)
			local l = xz:len()*0.25
			if l == numMousePos then
				for i=0,numMousePos-1 do
					local x = UnpackU16(xz:sub(i*4+1,i*4+2))
					local z = UnpackU16(xz:sub(i*4+3,i*4+4))
					local click = msg:sub(2,2) == "1"
					SendToUnsynced("mouseBroadcast",playerID,x,z,click)
				end
			end
			return true
		end
	end
else

--------------------------------------------------------------------------------

function gadget:Initialize()
	gadgetHandler:AddSyncAction("mouseBroadcast", handleMousePosEvent)
end

function gadget:Shutdown()
	gadgetHandler:RemoveSyncAction("mouseBroadcast")
end

function handleMousePosEvent(_,playerID,x,z,click)
	--here we receive mouse pos from other players and dispatch to luaui
	local myPlayerID = GetMyPlayerID()
	if myPlayerID == playerID then
		return
	end
	local spec, fullView = GetSpectatingState()
	if not spec or not fullView then
		local _,_,_,_,myAllyTeamID = GetPlayerInfo(myPlayerID)
		local _,_,targetSpec,_,allyTeamID = GetPlayerInfo(playerID)
		if targetSpec or allyTeamID ~= myAllyTeamID then
			return
		end
	end
    if Script.LuaUI("MouseCursorEvent") then
        Script.LuaUI.MouseCursorEvent(playerID,x,z,click)
    end
end

function gadget:Update()
	updateTimer = updateTimer + GetLastUpdateSeconds()

	if updateTimer > updateTick then
		local mx,my = GetMouseState()
		local _,pos = TraceScreenRay(mx,my,true)

		if pos then
			poshistory[n*2]	 = PackU16(floor(pos[1]))
			poshistory[n*2+1] = PackU16(floor(pos[3]))
			if n == numMousePos then
				lastx,lastz = pos[1],pos[3]
			end
			n = n + 1
		end
		
		updateTick = updateTimer + saveEach
	end
		
	if n > numMousePos then
		n = 0
		updateTimer = 0
		updateTick = saveEach
		
		local posStr = "0"
	
		for i=numMousePos,1,-1 do
			local xStr = poshistory[i*2]
			local zStr = poshistory[i*2+1]
			if xStr and zStr then
				posStr = posStr .. xStr .. zStr
			end
		end
		SendLuaRulesMsg("£" .. posStr)
	 
	end
end


function gadget:MousePress(x,y,button)
	if button == 2 then
		return
	end
	local mx,my = GetMouseState()
	local _,pos = TraceScreenRay(mx,my,true)

	if not pos then
		return
	end
	if abs(pos[1] - lastx) > 300 or abs(pos[3] - lastz) > 300 then
		for i=0,5 do
			local posindex = i%2 == 0 and 1 or 3
			poshistory[i] = PackU16(floor(pos[posindex])) 
		end
		lastx,lastz = pos[1],pos[3]
		updateTick = saveEach
		updateTimer = 0
		n = 0
		local posStr = "0"
		for i=numMousePos,1,-1 do
			local xStr = poshistory[i*2]
			local zStr = poshistory[i*2+1]
			if xStr and zStr then
				posStr = posStr .. xStr .. zStr
			end
		end
		SendLuaRulesMsg("£" .. posStr)
	end
end

end

