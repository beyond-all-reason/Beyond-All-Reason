if not RmlUi then
    return
end

local widget = widget ---@type Widget

function widget:GetInfo()
    return {
        name = "Rml context manager",
        desc = "This widget is responsible for handling dynamic interactions with Rml contexts.",
        author = "Mupersega",
        date = "2025",
        license = "GNU GPL, v2 or later",
        layer = -1000000,
        enabled = true
    }
end

local function calculateDpRatio()
    local viewSizeX, viewSizeY = Spring.GetViewGeometry()
    local userScale = Spring.GetConfigFloat("ui_scale", 1)
    local baseWidth = 1920
    local baseHeight = 1080
    local resFactor = math.min(viewSizeX / baseWidth, viewSizeY / baseHeight)
    local dpRatio = resFactor * userScale
    return math.floor(dpRatio * 100) / 100
end

local currentDpRatio = 1

local function updateContextsDpRatio()
    currentDpRatio = calculateDpRatio()
    local contexts = RmlUi.contexts()
    for _, context in ipairs(contexts) do
        context.dp_ratio = currentDpRatio
    end
end

-- Shared accessor so widgets don't reimplement calculateDpRatio().
-- Returns the current scale factor (resolution_factor * ui_scale), matching
-- whatever the shared RmlUi context is currently using.
WG.RmlContextManager = WG.RmlContextManager or {}
WG.RmlContextManager.getDpRatio = function() return currentDpRatio end

function widget:Initialize()
    if not RmlUi.GetContext("shared") then
        RmlUi.CreateContext("shared")
    end
    updateContextsDpRatio()
end

function widget:ViewResize()
    updateContextsDpRatio()
end

-- include also a listener for the ui_scale config variable changes

function widget:Shutdown()
    if WG.RmlContextManager then
        WG.RmlContextManager.getDpRatio = nil
    end
    Spring.Echo("Rml Context Manager shutdown, dynamic context dp ratio updates to contexts disabled." )
end
