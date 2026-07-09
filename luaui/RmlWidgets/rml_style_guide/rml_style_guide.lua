if not RmlUi then
    return
end

local widget = widget ---@type Widget
local utils = VFS.Include("luaui/Include/rml_utilities/utils.lua")
local ccg = VFS.Include("luaui/Include/rml_utilities/common_class_groups.lua")
local themeUtils = VFS.Include("luaui/Include/rml_utilities/theme_utils.lua")
local svgShapes = VFS.Include("luaui/Include/rml_utilities/svg_shapes.lua")

local activeTooltipText = nil  -- drives per-frame tooltip for copy buttons

function widget:GetInfo()
    return {
        name = "rml_style_guide",
        desc = "RML Style Guide showcasing common RmlUi class groups and styles available in BAR.",
        author = "Mupersega",
        date = "2025",
        license = "GNU GPL, v2 or later",
        layer = -10000,
        enabled = false,
    }
end

-- Helper function to convert class group tables to iterable arrays
local function createIterableArray(ccgTable, prefix, shouldSort)
    local result = {}
    for key, value in pairs(ccgTable or {}) do
        table.insert(result, {
            name = key,
            class = prefix .. "." .. key,
            styles = value
        })
    end
    
    -- Sort alphabetically by name if requested
    if shouldSort then
        table.sort(result, function(a, b)
            return a.name < b.name
        end)
    end
    
    return result
end

-- Helper function for text styles with examples and descriptions (excludes badges and pills)
local function createTextArray(ccgTable, prefix)
    local textExamples = {
        -- text group (fixed colors)
        label = { example = "Health Points:", description = "Form labels and captions" },
        value = { example = "1,250", description = "Stats, scores, and important values" },
        caption = { example = "Last updated 2 mins ago", description = "Fine print and metadata" },
        error = { example = "Connection Failed", description = "Error messages and alerts" },
        success = { example = "Mission Complete", description = "Success confirmations" },
        warning = { example = "Low Resources", description = "Warning messages" },
        tooltip = { example = "Press ESC to cancel", description = "Tooltip and help text" },
        body = { example = "This is body text for paragraphs and content.", description = "Regular paragraph text" },
        emphasis = { example = "Important notice", description = "Highlighted important text" },
        info = { example = "Information notice", description = "Informational text" },
        danger = { example = "Critical error", description = "Critical error messages" },
        
        -- themeText group (theme colors) - excluding badge and pill
        highlight = { example = "SELECTED", description = "Emphasized text with background" },
        heading = { example = "Section Title", description = "Heading text without margins" },
        subheading = { example = "Subsection", description = "Subheading text without margins" },
    }
    
    local result = {}
    for key, value in pairs(ccgTable or {}) do
        -- Skip badge and pill components - they belong in components section
        if key ~= "badge" and key ~= "pill" then
            local exampleData = textExamples[key] or { example = key, description = "Text style" }
            table.insert(result, {
                name = key,
                class = prefix .. "." .. key,
                styles = value,
                example = exampleData.example,
                description = exampleData.description
            })
        end
    end
    return result
end

-- Helper function for component styles (badges and pills)
local function createComponentArray(ccgTable, prefix, componentType)
    local componentExamples = {
        -- Badge examples (rectangular)
        general = { example = "NEW", description = "General themed badge style" },
        primary = { example = "ACTIVE", description = "Primary themed badge" },
        success = { example = "ONLINE", description = "Success state indicator" },
        warning = { example = "ALERT", description = "Warning state indicator" },
        danger = { example = "ERROR", description = "Error state indicator" },
        info = { example = "INFO", description = "Information state indicator" },
        construction = { example = "BUILD", description = "Construction/industrial themed badge with hazard pattern" },
        ghost = { example = "DRAFT", description = "Subtle ghost badge with border" },
        surface = { example = "THEME", description = "Surface themed badge" },
        
        -- Legacy themeText badge/pill (keep for backwards compatibility)
        badge = { example = "NEW", description = "Legacy themed badge from themeText group" },
        pill = { example = "ACTIVE", description = "Legacy themed pill from themeText group" },
    }
    
    -- Circles have different example content
    if componentType == "Circle" then
        componentExamples = {
            general = { example = "1", description = "General dark themed circular indicator with gradient" },
            primary = { example = "2", description = "Primary themed circular indicator" },
            success = { example = "S", description = "Success state circular indicator" },
            warning = { example = "!", description = "Warning state circular indicator" },
            danger = { example = "X", description = "Error state circular indicator" },
            info = { example = "i", description = "Information state circular indicator" },
            construction = { example = "C", description = "Construction/industrial themed circle with hazard pattern" },
            ghost = { example = "?", description = "Subtle ghost circle with border" },
            surface = { example = "T", description = "Surface themed circular indicator" },
        }
    end
    
    local result = {}
    for key, value in pairs(ccgTable or {}) do
        local exampleData = componentExamples[key] or { example = key:upper(), description = componentType .. " variant" }
        table.insert(result, {
            name = key,
            class = prefix .. "." .. key,
            styles = value,
            example = exampleData.example,
            description = exampleData.description
        })
    end
    
    -- Sort alphabetically by name
    table.sort(result, function(a, b)
        return a.name < b.name
    end)
    
    return result
