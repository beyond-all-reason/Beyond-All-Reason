if not RmlUi then
    return
end

local widget = widget ---@type Widget
local utils = VFS.Include("luaui/Include/rml_utilities/utils.lua")

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

-- Create a new data model every time to avoid reference oddities even with dm_handle
local function initModel()
    return {

        -- Main widget states
        expanded = true,
        debugMode = false,
        activeTab = "landing",

        -- All tabs
        tabs = {
            { id = "landing", label = "Welcome" },
            { id = "getting-started", label = "Getting Started" },
            { id = "base-widget-conventions", label = "Base Widget Conventions" },
            { id = "widget-positioning", label = "Widget Positioning" },
            { id = "data-binding", label = "Data Binding" },
            { id = "tools", label = "Tools" },
        },
        
        -- Custom class groups for this widget for repeatability
        my = {
            codeBlock = "flex flex-col p-3 bg-darker rounded border border-dark-alpha code-green text-sm",
            tabsNavigationStyles = "font-bold bg-darkest-semi-alpha bg-gradient-darker-alpha radial-focus-start text-outline-darkest-lg border-bottom border-darkest",
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

        -- How to cleanly use functions in the data model, use utils.GetCurrentModel(dm_handle) to avoid callback reference issues
        setActiveTab = function(event, tabId)
            local model = utils.GetCurrentModel(dm_handle)
            if model then
                if model.activeTab == tabId then
                    return
                end
                local oldTabEl = document:GetElementById(model.activeTab)
                if oldTabEl then
                    local newTabEl = document:GetElementById(tabId)
                    if newTabEl then
                        model.activeTab = tabId
                    end
                end
            end
        end,

        toggleExpand = function()
            local model = utils.GetCurrentModel(dm_handle)
            if model then
                model.expanded = not model.expanded
            end
    
            if document then
                if model.expanded then
                    document:SetClass("collapsed", false)
                else
                    document:SetClass("collapsed", true)
                end
            end
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
    
    Spring.Echo(WIDGET_ID .. ": Widget initialized successfully")
    return true
end

function widget:Shutdown()
    Spring.Echo(WIDGET_ID .. ": Shutting down widget...")

    local shutdownParams = {
        widgetId = WIDGET_ID,
        modelName = MODEL_NAME
    }
    
    utils.shutdownRmlWidget(self, shutdownParams, document, dm_handle)
    
    Spring.Echo(WIDGET_ID .. ": Shutdown complete")
end

function widget:Update()
    if dm_handle then
        dm_handle.currentTime = os.date("%H:%M:%S")
    end
end

-- Development helper function for hot reloading
function widget:Reload()
    Spring.Echo(WIDGET_ID .. ": Reloading widget...")
    widget:Shutdown()
    widget:Initialize()
end


-- Toggle RmlUi debugger - simple toggle function
function widget:ToggleDebugger()
    if dm_handle then
        dm_handle.debugMode = not dm_handle.debugMode
        
        if dm_handle.debugMode then
            RmlUi.SetDebugContext('shared')
            Spring.Echo(WIDGET_ID .. ": RmlUi debugger enabled")
        else
            RmlUi.SetDebugContext(nil)
            Spring.Echo(WIDGET_ID .. ": RmlUi debugger disabled")
        end
    end
end
