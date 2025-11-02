-- RmlWidgets Theme Utils
-- Complete theme management system for RmlUi widgets
-- Handles theme data, validation, and RML context application

-- Make themeUtils global so all widgets share the same instance
if not WG.rml_themeUtils then
    local themeUtils = {}
    WG.rml_themeUtils = themeUtils
    Spring.Echo("themeUtils: Created global WG.rml_themeUtils")
else
    Spring.Echo("themeUtils: Using existing global WG.rml_themeUtils")
end
local themeUtils = WG.rml_themeUtils

-- Core theme data - single source of truth
local themeData = {
    {id = "base", name = "Base"},
    {id = "armada", name = "Armada"},
    {id = "cortex", name = "Cortex"},
    {id = "legion", name = "Legion"}
}

function themeUtils.GetCurrentTheme()
    local theme = Spring.GetConfigString("rml_theme", "base")
    if themeUtils.isValid(theme) then
        return theme
    else
        return "base"
    end
end

-- Get available theme IDs
function themeUtils.getAvailable()
    local themes = {}
    for _, themeInfo in ipairs(themeData) do
        table.insert(themes, themeInfo.id)
    end
    return themes
end

-- Get theme display names for UI components
function themeUtils.getDisplayNames()
    local displayNames = {}
    for _, themeInfo in ipairs(themeData) do
        displayNames[themeInfo.id] = themeInfo.name
    end
    return displayNames
end

-- Check if a theme is valid
function themeUtils.isValid(themeName)
    local available = themeUtils.getAvailable()
    for _, validTheme in ipairs(available) do
        if validTheme == themeName then
            return true
        end
    end
    return false
end

-- Get theme info by ID
function themeUtils.getInfo(themeId)
    for _, themeInfo in ipairs(themeData) do
        if themeInfo.id == themeId then
            return themeInfo
        end
    end
    return nil
end

-- Apply theme to all RML contexts (modern approach)
-- @param themeName: Theme name (base, armada, cortex, legion)
-- @return boolean: Success status
function themeUtils.applyTheme(themeName)
    if not RmlUi then
        return false
    end
    
    themeName = themeName or "base"
    
    -- Get all available themes for deactivation
    local availableThemes = themeUtils.getAvailable()
    
    -- Apply theme to all contexts using context-level theme activation
    local contexts = RmlUi.contexts()
    for _, context in ipairs(contexts) do
        -- First deactivate all other themes
        for _, themeId in ipairs(availableThemes) do
            if themeId ~= themeName then
                context:ActivateTheme(themeId, false)
            end
        end
        
        -- Then activate the target theme
        context:ActivateTheme(themeName, true)
    end
    
    return true
end

-- Validate and apply theme to all contexts
-- @param themeName: Theme name to validate and apply
-- @return boolean: Success status
function themeUtils.setAndApplyTheme(themeName)
    -- Validate theme before applying
    if not themeUtils.isValid(themeName) then
        Spring.Echo("themeUtils: Invalid theme - " .. tostring(themeName))
        return false
    end
    
    -- Set the theme setting and apply it immediately
    Spring.SetConfigString("rml_theme", themeName)
    return themeUtils.applyTheme(themeName)
end

-- Get theme display names for UI components (legacy function for compatibility)
-- @return table: Map of theme keys to display names
function themeUtils.getThemeDisplayNames()
    return themeUtils.getDisplayNames()
end

return themeUtils