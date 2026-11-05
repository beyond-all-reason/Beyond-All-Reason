local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Self-Destruct Icons",
		desc = "Show an icon and countdown (if active) for units that have a self-destruct command",
		author = "Floris",
		date = "06.05.2014",
		license = "GNU GPL, v2 or later",
		layer = -50,
		enabled = true,
	}
end

-- Localized Spring API for performance
local spGetUnitDefID = Spring.GetUnitDefID
local spGetMyPlayerID = Spring.GetLocalPlayerID
local spGetSpectatingState = Spring.GetSpectatingState

local CMD_SELFD = CMD.SELFD

local ignoreUnitDefs = {}
local unitConf = {}
local isTransportDef = {}
local isFactoryDef = {}
for udid, unitDef in pairs(UnitDefs) do
	local xsize, zsize = unitDef.xsize, unitDef.zsize
	local scale = 6 * (xsize * xsize + zsize * zsize) ^ 0.5
	unitConf[udid] = 7 + (scale / 2.5)
	if string.find(unitDef.name, "droppod") then
		ignoreUnitDefs[udid] = true
	end
	if unitDef.isTransport then
		isTransportDef[udid] = true
	end
	if unitDef.isFactory then
		isFactoryDef[udid] = true
	end
end

-- {unitID -> unitDefID, ... }
-- presence of a unitID key indicates that the unit has an active (counting down) SELFD command
local activeSelfD = {}

-- {unitID -> unitDefID, ... }
-- presence of a unitID key indicates that the unit has a queued SELFD command
local queuedSelfD = {}

local drawLists = {}
---@type LuaFont
local font

local glDrawListAtUnit = gl.DrawListAtUnit
local glDepthTest = gl.DepthTest
local spIsUnitInView = Spring.IsUnitInView
local spIsUnitIcon = Spring.IsUnitIcon
local spGetUnitSelfDTime = Spring.GetUnitSelfDTime
local spGetAllUnits = Spring.GetAllUnits
local spGetUnitCommandCount = Spring.GetUnitCommandCount
local spGetUnitCurrentCommand = Spring.GetUnitCurrentCommand
local spIsUnitAllied = Spring.IsUnitAllied
local spGetCameraDirection = Spring.GetCameraDirection
local spIsGUIHidden = Spring.IsGUIHidden
local spGetUnitTransporter = Spring.GetUnitTransporter

local myPlayerID = spGetMyPlayerID()
local spec, fullView = spGetSpectatingState()

local function DrawIcon(text)
	local iconSize = 0.9
	gl.PushMatrix()

	gl.Color(0.9, 0.9, 0.9, 1)
	gl.Texture(":n:LuaUI/Images/skull.dds")
	gl.Billboard()
	gl.Translate(0, -1.2, 0)
	gl.TexRect(-iconSize / 2, -iconSize / 2, iconSize / 2, iconSize / 2)
	gl.Texture(false)

	if text ~= 0 then
		gl.Translate(iconSize / 2, -iconSize / 2, 0)
		font:Begin()
		font:SetTextColor(1, 1, 1, 1)
		font:SetOutlineColor(0, 0, 0, 1)
		font:Print(text, 0, 0, 0.66, "o")
		font:End()
	end

	gl.PopMatrix()
end

local function deleteDrawLists()
	for _, list in pairs(drawLists) do
		gl.DeleteList(list)
	end
	drawLists = {}
end

local function hasSelfDActive(unitID)
	local time = spGetUnitSelfDTime(unitID)
	return time ~= nil and time > 0
end

-- reads the queue without building command tables
local function hasSelfDQueued(unitID, unitDefID)
	-- a factory reports the queue of the units it builds, only its first command counts
	local count = isFactoryDef[unitDefID] and 1 or spGetUnitCommandCount(unitID)
	if not count then
		return false
	end
	for i = 1, count do
		local cmdID = spGetUnitCurrentCommand(unitID, i)
		if cmdID == CMD_SELFD then
			return true
		elseif cmdID == nil then
			return false
		end
	end
	return false
end

local sec = 0
local prevCamX, prevCamY, prevCamZ = spGetCameraDirection()

-- Update and UnitCmdDone only run while some unit has a self-destruct
local callInsActive = true

local function updateCallIns()
	local active = next(activeSelfD) ~= nil or next(queuedSelfD) ~= nil
	if active ~= callInsActive then
		callInsActive = active
		if active then
			sec = 0
			prevCamX, prevCamY, prevCamZ = spGetCameraDirection()
			widgetHandler:UpdateCallIn("Update")
			widgetHandler:UpdateCallIn("UnitCmdDone")
		else
			-- the lists have the camera facing baked in, and nothing watches the camera now
			deleteDrawLists()
			widgetHandler:RemoveCallIn("Update")
			widgetHandler:RemoveCallIn("UnitCmdDone")
		end
	end
end

local function updateUnit(unitID)
	local unitDefID = spGetUnitDefID(unitID)
	if hasSelfDActive(unitID) then
		activeSelfD[unitID] = unitDefID
	else
		activeSelfD[unitID] = nil
	end
	if hasSelfDQueued(unitID, unitDefID) then
		queuedSelfD[unitID] = unitDefID
	else
		queuedSelfD[unitID] = nil
	end
