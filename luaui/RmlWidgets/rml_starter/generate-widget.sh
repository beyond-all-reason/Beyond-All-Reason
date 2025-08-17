#!/bin/bash

# RML Widget Generator Script
# Usage: ./generate-widget.sh widget_name

if [ $# -eq 0 ]; then
    echo "Usage: $0 widget_name"
    echo "Example: $0 my_cool_widget"
    exit 1
fi

WIDGET_NAME="$1"
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

function widget:GetInfo()
    return {
        name = "WIDGET_NAME_PLACEHOLDER",
        desc = "Generated RML widget template",
        author = "Generated from rml_starter/generate-widget.sh",
        date = "2025",
        license = "GNU GPL, v2 or later",
        layer = -1000000,
        enabled = true,
    }
end

-- Constants
local WIDGET_NAME = "WIDGET_NAME_PLACEHOLDER"
local MODEL_NAME = "WIDGET_NAME_PLACEHOLDER_model"
local RML_PATH = "luaui/rmlwidgets/WIDGET_NAME_PLACEHOLDER/WIDGET_NAME_PLACEHOLDER.rml"

-- Widget state
local document
local dm_handle

-- Initial data model
local init_model = {
    message = "Hello from WIDGET_NAME_PLACEHOLDER!",
    currentTime = os.date("%H:%M:%S"),
    debugMode = false,
}

function widget:Initialize()
    if widget:GetInfo().enabled == false then
        Spring.Echo(WIDGET_NAME .. ": Widget is disabled, skipping initialization")
        return false
    end
    
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
        Spring.Echo(WIDGET_NAME .. ": ERROR - Failed to create data model")
        return false
    end
    
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

function widget:Update()
    if dm_handle then
        dm_handle.currentTime = os.date("%H:%M:%S")
    end
end

-- Widget functions callable from RML
function widget:Reload()
    Spring.Echo(WIDGET_NAME .. ": Reloading widget...")
    widget:Shutdown()
    widget:Initialize()
end

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
EOF

# Generate the RML file
cat > "$WIDGET_DIR/${WIDGET_NAME}.rml" << 'EOF'
<rml>
<head>
    <title>WIDGET_NAME_PLACEHOLDER Widget</title>
    
    <!-- External stylesheets -->
    <link rel="stylesheet" href="../styles.rcss" type="text/rcss" />
    <link rel="stylesheet" href="../rml-utils.rcss" type="text/rcss" />
    <link rel="stylesheet" href="../palette-standard-global.rcss" type="text/rcss" />
    <link rel="stylesheet" href="../palette-base.rcss" type="text/rcss" />
    <link rel="stylesheet" href="WIDGET_NAME_PLACEHOLDER.rcss" type="text/rcss" />
</head>
<body id="my_widget-widget">
    <div id="widget-container" data-model="my_widget_model" class="bg-black-semi-alpha">
        <!-- Small floating debug buttons -->
        <div class="debug-controls">
            <button class="debug-btn text-dark text-sm font-bold bg-primary" onclick="widget:Reload()" title="Reload Widget">reload</button>
            <button class="debug-btn text-dark text-sm font-bold bg-primary" onclick="widget:ToggleDebugger()" title="Toggle Debugger">debug</button>
        </div>
        
        <h1 class="text-white">my_widget</h1>
        
        <div class="content mt-4 flex flex-col gap-6">
            <p class="text-white">{{message}}</p>
            <p class="text-gray-600">Time: {{currentTime}}</p>
        </div>
    </div>
</body>
</rml>
EOF

# Generate the RCSS file
cat > "$WIDGET_DIR/${WIDGET_NAME}.rcss" << 'EOF'
/* WIDGET_NAME_PLACEHOLDER Widget Styles */
#WIDGET_NAME_PLACEHOLDER-widget {
    /* positional properties */
    position: absolute;
    top: 100dp; /* Adjust as needed */
    left: 10dp; /* Adjust as needed */
    /* dimensional properties */
    width: 300dp; /* Adjust as needed */
    height: 400dp; /* Adjust as needed */
}

#widget-container {
    display: flex;
    flex-direction: column;
    width: 100%;
    height: 100%;
}

/* Small floating debug controls */
.debug-controls {
    position: absolute;
    top: -15dp;
    right: -5dp;
    display: flex;
    gap: 3dp;
    z-index: 10;
}

.debug-btn {
    height: 20dp;
    padding: 0 4dp;
    cursor: pointer;
    text-align: center;
    line-height: 18dp;
    transition: all 0.1s;
}

.debug-btn:hover {
    transform: scale(1.1);
}

.debug-btn:active {
    transform: scale(0.95);
}

EOF

# Replace placeholders in all files
sed -i "s/WIDGET_NAME_PLACEHOLDER/$WIDGET_NAME/g" "$WIDGET_DIR/${WIDGET_NAME}.lua"
sed -i "s/WIDGET_NAME_PLACEHOLDER/$WIDGET_NAME/g" "$WIDGET_DIR/${WIDGET_NAME}.rml"
sed -i "s/WIDGET_NAME_PLACEHOLDER/$WIDGET_NAME/g" "$WIDGET_DIR/${WIDGET_NAME}.rcss"

echo ""
echo "✅ RML Widget '$WIDGET_NAME' generated successfully!"
echo ""
echo "Files created:"
echo "  📁 ../RmlWidgets/$WIDGET_NAME/"
echo "  📄 ../RmlWidgets/$WIDGET_NAME/${WIDGET_NAME}.lua"
echo "  📄 ../RmlWidgets/$WIDGET_NAME/${WIDGET_NAME}.rml"
echo "  📄 ../RmlWidgets/$WIDGET_NAME/${WIDGET_NAME}.rcss"
echo ""
echo "The widget includes:"
echo "  • Basic data model with message and currentTime"
echo "  • Initialize, Shutdown, Update lifecycle functions"
echo "  • Debugger and Reload toggles"
echo ""
echo "Ready to customize your widget!"
