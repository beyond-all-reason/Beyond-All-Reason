local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Cursor",
		desc = "auto sets a scale for the cursor based on screen resolution",
		author = "Floris",
		date = "",
		license = "GNU GPL, v2 or later",
		layer = 19000,
		enabled = true,
	}
end

-- Localized functions for performance
local mathAbs = math.abs

local Settings = {}
Settings.cursorSet = "icexuick"
Settings.cursorSize = 100
Settings.sizeMult = Spring.GetConfigFloat("cursorsize", 1)
Settings.version = 6 -- just so it won't restore configdata on load if it differs format

local force = true
local autoCursorSize

-- note: first entry should be icons inside base /anims folder
local cursorSets = {}
for k, subdir in pairs(VFS.SubDirs("anims")) do
	local set = string.gsub(string.sub(subdir, 1, #subdir - 1), "anims/", "") -- game anims folder
	set = string.gsub(string.sub(set, 1, #subdir), "anims\\", "") -- spring anims folder
	local subdirSplit = string.split(set, "_")
	if cursorSets[subdirSplit[1]] == nil then
		cursorSets[subdirSplit[1]] = {}
	end
	cursorSets[subdirSplit[1]][#cursorSets[subdirSplit[1]] + 1] = subdirSplit[2]
end

function NearestValue(table, number)
	local smallestSoFar, smallestIndex
	for i, y in ipairs(table) do
		if not smallestSoFar or (mathAbs(number - y) < smallestSoFar) then
			smallestSoFar = mathAbs(number - y)
			smallestIndex = i
		end
	end
	return smallestIndex, table[smallestIndex]
end

function widget:ViewResize()
	local ssx, ssy = Spring.GetScreenGeometry() -- doesn't change when you unplug external display
	autoCursorSize = 100 * (0.6 + (ssx * ssy / 10000000)) * Spring.GetConfigFloat("cursorsize", 1)
	SetCursor(Settings.cursorSet)
end

function widget:Initialize()
	force = true
	widget:ViewResize()

	WG.cursors = {}
	WG.cursors.getcursor = function()
		return Settings.cursorSet
	end
	WG.cursors.getcursorsets = function()
		local sets = {}
		for i, y in pairs(cursorSets) do
			sets[#sets + 1] = i
		end
		return sets
	end
	WG.cursors.setcursor = function(value)
		force = true
		SetCursor(value)
	end
	WG.cursors.getsizemult = function()
		return Spring.GetConfigFloat("cursorsize", 1)
	end
	WG.cursors.setsizemult = function(value)
		Spring.SetConfigFloat("cursorsize", value)
		widget:ViewResize()
	end
end

function widget:Shutdown()
	WG.cursors = nil
	local file = VFS.LoadFile("cmdcolors.txt")
	if file then
		Spring.LoadCmdColorsConfig(file)
	end
end

----------------------------
-- load cursors

-- replaced right away; the rest is animated (~60 frames each, ~0.7 s for all) and replaced one per Update
local immediateCursorNames = {
	"cursornormal",
	"uiresizev",
	"uiresizeh",
	"uiresized1",
	"uiresized2",
	"uimove",
}
local deferredCursorNames = {
	"cursorareaattack",
	"cursorattack",
	"cursorbuildbad",
	"cursorbuildgood",
	"cursorcapture",
	"cursorcentroid",
	"cursorwait",
	"cursortime",
	"cursorunload",
	"cursordwatch",
	"cursordgun",
	"cursorfight",
	"cursorgather",
	"cursordefend",
	"cursorpickup",
	"cursorrepair",
	"cursorrevive",
	"cursorrestore",
	"cursormove",
	"cursorpatrol",
	"cursorreclamate",
	"cursorselfd",
	"cursornumber",
	"cursorsettarget",
	"cursorupgmex",
	"cursorareamex",
}
local pendingCursorDir ---@type string?
local pendingCursorIndex = 0

local function replaceCursor(cursorDir, cursorName)
	Spring.ReplaceMouseCursor(cursorName, cursorDir .. "/" .. cursorName, (cursorName == "cursornormal"))
end

function widget:Update()
	pendingCursorIndex = pendingCursorIndex + 1
	local cursorName = deferredCursorNames[pendingCursorIndex]
	if pendingCursorDir and cursorName then
		replaceCursor(pendingCursorDir, cursorName)
	end
	if not pendingCursorDir or pendingCursorIndex >= #deferredCursorNames then
		pendingCursorDir = nil
		widgetHandler:RemoveCallIn("Update")
	end
end

function SetCursor(cursorSet)
	--Spring.Echo(autoCursorSize..'   '..cursorSets[cursorSet][NearestValue(cursorSets[cursorSet], autoCursorSize)])
	local oldSetName = Settings.cursorSet .. "_" .. Settings.cursorSize
	Settings.cursorSet = cursorSet
	Settings.cursorSize = cursorSets[cursorSet][NearestValue(cursorSets[cursorSet], autoCursorSize)]
	local cursorDir = cursorSet .. "_" .. Settings.cursorSize
	if cursorDir ~= oldSetName or force then
		force = false
		for i = 1, #immediateCursorNames do
			replaceCursor(cursorDir, immediateCursorNames[i])
		end
		pendingCursorDir = cursorDir
		pendingCursorIndex = 0
		widgetHandler:UpdateCallIn("Update")

		--local files = VFS.DirList("anims/"..cursorDir.."/")
		--for i=1, #files do
		--	local fileName = files[i]
		--	if string.find(fileName, "_0.") then
		--		local cursorName = string.sub(fileName, string.len("anims/"..cursorDir.."/")+1, string.find(fileName, "_0.") -1)
		--		--Spring.AssignMouseCursor(cursorName, cursorDir..'/'..cursorName, (cursorName == 'cursornormal'))
		--		Spring.ReplaceMouseCursor(cursorName, cursorDir..'/'..cursorName, (cursorName == 'cursornormal'))
		--	end
		--end

		local file = VFS.LoadFile("cmdcolors_" .. cursorSet .. ".txt")
		if file then
			Spring.LoadCmdColorsConfig(file)
		end

		-- hide engine unit selection box
		if WG.selectedunits or WG.teamplatter or WG.highlightselunits then
			Spring.LoadCmdColorsConfig("unitBox  0 1 0 0")
		end

		-- Hide metal extractor circles on non-metal maps
		if WG.resource_spot_finder and not WG.resource_spot_finder.isMetalMap then
			Spring.LoadCmdColorsConfig("rangeExtract         1.0  0.3  0.3  0.0")
		end
	end
end

function widget:GetConfigData()
	return Settings
end

function widget:SetConfigData(data)
	if data and type(data) == "table" and data.version then
		if data.version < 6 and data.sizeMult then
			Spring.SetConfigFloat("cursorsize", data.sizeMult)
		end
		Settings = data
		Settings.sizeMult = Spring.GetConfigFloat("cursorsize", 1)
	end
end