end

-- Constants
local WIDGET_ID = "rml_style_guide"
local MODEL_NAME = "rml_style_guide_model"
local RML_PATH = "luaui/RmlWidgets/rml_style_guide/rml_style_guide.rml"

-- Widget state
local document
local dm_handle
-- Create a fresh model table for each init
local function initModel()
    return {
        message = "Hello from rml_style_guide!",
        expanded = true,

        -- No widget: methods — model fns via data-event-* (see CLAUDE.md
        -- "The model is king"). The bound element is ev.current_element.
        copyToClipboard = function(ev)
            local element = ev and ev.current_element
            if not element then return end
            local tt = element:QuerySelector(".tooltip")
            local text = tt and tt.inner_rml or ""
            if text == "" then return end
            Spring.SetClipboard(widget:ParseToRml(text))
        end,
        tabs = {
            { id = "about", label = "About" },
            { id = "buttons", label = "Buttons" },
            { id = "text", label = "Text" },
            { id = "tags", label = "Tags" },
            { id = "cards", label = "Cards" },
            { id = "headings", label = "Headings" },
            { id = "panels", label = "Panels" },
            { id = "decorators", label = "Decorators" },
            { id = "playPanel", label = "Play Panel" },
        },
    
        activeTab = "about", -- Start on the about tab
    
        -- Custom Class Groups
        my = {
            groupCard = {
                container = "flex flex-col flex-3 h-full border-left border-primary-dark-alpha pl-4 space-between",
                title = ccg.definitions.themeText.subheading .. " flex-1",
                description = ccg.definitions.text.body .. " text-sm flex-1",
                classInfo = ccg.definitions.themeText.caption .. " flex-1",
            },
            compositeGroupInfoCard = {
                container = "flex flex-col gap-1 rounded flex-1",
                title = "flex flex-row items-center",
                copybutton = "p-0-5 flex gap-2 items-center w-4 h-4 justify-center",
                classInfo = ccg.definitions.themeText.caption .. " flex-1",
            },
            copySvgStyles = "h-2-5 w-2-5 mx-1 mt-0-5",
        },
    
        showCopyTooltip = function(event, className, name)
            activeTooltipText = '&lt;button data-attr-class=&quot;' .. className .. '&quot;&gt;' .. name .. '&lt;/button&gt;'
        end,

        hideCopyTooltip = function(event)
            activeTooltipText = nil
        end,

        -- Theme management
        currentTheme = "", -- set in init
        availableThemes = {
            { id = "base", name = "Base" },
            { id = "armada", name = "Armada" },
            { id = "cortex", name = "Cortex" },
            { id = "legion", name = "Legion" },
        },
        
        -- Create iterable arrays from class groups
        buttons = createIterableArray(ccg.definitions.button, ccg.prefix .. ".button"),
        themeButtons = createIterableArray(ccg.definitions.themeButton, ccg.prefix .. ".themeButton"),
        textStyles = createTextArray(ccg.definitions.text, ccg.prefix .. ".text"),
        themeTextStyles = createTextArray(ccg.definitions.themeText, ccg.prefix .. ".themeText"),
        badges = createComponentArray(ccg.definitions.badge, ccg.prefix .. ".badge", "Badge"),
        cards = createIterableArray(ccg.definitions.card, ccg.prefix .. ".card"),
        headings = createIterableArray(ccg.definitions.heading, ccg.prefix .. ".heading", true),
        panels = createIterableArray(ccg.buildPanels(ccg.readCurrentOptions()), ccg.prefix .. ".panel", true),
    
        -- Theme switching function for the data model
        switchTheme = function(event, themeId)
            if themeUtils.isValid(themeId) then
                -- Do exactly what gui_options.lua does - it should aim to be the source of truth
                Spring.SetConfigString("rml_theme", themeId)
                
                -- Apply theme to all RML widgets that have the theme API
                if WG.rml_theme_changed then
                    WG.rml_theme_changed(themeId)
                end
                
                -- Update our own current theme display
                dm_handle.currentTheme = themeId

            else
                Spring.Echo(WIDGET_ID .. ": Invalid theme: " .. tostring(themeId))
            end
        end,
    
        -- ordinarily an expanded and collapsed state should be handled by the model,
        -- but in this instance the whole widget gets collapsed and has no access to model properties,
        -- so we target it directly.
        toggleExpand = function()
            dm_handle.expanded = not dm_handle.expanded

            if document then
                if dm_handle.expanded then
                    document:SetClass("collapsed", false)
                else
                    document:SetClass("collapsed", true)
                end
            end
        end
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

    if dm_handle then
        dm_handle.currentTheme = themeUtils.GetCurrentTheme()
    end

    dm_handle.toggleExpand() -- start expanded true and toggle it closed on init to start collapsed

    self:InitShapes()

    return true
end

function widget:InitShapes()
    if not document then return end

    local notchedCornerBase = {
        sizeX = 45, sizeY = 30,
        fill = "rgb(38, 38, 42)",
    }

    local corners = { "bl", "br", "tl", "tr" }
    for _, corner in ipairs(corners) do
        local el = document:GetElementById("dec-notched-corner-" .. corner)
        if el then
            local opts = {}
            for k, v in pairs(notchedCornerBase) do opts[k] = v end
            opts.corner = corner
            pcall(function() el:SetAttribute("src", svgShapes.notchedCorner(opts)) end)
        end
    end

    local shapeBase = {
        fill = "rgb(38, 38, 42)",
    }

    for _, presetName in ipairs(svgShapes.intensityOrder) do
        for _, side in ipairs({ "l", "r" }) do
            local el = document:GetElementById("dec-taper-" .. side .. "-" .. presetName)
            if el then
                local opts = {}
                for k, val in pairs(shapeBase) do opts[k] = val end
                opts.depth = presetName
                opts.side = side == "l" and "left" or "right"
                pcall(function() el:SetAttribute("src", svgShapes.taper(opts)) end)
            end
        end

        local chevronEl = document:GetElementById("dec-chevron-" .. presetName)
        if chevronEl then
            local opts = {}
            for k, val in pairs(shapeBase) do opts[k] = val end
            opts.depth = presetName
            pcall(function() chevronEl:SetAttribute("src", svgShapes.chevron(opts)) end)
        end
    end
end

function widget:Shutdown()

    local shutdownParams = {
        widgetId = WIDGET_ID,
        modelName = MODEL_NAME
    }

    utils.shutdownRmlWidget(self, shutdownParams, document, dm_handle)

    -- Clear references
    document = nil
    dm_handle = nil

    Spring.Echo(WIDGET_ID .. ": Shutdown complete")
end

function widget:Update()
    -- Drive tooltip per-frame for copy button hovers
    if activeTooltipText and WG['rml_tooltip'] then
        local mx, my = Spring.GetMouseState()
        WG['rml_tooltip'].Show(activeTooltipText, mx, my)
    elseif not activeTooltipText and WG['rml_tooltip'] then
        WG['rml_tooltip'].Hide()
    end
end

-- Internal text helper (not RML-wired). Used by the copyToClipboard
-- model fn. Kept as a widget: method only because it's a plain helper,
-- not an inline-handler control path.
function widget:ParseToRml(escapedtring)
    -- parse something like this back to usable rml  &lt;button data-attr-class=&quot;cg.button.danger&quot;&gt;danger&lt;/button&gt; -- just replace things like &lt;
    local rmlString = escapedtring
    rmlString = rmlString:gsub("&lt;", "<")
    rmlString = rmlString:gsub("&gt;", ">")
    rmlString = rmlString:gsub("&quot;", "\"")
    rmlString = rmlString:gsub("&amp;", "&")
    return rmlString
end
