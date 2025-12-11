local widget = widget ---@type Widget

function widget:GetInfo()
   return {
      name      = "Self-Destruct Icons",
      desc      = "Show an icon and countdown (if active) for units that have a self-destruct command",
      author    = "Floris",
      date      = "06.05.2014",
      license   = "GNU GPL, v2 or later",
      layer     = -50,
      enabled   = true
   }
end


-- Localized Spring API for performance
local spGetUnitDefID = Spring.GetUnitDefID
local spGetSpectatingState = Spring.GetSpectatingState

local ignoreUnitDefs = {}
local unitConf = {}
for udid, unitDef in pairs(UnitDefs) do
	local xsize, zsize = unitDef.xsize, unitDef.zsize
	local scale = 6*( xsize*xsize + zsize*zsize )^0.5
	unitConf[udid] = 7 +(scale/2.5)
	if string.find(unitDef.name, 'droppod') then
		ignoreUnitDefs[udid] = true
	end
end

-- {unitID -> unitDefID, ... }
-- presence of a unitID key indicates that the unit has an active (counting down) SELFD command
local activeSelfD = {}

-- {unitID -> unitDefID, ... }
-- presence of a unitID key indicates that the unit has a queued SELFD command
local queuedSelfD = {}

local drawLists = {}

local glDrawListAtUnit			= gl.DrawListAtUnit
local glDepthTest				= gl.DepthTest
local spGetUnitDefID			= spGetUnitDefID
local spIsUnitInView 			= Spring.IsUnitInView
local spGetUnitSelfDTime		= Spring.GetUnitSelfDTime
local spGetAllUnits				= Spring.GetAllUnits
local spGetUnitCommands			= Spring.GetUnitCommands
local spIsUnitAllied			= Spring.IsUnitAllied
local spGetCameraDirection		= Spring.GetCameraDirection
local spIsGUIHidden				= Spring.IsGUIHidden
local spGetUnitTransporter		= Spring.GetUnitTransporter

local spec = spGetSpectatingState()



local function DrawIcon(text)
	local iconSize = 0.9
	gl.PushMatrix()

	gl.Color(0.9, 0.9, 0.9, 1)
	gl.Texture(':n:LuaUI/Images/skull.dds')
	gl.Billboard()
	gl.Translate(0, -1.2, 0)
	gl.TexRect(-iconSize/2, -iconSize/2, iconSize/2, iconSize/2)
	gl.Texture(false)

	if text ~= 0 then
		gl.Translate(iconSize/2, -iconSize/2, 0)
		font:Begin()
		font:SetTextColor(1, 1, 1, 1)
		font:SetOutlineColor(0, 0, 0, 1)
		font:Print(text, 0, 0, 0.66, "o")
		font:End()
	end

	gl.PopMatrix()
end

local function hasSelfDActive(unitID)
	local time = spGetUnitSelfDTime(unitID)
	return time ~= nil and time > 0
end

local function hasSelfDQueued(unitID)
	local limit = -1
	local unitDefID = spGetUnitDefID(unitID)
	if unitDefID and UnitDefs[unitDefID].isFactory then
		limit = 1
	end
	local cmdQueue = spGetUnitCommands(unitID, limit) or {}
	if #cmdQueue > 0 then
		for i = 1, #cmdQueue do
			if cmdQueue[i].id == CMD.SELFD then
				return true
			end
		end
	end
	return false
end

local function updateUnit(unitID)
	if hasSelfDActive(unitID) then
		activeSelfD[unitID] = spGetUnitDefID(unitID)
	else
		activeSelfD[unitID] = nil
	end
	if hasSelfDQueued(unitID) then
		queuedSelfD[unitID] = spGetUnitDefID(unitID)
	else
		queuedSelfD[unitID] = nil
	end
end

local function init()
	for k,_ in pairs(drawLists) do
		gl.DeleteList(drawLists[k])
	end
	drawLists = {}
	font = WG['fonts'].getFont(2, 1.5)

	spec = spGetSpectatingState()

	activeSelfD = {}
	queuedSelfD = {}
	local allUnits = spGetAllUnits()
	for i=1,#allUnits do
		updateUnit(allUnits[i])
	end
end

function widget:PlayerChanged(playerID)
	init()
end
function widget:ViewResize(vsx,vsy)
	init()
end

function widget:Initialize()
	init()
end


function widget:Shutdown()
	for k,_ in pairs(drawLists) do
		gl.DeleteList(drawLists[k])
	end
end