end

local function init()
	deleteDrawLists()
	font = WG.fonts.getFont(2, 1.5)

	spec, fullView = spGetSpectatingState()

	activeSelfD = {}
	queuedSelfD = {}
	local allUnits = spGetAllUnits()
	for i = 1, #allUnits do
		updateUnit(allUnits[i])
	end
	updateCallIns()
end

function widget:PlayerChanged(playerID)
	local prevFullView = fullView
	spec, fullView = spGetSpectatingState()
	if playerID == myPlayerID and prevFullView ~= fullView then
		init()
	end
end

function widget:ViewResize(vsx, vsy)
	init()
end

function widget:Initialize()
	init()
end

function widget:Shutdown()
	deleteDrawLists()
end

function widget:Update(dt)
	sec = sec + dt
	if sec > 0.15 then
		sec = 0
		local camX, camY, camZ = spGetCameraDirection()
		if camX ~= prevCamX or camY ~= prevCamY or camZ ~= prevCamZ then
			deleteDrawLists()
		end
		prevCamX, prevCamY, prevCamZ = camX, camY, camZ
	end
end

-- Stays registered while there is nothing to draw: re-registering moves a widget behind the others
-- of its layer, which would change what draws over the icons.
function widget:DrawWorld()
	if (next(activeSelfD) == nil and next(queuedSelfD) == nil) or spIsGUIHidden() then
		return
	end

	glDepthTest(false)

	local unitScale, countdown

	-- draw icon + countodown if there is an active self-d countdown going
	for unitID, unitDefID in pairs(activeSelfD) do
		-- nil when we can no longer read the unit, e.g. after a spectator switched to another team
		local selfDTime = (spec or spIsUnitAllied(unitID))
			and spIsUnitInView(unitID)
			and not spIsUnitIcon(unitID) -- DrawListAtUnit skips icons anyway, this saves the calls before it
			and spGetUnitSelfDTime(unitID)
		if selfDTime then
			local transporterID = spGetUnitTransporter(unitID)
			if transporterID == nil or not isTransportDef[spGetUnitDefID(transporterID)] then
				unitScale = unitConf[unitDefID]
				countdown = math.ceil(selfDTime / 2)
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
		if
			activeSelfD[unitID] == nil
			and (spec or spIsUnitAllied(unitID))
			and spIsUnitInView(unitID)
			and not spIsUnitIcon(unitID)
		then
			local transporterID = spGetUnitTransporter(unitID)
			if transporterID == nil or not isTransportDef[spGetUnitDefID(transporterID)] then
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

local ignoreQueueCmds = {
	[CMD.INSERT] = true,
	[CMD.REMOVE] = true,
	[CMD.WAIT] = true,
	[CMD.FIRE_STATE] = true,
	[CMD.MOVE_STATE] = true,
	[CMD.REPEAT] = true,
	[CMD.ONOFF] = true,
}

function widget:UnitCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOpts, cmdTag, playerID, fromSynced, fromLua)
	if cmdID ~= CMD_SELFD then
		-- had a queued selfd, but the queue was potentially replaced
		if
			queuedSelfD[unitID]
			and not cmdOpts.shift
			and not ignoreQueueCmds[cmdID]
			and not ignoreUnitDefs[unitDefID]
		then
			--queue was replaced, so mark not queued
			queuedSelfD[unitID] = nil
			updateCallIns()
		end
		return
	end
	if ignoreUnitDefs[unitDefID] then
		return
	end
	if cmdOpts.shift and isFactoryDef[unitDefID] then
		-- factories can receive shift-selfd orders, but they go to the units produced, not the factory itself
		return
	end
	local cmdCount = spGetUnitCommandCount(unitID) or 0

	if not cmdOpts.shift or cmdCount == 0 then
		-- simple selfd command, so toggle active (if there's no queue, shift doesn't change anything)
		if spGetUnitSelfDTime(unitID) > 0 then
			activeSelfD[unitID] = nil
		else
			activeSelfD[unitID] = unitDefID
		end
	else -- implies (cmdOpts.shift and cmdCount > 0)
		-- added a queued selfd; check if it's cancelling the only selfd command, then either mark queued or unqueued

		-- check if the only selfd command is at the end (and thus will get cancelled)
		local hasMiddleSelfd = false
		local hasEndSelfd = false
		for i = 1, cmdCount do
			if spGetUnitCurrentCommand(unitID, i) == CMD_SELFD then
				if i == cmdCount then
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
	updateCallIns()
end

-- only registered while some unit has a self-destruct
function widget:UnitCmdDone(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOpts, cmdTag)
	if ignoreUnitDefs[unitDefID] then
		return
	end

	if queuedSelfD[unitID] then
		updateUnit(unitID)
		updateCallIns()
	end
end

local function forgetUnit(unitID)
	if activeSelfD[unitID] or queuedSelfD[unitID] then
		activeSelfD[unitID] = nil
		queuedSelfD[unitID] = nil
		updateCallIns()
	end
end

function widget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam)
	forgetUnit(unitID)
end

function widget:CrashingAircraft(unitID, unitDefID, teamID)
	forgetUnit(unitID)
end
