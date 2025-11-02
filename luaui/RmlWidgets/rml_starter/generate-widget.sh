#!/bin/bash

# RML Widget Generator Script
# Usage: ./generate-widget.sh --name widget_name

# Default values
WIDGET_NAME=""

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --name)
            WIDGET_NAME="$2"
            shift 2
            ;;
        -h|--help)
            echo "RML Widget Generator"
            echo ""
            echo "Usage: $0 --name widget_name"
            echo ""
            echo "Required:"
            echo "  --name NAME        Widget name (alphanumeric and underscores only)"
            echo ""
            echo "Options:"
            echo "  -h, --help         Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0 --name my_widget"
            echo "  $0 --name build_menu"
            echo "  $0 --name unit_stats"
            echo ""
            echo "Generated widgets use standard size (300x400) and position (top-left)."
            echo "Customize size and position in the generated .rcss file as needed."
            exit 0
            ;;
        *)
            # Support legacy positional argument for backward compatibility
            if [[ -z "$WIDGET_NAME" ]]; then
                WIDGET_NAME="$1"
                shift
            else
                echo "Unknown argument: $1"
                exit 1
            fi
            ;;
    esac
done

# Validate widget name
if [[ -z "$WIDGET_NAME" ]]; then
    echo "Error: Widget name is required!"
    echo "Usage: $0 --name widget_name"
    echo "Use --help for more information"
    exit 1
fi

# Validate widget name format
if [[ ! "$WIDGET_NAME" =~ ^[a-zA-Z][a-zA-Z0-9_-]*$ ]]; then
    echo "Error: Widget name must start with a letter and contain only letters, numbers, underscores, and hyphens"
    exit 1
fi

WIDGET_DIR="../${WIDGET_NAME}"

# Check if widget directory already exists
if [ -d "$WIDGET_DIR" ]; then
    echo "Error: Widget directory '$WIDGET_DIR' already exists!"
    exit 1
fi

echo "Generating RML widget: $WIDGET_NAME"
echo "Creating directory: $WIDGET_DIR"

# Create widget directory
mkdir "$WIDGET_DIR"

# Generate the Lua file
cat > "$WIDGET_DIR/${WIDGET_NAME}.lua" << 'EOF'
if not RmlUi then
    return
end

local widget = widget ---@type Widget
local utils = VFS.Include("luaui/Include/rml_utilities/utils.lua")
local ccg = VFS.Include("luaui/Include/rml_utilities/common_class_groups.lua") -- already in model but useful here too for custom class groups

function widget:GetInfo()
    return {
        name = "WIDGET_NAME_PLACEHOLDER",
        desc = "Generated RML widget template",
        author = "Generated from rml_starter/generate-widget.sh",
        date = "2025",
        license = "GNU GPL, v2 or later",
        layer = -10000,
        enabled = false,
    }
end

-- Constants
local WIDGET_ID = "WIDGET_NAME_PLACEHOLDER"
local MODEL_NAME = "WIDGET_NAME_PLACEHOLDER_model"
local RML_PATH = "luaui/RmlWidgets/WIDGET_NAME_PLACEHOLDER/WIDGET_NAME_PLACEHOLDER.rml"

-- Widget state
local document
local dm_handle

