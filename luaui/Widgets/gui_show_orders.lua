local widget = widget ---@type Widget

-- This widget exposes the following actions:
--
--   bind <key> show orders -> show allied units orders

function widget:GetInfo()
	return {
		name = "Show Orders",
		desc = "Show allied units orders",
		author = "Niobium",
		date = "date",
		version = 1.0,
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

-----------------------------------------------------
-- Config
-----------------------------------------------------

local borderWidth = 2
local iconSize = 40
local maxColumns = 4
local maxRows = 2
local fontSize = 16

-----------------------------------------------------
-- Speedup
-----------------------------------------------------

local spDrawUnitCommands = Spring.DrawUnitCommands
local spGetFactoryCommands = Spring.GetFactoryCommands
local spGetSpecState = Spring.GetSpectatingState
local spGetTeamList = Spring.GetTeamList
local spGetMyAllyTeamID = Spring.GetMyAllyTeamID
local spGetTeamUnits = Spring.GetTeamUnits
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitPosition = Spring.GetUnitPosition
local spWorldToScreenCoords = Spring.WorldToScreenCoords
local spGetUnitStates = Spring.GetUnitStates

local glColor = gl.Color
local glTexture = gl.Texture
local glTexRect = gl.TexRect
local glRect = gl.Rect

-----------------------------------------------------
-- Globals
-----------------------------------------------------

local factoryDefIDs = {}
local GaiaTeamID = Spring.GetGaiaTeamID() -- set to -1 to include Gaia units

local font, chobbyInterface

-----------------------------------------------------
-- Widget State Globals
-----------------------------------------------------

--- Whether the widget is active or not (keypressed and in-game)
local active = false

--- Table indexed by teamID and all units as values
local teamsUnits = {}

--- The cells to be drawn.
---
--- In the format:
--- ```
--- {
---   unitID = arrayof {
---     texture = string
---     text = string
---     isrepeat = bool
---     sx = number -- screen coord x
---     sy = number -- screen coord x
---   }
--- }
--- ```
---
--- NOTE: Used to show progress percentage for units being
--- Some time this changed in BAR to only show factories, this is fine but its
--- worth to note the logic is generic. We filter by factories
local unitsCells = {}

-----------------------------------------------------
-- Code
-----------------------------------------------------

-- NOTE: Engine for some reason returns this weird 'n' thing
-- The funky ass format looks like this:
-- ```
-- {
--   [2]={
--     [260]=20,
--   },
--   [3]={
--     [300]=5,
--   },
--   n=3,
-- }
-- ```
-- See: https://github.com/beyond-all-reason/RecoilEngine/issues/2571
local function getNonBrokenEngineReturn(brokenValue)
	if not brokenValue then
		return brokenValue
	end

	local value = {}
	for brokenKey, brokenVal in pairs(brokenValue) do
		if brokenKey ~= "n" then
			local actualKey, actualVal = next(brokenVal)

			if actualKey then
				value[actualKey] = actualVal
			end
		end
	end

	return value
end

local function UpdateState()
	teamsUnits = {}

	local _, fullView, _ = spGetSpecState()
	local allyTeamID = not fullView and spGetMyAllyTeamID() or nil
	local teams = spGetTeamList(allyTeamID)

	for _, teamID in pairs(teams) do
		if teamID ~= GaiaTeamID then
			teamsUnits[teamID] = spGetTeamUnits(teamID)
			local teamFactories = Spring.GetTeamUnitsByDefs(teamID, factoryDefIDs)

			for _, uID in ipairs(teamFactories) do
				local cells = {}
				local uDefID = spGetUnitDefID(uID)
				local ux, uy, uz = spGetUnitPosition(uID)
				local sx, sy = spWorldToScreenCoords(ux, uy, uz)
				local uCmds = spGetFactoryCommands(uID, -1)
				local isrepeat = select(4, spGetUnitStates(uID, false, true))

				if #uCmds == 0 then
					cells[1] = { texture = "#" .. uDefID, text = "IDLE", isrepeat = isrepeat, sx = sx, sy = sy }
				end

				local factoryQueueCounts = getNonBrokenEngineReturn(Spring.GetFactoryCounts(uID))

				for queueDefID, count in pairs(factoryQueueCounts) do
					local cell = { isrepeat = isrepeat, sx = sx, sy = sy }
					cell.text = count
					cell.texture = "#" .. queueDefID

					cells[#cells + 1] = cell
				end

				unitsCells[uID] = cells
			end
		end
	end
end

-- local function handleSetModifier(cmd, extra, args, data, isRepeat, isRelease, actions)
local function handleSetModifier(_, _, args, data)
	if args[1] ~= "orders" then
		return
	end

	data = data or {}
	active = data[1]
end

function widget:Initialize()
	widget:ViewResize()

	for uDefID, uDef in pairs(UnitDefs) do
		if uDef.isFactory then
			factoryDefIDs[#factoryDefIDs + 1] = uDefID
		end
	end

	widgetHandler:AddAction("show", handleSetModifier, { true }, "p")
	widgetHandler:AddAction("show", handleSetModifier, { false }, "r")
end

function widget:ViewResize()
	font = WG["fonts"].getFont(1, 1.5)
end

-- function widget:RecvLuaMsg(msg, playerID)
function widget:RecvLuaMsg(msg)
	if msg:sub(1, 18) == "LobbyOverlayActive" then
		chobbyInterface = (msg:sub(1, 19) == "LobbyOverlayActive1")
	end
end

function widget:GameFrame()
	if not active then
		return
	end

	if chobbyInterface then
		active = false
		return
	end

	-- Consider checking if any state has actually changed
	-- before doing this, probably not a big deal
	UpdateState()
end

function widget:DrawWorld()
	if not active then
		return
	end

	for _, teamUnits in pairs(teamsUnits) do
		spDrawUnitCommands(teamUnits)
	end
end

function widget:DrawScreen()
	if not active then
		return
	end

	local userScale = Spring.GetConfigFloat("ui_scale", 1)
	local vsx = WG.FlowUI.vsx
	local vsy = WG.FlowUI.vsy

	local baseWidth = 1920
	local baseHeight = 1080
	local resFactor = math.min(vsx / baseWidth, vsy / baseHeight) * userScale

	local resBorderWidth = resFactor * borderWidth
	local resIconSize = resFactor * iconSize
	local resFontSize = resFactor * fontSize

	for unitID, cells in pairs(unitsCells) do
		if Spring.IsUnitInView(unitID) then
			for r = 0, maxRows - 1 do
				for c = 1, maxColumns do
					local cell = cells[maxColumns * r + c]
					if not cell then
						break
					end

					local cx = cell.sx + (c - 1) * (resIconSize + resBorderWidth)
					local cy = cell.sy - r * (resIconSize + resBorderWidth)

					if cell.isrepeat then
						glColor(0.0, 0.0, 0.5, 1.0)
					else
						glColor(0.0, 0.0, 0.0, 1.0)
					end

					glRect(cx, cy, cx + resIconSize + 2 * resBorderWidth, cy - iconSize - 2 * resBorderWidth)

					glColor(1.0, 1.0, 1.0, 1.0)
					glTexture(cell.texture)
					glTexRect(
						cx + resBorderWidth,
						cy - resIconSize - resBorderWidth,
						cx + resIconSize + resBorderWidth,
						cy - resBorderWidth
					)
					glTexture(false)

					if cell.text then
						font:Begin()
						font:Print(cell.text, cx + resBorderWidth + 2, cy - resIconSize, resFontSize, "ob")
						font:End()
					end
				end
			end
		end
	end
end
