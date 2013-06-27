function widget:GetInfo()
	return {
		name	= "Map Draw Blocker",
		desc	= "blocks map draws from spammers",
		author	= "BD",
		date	= "-",
		license = "WTFPL",
		layer	= 0,
		enabled = false,
	}
end

-- blocklimit = num drawing actions / counterNum 
local counterNum = 25
local blocklimit = 8
local unblocklimit = 0.5
local unblocktime = 30

local GetPlayerList = Spring.GetPlayerList
local GetPlayerInfo = Spring.GetPlayerInfo
local GetTeamColor  = Spring.GetTeamColor
local GetPlayerTraffic = Spring.GetPlayerTraffic
local Echo = Spring.Echo
local floor = math.floor
local fmod = math.fmod

-- see rts/System/BaseNetProtocol.h for message ids
local traffic = {
	NETMSG_MAPDRAW = {
		id = 31,
		playerdata = {},
	},
}

-- drawCmds[playerid] = {counters = {point = {}, line = {}, erase = {}}, labels = {...}, blocked = false}
local drawCmds = {}
local drawTypes = { "point", "line", "erase" }
local validTypes = {line=true}
local timeCounter = 1
local drawLinedistanceWeight = 0.02
local currentCounter = -1
local timerCmd = 0
local timeFrame = 1
local secondTimer = 0

local myPlayerNum = Spring.GetMyPlayerID()

local action_unblock = "mapdrawunblock"
local action_block = "mapdrawblock"
local action_list = "mapdrawlistblocked"



-- helper functions


local function ClearCurrentBuffer()
	for i,p in pairs(GetPlayerList()) do
		local playerDraw = drawCmds[p]
		if not playerDraw then
			playerDraw = {}
			playerDraw.blocked = false
			playerDraw.counters = {}
			playerDraw.labels = {}
			playerDraw.accumulator = 0
		else
			playerDraw.counters[currentCounter-counterNum] = nil
			playerDraw.counters[currentCounter] = playerDraw.accumulator
			playerDraw.accumulator = 0
		end
		drawCmds[p] = playerDraw
	end

end


local function CheckTresholds()
	for player,data in pairs(drawCmds) do
		local sum = 0
		local iterationCount = 0 
		for _,val in pairs(data.counters) do
			sum = sum + val
			iterationCount = iterationCount + 1
		end
		sum = sum / (iterationCount * timeFrame)
		if sum > blocklimit then
			local wasBlocked = data.blocked 
			data.blocked = timerCmd
			if not wasBlocked then
				Echo("Blocking map draw for " .. GetPlayerInfo(player))
			end
		end
		if sum < unblocklimit and data.blocked and (currentCounter-data.blocked > unblocklimit ) then
			data.blocked = false
			Echo("Unblocking map draw for " .. GetPlayerInfo(player))
		end
	end
end


function ActionUnBlock(_,_,parms)
	local p = tonumber(parms[1])
	if not p then return end
	if drawCmds[p] then
		drawCmds[p].blocked = false
		Echo("unblocking map draw for " .. GetPlayerInfo(p))
	end
end

function ActionBlock(_,_,parms)
	local p = tonumber(parms[1])
	if not p then return end
	if drawCmds[p] then
		drawCmds[p].blocked = timerCmd
		Echo("blocking map draw for " .. GetPlayerInfo(p))
	end
end


function ActionList()
	for player,data in pairs(drawCmds) do
		if data.blocked then
			Echo(GetPlayerInfo(player) .. " is blocked ")
		end
	end
end

-- callins


function widget:Initialize()

	ClearCurrentBuffer()

	widgetHandler:AddAction(action_unblock, ActionUnBlock, nil, "t")
	widgetHandler:AddAction(action_block, ActionBlock, nil, "t")
	widgetHandler:AddAction(action_list, ActionList, nil, "t")

end


function widget:Shutdown()
	widgetHandler:RemoveAction(action_unlock)
	widgetHandler:RemoveAction(action_block)
	widgetHandler:RemoveAction(action_list)

end


function AutoUnblock()
end

function widget:Update(dt)
	timerCmd = timerCmd + dt
	secondTimer = secondTimer + dt
	if secondTimer > timeFrame then
		secondTimer = 0
		currentCounter = currentCounter +1
		-- flip buffer
		ClearCurrentBuffer()
		CheckTresholds()
	end

end


--[[
point x y z str
line x y z x y z
erase: x y z r
]]
function widget:MapDrawCmd(playerID, cmdType, startx, starty, startz, a, b, c)
	if drawCmds[playerID] and cmdType ~= "erase" then
		local weight = 10 -- point weight
		if cmdType == "line" then
			weight = ((startx-a)^2+(starty-b)^2+(startz-c)^2)^0.5 * drawLinedistanceWeight
		end
		drawCmds[playerID].accumulator = drawCmds[playerID].accumulator + weight
		return drawCmds[playerID].blocked
	end
	return false
end
