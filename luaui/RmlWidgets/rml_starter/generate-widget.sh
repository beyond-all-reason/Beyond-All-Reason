#!/bin/bash

# RML Widget Generator
# Usage: ./generate-widget.sh --name widget_name
#
# Requires bash. On Windows, run it from Git Bash or WSL — NOT PowerShell
# or cmd. (No PowerShell port: keeping one canonical script avoids drift.)
#
# Scaffolds a new RML widget (.lua/.rml/.rcss) using the canonical BAR
# patterns: model-is-king (no widget: methods), block layout (no nested
# flex-column), CCG for components + utility classes for layout. No debug
# buttons — only rml_starter has those. See ../agents.md.

set -euo pipefail

WIDGET_NAME=""

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
            echo "Requires bash (Windows: run from Git Bash or WSL, not PowerShell/cmd)."
            echo ""
            echo "Required:"
            echo "  --name NAME        Widget name (letters, numbers, _ and - ; must start with a letter)"
            echo ""
            echo "Options:"
            echo "  -h, --help         Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0 --name my_widget"
            echo "  $0 --name build_menu"
            echo ""
            echo "Generated widgets use a compact 260x300dp box at top-left."
            echo "Customize size/position in the generated .rcss file (size tight to content)."
            exit 0
            ;;
        *)
            # Legacy positional argument
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

if [[ -z "$WIDGET_NAME" ]]; then
    echo "Error: Widget name is required!"
    echo "Usage: $0 --name widget_name   (use --help for more)"
    exit 1
fi

if [[ ! "$WIDGET_NAME" =~ ^[a-zA-Z][a-zA-Z0-9_-]*$ ]]; then
    echo "Error: Widget name must start with a letter and contain only letters, numbers, underscores, and hyphens"
    exit 1
fi

# Resolve paths relative to THIS script, so it works from any CWD.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WIDGET_DIR="$SCRIPT_DIR/../${WIDGET_NAME}"

if [ -d "$WIDGET_DIR" ]; then
    echo "Error: Widget directory already exists: $WIDGET_DIR"
    exit 1
fi

echo "Generating RML widget: $WIDGET_NAME"
mkdir "$WIDGET_DIR"

# ---------------------------------------------------------------------------
# Lua — logic, model factory, no debug UI, no per-frame Update
# ---------------------------------------------------------------------------
cat > "$WIDGET_DIR/${WIDGET_NAME}.lua" << EOF
-- ${WIDGET_NAME} — RML widget
--
-- THE MODEL IS KING. Change the view by mutating dm_handle fields and
-- letting data binding update it. Do NOT use GetElementById / QuerySelector
-- / SetClass / SetAttribute / .inner_rml / AppendChild to drive UI state.
-- The only sanctioned DOM manipulation is rare (documented data-binding
-- bug, SVG injection, measured perf hot path) and MUST carry a marker:
--   -- rml-dom-escape: <one-line technical reason>
-- See luaui/RmlWidgets/agents.md — "The model is king".

if not RmlUi then
    return
end

local widget = widget ---@type Widget
local utils = VFS.Include("luaui/Include/rml_utilities/utils.lua")

local WIDGET_ID = "${WIDGET_NAME}"
local MODEL_NAME = "${WIDGET_NAME}_model"
local RML_PATH = "luaui/RmlWidgets/${WIDGET_NAME}/${WIDGET_NAME}.rml"

local document
local dm_handle

-- Factory: a fresh model table every init (avoids stale references).
-- Every key the widget will ever use MUST be declared here; you cannot
-- add new model keys after the document loads.
local function initModel()
    return {
        message = "Hello from ${WIDGET_NAME}!",
        status = "Ready",

        -- Bundle repeated *layout* utility combos here, then use
        -- my.<name> in the .rml. (Components use ccg.* directly.)
        my = {
            -- rowLayout = "flex items-center justify-between p-2",
        },

        handleConfirm = function()
            dm_handle.status = "Confirmed"
            dm_handle.message = "Action confirmed!"
        end,

        handleCancel = function()
            dm_handle.status = "Cancelled"
            dm_handle.message = "Action cancelled"
        end,
    }
end

function widget:GetInfo()
    return {
        name = "${WIDGET_NAME}",
        desc = "Generated RML widget template",
        author = "Generated from rml_starter/generate-widget.sh",
        date = "2025",
        license = "GNU GPL, v2 or later",
        layer = -1000,
        enabled = false,
    }
end

function widget:Initialize()
    local result = utils.initializeRmlWidget(self, {
        widgetId = WIDGET_ID,
        modelName = MODEL_NAME,
        rmlPath = RML_PATH,
        initModel = initModel(),
        useCommonClassGroups = true,  -- ccg.* for components (see ../agents.md)
    })
    if not result then
        return false
    end
    document = result.document
    dm_handle = result.dm_handle
    return true
end

function widget:Shutdown()
    utils.shutdownRmlWidget(self, {
        widgetId = WIDGET_ID,
        modelName = MODEL_NAME,
    }, document, dm_handle)
    document = nil
    dm_handle = nil
end
EOF

