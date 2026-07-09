if not RmlUi then
    return
end

local widget = widget ---@type Widget
local utils = VFS.Include("luaui/Include/rml_utilities/utils.lua")
local EzSVG = VFS.Include("luaui/Include/rml_utilities/EzSVG.lua")
local svgShapes = VFS.Include("luaui/Include/rml_utilities/svg_shapes.lua")

function widget:GetInfo()
    return {
        name = "RML Starter",
        desc = "RML widget demonstrating RmlUi best practices in BAR, common patterns, and expected conventions for primary widgets.",
        author = "Mupersega",
        date = "2025",
        license = "GNU GPL, v2 or later",
        layer = -10000,
        enabled = false,
    }
end

-- Constants
local WIDGET_ID = "rml_starter"
local MODEL_NAME = "rml_starter_model"
local RML_PATH = "luaui/rmlwidgets/rml_starter/rml_starter.rml"

-- Widget state
local document
local dm_handle

-- ── SVG demo state ──
local svgGraphEl

-- Graph data (generated once, re-rendered during sweep)
local svgGraphData = nil   -- array of {color, scores}
local svgGraphMaxScore = 0
local svgPointCount = 30

-- Sweep state
local svgSweepRunning = false
local svgSweepElapsed = 0
local svgSweepAccum = 0      -- accumulator for throttling
local SVG_SWEEP_DURATION = 3 -- seconds
local SVG_RENDER_INTERVAL = 1 / 60
local svgSmooth = false

-- Filter state
local svgSelected = {}
local svgHasSelection = false

local PLAYER_NAMES = { "Alpha", "Bravo", "Charlie", "Delta" }

-- Playground state
local playgroundEl
local playShape = "taper-left"
local playDepth = 30
local playCorner = "bl"
local playFill = "rgb(38,38,42)"
local playOpacity = 0.8
local playGradient = false

local PLAY_FILLS = {
	"rgb(38,38,42)",
	"rgb(65,65,70)",
	"rgb(120,120,125)",
}

-- ── Tooltip Layer demo state ──
-- The shared overlay (rml_tooltip_layer / WG['rml_tooltip']) is *driven*,
-- not fire-and-forget: it auto-hides ~170ms after the last Show(). So
-- hover handlers only set state here; widget:Update re-Shows it every
-- frame with live cursor coords while a demo target is hovered.
local ttDemoText = nil    -- body content (inner RML); nil = nothing hovered
local ttDemoTitle = nil   -- optional title; nil = plain (untitled) slot
local ttDemoActive = false -- did we Show() last frame? (Hide only on transition)

