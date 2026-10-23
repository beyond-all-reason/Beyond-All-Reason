local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Save Game Menu",
		desc = "bla",
		author = "KingRaptor, stripped down to nothing by beherith", --https://raw.githubusercontent.com/ZeroK-RTS/Zero-K/c765e592cb1cc6fc34438d274874f4c33f6e5f9c/LuaUI/Widgets/gui_savegame.lua
		date = "2021",
		license = "GNU GPL, v2 or later",
		layer = -9999,
		enabled = true,
	}
end

-- Localized functions for performance
local mathFloor = math.floor

-- Localized Spring API for performance
local spGetGameFrame = Spring.GetGameFrame

local SAVE_DIR = "Saves"
local SAVE_DIR_LENGTH = string.len(SAVE_DIR) + 2

local SAVE_TYPE = "save "

local function trim(str)
	return str:match("^()%s*$") and "" or str:match("^%s*(.*%S)")
end

--------------------------------------------------------------------------------
-- Savegame utility functions
--------------------------------------------------------------------------------
-- FIXME: currently unused as it doesn't seem to give the correct order

local function FindFirstEmptySaveSlot()
	-- Find the first unused save slot number (e.g., save001, save002, etc.)
	local saveFiles = VFS.DirList(SAVE_DIR, "*.lua")
	local usedSlots = {}

	for _, path in ipairs(saveFiles) do
		local filename = string.sub(path, SAVE_DIR_LENGTH, -5)
		local slotNum = string.match(filename, "^save(%d+)$")
		if slotNum then
			usedSlots[tonumber(slotNum)] = true
		end
	end

	-- Find first empty slot starting from 1
	for i = 1, 999 do
		if not usedSlots[i] then
			return i
		end
	end

	return 1 -- fallback
end

local function SaveGame(filename, description, requireOverwrite)
	if WG.Analytics and WG.Analytics.SendRepeatEvent then
		WG.Analytics.SendRepeatEvent("game_start:savegame", filename)
	end
	local success, err = pcall(function()
		Spring.CreateDir(SAVE_DIR)
		filename = (filename and trim(filename)) or ("save" .. string.format("%03d", FindFirstEmptySaveSlot()))
		path = SAVE_DIR .. "/" .. filename .. ".lua"
		local saveData = {}
		--saveData.filename = filename
		saveData.date = os.date("*t")
		saveData.description = description or "No description"
		saveData.gameName = Game.gameName
		saveData.gameVersion = Game.gameVersion
		saveData.engineVersion = Engine.version
		saveData.map = Game.mapName
		saveData.gameID = (
			Spring.GetGameRulesParam("save_gameID")
			or (Game.gameID and Game.gameID or Spring.GetGameRulesParam("GameID"))
		)
		saveData.gameframe = spGetGameFrame()
		saveData.totalGameframe = spGetGameFrame() + (Spring.GetGameRulesParam("totalSaveGameFrame") or 0)
		saveData.playerName = Spring.GetPlayerInfo(Spring.GetLocalPlayerID(), false)
		table.save(saveData, path)

		-- TODO: back up existing save?
		--if VFS.FileExists(SAVE_DIR .. "/" .. filename) then
		--end

		if requireOverwrite then
			Spring.SendCommands(SAVE_TYPE .. filename .. " -y")
		else
			Spring.SendCommands(SAVE_TYPE .. filename)
		end
		Spring.Log(widget:GetInfo().name, LOG.INFO, "Saved game to " .. path)

		--DisposeWindow()
	end)
	if not success then
		Spring.Log(widget:GetInfo().name, LOG.ERROR, "Error saving game: " .. err)
	end
end

local function savegameCmd(_, _, params)
	Spring.Echo("Trying to save:", params[1])
	local savefilename = params[1]
	SaveGame(savefilename, savefilename, true)

	if Spring.GetMenuName and string.find(string.lower(Spring.GetMenuName()), "chobby") ~= nil then
		Spring.SendLuaMenuMsg("gameSaved")
	end
end

function widget:Initialize()
	WG.savegame = {}
	widgetHandler:AddAction("savegame", savegameCmd, nil, "t")
end

function widget:Shutdown()
	WG.savegame = nil
	widgetHandler:RemoveAction("savegame")
end

--[[
local options = {}
function widget:GameFrame(n)

	if not options.enableautosave.value then
		return
	end
	if options.autosaveFrequency.value == 0 then
		return
	end
	if n % (options.autosaveFrequency.value * 1800) == 0 and n ~= 0 then
		if Spring.GetSpectatingState() or Spring.IsReplay() or (not WG.crude.IsSinglePlayer()) then
			return
		end
		Spring.Log(widget:GetInfo().name, LOG.INFO, "Autosaving")
		SaveGame("autosave", "", true)
	end
end
]]
--
