#!/bin/bash

# RML Widget Generator Script
# Usage: ./generate-widget.sh widget_name

if [ $# -eq 0 ]; then
    echo "Usage: $0 widget_name"
    echo "Example: $0 my_cool_widget"
    exit 1
fi

WIDGET_NAME="$1"
WIDGET_DIR="${WIDGET_NAME}"

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
        name = "WIDGET_NAME_PLACEHOLDER Widget",
        desc = "Generated RML widget template",
        author = "Generated",
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
    <link rel="stylesheet" href="../palette-standard-global.rcss" type="text/rcss" />
    <link rel="stylesheet" href="../rml-utils.rcss" type="text/rcss" />
    <link rel="stylesheet" href="WIDGET_NAME_PLACEHOLDER.rcss" type="text/rcss" />
</head>
<body id="WIDGET_NAME_PLACEHOLDER-widget">
    <div class="widget-container" data-model="WIDGET_NAME_PLACEHOLDER_model">
        <!-- Small floating debug buttons -->
        <div class="debug-controls">
            <button class="debug-btn text-white" onclick="widget:Reload()" title="Reload Widget">R</button>
            <button class="debug-btn text-white" onclick="widget:ToggleDebugger()" title="Toggle Debugger">{{debugMode ? 'D' : 'D'}}</button>
        </div>
        
        <h1 class="text-white">WIDGET_NAME_PLACEHOLDER Widget</h1>
        
        <div class="content">
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
    pointer-events: auto;
    position: absolute;
    top: 10%;
    right: 10dp;
    width: 320dp;
    min-height: 150dp;
    padding: 16dp;
    background-color: rgba(20, 25, 30, 230);
    border: 1px rgba(100, 120, 140, 80);
    border-radius: 2dp;
    box-sizing: border-box;
    display: flex;
    flex-direction: column;
}

.widget-container {
    /* Flexbox layout for the widget content */
    display: flex;
    flex-direction: column;
    flex: 1;
}

/* Small floating debug controls */
.debug-controls {
    position: absolute;
    top: -2dp;
    right: -2dp;
    display: flex;
    gap: 2dp;
    z-index: 10;
}

.debug-btn {
    width: 20dp;
    height: 20dp;
    padding: 0;
    background-color: rgba(60, 120, 180, 180);
    border: 1px solid rgba(80, 140, 200, 120);
    border-radius: 2dp;
    cursor: pointer;
    font-size: 11dp;
    font-weight: bold;
    text-align: center;
    line-height: 18dp;
    transition: all 0.15s;
}

.debug-btn:hover {
    background-color: rgba(80, 140, 200, 220);
    border-color: rgba(100, 160, 220, 160);
    transform: scale(1.1);
}

.debug-btn:active {
    background-color: rgba(50, 100, 160, 240);
    transform: scale(0.95);
}

.widget-container h1 {
    margin: 0 0 12dp 0;
    font-size: 18dp;
    font-weight: bold;
    line-height: 1.2;
}

.content {
    margin-top: 8dp;
    display: flex;
    flex-direction: column;
    gap: 6dp;
}

.content p {
    margin: 0;
    line-height: 1.4;
    font-size: 14dp;
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
echo "  📁 $WIDGET_DIR/"
echo "  📄 $WIDGET_DIR/${WIDGET_NAME}.lua"
echo "  📄 $WIDGET_DIR/${WIDGET_NAME}.rml"
echo "  📄 $WIDGET_DIR/${WIDGET_NAME}.rcss"
echo ""
echo "The widget includes:"
echo "  • Basic data model with message and currentTime"
echo "  • Initialize, Shutdown, Update lifecycle functions"
echo "  • Debugger and Reload toggles"
echo ""
echo "Ready to customize your widget!"
