local widget = widget ---@type Widget
local musicTrackFilters = VFS.Include("common/music_track_filters.lua")

function widget:GetInfo()
	return {
		name      = "Music Filters",
		desc      = "Toggles soundtrack packs and tracks",
		author    = "Codex",
		date      = "2026",
		license   = "GNU GPL, v2 or later",
		layer     = -99991,
		enabled   = true,
	}
end

local spGetViewGeometry = Spring.GetViewGeometry
local spGetMouseState = Spring.GetMouseState
local spIsGUIHidden = Spring.IsGUIHidden
local spSetConfigString = Spring.SetConfigString
local spGetConfigString = Spring.GetConfigString

local glColor = gl.Color
local glRect = gl.Rect
local glText = gl.Text

local vsx, vsy = spGetViewGeometry()
local showWindow = false
local scrollOffset = 0
local maxScroll = 0
local rowRects = {}
local closeRect
local packs = {}
local expandedPacks = {}
local disabledPacks = {}
local disabledTracks = {}

local windowRect = { 0, 0, 0, 0 }
local rowHeight = 28
local headerHeight = 46
local footerHeight = 34
local padding = 14

local packDirs = {
	"music/original/menu",
	"music/original/loading",
	"music/original/peace",
	"music/original/warlow",
	"music/original/warhigh",
	"music/original/interludes",
	"music/original/victory",
	"music/original/defeat",
	"music/original/gameover",

	"music/original/events/raptors/loading",
	"music/original/events/raptors/peace",
	"music/original/events/raptors/warlow",
	"music/original/events/raptors/warhigh",
	"music/original/events/raptors/interludes",
	"music/original/events/raptors/bossfight",
	"music/original/events/scavengers/loading",
	"music/original/events/scavengers/peace",
	"music/original/events/scavengers/warlow",
	"music/original/events/scavengers/warhigh",
	"music/original/events/scavengers/interludes",
	"music/original/events/scavengers/bossfight",
	"music/original/events/aprilfools/menu",
	"music/original/events/aprilfools/loading",
	"music/original/events/aprilfools/peace",
	"music/original/events/aprilfools/war",
	"music/original/events/aprilfools/warlow",
	"music/original/events/aprilfools/warhigh",
	"music/original/events/aprilfools/interludes",
	"music/original/events/halloween/menu",
	"music/original/events/halloween/loading",
	"music/original/events/halloween/peace",
	"music/original/events/halloween/war",
	"music/original/events/halloween/warlow",
	"music/original/events/halloween/warhigh",
	"music/original/events/halloween/interludes",
	"music/original/events/xmas/menu",
	"music/original/events/xmas/loading",
	"music/original/events/xmas/peace",
	"music/original/events/xmas/war",
	"music/original/events/xmas/warlow",
	"music/original/events/xmas/warhigh",
	"music/original/events/xmas/interludes",

	"music/map/loading",
	"music/map/peace",
	"music/map/warlow",
	"music/map/warhigh",
	"music/map/interludes",

	"music/custom/menu",
	"music/custom/loading",
	"music/custom/peace",
	"music/custom/war",
	"music/custom/warlow",
	"music/custom/warhigh",
	"music/custom/interludes",
	"music/custom/bossfight",
	"music/custom/victory",
	"music/custom/defeat",
	"music/custom/gameover",
}

local segmentLabels = {
	original = "Original",
	events = "Events",
	raptors = "Raptors",
	scavengers = "Scavengers",
	aprilfools = "April Fools",
	halloween = "Halloween",
	xmas = "Christmas",
	map = "Map",
	custom = "Custom",
	menu = "Menu",
	loading = "Loading",
	peace = "Peace",
	war = "War",
	warlow = "War Low",
	warhigh = "War High",
	interludes = "Interludes",
	bossfight = "Boss Fight",
	victory = "Victory",
	defeat = "Defeat",
	gameover = "Game Over",
}