-- Create a new data model every time to avoid reference oddities even with dm_handle
local function initModel()
    return {
        message = "Hello from WIDGET_NAME_PLACEHOLDER!",
        currentTime = os.date("%H:%M:%S"),
        debugMode = false,
        status = "Ready",
        
        -- Custom class groups for this widget (add your own here)
        my = {
            -- Example: custom button style
            -- customButton = ccg.definitions.button.default .. " custom-additions"
        },
        
        handleConfirm = function()
            local model = utils.GetCurrentModel(dm_handle)
            if model then
                model.status = "Confirmed"
                model.message = "Action confirmed!"
                Spring.Echo(WIDGET_ID .. ": User confirmed action")
            end
        end,
        
        handleCancel = function()
            local model = utils.GetCurrentModel(dm_handle)
            if model then
                model.status = "Cancelled"
                model.message = "Action cancelled"
                Spring.Echo(WIDGET_ID .. ": User cancelled action")
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
    
    Spring.Echo(WIDGET_ID .. ": Widget initialized successfully")
    return true
end

function widget:Shutdown()
    Spring.Echo(WIDGET_ID .. ": Shutting down widget...")
    
    -- Use the modern utility function to shutdown
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
    if dm_handle then
        dm_handle.currentTime = os.date("%H:%M:%S")
    end
end

-- Widget functions callable from RML
function widget:Reload()
    Spring.Echo(WIDGET_ID .. ": Reloading widget...")
    widget:Shutdown()
    widget:Initialize()
end

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
EOF

# Generate the RML file
cat > "$WIDGET_DIR/${WIDGET_NAME}.rml" << 'EOF'
<rml>
<head>
    <title>WIDGET_NAME_PLACEHOLDER Widget</title>

    <!-- External stylesheets - order matters for cascading -->
    <link rel="stylesheet" href="../styles.rcss" type="text/rcss" />
    <link rel="stylesheet" href="../rml-utility-classes.rcss" type="text/rcss" />
    <link rel="stylesheet" href="../palette-standard-global.rcss" type="text/rcss" />
    <link rel="stylesheet" href="../themes/theme-base.rcss" type="text/rcss" />
    <link rel="stylesheet" href="../themes/theme-armada.rcss" type="text/rcss" />
    <link rel="stylesheet" href="../themes/theme-cortex.rcss" type="text/rcss" />
    <link rel="stylesheet" href="../themes/theme-legion.rcss" type="text/rcss" />

    <link rel="stylesheet" href="WIDGET_NAME_PLACEHOLDER.rcss" type="text/rcss" />
</head>
<body id="WIDGET_NAME_PLACEHOLDER-widget" class="widget-shadow rounded-lg">
    <div id="widget-container" data-model="WIDGET_NAME_PLACEHOLDER_model" data-attr-class="ccg.sheet.general.container + ' flex flex-col h-full justify-between'">
        <!-- Small floating debug buttons -->
        <div class="debug-controls absolute top right pr-2 pt-2">
            <button data-attr-class="ccg.text.warning + ' px-1 debug-btn'" onclick="widget:Reload()" title="Reload Widget">
                <span>reload</span> 
            </button>
            <button data-attr-class="ccg.text.warning + ' px-1 debug-btn'" onclick="widget:ToggleDebugger()" title="Toggle Debugger">
                <span>debug</span>
            </button>
        </div>
        <div data-attr-class="ccg.sheet.general.title + ' flex flex-col justify-between items-center relative min-h-8'">
            <span>
                WIDGET_NAME_PLACEHOLDER
            </span>
        </div>

        <div data-attr-class="ccg.sheet.general.content">
            <h1 data-attr-class="ccg.heading.h4">{{message}}</h1>
            
            <div class="flex flex-col gap-4">
                <p data-attr-class="ccg.text.body">This is a generated RML widget template using modern patterns.</p>
                
                
                <!-- Example with basic state -->
                <div class="flex flex-col gap-3">
                    <p data-attr-class="ccg.text.body">Status: <span data-attr-class="ccg.text.body">{{status}}</span></p>
                </div>
                
                
                <p data-attr-class="ccg.text.caption">Time: {{currentTime}}</p>
            </div>
        </div>
        <div data-attr-class="ccg.panel.info + ' p-3 m-3'">
            <p data-attr-class="ccg.text.warning">Remember!</p>
            <p data-attr-class="ccg.text.body">Enable the <strong>rml_style_guide</strong> widget to explore all available styling components. Press F11 and search "style guide"</p>
        </div>
        
        <div data-attr-class="ccg.sheet.general.footer">            
            <div class="flex flex-row justify-end gap-2">
                <button data-attr-class="ccg.button.danger + ' px-2 py-1'" data-event-click="handleCancel()">cancel</button>
                <button data-attr-class="ccg.button.success + ' px-2 py-1'" data-event-click="handleConfirm()">confirm</button>
            </div>
        </div>
    </div>
</body>
</rml>
EOF

# Generate the RCSS file
cat > "$WIDGET_DIR/${WIDGET_NAME}.rcss" << EOF
/* WIDGET_NAME_PLACEHOLDER Widget Styles */
#WIDGET_NAME_PLACEHOLDER-widget {
    /* Standard positioning and sizing - customize as needed */
    display: flex;
    position: absolute;
    left: 50dp;
    top: 100dp;
    width: 300dp;
    height: 400dp;
}

#widget-container {
    display: flex;
    flex-direction: column;
    flex: 1;
}

/* Debug controls */
.debug-controls {
    display: flex;
    justify-content: center;
    align-items: center;
    gap: 3dp;
    z-index: 50;
}

.debug-btn:hover {
    filter: brightness(1.2);
}

.debug-btn:hover>span {
    transform: translateY(-1dp);
}

/* Custom widget styles go here */

EOF

# Replace placeholders in all files
sed -i "s/WIDGET_NAME_PLACEHOLDER/$WIDGET_NAME/g" "$WIDGET_DIR/${WIDGET_NAME}.lua"
sed -i "s/WIDGET_NAME_PLACEHOLDER/$WIDGET_NAME/g" "$WIDGET_DIR/${WIDGET_NAME}.rml"
sed -i "s/WIDGET_NAME_PLACEHOLDER/$WIDGET_NAME/g" "$WIDGET_DIR/${WIDGET_NAME}.rcss"

echo ""
echo "✅ RML Widget '$WIDGET_NAME' generated successfully!"
echo ""
echo "Configuration:"
echo "  📐 Size: 300x400dp (customize in .rcss file)"
echo "  📍 Position: top-left (customize in .rcss file)"
echo "  🔧 Enabled: false (change to true in GetInfo() when ready)"
echo ""
echo "Files created:"
echo "  📁 $WIDGET_DIR/"
echo "  📄 $WIDGET_DIR/${WIDGET_NAME}.lua"
echo "  📄 $WIDGET_DIR/${WIDGET_NAME}.rml"
echo "  📄 $WIDGET_DIR/${WIDGET_NAME}.rcss"
echo ""
echo "The widget includes:"
echo "  • Modern utils.initializeRmlWidget() and utils.shutdownRmlWidget() patterns"
echo "  • Common Class Groups (CCG) integration for consistent styling"
echo "  • Theme utilities for proper theme support"
echo "  • Clean starter template with basic data model"
echo "  • Debugger and Reload functions"
echo ""
echo "To use Common Class Groups in your templates:"
echo "  • Use data-attr-class=\"ccg.button.default\" for standard buttons"
echo "  • Use data-attr-class=\"ccg.text.body\" for body text"
echo "  • Use data-attr-class=\"ccg.heading.h4\" for headings"
echo "  • Extend with: data-attr-class=\"ccg.button.default + ' custom-class'\""
echo ""
echo "Next steps:"
echo "  1. Set enabled = true in the GetInfo() function"
echo "  2. Customize size and position in the .rcss file"
echo "  3. Enable the rml_style_guide widget to explore styling options"
echo ""
echo "Ready to customize your widget!"
