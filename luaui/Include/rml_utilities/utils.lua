-- RmlWidgets Utils
-- Common utility functions for RmlUi widgets

-- This is to ensure common class groups are loaded and providing this in the context manage is too early.
local ccg = VFS.Include("luaui/Include/rml_utilities/common_class_groups.lua")

-- Make utils global so all widgets share the same instance
if not WG.rml_utils then
    local utils = {}
    WG.rml_utils = utils
    Spring.Echo("utils: Created global WG.rml_utils")
else
    Spring.Echo("utils: Using existing global WG.rml_utils")
end
local utils = WG.rml_utils

-- Helper to combine multiple class strings
function utils.combineClasses(...)
    local args = {...}
    local result = {}
    
    for _, classStr in ipairs(args) do
        if classStr and classStr ~= "" then
            table.insert(result, classStr)
        end
    end
    
    return table.concat(result, " ")
end



-- RML Widget initialization helper
function utils.initializeRmlWidget(widget, initParams)
    -- Validate required parameters
    if not initParams.widgetId then
        return false
    end
    if not initParams.modelName then
        return false
    end
    if not initParams.rmlPath then
        return false
    end
    if not initParams.initModel then
        return false
    end

    local widgetId = initParams.widgetId
    
    -- Get the shared RML context
    widget.rmlContext = RmlUi.GetContext("shared")
    if not widget.rmlContext then
        return false
    end

    if initParams.useCommonClassGroups then
        -- Ensure class groups are available
        if not WG.rml_commonClassGroups then
            Spring.Echo(widgetId .. ": Error - WG.rml_commonClassGroups not found")
            return false
        end
        
        -- Add shared class groups to the init model
        initParams.initModel[ccg.prefix] = {}
        for key, value in pairs(ccg.getForModel()) do
            initParams.initModel[ccg.prefix][key] = value
        end
    end

    -- Create and bind the data model
    local dm_handle = widget.rmlContext:OpenDataModel(initParams.modelName, initParams.initModel)
    if not dm_handle then
        return false
    end

    -- Load the RML document
    local document = widget.rmlContext:LoadDocument(initParams.rmlPath, widget)
    if not document then
        widget.rmlContext:RemoveDataModel(initParams.modelName)
        return false
    end

    -- Apply styles and show the document
    document:ReloadStyleSheet()
    document:Show()
    
    -- Return the created objects for the widget to store
    return {
        document = document,
        dm_handle = dm_handle
    }
end

-- RML Widget shutdown helper
function utils.shutdownRmlWidget(widget, shutdownParams, document, dm_handle)
    local widgetId = shutdownParams.widgetId
    Spring.Echo(widgetId .. ": Shutting down widget...")
    
    -- Clean up data model
    if not widget.rmlContext then
        Spring.Echo(widgetId .. ": Warning: No RML context found during shutdown")
        return
    end
    local removed = widget.rmlContext:RemoveDataModel(shutdownParams.modelName)
    if removed then
        Spring.Echo(widgetId .. ": Data model '" .. shutdownParams.modelName .. "' removed successfully")
    else
        Spring.Echo(widgetId .. ": Warning: Data model '" .. shutdownParams.modelName .. "' could not be removed or did not exist")
    end
    -- if widget.rmlContext and dm_handle then
    -- end
    
    -- Close document
    if document then
        document:Close()
    end
    
    widget.rmlContext = nil
    Spring.Echo(widgetId .. ": Shutdown complete")
end

-- Theme management utilities

-- Helper to get the current data model handle used primarily in init model functions to avoid reassignment after initialization.
function utils.GetCurrentModel(dm_handle)
    return dm_handle
end

return utils