local function splitPath(path)
	local parts = {}
	for part in string.gmatch(path, "[^/]+") do
		if part ~= "music" then
			parts[#parts + 1] = part
		end
	end
	return parts
end

local function packLabel(path)
	local parts = splitPath(musicTrackFilters.NormalizePath(path))
	local labels = {}
	for i = 1, #parts do
		labels[#labels + 1] = segmentLabels[parts[i]] or string.gsub(parts[i], "^%l", string.upper)
	end

	if labels[1] == "Original" and labels[2] == "Events" then
		table.remove(labels, 1)
	end

	return table.concat(labels, " / ")
end

local function trackLabel(path)
	local name = string.match(path, "[^/\\]+$") or path
	name = string.gsub(name, "%.%w+$", "")
	return name
end

local function truncate(text, maxChars)
	if string.len(text) <= maxChars then
		return text
	end
	return string.sub(text, 1, math.max(1, maxChars - 3)) .. "..."
end

local function readConfig()
	disabledPacks = musicTrackFilters.ParseSet(spGetConfigString(musicTrackFilters.CONFIG_DISABLED_PACKS, ""))
	disabledTracks = musicTrackFilters.ParseSet(spGetConfigString(musicTrackFilters.CONFIG_DISABLED_TRACKS, ""))
end

local function saveConfig()
	spSetConfigString(musicTrackFilters.CONFIG_DISABLED_PACKS, musicTrackFilters.SerializeSet(disabledPacks))
	spSetConfigString(musicTrackFilters.CONFIG_DISABLED_TRACKS, musicTrackFilters.SerializeSet(disabledTracks))

	if WG.music and WG.music.RefreshTrackList then
		WG.music.RefreshTrackList()
	end
end

local function scanPacks()
	packs = {}
	local seenDirs = {}
	local allowedExtensions = "{*.ogg,*.mp3}"

	for i = 1, #packDirs do
		local dir = musicTrackFilters.NormalizePath(packDirs[i])
		if not seenDirs[dir] then
			seenDirs[dir] = true
			local tracks = VFS.DirList(dir, allowedExtensions)
			if #tracks > 0 then
				table.sort(tracks, function(a, b)
					return string.lower(trackLabel(a)) < string.lower(trackLabel(b))
				end)
				packs[#packs + 1] = {
					path = dir,
					label = packLabel(dir),
					tracks = tracks,
				}
			end
		end
	end
end

local function refreshData()
	readConfig()
	scanPacks()
end

local function setWindowGeometry()
	local width = math.min(760, math.floor(vsx * 0.82))
	local height = math.min(660, math.floor(vsy * 0.82))
	local x1 = math.floor((vsx - width) * 0.5)
	local y1 = math.floor((vsy - height) * 0.5)
	windowRect = { x1, y1, x1 + width, y1 + height }
	closeRect = { windowRect[3] - 38, windowRect[4] - 36, windowRect[3] - 12, windowRect[4] - 12 }
end

local function drawText(text, x, y, size, options, color)
	color = color or { 1, 1, 1, 1 }
	local font = WG.fonts and WG.fonts.getFont and WG.fonts.getFont()
	if font then
		font:Begin()
		font:SetTextColor(color[1], color[2], color[3], color[4])
		font:Print(text, x, y, size, options or "n")
		font:End()
	else
		glColor(color)
		glText(text, x, y, size, options or "n")
	end
end

local function drawBox(rect, color)
	glColor(color)
	glRect(rect[1], rect[2], rect[3], rect[4])
end

local function drawCheckbox(x, y, enabled, muted, partial)
	local size = 16
	local bg = enabled and { 0.16, 0.42, 0.25, muted and 0.45 or 0.95 } or { 0.28, 0.28, 0.31, muted and 0.35 or 0.95 }
	drawBox({ x, y, x + size, y + size }, { 0.04, 0.05, 0.06, 0.95 })
	drawBox({ x + 2, y + 2, x + size - 2, y + size - 2 }, bg)
	if enabled then
		drawText("x", x + 5, y + 1, 15, "n", { 0.92, 1, 0.92, muted and 0.55 or 1 })
	elseif partial then
		drawText("-", x + 5, y + 2, 15, "n", { 1, 0.88, 0.55, 1 })
	end
	return { x, y, x + size, y + size }
end

local function getPackEnabledCount(pack)
	if disabledPacks[pack.path] then
		return 0
	end

	local count = 0
	for i = 1, #pack.tracks do
		if not disabledTracks[musicTrackFilters.NormalizePath(pack.tracks[i])] then
			count = count + 1
		end
	end
	return count
end

local function totalContentHeight()
	local height = 0
	for i = 1, #packs do
		height = height + rowHeight
		if expandedPacks[packs[i].path] then
			height = height + (#packs[i].tracks * rowHeight)
		end
	end
	return height
end

local function clampScroll()
	local visibleHeight = (windowRect[4] - windowRect[2]) - headerHeight - footerHeight
	maxScroll = math.max(0, totalContentHeight() - visibleHeight)
	scrollOffset = math.max(0, math.min(scrollOffset, maxScroll))
end

local function toggleWindow(force)
	if force ~= nil then
		showWindow = force
	else
		showWindow = not showWindow
	end

	if showWindow then
		refreshData()
	end
end

local function toggleWindowAction()
	toggleWindow()
end

local function togglePack(pack)
	if disabledPacks[pack.path] then
		disabledPacks[pack.path] = nil
	else
		disabledPacks[pack.path] = true
	end
	saveConfig()
end

local function toggleTrack(trackPath)
	local normalizedTrack = musicTrackFilters.NormalizePath(trackPath)
	if disabledTracks[normalizedTrack] then
		disabledTracks[normalizedTrack] = nil
	else
		disabledTracks[normalizedTrack] = true
	end
	saveConfig()
end

local function rectContains(rect, x, y)
	return rect and x >= rect[1] and x <= rect[3] and y >= rect[2] and y <= rect[4]
end

local function drawPackRow(pack, rowTop)
	local x1, _, x2 = windowRect[1], windowRect[2], windowRect[3]
	local rowBottom = rowTop - rowHeight
	local enabledCount = getPackEnabledCount(pack)
	local packEnabled = not disabledPacks[pack.path]
	local partial = packEnabled and enabledCount < #pack.tracks
	local arrow = expandedPacks[pack.path] and "-" or "+"

	drawBox({ x1 + padding, rowBottom, x2 - padding, rowTop - 1 }, { 0.10, 0.12, 0.14, 0.86 })
	local toggleRect = drawCheckbox(x2 - padding - 18, rowBottom + 6, packEnabled and not partial, false, partial)
	drawText(arrow, x1 + padding + 8, rowBottom + 7, 14, "n", { 0.85, 0.9, 0.95, 0.95 })
	drawText(truncate(pack.label, 58), x1 + padding + 34, rowBottom + 7, 14, "n", { 0.92, 0.95, 0.98, 1 })
	drawText(enabledCount .. "/" .. #pack.tracks, x2 - padding - 92, rowBottom + 7, 13, "n", { 0.68, 0.73, 0.78, 0.95 })

	rowRects[#rowRects + 1] = {
		type = "pack",
		pack = pack,
		rect = { x1 + padding, rowBottom, x2 - padding, rowTop },
		toggleRect = toggleRect,
		expandRect = { x1 + padding, rowBottom, x2 - padding - 104, rowTop },
	}
end

local function drawTrackRow(pack, trackPath, rowTop)
	local x1, _, x2 = windowRect[1], windowRect[2], windowRect[3]
	local rowBottom = rowTop - rowHeight
	local normalizedTrack = musicTrackFilters.NormalizePath(trackPath)
	local packEnabled = not disabledPacks[pack.path]
	local trackEnabled = packEnabled and not disabledTracks[normalizedTrack]

	drawBox({ x1 + padding + 22, rowBottom, x2 - padding, rowTop - 1 }, { 0.07, 0.08, 0.10, 0.78 })
	local toggleRect = drawCheckbox(x2 - padding - 18, rowBottom + 6, trackEnabled, not packEnabled)
	drawText(truncate(trackLabel(trackPath), 68), x1 + padding + 44, rowBottom + 7, 13, "n", packEnabled and { 0.78, 0.82, 0.86, 1 } or { 0.45, 0.48, 0.52, 0.9 })

	rowRects[#rowRects + 1] = {
		type = "track",
		pack = pack,
		track = trackPath,
		rect = { x1 + padding + 22, rowBottom, x2 - padding, rowTop },
		toggleRect = toggleRect,
	}
end

function widget:ViewResize()
	vsx, vsy = spGetViewGeometry()
	setWindowGeometry()
	clampScroll()
end

function widget:DrawScreen()
	if not showWindow or spIsGUIHidden() then
		return
	end

	clampScroll()
	rowRects = {}

	local x1, y1, x2, y2 = windowRect[1], windowRect[2], windowRect[3], windowRect[4]
	local listTop = y2 - headerHeight
	local listBottom = y1 + footerHeight
	local rowTop = listTop + scrollOffset

	drawBox(windowRect, { 0.02, 0.025, 0.03, 0.94 })
	drawBox({ x1, y2 - headerHeight, x2, y2 }, { 0.09, 0.11, 0.13, 0.98 })
	drawBox({ x1, y1, x2, y1 + footerHeight }, { 0.07, 0.08, 0.10, 0.98 })
	drawText("Music Filters", x1 + padding, y2 - 29, 18, "n", { 0.96, 0.98, 1, 1 })
	drawText("x", closeRect[1] + 8, closeRect[2] + 4, 18, "n", { 0.95, 0.95, 0.95, 1 })
	drawText(#packs .. " packs", x1 + padding, y1 + 10, 12, "n", { 0.62, 0.66, 0.70, 1 })

	for i = 1, #packs do
		local pack = packs[i]
		if rowTop >= listBottom and rowTop - rowHeight <= listTop then
			drawPackRow(pack, rowTop)
		end
		rowTop = rowTop - rowHeight

		if expandedPacks[pack.path] then
			for j = 1, #pack.tracks do
				if rowTop >= listBottom and rowTop - rowHeight <= listTop then
					drawTrackRow(pack, pack.tracks[j], rowTop)
				end
				rowTop = rowTop - rowHeight
			end
		end
	end

	if maxScroll > 0 then
		local scrollAreaHeight = listTop - listBottom
		local thumbHeight = math.max(28, scrollAreaHeight * (scrollAreaHeight / (scrollAreaHeight + maxScroll)))
		local thumbTravel = scrollAreaHeight - thumbHeight
		local thumbTop = listTop - ((scrollOffset / maxScroll) * thumbTravel)
		drawBox({ x2 - 6, thumbTop - thumbHeight, x2 - 3, thumbTop }, { 0.5, 0.58, 0.66, 0.8 })
	end
end

function widget:IsAbove(x, y)
	return showWindow and rectContains(windowRect, x, y)
end

function widget:GetTooltip(x, y)
	if showWindow and rectContains(windowRect, x, y) then
		return "Music Filters"
	end
end

function widget:MouseWheel(up, value)
	local x, y = spGetMouseState()
	if not showWindow or not rectContains(windowRect, x, y) then
		return
	end

	if up then
		scrollOffset = scrollOffset - (rowHeight * 3)
	else
		scrollOffset = scrollOffset + (rowHeight * 3)
	end
	clampScroll()
	return true
end

function widget:MousePress(x, y, button)
	if not showWindow or button ~= 1 then
		return
	end

	if rectContains(closeRect, x, y) then
		toggleWindow(false)
		return true
	end

	for i = 1, #rowRects do
		local row = rowRects[i]
		if rectContains(row.toggleRect, x, y) then
			if row.type == "pack" then
				togglePack(row.pack)
			else
				toggleTrack(row.track)
			end
			return true
		elseif row.type == "pack" and rectContains(row.expandRect, x, y) then
			expandedPacks[row.pack.path] = not expandedPacks[row.pack.path]
			clampScroll()
			return true
		end
	end

	return rectContains(windowRect, x, y)
end

function widget:Initialize()
	refreshData()
	widget:ViewResize()
	WG.musicFilters = {
		Toggle = toggleWindow,
		Refresh = refreshData,
	}
	widgetHandler:AddAction("musicfilters", toggleWindowAction, nil, "t")
end

function widget:Shutdown()
	WG.musicFilters = nil
	widgetHandler:RemoveAction("musicfilters")
end