# ---------------------------------------------------------------------------
# RML — block layout, utilities by default (CCG for heavy repeats), no debug UI
# ---------------------------------------------------------------------------
cat > "$WIDGET_DIR/${WIDGET_NAME}.rml" << EOF
<rml>
<head>
    <title>${WIDGET_NAME} Widget</title>

    <!-- Stylesheet order matters (do not reorder) -->
    <link rel="stylesheet" href="../styles.rcss" type="text/rcss" />
    <link rel="stylesheet" href="../rml-utility-classes.rcss" type="text/rcss" />
    <link rel="stylesheet" href="../palette-standard-global.rcss" type="text/rcss" />
    <link rel="stylesheet" href="../components.rcss" type="text/rcss" />
    <link rel="stylesheet" href="../themes/theme-base.rcss" type="text/rcss" />
    <link rel="stylesheet" href="../themes/theme-armada.rcss" type="text/rcss" />
    <link rel="stylesheet" href="../themes/theme-cortex.rcss" type="text/rcss" />
    <link rel="stylesheet" href="../themes/theme-legion.rcss" type="text/rcss" />

    <link rel="stylesheet" href="${WIDGET_NAME}.rcss" type="text/rcss" />
</head>
<body id="${WIDGET_NAME}-widget" class="widget-shadow">
    <!-- Single wrapper with data-model. Block layout: children stack
         top-to-bottom in one layout pass. Never use flex-direction:
         column here — it is the #1 layout-perf killer in this engine. -->
    <!-- Container uses ccg.panel.general — a heavy, frequently-repeated
         aggregation, which is exactly what CCG is for. Everything else
         below is plain utility classes (the default). Buttons use
         ccg.button.* for the same reason. -->
    <!-- RADIUS: the body has NO rounded-* class. The widget FRAME's corner
         radius is owned by the style-mode radius axis (utils applies
         radius-square/subtle/rounded from the user's setting). Do NOT add
         rounded-lg here, and keep small interior elements (bars, thin rows,
         cells) SQUARE — radius on a few-dp element reads as a blob. -->
    <div id="widget-container" data-model="${WIDGET_NAME}_model" data-attr-class="ccg.panel.general">

        <div class="starter-title text-lg font-bold text-primary">${WIDGET_NAME}</div>

        <div class="starter-section">
            <h1 class="text-xl font-bold text-light">{{message}}</h1>
            <p class="text-sm text-medium">A generated RML widget: utilities by default, CCG for heavy repeats, block layout, no per-frame polling.</p>
        </div>

        <div class="starter-section">
            <p class="text-sm text-medium">Status: <span class="text-sm font-bold text-light">{{status}}</span></p>
        </div>

        <div class="starter-hint bg-warning-alpha rounded">
            <p class="text-sm font-bold text-warning">Tip</p>
            <p class="text-sm text-medium">Enable the <strong>rml_style_guide</strong> widget (press F11, search "style guide") to browse every utility class and CCG group.</p>
        </div>

        <div class="starter-actions flex justify-end gap-2">
            <button data-attr-class="ccg.button.danger + ' px-2 py-1'" data-event-click="handleCancel()">cancel</button>
            <button data-attr-class="ccg.button.success + ' px-2 py-1'" data-event-click="handleConfirm()">confirm</button>
        </div>
    </div>
</body>
</rml>
EOF

# ---------------------------------------------------------------------------
# RCSS — block-first; layout only (colours via utilities / CCG in .rml)
# ---------------------------------------------------------------------------
cat > "$WIDGET_DIR/${WIDGET_NAME}.rcss" << EOF
/* ${WIDGET_NAME} widget styles */

/* Size the box TIGHT to its contents — avoid oversized panels. Dense HUD
   widgets should hug their content (small dp box, text-sm/text-xs, tight
   padding). This 260x300 default is a starting point; shrink it further to
   fit what you actually draw. The frame radius comes from the style-mode
   axis (see the .rml body note) — do not add a border-radius here. */
#${WIDGET_NAME}-widget {
    position: absolute;
    left: 50dp;
    top: 100dp;
    width: 260dp;
    height: 300dp;
    display: block;
}

/* Block layout = single layout pass. Do NOT switch this to
   display: flex; flex-direction: column — see ../agents.md perf rules. */
#widget-container {
    display: block;
    position: relative;
    height: 100%;
    padding: 12dp;
}

.starter-title {
    height: 22dp;
    margin-bottom: 10dp;
}

.starter-section {
    margin-bottom: 10dp;
}

/* Colours come from utility classes (and CCG for the panel/buttons) in
   the .rml. Never hard-code colours in widget RCSS — layout only. */
.starter-hint {
    margin-bottom: 10dp;
    padding: 8dp;
}

.starter-actions {
    margin-top: 10dp;
}
EOF

echo ""
echo "RML Widget '$WIDGET_NAME' generated."
echo ""
echo "Files:"
echo "  $WIDGET_DIR/${WIDGET_NAME}.lua"
echo "  $WIDGET_DIR/${WIDGET_NAME}.rml"
echo "  $WIDGET_DIR/${WIDGET_NAME}.rcss"
echo ""
echo "Defaults baked in (the canonical patterns — keep them):"
echo "  - Block layout, no nested flex-column"
echo "  - Utility classes by default; CCG (ccg.*) only for heavy repeats (panel, buttons)"
echo "  - No debug buttons (only rml_starter has those); no per-frame polling"
echo "  - Frame radius via style-mode axis only (no rounded-* on body; square interior elements)"
echo "  - Compact box sized to content (text-sm/text-xs in dense widgets)"
echo ""
echo "Next steps:"
echo "  1. Set enabled = true in GetInfo() when ready"
echo "  2. Adjust size/position in ${WIDGET_NAME}.rcss"
echo "  3. Enable the rml_style_guide widget to explore styling"
