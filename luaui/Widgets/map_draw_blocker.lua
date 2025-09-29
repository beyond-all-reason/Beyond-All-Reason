local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name	= "Map Draw Blocker",
		desc	= "blocks map draws from spammers",
		author	= "BrainDamage",
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

local GetPlayerList = Spring.GetPlayerList
local GetPlayerInfo = Spring.GetPlayerInfo
local Echo = Spring.Echo

-- drawCmds[playerid] = {counters = {point = {}, line = {}, erase = {}}, labels = {...}, blocked = false}
local drawCmds = {}
local drawLinedistanceWeight = 0.02
local currentCounter = -1
local timerCmd = 0
local timeFrame = 1
local secondTimer = 0

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
				Echo( Spring.I18N('ui.mapDrawBlocker.block', { player = (WG.playernames and WG.playernames.getPlayername) and WG.playernames.getPlayername(player) or GetPlayerInfo(player,false) }) )
			end
		end
		if sum < unblocklimit and data.blocked and (currentCounter-data.blocked > unblocklimit ) then
			data.blocked = false
			Echo( Spring.I18N('ui.mapDrawBlocker.unblock', { player = (WG.playernames and WG.playernames.getPlayername) and WG.playernames.getPlayername(player) or GetPlayerInfo(player,false) }) )
		end
	end
end

function widget:Initialize()
	ClearCurrentBuffer()
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
