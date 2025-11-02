-- RmlWidgets Common Class Groups
-- Utility system for managing reusable CSS class combinations provided in templates via the data-attr-class
-- Should later optimizations be required the first would be to facilitate more precise class group retrieval
-- e.g., commonClassGroups.get("button.success") to get only the success button classes.
-- Currently we do not know the limits or performance applications of frontloading widget models with all class groups.

if not WG.rml_commonClassGroups then
    local commonClassGroups = {}
    WG.rml_commonClassGroups = commonClassGroups
    Spring.Echo("commonClassGroups: Created global WG.rml_commonClassGroups")
else
    Spring.Echo("commonClassGroups: Using existing global WG.rml_commonClassGroups")
end

local commonClassGroups = WG.rml_commonClassGroups

commonClassGroups.prefix = "ccg"

commonClassGroups.definitions = {
    text = {
        success = "text-sm font-bold text-success text-outline-darker-lg",
        warning = "text-sm font-bold text-warning text-outline-darker-lg",
        tooltip = "text-sm font-normal text-light p-2 rounded border bg-darker border-light-alpha",
        body = "text-sm font-normal text-light",
        info = "text-sm font-bold text-info text-outline-darker-lg",
        caption = "text-sm font-normal text-medium",
        emphasis = "text-sm font-semibold text-light text-outline-darker-lg",
        danger = "text-sm font-bold text-danger text-outline-darker-lg",
    },

    themeText = {
        badge = "text-sm font-bold text-darkest pl-2 pr-2 pt-0-5 pb-0-5 rounded bg-gradient_primary-accent",
        pill = "text-sm font-bold text-darkest pl-2 pr-2 pt-0-5 pb-0-5 rounded-full bg-gradient_primary-accent",
        label = "text-sm font-normal text-muted",
        value = "text-base font-bold text-primary",
        caption = "text-sm font-normal text-muted",
        highlight = "text-base font-bold text-surface bg-surface-anti pl-1 pr-1 rounded",
        heading = "text-lg font-bold text-primary text-outline-darkest-lg",
        subheading = "text-base font-bold text-secondary text-outline-darkest",
    },

    badge = {
        primary = "text-sm font-bold text-darkest pl-2 pr-2 pt-0-5 pb-0-5 rounded bg-gradient_primary-accent",
        success = "text-sm font-bold text-success pl-2 pr-2 pt-0-5 pb-0-5 rounded bg-success text-outline-darker-lg",
        warning = "text-sm font-bold text-warning pl-2 pr-2 pt-0-5 pb-0-5 rounded bg-warning text-outline-darker-lg",
        danger = "text-sm font-bold text-danger pl-2 pr-2 pt-0-5 pb-0-5 rounded bg-danger text-outline-darker-lg",
        info = "text-sm font-bold text-info pl-2 pr-2 pt-0-5 pb-0-5 rounded bg-info text-outline-darker-lg",
        construction = "text-sm font-bold text-warning pl-2 pr-2 pt-0-5 pb-0-5 rounded bg-warning hazards-construction text-outline-darkest-lg border border-warning clip",
        ghost = "text-sm font-bold text-light pl-2 pr-2 pt-0-5 pb-0-5 rounded border border-light-alpha bg-darkest-alpha",
        surface = "text-sm font-bold text-surface-anti pl-2 pr-2 pt-0-5 pb-0-5 rounded bg-surface",
        general = "text-sm font-bold text-medium pl-2 pr-2 pt-0-5 pb-0-5 rounded bg-gradient bg-light text-outline-darkest-lg",
    },

    pill = {
        primary = "text-sm font-bold text-darkest pl-2 pr-2 pt-0-5 pb-0-5 rounded-full bg-gradient_primary-accent",
        success = "text-sm font-bold text-success pl-2 pr-2 pt-0-5 pb-0-5 rounded-full bg-success text-outline-darker-lg",
        warning = "text-sm font-bold text-warning pl-2 pr-2 pt-0-5 pb-0-5 rounded-full bg-warning text-outline-darker-lg",
        danger = "text-sm font-bold text-danger pl-2 pr-2 pt-0-5 pb-0-5 rounded-full bg-danger text-outline-darker-lg",
        info = "text-sm font-bold text-info pl-2 pr-2 pt-0-5 pb-0-5 rounded-full bg-info text-outline-darker-lg",
        construction = "text-sm font-bold text-warning pl-2 pr-2 pt-0-5 pb-0-5 rounded-full bg-warning hazards-construction text-outline-darkest-lg border border-warning clip",
        ghost = "text-sm font-bold text-light pl-2 pr-2 pt-0-5 pb-0-5 rounded-full border border-light-alpha bg-darkest-alpha",
        surface = "text-sm font-bold text-surface-anti pl-2 pr-2 pt-0-5 pb-0-5 rounded-full bg-surface",
        general = "text-sm font-bold text-medium pl-2 pr-2 pt-0-5 pb-0-5 rounded-full bg-gradient bg-light text-outline-darkest-lg",
    },

    circle = {
        general = "text-xs font-bold text-darkest w-4 h-4 rounded-full radial-focus-start-feint flex items-center justify-center",
        primary = "text-xs font-bold text-darkest w-4 h-4 rounded-full bg-gradient_primary-accent flex items-center justify-center",
        success = "text-xs font-bold text-success w-4 h-4 rounded-full bg-success text-outline-darker-lg flex items-center justify-center",
        warning = "text-xs font-bold text-warning w-4 h-4 rounded-full bg-warning text-outline-darker-lg flex items-center justify-center",
        danger = "text-xs font-bold text-danger w-4 h-4 rounded-full bg-danger text-outline-darker-lg flex items-center justify-center",
        info = "text-xs font-bold text-info w-4 h-4 rounded-full bg-info text-outline-darker-lg flex items-center justify-center",
        ghost = "text-xs font-bold text-light w-4 h-4 rounded-full bg-darkest-alpha flex items-center justify-center",
        surface = "text-xs font-bold text-surface-anti w-4 h-4 rounded-full bg-surface flex items-center justify-center",
    },

    container = {
        text = {
            main = "max-w-3xl mx-auto text-base leading-relaxed",
            header = "max-w-3xl mx-auto text-center mb-6",
            footer = "max-w-3xl mx-auto text-center mt-6 mb-6"
        },
    },

    heading = {
        h1 = "text-4xl font-extrabold mt-4 mb-2 text-outline-darker-lg",
        h2 = "text-3xl font-bold mt-3 mb-2 text-outline-darker-lg",
        h3 = "text-2xl font-bold mt-3 mb-1 text-outline-darker-lg",
        h4 = "text-xl font-bold mt-2 mb-1 text-outline-darker-lg",
        h5 = "text-lg font-bold mt-2 mb-1",
        h6 = "text-base font-bold mt-1 mb-1",
        title = "text-lg font-bold text-primary text-shadow",
        subtitle = "text-base font-normal text-secondary",
        section = "text-xl font-bold text-primary mt-6 mb-3",
    },

    button = {
        general = "text-center text-light bg-darkest bg-gradient-darkest hover-brighten cursor-pointer",
        success = "text-center text-success text-outline-darker-lg bg-success radial-focus-center-feint hover-brighten cursor-pointer",
        warning = "text-center text-warning text-outline-darker-lg bg-warning radial-focus-center-feint hover-brighten cursor-pointer",
        danger = "text-center text-danger text-outline-darker-lg bg-danger radial-focus-center-feint hover-brighten cursor-pointer",
        ghost = "text-center text-light font-bold bg-darkest-alpha border border-light-alpha hover-fade cursor-pointer",
    },
    
    themeButton = {
        primary = "text-center text-darkest font-bold bg-gradient_primary-accent hover-brighten cursor-pointer",
        ghost = "text-center text-primary font-bold border-2 border border-primary-alpha bg-primary-hover-alpha cursor-pointer",
        surface = "text-center text-surface-anti font-bold bg-surface border border-surface-alpha hover-brighten cursor-pointer",
        secondary = "text-center text-primary-dark bg-gradient_primary-alpha font-bold hover-brighten cursor-pointer bg-secondary",
    },

    nav = {
        container = "flex bg-dark-alpha min-h-8 box-shadow-md z-10",
    },

    panel = {
        general = "gap-6 p-4 rounded border-sm border-darker-alpha box-shadow-sm bg-darker-alpha radial-focus-start-feint",
        primary = "bg-primary-alpha shadow-md rounded border-primary-dark border hazards-135 text-shadow",
        construction = "bg-warning shadow-lg rounded border-warning border-2 hazards-construction-textured text-outline-darkest-lg border border-warning-alpha",
        danger = "bg-danger-alpha shadow-md rounded border-danger border hazards-225 text-shadow",
        info = "bg-info-alpha shadow-md rounded border-darker-alpha border text-shadow radial-focus-start-feint",
        success = "bg-success-alpha shadow-md rounded border-success border radial-focus-start-feint text-shadow",
        warning = "bg-warning-alpha shadow-md rounded border-warning border radial-focus-start-feint text-shadow",
    },

    sheet = {
        general = {
            container = "hazards-135 bg-darkest",
            title = "text-2xl font-bold bg-darkest-semi-alpha p-3 bg-gradient-darker-alpha radial-focus-start text-outline-darkest-lg border-bottom border-darkest",
            content = "p-4",
            footer = "p-3 bg-darkest-alpha border-top border-darkest",
        },
        primary = {
            container = "radial-focus-start box-shadow-md hazards-225",
            title = "text-2xl font-bold bg-primary-semi-alpha p-3 bg-gradient_primary-alpha text-outline-darkest-lg",
            content = "p-4",
            footer = "p-3 bg-primary-alpha",
        },
        construction = {
            container = "border border-darkest-alpha clip",
            title = "hazards-construction-textured text-xl font-bold bg-warning p-3 text-outline-darkest-lg border-bottom border-warning-alpha flex items-center justify-between",
            content = "p-4",
            footer = "p-3 bg-darker text-warning text-outline-darkest",
        },
        modal = {
            container = "hazards-135 bg-darkest rounded-lg border border-dark clip box-shadow-md",
            title = "text-xl font-bold bg-darkest-semi-alpha p-3 bg-gradient-darker-alpha text-outline-darkest-lg border-bottom border-darkest",
            content = "p-4",
            footer = "p-3 bg-darkest-alpha border-top border-darkest rounded-b-lg",
        },
        surface = {
            container = "rounded-lg border border-surface-alpha shadow-lg clip box-shadow-md radial-focus-center-feint",
            title = "text-xl font-bold bg-surface-semi-alpha p-3 bg-gradient_surface-textured text-outline-darkest-lg",
            content = "p-4",
            footer = "p-3 bg-surface-alpha rounded-b-lg",
        },
    },

    card = {
        general = "bg-darker-alpha p-2 box-shadow-sm",
        primary = "bg-primary p-2 box-shadow-sm",
        primaryAlpha = "bg-primary-alpha p-4 box-shadow-sm",
        light = "bg-light p-2 box-shadow-sm",
        lightAlpha = "bg-light-alpha p-2 box-shadow-sm bg-gradient",
        dark = "bg-dark p-2 box-shadow-sm",
        accent = "bg-accent p-2 box-shadow-sm", 
        accentAlpha = "bg-accent-alpha p-2 box-shadow-sm",
        surface = "bg-surface-anti bg-gradient_surface-textured p-2 box-shadow-md cursor-pointer",
        ghost = "bg-transparent border border-primary-alpha p-2 hover-fade",
        glass = "bg-darker bg-gradient_glass border border-primary-alpha p-2 box-shadow-lg",
    },
}

