local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Mission Battle Log",
		desc = "Shows the newest Mission API battle log messages",
		date = "October 2026",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

-- A stand-in display for the battle log, until it has a real UI.

local spGetViewGeometry = Spring.GetViewGeometry

local MessageTypes = VFS.Include("luarules/mission_api/parameter_types.lua").Enums.MessageType

local MESSAGES_SHOWN = 6
local FONT_SIZE = 16
local LINE_HEIGHT = 1.3

local messageColors = {
	[MessageTypes.Briefing] = "\255\200\200\255",
	[MessageTypes.Message] = "\255\255\255\255",
	[MessageTypes.Objective] = "\255\255\220\100",
	[MessageTypes.Notification] = "\255\255\150\100",
	[MessageTypes.Dialogue] = "\255\150\255\150",
}
local defaultColor = messageColors[MessageTypes.Message]

local font ---@type LuaFont
local textX = 0 ---@type number
local textY = 0 ---@type number
local fontSize = FONT_SIZE ---@type number

function widget:ViewResize(viewSizeX, viewSizeY)
	fontSize = FONT_SIZE * viewSizeY / 1080
	textX = viewSizeX * 0.01
	textY = viewSizeY * 0.7
	font = WG.fonts.getFont(1, 1.5)
end

function widget:Initialize()
	widget:ViewResize(spGetViewGeometry())
end

function widget:DrawScreen()
	local battleLog = WG.MissionAPI and WG.MissionAPI.BattleLog
	if not battleLog or #battleLog == 0 then
		return
	end

	font:Begin()
	local first = math.max(1, #battleLog - MESSAGES_SHOWN + 1)
	for i = first, #battleLog do
		local message = battleLog[i]
		local y = textY - (i - first) * fontSize * LINE_HEIGHT
		font:Print((messageColors[message.messageType] or defaultColor) .. message.message, textX, y, fontSize, "o")
	end
	font:End()
end
