if not RmlUi then
    return
end

local widget = widget ---@type Widget

function widget:GetInfo()
    return {
        name = "RML Widget Starter",
        desc = "Rml Starter template demonstrating RmlUi widget best practices and common patterns.",
        author = "Mupersega",
        date = "2025",
        license = "GNU GPL, v2 or later",
        layer = -1000000,
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

-- Initial data model - Used only for setting the initial state of the model, not for updates, for this use the dm_handle.
local init_model = {
    -- String data with dynamic content
    message = "Hello! This text comes from the Lua data model and demonstrates variable binding.",
    
    -- Array of objects - demonstrates iteration
    testArray = {
        { name = "Configuration", value = 100 },
        { name = "Game State", value = 200 },
        { name = "UI Controls", value = 300 },
        { name = "User Preferences", value = 400 },
    },
    
    -- Tab system state (controlled by data binding)
    activeTab = "", -- Start empty for landing page.

    -- All tabs
    tabs = {
        { id = "getting-started", label = "Getting Started" },
        { id = "base-widget-conventions", label = "Base Widget Conventions" },
        { id = "widget-positioning", label = "Widget Positioning" },
        { id = "data-binding", label = "Data Binding" },
        { id = "styling", label = "Styling" },
        { id = "tools", label = "Tools" },
    },

    -- Current time for demonstrations
    currentTime = os.date("%H:%M:%S"),
    
    -- Debug mode toggle
    debugMode = false,
    
    -- Data binding demo variables
    playerName = "Commander",
    metalCount = 250,
    gamePaused = false,
}

-- Widget lifecycle functions
function widget:Initialize()
    -- Initialize the widget
    Spring.Echo(WIDGET_ID .. ": Initializing widget...")
    
    -- Get the shared RML context
    widget.rmlContext = RmlUi.GetContext("shared")
    if not widget.rmlContext then
        Spring.Echo(WIDGET_ID .. ": ERROR - Failed to get RML context")
        return false
    end

    -- Create and bind the data model
    dm_handle = widget.rmlContext:OpenDataModel(MODEL_NAME, init_model)
    if not dm_handle then
        Spring.Echo(WIDGET_ID .. ": ERROR - Failed to create data model '" .. MODEL_NAME .. "'")
        return false
    end

    Spring.Echo(WIDGET_ID .. ": Data model created successfully")

    -- Load the RML document
    document = widget.rmlContext:LoadDocument(RML_PATH, widget)
    if not document then
        Spring.Echo(WIDGET_ID .. ": ERROR - Failed to load document: " .. RML_PATH)
        widget:Shutdown()
        return false
    end

    -- Apply styles and show the document
    document:ReloadStyleSheet()
    document:Show()
    
    Spring.Echo(WIDGET_ID .. ": Widget initialized successfully")
    
    return true
end

function widget:Shutdown()
    Spring.Echo(WIDGET_ID .. ": Shutting down widget...")
    
    -- Clean up data model
    if widget.rmlContext and dm_handle then
        widget.rmlContext:RemoveDataModel(MODEL_NAME)
        dm_handle = nil
    end
    
    -- Close document
    if document then
        document:Close()
        document = nil
    end
    
    widget.rmlContext = nil
    Spring.Echo(WIDGET_ID .. ": Shutdown complete")
end

-- Development helper function for hot reloading
function widget:Reload(event)
    Spring.Echo(WIDGET_ID .. ": Reloading widget (event: " .. tostring(event) .. ")")
    widget:Shutdown()
    widget:Initialize()
end

-- Update current time (can be called periodically or in response to events)
function widget:UpdateCurrentTime()
    if dm_handle then
        dm_handle.currentTime = os.date("%H:%M:%S")
        Spring.Echo(WIDGET_ID .. ": Updated current time to: " .. dm_handle.currentTime)
    end
end

-- Example of how to update the data model from Lua
function widget:UpdateMessage(newMessage)
    if dm_handle then
        dm_handle.message = newMessage
        Spring.Echo(WIDGET_ID .. ": Message updated to: " .. newMessage)
    end
end

-- Example of adding items to the array
function widget:AddTestItem(name, value)
    if dm_handle and dm_handle.testArray then
        table.insert(dm_handle.testArray, { name = name, value = value })
        Spring.Echo(WIDGET_ID .. ": Added item: " .. name)
    end
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

-- Data binding demo functions
function widget:AddMetal()
    if dm_handle then
        dm_handle.metalCount = dm_handle.metalCount + 100
        Spring.Echo(WIDGET_ID .. ": Added 100 metal, total: " .. dm_handle.metalCount)
    end
end

function widget:SubtractMetal()
    if dm_handle then
        dm_handle.metalCount = math.max(0, dm_handle.metalCount - 50)
        Spring.Echo(WIDGET_ID .. ": Subtracted 50 metal, total: " .. dm_handle.metalCount)
    end
end

function widget:ClearMetal()
    if dm_handle then
        dm_handle.metalCount = 0
        Spring.Echo(WIDGET_ID .. ": Cleared metal, total: " .. dm_handle.metalCount)
    end
end