-- Get class string for a component
function commonClassGroups.get(componentName)
    if not commonClassGroups.definitions[componentName] then
        Spring.Echo("Warning: Class group '" .. componentName .. "' not found")
        return ""
    end
    
    return commonClassGroups.definitions[componentName]
end

-- Check if a class group exists
function commonClassGroups.exists(componentName)
    return commonClassGroups.definitions[componentName] ~= nil
end

-- Get all class groups for RML data model
function commonClassGroups.getForModel()
    local result = {}
    for componentName, classes in pairs(commonClassGroups.definitions) do
        result[componentName] = classes
    end
    return result
end

-- Get specific class groups for RML data model
function commonClassGroups.getSpecificForModel(componentNames)
    local result = {}
    for _, componentName in ipairs(componentNames) do
        if commonClassGroups.definitions[componentName] then
            result[componentName] = commonClassGroups.definitions[componentName]
        else
            Spring.Echo("Warning: Class group '" .. componentName .. "' not found")
        end
    end
    return result
end

-- List all available class groups
function commonClassGroups.list()
    local groups = {}
    for componentName, _ in pairs(commonClassGroups.definitions) do
        table.insert(groups, componentName)
    end
    table.sort(groups)
    return groups
end

-- Debug: Print all class groups
function commonClassGroups.debug()
    Spring.Echo("=== Class Groups ===")
    local groups = commonClassGroups.list()
    if #groups == 0 then
        Spring.Echo("No class groups defined")
        return
    end
    
    for _, componentName in ipairs(groups) do
        Spring.Echo(componentName .. " = " .. commonClassGroups.definitions[componentName])
    end
    Spring.Echo("Total: " .. #groups .. " class groups")
end

return commonClassGroups