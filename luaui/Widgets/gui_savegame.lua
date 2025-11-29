local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Save Game Menu",
		desc = "bla",
		author = "KingRaptor, stripped down to nothing by beherith", --https://raw.githubusercontent.com/ZeroK-RTS/Zero-K/c765e592cb1cc6fc34438d274874f4c33f6e5f9c/LuaUI/Widgets/gui_savegame.lua
		date = "2021",
		license = "GNU GPL, v2 or later",
		layer = -9999,
		enabled = true
	}
end


-- Localized functions for performance
local mathFloor = math.floor

-- Localized Spring API for performance
local spGetGameFrame = Spring.GetGameFrame

local SAVE_DIR = "Saves"
local SAVE_DIR_LENGTH = string.len(SAVE_DIR) + 2

local LOAD_GAME_STRING = "loadFilename "
local SAVE_TYPE = "save "

local function WriteDate(dateTable)
	return string.format("%02d/%02d/%04d", dateTable.day, dateTable.month, dateTable.year)
		.. " " .. string.format("%02d:%02d:%02d", dateTable.hour, dateTable.min, dateTable.sec)
end

local function SecondsToClock(seconds)
	local seconds = tonumber(seconds)

	if seconds <= 0 then
		return "00:00";
	else
		hours = string.format("%02d", mathFloor(seconds / 3600));
		mins = string.format("%02d", mathFloor(seconds / 60 - (hours * 60)));
		secs = string.format("%02d", mathFloor(seconds - hours * 3600 - mins * 60));
		if seconds >= 3600 then
			return hours .. ":" .. mins .. ":" .. secs
		else
			return mins .. ":" .. secs
		end
	end
end

local function trim(str)
	return str:match '^()%s*$' and '' or str:match '^%s*(.*%S)'
end

--------------------------------------------------------------------------------
-- Savegame utlity functions
--------------------------------------------------------------------------------
-- FIXME: currently unused as it doesn't seem to give the correct order

local function GetSaveExtension(path)
	if VFS.FileExists(path .. ".ssf") then
		return ".ssf"
	end
	return VFS.FileExists(path .. ".slsf") and ".slsf"
end

local function GetSaveWithExtension(path)
	local ext = GetSaveExtension(path)
	return ext and path .. ext
end

-- Returns the data stored in a save file
local function GetSave(path)
	local ret = nil
	local success, err = pcall(function()
		local saveData = VFS.Include(path)
		saveData.filename = string.sub(path, SAVE_DIR_LENGTH, -5)    -- pure filename without directory or extension
		saveData.path = path
		ret = saveData
	end)
	if (not success) then
		Spring.Log(widget:GetInfo().name, LOG.ERROR, "Error getting save " .. path .. ": " .. err)
	else
		local engineSaveFilename = GetSaveWithExtension(string.sub(path, 1, -5))
		if not engineSaveFilename then
			--Spring.Log(widget:GetInfo().name, LOG.ERROR, "Save " .. engineSaveFilename .. " does not exist")
			return nil
		else
			return ret
		end
	end
end

local function GetSaveDescText(saveFile)
	if not saveFile then
		return ""
	end
	return (saveFile.description or "no description")
		.. "\n" .. saveFile.gameName .. " " .. saveFile.gameVersion
		.. "\n" .. saveFile.map
		.. "\n" .. (WG.Translate("interface", "time_ingame") or "Ingame time") .. ": " .. SecondsToClock((saveFile.totalGameframe or saveFile.gameframe or 0) / 30)
		.. "\n" .. WriteDate(saveFile.date)
end

local function SaveGame(filename, description, requireOverwrite)
	if WG.Analytics and WG.Analytics.SendRepeatEvent then
		WG.Analytics.SendRepeatEvent("game_start:savegame", filename)
	end
	local success, err = pcall(
		function()
			Spring.CreateDir(SAVE_DIR)
			filename = (filename and trim(filename)) or ("save" .. string.format("%03d", FindFirstEmptySaveSlot()))
			path = SAVE_DIR .. "/" .. filename .. ".lua"
			local saveData = {}
			--saveData.filename = filename
			saveData.date = os.date('*t')
			saveData.description = description or "No description"
			saveData.gameName = Game.gameName
			saveData.gameVersion = Game.gameVersion
			saveData.engineVersion = Engine.version
			saveData.map = Game.mapName
			saveData.gameID = (Spring.GetGameRulesParam("save_gameID") or (Game.gameID and Game.gameID or Spring.GetGameRulesParam("GameID")))
			saveData.gameframe = spGetGameFrame()
			saveData.totalGameframe = spGetGameFrame() + (Spring.GetGameRulesParam("totalSaveGameFrame") or 0)
			saveData.playerName = Spring.GetPlayerInfo(Spring.GetMyPlayerID(), false)
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
		end
	)
	if (not success) then
		Spring.Log(widget:GetInfo().name, LOG.ERROR, "Error saving game: " .. err)
	end
end

local function LoadGameByFilename(filename)
	local saveData = GetSave(SAVE_DIR .. '/' .. filename .. ".lua")
	if saveData then
		if Spring.GetMenuName and Spring.SendLuaMenuMsg and Spring.GetMenuName() then
			Spring.SendLuaMenuMsg(LOAD_GAME_STRING .. filename)
		else
			local ext = GetSaveExtension(SAVE_DIR .. '/' .. filename)
			if not ext then
				Spring.Log(widget:GetInfo().name, LOG.ERROR, "Error loading game: cannot find save file.")
				return
			end
			local success, err = pcall(
				function()
					-- This should perhaps be handled in chobby first?
					--Spring.Log(widget:GetInfo().name, LOG.INFO, "Save file " .. path .. " loaded")

					local script = [[
	[GAME]
	{
		SaveFile=__FILE__;
		IsHost=1;
		OnlyLocal=1;
		MyPlayerName=__PLAYERNAME__;
	}
	]]
					script = script:gsub("__FILE__", filename .. ext)
					script = script:gsub("__PLAYERNAME__", saveData.playerName)
					Spring.Reload(script)
				end
			)
			if (not success) then
				Spring.Log(widget:GetInfo().name, LOG.ERROR, "Error loading game: " .. err)
			end
		end
	else
		Spring.Log(widget:GetInfo().name, LOG.ERROR, "Save game " .. filename .. " not found")
	end
	if saveFilenameEdit then
		saveFilenameEdit:SetText(filename)
	end
end

local function DeleteSave(filename)
	if not filename then
		Spring.Log(widget:GetInfo().name, LOG.ERROR, "No filename specified for save deletion")
	end
	local success, err = pcall(function()
		local pathNoExtension = SAVE_DIR .. "/" .. filename
		os.remove(pathNoExtension .. ".lua")
		local saveFilePath = GetSaveWithExtension(pathNoExtension)
		if saveFilePath then
			os.remove(saveFilePath)
		end
	end)
	if (not success) then
		Spring.Log(widget:GetInfo().name, LOG.ERROR, "Error deleting save " .. filename .. ": " .. err)
	end
end

local function savegameCmd(_, _, params)
	Spring.Echo("Trying to save:", params[1])
	local savefilename = params[1]
	SaveGame(savefilename, savefilename, true)

	if Spring.GetMenuName and string.find(string.lower(Spring.GetMenuName()), 'chobby') ~= nil then
		Spring.SendLuaMenuMsg("gameSaved")
	end
end

function widget:Initialize()
	WG['savegame'] = {}
	widgetHandler:AddAction("savegame", savegameCmd, nil, 't')
end

function widget:Shutdown()
	WG['savegame'] = nil
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
]]--
