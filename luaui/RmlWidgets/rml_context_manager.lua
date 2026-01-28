
if not RmlUi then
    return
end

local widget = widget ---@type Widget

function widget:GetInfo()
    return {
        name = "Rml context manager",
        desc = "This widget is responsible for handling interactions with RmlUi contexts, and is essential for the smooth functioning of Rml widgets.",
        author = "Mupersega",
        date = "2025",
        license = "GNU GPL, v2 or later",
        layer = -100000,
        enabled = true
    }
end

local function calculateDpRatio()
    local viewSizeY = Spring.GetViewGeometry()
    local userScale = Spring.GetConfigFloat("ui_scale", 1)
    local baseHeight = 1080
    local resFactor = viewSizeY / baseHeight
    local dpRatio = resFactor * userScale
    return math.floor(dpRatio * 100) / 100
end

local function updateContextsDpRatio()
    local newDpRatio = calculateDpRatio()
    local contexts = RmlUi.contexts()
    for _, context in ipairs(contexts) do
        context.dp_ratio = newDpRatio
    end
end

local function getAllDocuments(contextName)
    local docs = {}
    local context = RmlUi.GetContext(contextName)
    if context then
        for _, doc in ipairs(context.documents) do
            table.insert(docs, doc)
        end
    end
    return docs
end

local function hideContextDocuments(contextName)
    local docs = getAllDocuments(contextName)
    for _, doc in ipairs(docs) do
        doc:Hide()
    end
end

local function showContextDocuments(contextName)
    local docs = getAllDocuments(contextName)
    for _, doc in ipairs(docs) do
        doc:Show()
    end
end

function widget:Initialize()
    if not RmlUi.GetContext("shared") then
        RmlUi.CreateContext("shared")
    end

    updateContextsDpRatio()
    
    -- Get and apply initial theme
    local themeUtils = VFS.Include("luaui/Include/rml_utilities/theme_utils.lua")

    local initialTheme = themeUtils.GetCurrentTheme()
    Spring.Echo("RML Context Manager: Initialize - Initial theme: " .. tostring(initialTheme))
    self:SetTheme(initialTheme)
    
    -- Register the global theme change handler that gui_options calls
    WG.rml_theme_changed = function(newTheme)
        Spring.Echo("RML Context Manager: Theme changed via WG to: " .. tostring(newTheme))
        self:SetTheme(newTheme)
    end

    -- TODO: add listener for ui_scale changes to update dp_ratio also when that changes
    
    Spring.Echo("RML Context Manager: Registered WG.rml_theme_changed")
end

function widget:ViewResize()
    updateContextsDpRatio()
end

function widget:SetTheme(value)
    Spring.Echo("RML Context Manager: SetTheme called with theme: " .. tostring(value))
    local contexts = RmlUi.contexts()
    Spring.Echo("RML Context Manager: Found " .. #contexts .. " contexts")
    
    -- Available themes to deactivate  - this could later be deduced from palettes in ./RmlWidgets/palettes
    local allThemes = { "base", "armada", "cortex", "legion" }
    
    for i, context in ipairs(contexts) do
        -- First deactivate all other themes
        for _, themeName in ipairs(allThemes) do
            if themeName ~= value then
                Spring.Echo("RML Context Manager: Deactivating theme '" .. themeName .. "' from context " .. i)
                context:ActivateTheme(themeName, false)
            end
        end
        
        -- Then activate the desired theme
        Spring.Echo("RML Context Manager: Activating theme '" .. tostring(value) .. "' on context " .. i)
        context:ActivateTheme(value, true)
    end
    Spring.Echo("RML Context Manager: Theme application complete")
end

-- This handles showing/hiding Rml documents when the lobby overlay is active/inactive
function widget:RecvLuaMsg(msg, playerID)
    if msg:sub(1, 19) == 'LobbyOverlayActive0' then
        showContextDocuments("shared")
    elseif msg:sub(1, 19) == 'LobbyOverlayActive1' then
        hideContextDocuments("shared")
    end
end

function widget:Shutdown()
    -- Clean up the global theme change handler
    WG.rml_theme_changed = nil
    Spring.Echo("Rml Context Manager shutdown, dynamic context dp ratio updates to contexts disabled." )
end
