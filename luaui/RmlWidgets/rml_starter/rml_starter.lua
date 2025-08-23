if not RmlUi then
    return
end

local widget = widget ---@type Widget

function widget:GetInfo()
    return {
        name = "RML Widget Starter",
        desc = "Comprehensive starter template demonstrating RmlUi widget best practices and common patterns.",
        author = "Mupersega",
        date = "2025",
        license = "GNU GPL, v2 or later",
        layer = -1000000,
        enabled = true, -- Set to true to enable the widget by default
    }
end

-- Constants
local WIDGET_NAME = "RML Starter"
local MODEL_NAME = "starter_model"
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
    activeTab = "base-widget-structure", -- Start empty for landing page.

    -- All tabs
    tabs = {
        { id = "getting-started", label = "Getting Started" },
        { id = "base-widget-structure", label = "Base Widget Structure" },
        { id = "data-binding", label = "Data Binding" },
        { id = "event-handling", label = "Event Handling" },
        { id = "debugging", label = "Debugging" },
        { id = "examples", label = "Examples" },
        { id = "performance", label = "Performance" },
        { id = "best-practices", label = "Best Practices" },
        { id = "tools", label = "Tools" },
    },

    -- Current time for demonstrations
    currentTime = os.date("%H:%M:%S"),
    
    -- Debug mode toggle
    debugMode = false,
}

-- Widget lifecycle functions
function widget:Initialize()

    -- Initialize the widget
    Spring.Echo(WIDGET_NAME .. ": Initializing widget...")
    
    -- Get the shared RML context
    widget.rmlContext = RmlUi.GetContext("shared")
    if not widget.rmlContext then
        Spring.Echo(WIDGET_NAME .. ": ERROR - Failed to get RML context")
        return false
    end

    -- Create and bind the data model
    dm_handle = widget.rmlContext:OpenDataModel(MODEL_NAME, init_model)
    if not dm_handle then
        Spring.Echo(WIDGET_NAME .. ": ERROR - Failed to create data model '" .. MODEL_NAME .. "'")
        return false
    end
    
    -- Set up data model change listeners
    
    Spring.Echo(WIDGET_NAME .. ": Data model created successfully")

    -- Load the RML document
    document = widget.rmlContext:LoadDocument(RML_PATH, widget)
    if not document then
        Spring.Echo(WIDGET_NAME .. ": ERROR - Failed to load document: " .. RML_PATH)
        widget:Shutdown()
        return false
    end

    -- Apply styles and show the document
    document:ReloadStyleSheet()
    document:Show()
    
    Spring.Echo(WIDGET_NAME .. ": Widget initialized successfully")
    
    return true
end

function widget:Shutdown()
    Spring.Echo(WIDGET_NAME .. ": Shutting down widget...")
    
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
    Spring.Echo(WIDGET_NAME .. ": Shutdown complete")
end

-- Development helper function for hot reloading
function widget:Reload(event)
    Spring.Echo(WIDGET_NAME .. ": Reloading widget (event: " .. tostring(event) .. ")")
    widget:Shutdown()
    widget:Initialize()
end

-- Update current time (can be called periodically or in response to events)
function widget:UpdateCurrentTime()
    if dm_handle then
        dm_handle.currentTime = os.date("%H:%M:%S")
        Spring.Echo(WIDGET_NAME .. ": Updated current time to: " .. dm_handle.currentTime)
    end
end

-- Example of how to update the data model from Lua
function widget:UpdateMessage(newMessage)
    if dm_handle then
        dm_handle.message = newMessage
        Spring.Echo(WIDGET_NAME .. ": Message updated to: " .. newMessage)
    end
end

-- Example of adding items to the array
function widget:AddTestItem(name, value)
    if dm_handle and dm_handle.testArray then
        table.insert(dm_handle.testArray, { name = name, value = value })
        Spring.Echo(WIDGET_NAME .. ": Added item: " .. name)
    end
end

-- Toggle RmlUi debugger - simple toggle function
function widget:ToggleDebugger()
    if dm_handle then
        dm_handle.debugMode = not dm_handle.debugMode
        
        if dm_handle.debugMode then
            RmlUi.SetDebugContext('shared')
            Spring.Echo(WIDGET_NAME .. ": RmlUi debugger enabled")
        else
            RmlUi.SetDebugContext(nil)
            Spring.Echo(WIDGET_NAME .. ": RmlUi debugger disabled")
        end
    end
end