local sec = 0
local prevCam = {spGetCameraDirection()}
function widget:Update(dt)
	sec = sec + dt
	if sec > 0.15 then
		sec = 0
		local camX, camY, camZ = spGetCameraDirection()
		if camX ~= prevCam[1] or  camY ~= prevCam[2] or  camZ ~= prevCam[3] then
			for k,_ in pairs(drawLists) do
				gl.DeleteList(drawLists[k])
				drawLists[k] = nil
			end
		end
		prevCam = {camX,camY,camZ}
	end
end

function widget:DrawWorld()
	if spIsGUIHidden() then return end

	glDepthTest(false)

	local unitScale, countdown

	-- draw icon + countodown if there is an active self-d countdown going
	for unitID, unitDefID in pairs(activeSelfD) do
		if (spIsUnitAllied(unitID) or spec) and spIsUnitInView(unitID) then
			if spGetUnitTransporter(unitID) == nil then
				unitScale = unitConf[unitDefID]
				countdown = math.ceil(spGetUnitSelfDTime(unitID) / 2)
				if not drawLists[countdown] then
					drawLists[countdown] = gl.CreateList(DrawIcon, countdown)
				end
				glDrawListAtUnit(unitID, drawLists[countdown], false, unitScale, unitScale, unitScale)
			end
		end
	end

	-- draw just icon if there is a queued self-d command
	for unitID, unitDefID in pairs(queuedSelfD) do
		-- don't draw this if it also has an active countdown
		if activeSelfD[unitID] == nil and (spIsUnitAllied(unitID) or spec) and spIsUnitInView(unitID) then
			if spGetUnitTransporter(unitID) == nil then
				unitScale = unitConf[unitDefID]
				if not drawLists[0] then
					drawLists[0] = gl.CreateList(DrawIcon, 0)
				end
				glDrawListAtUnit(unitID, drawLists[0], true, unitScale, unitScale, unitScale)
			end
		end
	end

	glDepthTest(true)
end

local CMD_IGNORE_QUEUE = {
	CMD.INSERT,
	CMD.REMOVE,
	CMD.WAIT,
	CMD.FIRE_STATE,
	CMD.MOVE_STATE,
	CMD.REPEAT,
	CMD.ONOFF,
}

function widget:UnitCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOpts, cmdTag, playerID, fromSynced, fromLua)
	if ignoreUnitDefs[unitDefID] then
		return
	end

	if cmdID ~= CMD.SELFD and not cmdOpts.shift and queuedSelfD[unitID] then
		-- had a queued selfd, but the queue was potentially replaced

		-- check for commands that don't replace the queue
		if not table.contains(CMD_IGNORE_QUEUE, cmdID) then
			--queue was replaced, so mark not queued
			queuedSelfD[unitID] = nil
		end
	elseif cmdID == CMD.SELFD then
		if cmdOpts.shift and UnitDefs[unitDefID].isFactory then
			-- factories can receive shift-selfd orders, but they go to the units produced, not the factory itself
			return
		end
		local cmdQueue = spGetUnitCommands(unitID, -1)
		local hasCmdQueue = #cmdQueue > 0

		if not cmdOpts.shift or not hasCmdQueue then
			-- simple selfd command, so toggle active (if there's no queue, shift doesn't change anything)
			if spGetUnitSelfDTime(unitID) > 0 then
				activeSelfD[unitID] = nil
			else
				activeSelfD[unitID] = unitDefID
			end
		else -- implies (cmdOpts.shift and hasCmdQueue)
			-- added a queued selfd; check if it's cancelling the only selfd command, then either mark queued or unqueued

			-- check if the only selfd command is at the end (and thus will get cancelled)
			local hasMiddleSelfd = false
			local hasEndSelfd = false
			for i = 1, #cmdQueue do
				if cmdQueue[i].id == CMD.SELFD then
					if i == #cmdQueue then
						hasEndSelfd = true
					else
						hasMiddleSelfd = true
					end
				end
			end

			if not hasMiddleSelfd and hasEndSelfd then
				-- cancelled only selfd command
				queuedSelfD[unitID] = nil
			else
				-- normal queued command
				queuedSelfD[unitID] = unitDefID
			end
		end
	end
end

function widget:UnitCmdDone(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOpts, cmdTag)
	if ignoreUnitDefs[unitDefID] then
		return
	end

	if queuedSelfD[unitID] then
		updateUnit(unitID)
	end
end

function widget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam)
	activeSelfD[unitID] = nil
	queuedSelfD[unitID] = nil
end


function widget:CrashingAircraft(unitID, unitDefID, teamID)
	activeSelfD[unitID] = nil
	queuedSelfD[unitID] = nil
end