-- Build gradient SVG manually (shape library doesn't handle gradients)
local function buildGradientShape(shapeType, opts)
	local W, H = 100, 100
	local doc = EzSVG.Document(W, H)
	doc["viewBox"] = "0 0 " .. W .. " " .. H
	doc["preserveAspectRatio"] = "none"
	doc["width"] = nil
	doc["height"] = nil

	local grad = EzSVG.LinearGradient(0, 0, 100, 0)
	grad:addStop(0, opts.fill, opts.opacity or 0.8)
	grad:addStop(100, opts.fill, 0)
	grad:setID("pg-grad")
	doc:addDef(grad)

	local points
	if shapeType == "notchedCorner" then
		local sx = opts.sizeX or 45
		local sy = opts.sizeY or 30
		local corner = opts.corner or "bl"
		if corner == "bl" then
			points = { 0, 0, W, 0, W, H, sx, H, 0, H - sy }
		elseif corner == "br" then
			points = { 0, 0, W, 0, W, H - sy, W - sx, H, 0, H }
		elseif corner == "tl" then
			points = { sx, 0, W, 0, W, H, 0, H, 0, sy }
		elseif corner == "tr" then
			points = { 0, 0, W - sx, 0, W, sy, W, H, 0, H }
		end
	elseif shapeType == "taper-left" then
		local d = opts.depth or 30
		points = { 0, 0, W, 0, W, H, d, H }
	elseif shapeType == "taper-right" then
		local d = opts.depth or 30
		points = { 0, 0, W, 0, W - d, H, 0, H }
	end

	if points then
		doc:add(EzSVG.Polygon(points, { fill = grad:getURLRef() }))
	end
	return doc:tostr()
end

local function renderPlayground()
	if not playgroundEl then return end
	local svg
	if playGradient then
		local opts = { fill = playFill, opacity = playOpacity }
		if playShape == "notchedCorner" then
			opts.corner = playCorner
			opts.sizeX = playDepth
			opts.sizeY = math.floor(playDepth * 0.66)
		else
			opts.depth = playDepth
		end
		svg = buildGradientShape(playShape, opts)
	elseif playShape == "notchedCorner" then
		svg = svgShapes.notchedCorner({
			corner = playCorner,
			sizeX = playDepth,
			sizeY = math.floor(playDepth * 0.66),
			fill = playFill,
			opacity = playOpacity,
		})
	elseif playShape == "taper-left" then
		svg = svgShapes.taper({
			side = "left",
			depth = playDepth,
			fill = playFill,
			opacity = playOpacity,
		})
	elseif playShape == "taper-right" then
		svg = svgShapes.taper({
			side = "right",
			depth = playDepth,
			fill = playFill,
			opacity = playOpacity,
		})
	end
	if svg then
		playgroundEl:SetAttribute("src", svg)
	end
end

local function getPlayCode()
	local opStr = ", opacity = " .. playOpacity
	if playGradient then
		return '-- Gradient: build manually with EzSVG.LinearGradient\n-- fill = "' .. playFill .. '"' .. opStr .. ' fading to transparent'
	end
	if playShape == "notchedCorner" then
		return 'svgShapes.notchedCorner({ corner = "' .. playCorner .. '", sizeX = ' .. playDepth .. ', sizeY = ' .. math.floor(playDepth * 0.66) .. ', fill = "' .. playFill .. '"' .. opStr .. ' })'
	elseif playShape == "taper-left" then
		return 'svgShapes.taper({ side = "left", depth = ' .. playDepth .. ', fill = "' .. playFill .. '"' .. opStr .. ' })'
	elseif playShape == "taper-right" then
		return 'svgShapes.taper({ side = "right", depth = ' .. playDepth .. ', fill = "' .. playFill .. '"' .. opStr .. ' })'
	end
	return ""
end

local GRAPH_COLORS = {
	"rgb(43, 165, 234)",  -- blue
	"rgb(239, 68, 68)",   -- red
	"rgb(34, 197, 94)",   -- green
	"rgb(250, 212, 0)",   -- yellow
}

local function easeInOutCubic(t)
	if t < 0.5 then
		return 4 * t * t * t
	else
		local f = 2 * t - 2
		return 0.5 * f * f * f + 1
	end
end

-- Catmull-Rom spline interpolation
local function catmullRom(p0, p1, p2, p3, t)
	local t2 = t * t
	local t3 = t2 * t
	return 0.5 * (
		(2 * p1) +
		(-p0 + p2) * t +
		(2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 +
		(-p0 + 3 * p1 - 3 * p2 + p3) * t3
	)
end

local function smoothScores(scores, subdivisions)
	local n = #scores
	if n < 2 then return scores end
	subdivisions = subdivisions or 4
	local result = {}
	for i = 1, n - 1 do
		local p0 = scores[math.max(1, i - 1)]
		local p1 = scores[i]
		local p2 = scores[math.min(n, i + 1)]
		local p3 = scores[math.min(n, i + 2)]
		result[#result + 1] = p1
		for s = 1, subdivisions - 1 do
			result[#result + 1] = math.max(0, catmullRom(p0, p1, p2, p3, s / subdivisions))
		end
	end
	result[#result + 1] = scores[n]
	return result
end

local function generateGraphData()
	local players = {}
	local playerCount = 3 + math.floor(math.random() * 2) -- 3-4
	svgPointCount = 40 + math.floor(math.random() * 60)   -- 40-99
	svgGraphMaxScore = 0
	for p = 1, playerCount do
		local scores = {}
		local score = math.random(20, 60)
		for i = 1, svgPointCount do
			score = math.max(0, score + math.random(-12, 15))
			scores[i] = score
			if score > svgGraphMaxScore then svgGraphMaxScore = score end
		end
		players[p] = {
			name = PLAYER_NAMES[p] or ("P" .. p),
			color = GRAPH_COLORS[p],
			scores = scores,
		}
	end
	if svgGraphMaxScore == 0 then svgGraphMaxScore = 1 end
	svgGraphData = players
	svgSelected = {}
	svgHasSelection = false
end

local function getFilteredPlayers()
	if not svgGraphData then return {} end
	if not svgHasSelection then return svgGraphData end
	local filtered = {}
	for i, player in ipairs(svgGraphData) do
		if svgSelected[i] then
			filtered[#filtered + 1] = player
		end
	end
	return filtered
end

local function updatePlayerListModel()
	if not dm_handle or not svgGraphData then return end
	local list = {}
	for i, player in ipairs(svgGraphData) do
		list[#list + 1] = {
			index = tostring(i),
			name = player.name,
			color = player.color,
			selected = svgSelected[i] and true or false,
		}
	end
	dm_handle.svgPlayerList = list
end

local function buildSvgGraph(players, revealFraction)
	if not players or #players == 0 then return "" end
	local W, H = 400, 140
	local PAD_LEFT, PAD_RIGHT, PAD_TOP, PAD_BOTTOM = 30, 10, 10, 20
	local gw = W - PAD_LEFT - PAD_RIGHT
	local gh = H - PAD_TOP - PAD_BOTTOM

	local doc = EzSVG.Document(W, H)
	doc:add(EzSVG.Rect(0, 0, W, H, 4, 4, { fill = "rgb(15, 15, 25)" }))

	-- Grid
	local gridSteps = 3
	for i = 0, gridSteps do
		local y = PAD_TOP + gh - (i / gridSteps) * gh
		doc:add(EzSVG.Line(PAD_LEFT, y, W - PAD_RIGHT, y, {
			stroke = "rgb(50, 50, 70)", ["stroke-width"] = "0.5",
		}))
		doc:add(EzSVG.Text(tostring(math.floor(svgGraphMaxScore * i / gridSteps)), PAD_LEFT - 4, y + 3, {
			fill = "rgb(100, 100, 120)", ["font-size"] = "7", ["text-anchor"] = "end",
		}))
	end

	-- Prepare draw data (optionally smoothed)
	local SUBDIVISIONS = 4
	local drawPlayers = {}
	for _, player in ipairs(players) do
		local scores = player.scores
		if svgSmooth then
			scores = smoothScores(scores, SUBDIVISIONS)
		end
		drawPlayers[#drawPlayers + 1] = { color = player.color, scores = scores }
	end

	local pointCount = svgSmooth
		and ((svgPointCount - 1) * SUBDIVISIONS + 1)
		or svgPointCount

	-- How many points to draw
	local drawCount = pointCount
	if revealFraction and revealFraction < 1.0 then
		drawCount = math.max(1, math.floor(revealFraction * pointCount))
	end

	-- Sweep cursor
	if drawCount < pointCount then
		local cx = PAD_LEFT + ((drawCount - 1) / (pointCount - 1)) * gw
		doc:add(EzSVG.Line(cx, PAD_TOP, cx, PAD_TOP + gh, {
			stroke = "rgb(255, 255, 255)", ["stroke-width"] = "0.5", opacity = "0.25",
		}))
	end

	-- Lines
	for _, player in ipairs(drawPlayers) do
		local path = EzSVG.Path({
			fill = "none", stroke = player.color,
			["stroke-width"] = "1.5", ["stroke-linejoin"] = "round",
		})
		local limit = math.min(drawCount, #player.scores)
		for i = 1, limit do
			local x = PAD_LEFT + ((i - 1) / (pointCount - 1)) * gw
			local y = PAD_TOP + gh - (player.scores[i] / svgGraphMaxScore) * gh
			if i == 1 then path:moveToA(x, y) else path:lineToA(x, y) end
		end
		doc:add(path)

		-- Tip dot during sweep
		if drawCount < pointCount and limit >= 1 then
			local tx = PAD_LEFT + ((limit - 1) / (pointCount - 1)) * gw
			local ty = PAD_TOP + gh - (player.scores[limit] / svgGraphMaxScore) * gh
			doc:add(EzSVG.Circle(tx, ty, 2, { fill = player.color }))
		end
	end

	return doc:tostr()
end

local function renderSvgGraph()
	if not svgGraphEl or not svgGraphData then return end
	local fraction = nil
	if svgSweepRunning then
		local t = math.min(1.0, svgSweepElapsed / SVG_SWEEP_DURATION)
		fraction = easeInOutCubic(t)
	end
	local players = getFilteredPlayers()
	svgGraphEl:SetAttribute("src", buildSvgGraph(players, fraction))
end

-- Create a fresh model table for each init
local function initModel()
    return {

        -- Main widget states
        expanded = true,
        debugMode = false,
        reloadRequested = false,  -- set by requestReload(); acted on in widget:Update
        activeTab = "landing",

        -- No widget: methods — model fns + data-event-* (see CLAUDE.md
        -- "The model is king"). requestReload defers teardown to Update
        -- so the model isn't destroyed inside its own dispatch.
        requestReload = function()
            dm_handle.reloadRequested = true
        end,
        toggleDebugger = function()
            dm_handle.debugMode = not dm_handle.debugMode
            RmlUi.SetDebugContext(dm_handle.debugMode and 'shared' or nil)
        end,
        copyPlayCode = function()
            local code = getPlayCode()
            if code and code ~= "" then
                Spring.SetClipboard(code)
                Spring.Echo(WIDGET_ID .. ": Copied decorator code to clipboard")
            end
        end,

        -- Tooltip Layer demo (see the "Tooltip Layer" tab). Handlers ONLY
        -- set state — no WG['rml_tooltip'] calls here. widget:Update reads
        -- this state and drives the shared overlay with live cursor coords.
        showTooltipDemo = function(event, text, title)
            ttDemoText = text
            ttDemoTitle = (title ~= nil and title ~= "") and title or nil
        end,
        showRichTooltipDemo = function()
            -- Markup content is normally assembled in Lua, not passed
            -- through an RML attribute (avoids nested-quote escaping).
            ttDemoText = "<span class='text-warning font-bold'>Markup works</span> — the body is inner RML."
            ttDemoTitle = nil
        end,
        hideTooltipDemo = function()
            ttDemoText = nil
            ttDemoTitle = nil
        end,

        -- All tabs
        tabs = {
            { id = "landing", label = "Welcome" },
            { id = "getting-started", label = "Getting Started" },
            { id = "base-widget-conventions", label = "Base Widget Conventions" },
            { id = "widget-positioning", label = "Widget Positioning" },
            { id = "data-binding", label = "Data Binding" },
            { id = "tooltips", label = "Tooltip Layer" },
            { id = "tools", label = "Tools" },
            { id = "svg", label = "SVG" },
        },
        
        -- Custom class groups for this widget for repeatability
        my = {
            codeBlock = "flex flex-col p-3 bg-darker rounded border border-dark-alpha code-green text-sm",
            tabsNavigationStyles = "font-bold bg-darkest-semi-alpha bg-gradient-darker-alpha radial-focus-start text-outline-darkest-lg border-bottom border-darkest",
            -- Flat replacements for the removed nested ccg.sheet.* group
            -- (CCG groups are flat now — no sub-components; layout via utilities).
            sheet = "hazards-135 bg-darkest",
            sheetTitle = "text-upper hazards-construction-textured text-xl font-bold bg-warning p-3 text-outline-darkest-lg border-bottom border-warning-alpha flex items-center justify-between",
            sheetContent = "p-4",
        },

        -- Data binding demo variables
        playerName = "Commander",
        currentTime = os.date("%H:%M:%S"),

        testArray = {
            { name = "Configuration", value = 100 },
            { name = "Game State", value = 200 },
            { name = "UI Controls", value = 300 },
            { name = "User Preferences", value = 400 },
        },

        -- Data binding examples table
        dataBindingExamples = {
            
            -- Array examples for iteration
            playerList = {
                { name = "Player1", team = "Armada", score = 1250 },
                { name = "Player2", team = "Cortex", score = 980 },
                { name = "Player3", team = "Legion", score = 1100 },
            },
            
            unitQueue = {
                { name = "Construction Bot", cost = 100, time = "15s" },
                { name = "Light Laser Turret", cost = 250, time = "30s" },
                { name = "Solar Collector", cost = 150, time = "20s" },
            },

            availableThemes = {
                { id = "base", name = "Base" },
                { id = "armada", name = "Armada" },
                { id = "cortex", name = "Cortex" },
                { id = "legion", name = "Legion" },
            },
        },

        setActiveTab = function(event, tabId)
            if dm_handle.activeTab == tabId then
                return
            end
            local oldTabEl = document:GetElementById(dm_handle.activeTab)
            if oldTabEl then
                local newTabEl = document:GetElementById(tabId)
                if newTabEl then
                    dm_handle.activeTab = tabId
                end
            end
        end,

        toggleExpand = function()
            dm_handle.expanded = not dm_handle.expanded

            if document then
                if dm_handle.expanded then
                    document:SetClass("collapsed", false)
                else
                    document:SetClass("collapsed", true)
                end
            end
        end,

        -- SVG demo
        svgSweepRunning = false,
        svgSmooth = false,
        svgPlayerList = {},

        generateSvgGraph = function()
            generateGraphData()
            updatePlayerListModel()
            svgSweepRunning = false
            svgSweepElapsed = 0
            dm_handle.svgSweepRunning = false
            renderSvgGraph()
        end,

        toggleSvgSmooth = function()
            svgSmooth = not svgSmooth
            dm_handle.svgSmooth = svgSmooth
            renderSvgGraph()
        end,

        toggleSvgSweep = function()
            if not svgGraphData then return end

            svgSweepRunning = not svgSweepRunning
            dm_handle.svgSweepRunning = svgSweepRunning

            if svgSweepRunning then
                svgSweepElapsed = 0
                svgSweepAccum = 0
            end
            renderSvgGraph()
        end,

        toggleSvgPlayer = function(event, indexStr)
            if not svgGraphData then return end
            local idx = tonumber(indexStr)
            if not idx or not svgGraphData[idx] then return end

            if not svgHasSelection then
                svgSelected = {}
                svgSelected[idx] = true
                svgHasSelection = true
            else
                svgSelected[idx] = not svgSelected[idx] or nil
                svgHasSelection = false
                for _ in pairs(svgSelected) do
                    svgHasSelection = true
                    break
                end
            end

            updatePlayerListModel()
            renderSvgGraph()
        end,

        -- Decorator playground
        playShape = "taper-left",
        playDepth = "30",
        playCorner = "bl",
        playFill = "rgb(38,38,42)",
        playOpacity = "0.8",
        playGradient = false,
        playCode = "",

        setPlayShape = function(event, shape)
            playShape = shape
            dm_handle.playShape = shape
            dm_handle.playCode = getPlayCode()
            renderPlayground()
        end,

        setPlayDepth = function(event, depth)
            playDepth = tonumber(depth) or 30
            dm_handle.playDepth = tostring(playDepth)
            dm_handle.playCode = getPlayCode()
            renderPlayground()
        end,

        setPlayCorner = function(event, corner)
            playCorner = corner
            dm_handle.playCorner = corner
            dm_handle.playCode = getPlayCode()
            renderPlayground()
        end,

        setPlayFill = function(event, fill)
            playFill = fill
            dm_handle.playFill = fill
            dm_handle.playCode = getPlayCode()
            renderPlayground()
        end,

        setPlayOpacity = function(event, op)
            playOpacity = tonumber(op) or 0.8
            dm_handle.playOpacity = tostring(playOpacity)
            dm_handle.playCode = getPlayCode()
            renderPlayground()
        end,

        togglePlayGradient = function()
            playGradient = not playGradient
            dm_handle.playGradient = playGradient
            dm_handle.playCode = getPlayCode()
            renderPlayground()
        end,
    }
end

function widget:Initialize()
    local result = utils.initializeRmlWidget(self, {
        widgetId = WIDGET_ID,
        modelName = MODEL_NAME,
        rmlPath = RML_PATH,
        initModel = initModel(), -- Use fresh model every time
        useCommonClassGroups = true,
    })
    if not result then
        return false
    end
    
    document = result.document
    dm_handle = result.dm_handle

    dm_handle.toggleExpand() -- start expanded true and toggle it closed on init to start collapsed

    -- SVG demo
    svgGraphEl = document:GetElementById("svg-demo-graph")
    generateGraphData()
    updatePlayerListModel()
    renderSvgGraph()
    svgSweepRunning = false

    -- Shape playground
    playgroundEl = document:GetElementById("svg-playground")
    dm_handle.playCode = getPlayCode()
    renderPlayground()

    return true
end

function widget:Shutdown()
    local shutdownParams = {
        widgetId = WIDGET_ID,
        modelName = MODEL_NAME
    }
    utils.shutdownRmlWidget(self, shutdownParams, document, dm_handle)
    -- Don't orphan the shared overlay if we're torn down mid-hover.
    if ttDemoActive and WG['rml_tooltip'] then
        WG['rml_tooltip'].Hide()
    end
    ttDemoText = nil
    ttDemoTitle = nil
    ttDemoActive = false
    svgGraphEl = nil
    svgSweepRunning = false
    svgSweepElapsed = 0
    svgSweepAccum = 0
    svgGraphData = nil
    playgroundEl = nil
end

function widget:Update(dt)
    if dm_handle and dm_handle.reloadRequested then
        -- Deferred reload: tear down OUTSIDE the data-event dispatch that
        -- requested it (Shutdown from inside a model fn = use-after-free).
        widget:Shutdown()
        widget:Initialize()
        return
    end
    if dm_handle then
        dm_handle.currentTime = os.date("%H:%M:%S")
    end

    -- Tooltip Layer demo: drive the shared overlay while a demo target is
    -- hovered. Same hover->Show / out->Hide idea as rml_style_guide, with
    -- two refinements worth copying: (1) gated on the tab being active so
    -- we don't fight other widgets when you're elsewhere, and (2) Hide()
    -- only on the hover-out transition — the slot is a single shared
    -- resource, so blindly Hiding every idle frame would clobber another
    -- widget's tooltip.
    if dm_handle and dm_handle.activeTab == "tooltips" and WG['rml_tooltip'] then
        if ttDemoText then
            local mx, my = Spring.GetMouseState()
            WG['rml_tooltip'].Show(ttDemoText, mx, my, ttDemoTitle)
            ttDemoActive = true
        elseif ttDemoActive then
            WG['rml_tooltip'].Hide()
            ttDemoActive = false
        end
    end

    if svgSweepRunning and svgGraphData and svgGraphEl then
        svgSweepElapsed = svgSweepElapsed + dt
        svgSweepAccum = svgSweepAccum + dt

        if svgSweepElapsed >= SVG_SWEEP_DURATION then
            svgSweepRunning = false
            svgSweepElapsed = SVG_SWEEP_DURATION
            if dm_handle then
                dm_handle.svgSweepRunning = false
            end
            renderSvgGraph()
        elseif svgSweepAccum >= SVG_RENDER_INTERVAL then
            svgSweepAccum = svgSweepAccum - SVG_RENDER_INTERVAL
            renderSvgGraph()
        end
    end
end
