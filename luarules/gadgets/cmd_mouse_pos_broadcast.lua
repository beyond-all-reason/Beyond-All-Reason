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

if gadgetHandler:IsSyncedCode() then
	return
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
local SendLuaUIMsg		= Spring.SendLuaUIMsg
local GetLastUpdateSeconds = Spring.GetLastUpdateSeconds


local PackU16			= VFS.PackU16

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

--------------------------------------------------------------------------------

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
		SendLuaUIMsg("£" .. posStr,"a")
	 
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
		SendLuaUIMsg("£" .. posStr,"a") 
	end
end

