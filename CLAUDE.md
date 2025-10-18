# Beyond All Reason - Codebase Documentation

**Last Updated:** 2025-10-18
**Repository:** https://github.com/beyond-all-reason/Beyond-All-Reason
**Game Engine:** Recoil (fork of Spring RTS Engine)

## Table of Contents
1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Directory Structure](#directory-structure)
4. [Core Systems](#core-systems)
5. [Development Guide](#development-guide)
6. [Git Workflow & Contributing](#git-workflow--contributing)
7. [Debugging & Testing](#debugging--testing)
8. [Quick Reference](#quick-reference)
9. [Code Search Tips](#code-search-tips)
10. [Troubleshooting](#troubleshooting)
11. [Key Files Reference](#key-files-reference)
12. [External Resources](#external-resources)

---

## Overview

Beyond All Reason (BAR) is an open-source Real-Time Strategy (RTS) game built on the Recoil engine. The game features large-scale battles with full physical simulation in a sci-fi setting.

### Quick Stats
- **Primary Language:** Lua
- **Total Files:** 17,347 files
- **Lua Files:** ~2,075 files
- **Repository Size:** 6.4 GB (includes assets)
- **License:** GNU GPL v2+

### Components
BAR consists of two primary components:
1. **Game Code** (this repository) - Core game logic, units, UI
2. **Lobby/Launcher** ([BYAR-Chobby](https://github.com/beyond-all-reason/BYAR-Chobby)) - Game launcher and multiplayer lobby

The game runs on the **Recoil engine** (https://github.com/beyond-all-reason/spring), a fork of the Spring RTS engine.

---

## Architecture

### Execution Model

BAR uses the Spring/Recoil engine's Lua execution model with distinct execution contexts:

```
┌─────────────────────────────────────────────────┐
│              Recoil Engine (C++)                │
│  (Physics, Rendering, Networking, Sound)        │
└─────────────────────────────────────────────────┘
           ▲         ▲         ▲         ▲
           │         │         │         │
    ┌──────┴───┐ ┌──┴──────┐ ┌┴────────┐│
    │ LuaRules │ │  LuaUI  │ │ LuaIntro││LuaAI
    │ (Synced) │ │(Unsynced│ │(Unsynced││
    └──────────┘ └─────────┘ └─────────┘└────────┘
```

### Lua Execution Contexts

1. **LuaRules** (`luarules/`)
   - **Synced code** - Runs on all clients and server identically
   - Game logic, rules, physics modifications
   - Unit behavior, damage calculations
   - Economy, resources
   - Uses **Gadgets** (modular plugins)

2. **LuaUI** (`luaui/`)
   - **Unsynced code** - Runs only on local client
   - User interface, HUD, controls
   - Visual effects, graphics
   - Input handling
   - Uses **Widgets** (modular UI components)

3. **LuaIntro** (`luaintro/`)
   - Unsynced code for intro sequences

4. **LuaAI** (defined in `luaai.lua`)
   - AI bot implementations

### Initialization Flow

```
init.lua (global)
    ↓
Common libraries & utilities loaded
    ↓
    ├─→ luarules/main.lua → gadgets.lua → All Gadgets
    ├─→ luaui/main.lua → barwidgets.lua → All Widgets
    └─→ luaai.lua → AI definitions
```

---

## Directory Structure

### Top-Level Directories

```
Beyond-All-Reason/
├── anims/              # Animation files
├── bitmaps/            # Texture files, sprites, UI graphics
├── common/             # Shared Lua utilities (used by all contexts)
├── effects/            # Particle effects, visual effects
├── features/           # Map features (rocks, trees, etc.)
├── fonts/              # Font files
├── gamedata/           # Core game data definitions
├── icons/              # Unit icons, command icons
├── language/           # Internationalization/translation files
├── luaintro/           # Intro sequence code
├── luarules/           # Game rules and logic (synced)
│   ├── configs/        # Configuration files
│   ├── gadgets/        # Modular game logic components
│   ├── mission_api/    # Mission/scenario system
│   └── Utilities/      # Helper functions
├── luaui/              # User interface (unsynced)
│   ├── configs/        # UI configuration
│   ├── Headers/        # Lua header files (constants)
│   ├── Include/        # Shared UI libraries
│   ├── RmlWidgets/     # RmlUI-based widgets (new UI system)
│   ├── Scenarios/      # Tutorial/scenario UI
│   ├── Shaders/        # GLSL shaders for UI
│   ├── Tests/          # Unit tests
│   └── Widgets/        # UI components (~200+ widgets)
├── lups/               # Lua Particle System
├── modelmaterials/     # Material definitions for 3D models
├── modules/            # Reusable Lua modules
├── music/              # Music files
├── objects3d/          # 3D model files (.s3o)
├── scripts/            # Unit animation scripts (.cob, .lua)
├── shaders/            # GLSL shader files
├── sidepics/           # Faction/side images
├── singleplayer/       # Singleplayer scenarios
├── sounds/             # Sound effects
├── tools/              # Development tools
├── types/              # Type definitions
├── unitbasedefs/       # Base unit definition templates
├── unitpics/           # Unit preview images
├── units/              # Unit definitions
│   ├── ArmBots/        # Armada robot units
│   ├── ArmBuildings/   # Armada structures
│   ├── ArmVehicles/    # Armada vehicles
│   ├── ArmAircraft/    # Armada aircraft
│   ├── CorBots/        # Cortex robot units
│   ├── CorBuildings/   # Cortex structures
│   └── ...
├── unittextures/       # Unit texture files
└── weapons/            # Weapon definitions
```

### Key Configuration Files

| File | Purpose |
|------|---------|
| `modinfo.lua` | Game metadata (name, version) |
| `modoptions.lua` | Game mode options/settings (77KB+) |
| `EngineOptions.lua` | Engine configuration |
| `luaai.lua` | AI bot definitions |
| `init.lua` | Global initialization, loads common utilities |

---

## Core Systems

### 1. Gadget System (LuaRules)

**Location:** `luarules/gadgets/`

Gadgets are modular, self-contained pieces of game logic. Each gadget:
- Has a `GetInfo()` function defining metadata
- Can be enabled/disabled
- Has a layer ordering for execution priority
- Hooks into engine call-ins (events)

**Example Gadget Structure:**
```lua
-- luarules/gadgets/unit_interceptors.lua
local gadget = gadget ---@type Gadget

function gadget:GetInfo()
    return {
        name     = "Don't target flyover nukes",
        desc     = "Antinukes can target flyover nukes, this ensures they don't.",
        author   = "Beherith",
        date     = "2023.11.09",
        license  = "GNU GPL, v2 or later",
        layer    = 0,
        enabled  = true
    }
end

if not gadgetHandler:IsSyncedCode() then
    return false  -- No unsynced code
end

function gadget:Initialize()
    -- Setup code
end

function gadget:AllowWeaponInterceptTarget(interceptorUnitID, interceptorWeaponID, targetProjectileID)
    -- Game logic
end
```

**Common Gadget Categories:**
- `ai_*.lua` - AI-related gadgets
- `api_*.lua` - API providers for other gadgets/widgets
- `cmd_*.lua` - Custom commands
- `game_*.lua` - Core game mechanics
- `unit_*.lua` - Unit behavior modifications
- `camera_*.lua` - Camera controls

**Gadget Handler:** `luarules/gadgets.lua` (1,700+ lines)
- Manages gadget lifecycle
- Routes engine call-ins to gadgets
- Provides `GG` (Gadget Globals) shared table

### 2. Widget System (LuaUI)

**Location:** `luaui/Widgets/`

Widgets are modular UI components. Similar structure to gadgets but for UI:
- ~200+ widgets in the codebase
- Handle rendering, input, HUD elements
- Can communicate via `WG` (Widget Globals)

**Example Widget Structure:**
```lua
-- luaui/Widgets/camera_fov_changer.lua
local widget = widget ---@type Widget

function widget:GetInfo()
    return {
        name      = "FOV changer",
        desc      = "shortcuts: keypad 1/7 or CTRL+O/P",
        author    = "",
        date      = "",
        license   = "GNU GPL, v2 or later",
        layer     = 999999,
        enabled   = false
    }
end

function widget:KeyRelease(key, modifier)
    -- Handle input
end
```

**Common Widget Categories:**
- `gui_*.lua` - GUI elements
- `gfx_*.lua` - Graphics/visual effects
- `cmd_*.lua` - Command enhancements
- `camera_*.lua` - Camera controls
- `api_*.lua` - API providers
- `dbg_*.lua` - Debug tools

**Widget Handler:** `luaui/barwidgets.lua` (2,300+ lines)
- Custom widget manager (forked from Spring's widgets.lua)
- Manages widget lifecycle
- Routes call-ins to widgets

### 3. Unit Definition System

**Location:** `units/`

Units are defined in Lua tables with extensive configuration:

**Example Unit:** `units/ArmBots/armpw.lua` (Peewee - basic infantry bot)
```lua
return {
    armpw = {
        -- Build properties
        buildtime = 1650,
        energycost = 900,
        metalcost = 54,

        -- Physical properties
        health = 370,
        speed = 87,
        turnrate = 1214.4,

        -- Visual
        objectname = "Units/ARMPW.s3o",
        script = "Units/ARMPW.cob",

        -- Weapons
        weapondefs = {
            emg = {
                -- Weapon definition
                range = 180,
                damage = { default = 9, vtol = 3 },
            }
        },
        weapons = {
            [1] = { def = "EMG" }
        },

        -- Death/corpse
        featuredefs = {
            dead = { ... },
            heap = { ... }
        }
    }
}
```

**Unit Organization:**
- By faction: `ArmBots/`, `CorBots/`, etc.
- By type: Bots, Vehicles, Aircraft, Ships, Buildings
- T1 units in main directory, T2/T3 in subdirectories

### 4. Common Utilities

**Location:** `common/`

Shared libraries loaded by all Lua contexts:

| File | Purpose |
|------|---------|
| `numberfunctions.lua` | Math utilities |
| `stringFunctions.lua` | String manipulation |
| `tablefunctions.lua` | Table utilities |
| `springFunctions.lua` | Spring engine helpers |
| `platformFunctions.lua` | Platform detection |
| `luaUtilities/json.lua` | JSON parsing |

**Loaded by:** `init.lua:5-8`

### 5. Module System

**Location:** `modules/`

Reusable game systems:
- `i18n/` - Internationalization system
- `customcommands.lua` - Custom command definitions
- `lava.lua` - Lava map feature
- `graphics/` - Graphics initialization

### 6. AI System

**Location:** `luaai.lua`

Defines available AI bots:
- SimpleAI (Easy)
- STAI (Medium)
- Shard (Basic)
- RaptorsAI (Co-op defense)
- ScavengersAI (Infinite games)

AI implementations are external (not in this repo).

### 7. Configuration System

**`modoptions.lua`** (77KB file)
- Defines all game options/settings
- Team settings, economy settings
- Resource multipliers
- Game modes (Raptors, Scavengers, etc.)
- Used by lobby to present options

### 8. Asset Pipeline

**3D Models:**
- Format: `.s3o` (Spring 3D Object)
- Location: `objects3d/`
- Materials: `modelmaterials/`

**Scripts:**
- Unit animations: `scripts/` (`.cob` compiled or `.lua`)
- Control turret aiming, walking, firing animations

**Textures:**
- Main textures: `unittextures/`
- Bitmaps: `bitmaps/`
- Normal maps referenced in unit definitions

---

## Development Guide

### Setting Up Dev Environment

1. **Install BAR** from https://www.beyondallreason.info/download

2. **Find install directory:**
   - Open launcher → "Open install directory"
   - Example: `AppData/Local/Programs/Beyond-All-Reason/data`

3. **Enable dev mode:**
   ```bash
   touch <install-directory>/devmode.txt
   ```

4. **Clone game code:**
   ```bash
   cd <install-directory>/data/games
   git clone --recurse-submodules https://github.com/beyond-all-reason/Beyond-All-Reason.git BAR.sdd
   ```
   **Important:** Directory must end in `.sdd`

5. **Select dev version:**
   - Launch game → Settings → Developer → Singleplayer
   - Select "Beyond All Reason Dev"

6. **Test changes:**
   - Edit files in `BAR.sdd/`
   - Launch match normally
   - Changes take effect immediately

### Code Conventions

**File Naming:**
- Gadgets/Widgets: `category_description.lua`
  - `api_*` = Provides API
  - `gui_*` = GUI component
  - `cmd_*` = Custom command
  - `game_*` = Core game mechanic
  - `unit_*` = Unit behavior

**Lua Style:**
- Local functions for performance
- Localize Spring API functions at top of file
- Use type annotations: `---@type Gadget`

**Performance:**
- Gadgets run every frame in synced code
- Minimize per-frame work
- Cache lookups, use tables for O(1) access
- Example from `unit_interceptors.lua:32`:
  ```lua
  -- Hash: (100000 * weaponNum + unitDefID) → coverageSquared
  local interceptorUnitDefWeapCovSqr = {}
  ```

### Testing

**Unit Tests:** `luaui/Tests/`

**Debug Tools:**
- `luaui/debug.lua` - Debug utilities
- Debug widgets in `Widgets/dbg_*.lua`

### Call-Ins (Engine Events)

Both gadgets and widgets hook into engine events:

**Common Call-Ins:**
- `Initialize()` - On load
- `Shutdown()` - On unload
- `GameFrame(frame)` - Every frame
- `UnitCreated(unitID, unitDefID, unitTeam)` - Unit spawned
- `UnitDestroyed(unitID, unitDefID, unitTeam)` - Unit died
- `DrawScreen()` - Render UI (widgets)
- `KeyPress(key, mods, ...)` - Keyboard input

Full list: `luarules/gadgets.lua` call-in routing, `luaui/callins.lua`

---

## Git Workflow & Contributing

### Forking and Setting Up

1. **Fork the repository** on GitHub
2. **Clone your fork locally:**
   ```bash
   git clone https://github.com/YOUR_USERNAME/Beyond-All-Reason.git
   cd Beyond-All-Reason
   ```
3. **Add upstream remote:**
   ```bash
   git remote add upstream https://github.com/beyond-all-reason/Beyond-All-Reason.git
   ```
4. **Verify remotes:**
   ```bash
   git remote -v
   # origin    https://github.com/YOUR_USERNAME/Beyond-All-Reason.git (fetch)
   # origin    https://github.com/YOUR_USERNAME/Beyond-All-Reason.git (push)
   # upstream  https://github.com/beyond-all-reason/Beyond-All-Reason.git (fetch)
   # upstream  https://github.com/beyond-all-reason/Beyond-All-Reason.git (push)
   ```

### Making Changes

1. **Keep master branch in sync:**
   ```bash
   git checkout master
   git pull upstream master
   git push origin master
   ```

2. **Create a feature branch:**
   ```bash
   git checkout -b fix-issue-1234-description
   # Naming: fix-issue-XXXX-short-description
   # or: feature-short-description
   ```

3. **Make your changes**
   - Edit files as needed
   - Test changes in-game (see Testing section)

4. **Commit your changes:**
   ```bash
   git add path/to/changed/files
   git commit -m "Descriptive commit message

   Longer description of what changed and why.

   Fixes #1234"
   ```

5. **Push to your fork:**
   ```bash
   git push origin fix-issue-1234-description
   ```

6. **Create Pull Request:**
   ```bash
   gh pr create --repo beyond-all-reason/Beyond-All-Reason \
     --base master \
     --title "Fix issue #1234: Description" \
     --body "Summary of changes..."
   ```

### Commit Message Best Practices

- **First line:** Clear, concise summary (50 chars or less)
- **Body:** Explain what changed and why (not how - code shows that)
- **Reference issues:** Use `Fixes #1234` or `Closes #1234`
- **Example:**
  ```
  Lower jammer range visualization threshold to 63

  Mine layer vehicles have a jammer range of 64, but the visualization
  widget only showed ranges >= 100. This made it difficult to see mine
  layer jammer coverage.

  Fixes #5815
  ```

### Code Review Process

1. **Respond to feedback** - Address reviewer comments
2. **Make requested changes** - Commit to same branch
3. **Push updates** - `git push origin branch-name`
4. **PR automatically updates** - No need to close/reopen

---

## Debugging & Testing

### In-Game Console

Press `\` (backslash) or `/` (forward slash) to open console:

**Useful Commands:**
- `/luaui reload` - Reload all widgets without restarting
- `/luarules reload` - Reload all gadgets (careful: can desync multiplayer)
- `/debuggl` - Show OpenGL debug info
- `/debug` - Enable debug mode
- `/cheat` - Enable cheat mode (singleplayer only)
- `/godmode` - Make units invulnerable
- `/give [unitname]` - Spawn a unit (requires /cheat)

### Logging and Debugging

**Widget/Gadget Logging:**
```lua
-- In widgets
Spring.Echo("Debug message:", value)
Spring.Log("WidgetName", LOG.INFO, "Info message")
Spring.Log("WidgetName", LOG.ERROR, "Error message")

-- Print table contents
Spring.Echo(table.toString(myTable))
```

**Check Logs:**
- **Location:** Game install directory
- **File:** `infolog.txt` - Contains all Spring.Echo output
- **Errors:** Look for `[f=-000001]` lines for initialization errors

**Debug Widget:**
```lua
-- Add to widget for real-time debugging
function widget:DrawScreen()
    gl.Text("Debug: " .. tostring(myVariable), 100, 100, 16, "o")
end
```

### Testing Workflow

1. **Make code changes** in repository
2. **Start a skirmish match:**
   - Quick Start → Skirmish
   - Choose any map
   - Add AI opponent (optional)
   - Click "Start Game"
3. **Test your changes** in-game
4. **Check console** for errors (press `\`)
5. **Review logs** if issues occur
6. **Iterate** - Exit game, modify code, restart

### Unit Testing

**Location:** `luaui/Tests/`

**Running Tests:**
```lua
-- In-game console
/luaui reload
-- Tests run automatically on widget load
```

**Writing Tests:**
```lua
-- luaui/Tests/test_myfeature.lua
local widget = widget ---@type Widget

function widget:GetInfo()
    return {
        name = "Test: My Feature",
        desc = "Tests for my feature",
        author = "Your Name",
        date = "2024",
        license = "GNU GPL, v2 or later",
        layer = 0,
        enabled = false,  -- Enable manually for testing
        handler = true,
        api = true,
        hidden = true,
    }
end

function widget:Initialize()
    -- Run tests
    assert(testCondition, "Test failed: description")
    Spring.Echo("All tests passed!")
end
```

### Common Debugging Patterns

**Finding Unit Definition IDs:**
```lua
-- In widget or gadget
local unitDefID = Spring.GetUnitDefID(unitID)
local unitDef = UnitDefs[unitDefID]
Spring.Echo("Unit name:", unitDef.name)
Spring.Echo("Unit ID:", unitDefID)
```

**Tracking Widget/Gadget Loading:**
```lua
function widget:Initialize()
    Spring.Echo("MyWidget initialized!")
    -- Your init code
end

function widget:Shutdown()
    Spring.Echo("MyWidget shutting down!")
end
```

**Performance Profiling:**
```lua
local startTime = Spring.GetTimer()
-- Code to profile
local elapsed = Spring.DiffTimers(Spring.GetTimer(), startTime)
Spring.Echo("Execution time:", elapsed, "seconds")
```

---

## Quick Reference

### Finding Code Quickly

**By File Pattern:**
```bash
# Find all jammer-related widgets
find luaui/Widgets -name "*jammer*"

# Find unit definition files
find units -name "arm*.lua" | grep -i "vehicle"
```

**By Content:**
```bash
# Find all widgets using a specific API
grep -r "Spring.GetUnitDefID" luaui/Widgets/

# Find gadgets handling unit creation
grep -r "function gadget:UnitCreated" luarules/gadgets/
```

**Using GitHub CLI:**
```bash
# List open issues
gh issue list --limit 20

# View specific issue
gh issue view 1234

# Search issues
gh issue list --search "jammer"
```

### Common Widget Patterns

**Accessing Other Widgets:**
```lua
function widget:Initialize()
    -- Check if another widget is available
    if WG['myotherwidget'] then
        local data = WG['myotherwidget'].getData()
    end
end
```

**Drawing on Screen:**
```lua
function widget:DrawScreen()
    gl.Color(1, 1, 1, 1)  -- White, fully opaque
    gl.Text("Hello World", 100, 100, 16, "o")  -- x, y, size, options
end
```

**Handling Input:**
```lua
function widget:KeyPress(key, mods, isRepeat)
    if key == 0x061 then  -- 'a' key
        Spring.Echo("A pressed!")
        return true  -- Consume the event
    end
    return false  -- Let other widgets handle it
end
```

### Common Gadget Patterns

**Iterating Over Units:**
```lua
function gadget:GameFrame(frame)
    if frame % 30 == 0 then  -- Every second (30 frames)
        local allUnits = Spring.GetAllUnits()
        for i = 1, #allUnits do
            local unitID = allUnits[i]
            -- Process unit
        end
    end
end
```

**Modifying Unit Behavior:**
```lua
function gadget:UnitCreated(unitID, unitDefID, unitTeam)
    -- Customize unit on creation
    Spring.SetUnitHealth(unitID, 1000)
end

function gadget:UnitDamaged(unitID, unitDefID, unitTeam, damage, paralyzer,
                             weaponDefID, projectileID, attackerID,
                             attackerDefID, attackerTeam)
    -- Modify damage
    return damage * 0.5  -- Halve all damage
end
```

### Common Spring API Functions

**Unit Information:**
```lua
Spring.GetUnitDefID(unitID)
Spring.GetUnitPosition(unitID)
Spring.GetUnitHealth(unitID)
Spring.GetUnitTeam(unitID)
Spring.GetAllUnits()
Spring.GetTeamUnits(teamID)
```

**Commands:**
```lua
Spring.GiveOrderToUnit(unitID, CMD.MOVE, {x, y, z}, {})
Spring.GiveOrderToUnit(unitID, CMD.ATTACK, {targetID}, {})
Spring.GiveOrderToUnit(unitID, CMD.STOP, {}, {})
```

**UI Functions (Widgets Only):**
```lua
Spring.GetMouseState()
Spring.TraceScreenRay(x, y, true)
Spring.GetCameraPosition()
Spring.GetCameraDirection()
```

**Game Information:**
```lua
Spring.GetGameFrame()
Spring.GetGameSeconds()
Spring.GetMyTeamID()
Spring.GetMyAllyTeamID()
Spring.GetTeamList()
```

### File Locations Cheat Sheet

| What You Want | Where to Look |
|---------------|---------------|
| Add new widget | `luaui/Widgets/gui_yourwidget.lua` |
| Add new gadget | `luarules/gadgets/game_yourgadget.lua` |
| Modify unit stats | `units/FactionType/unitname.lua` |
| Add weapon | `weapons/weaponname.lua` |
| Change UI visuals | `luaui/Widgets/gui_*.lua` |
| Modify game rules | `luarules/gadgets/game_*.lua` |
| Add custom command | `luarules/gadgets/cmd_*.lua` |
| Debug tools | `luaui/Widgets/dbg_*.lua` |

---

## Code Search Tips

### Using Grep Effectively

**Find Widget/Gadget by Feature:**
```bash
# Find all radar-related code
grep -r "radar" luaui/Widgets/ --include="*.lua" -l

# Find where a specific function is called
grep -r "GetUnitDefID" luaui/ -n

# Find configuration values
grep -r "minJammerDistance\|maxRadarRange" luaui/
```

**Find Unit Definitions:**
```bash
# Find all units with specific properties
grep -r "radardistancejam.*64" units/

# Find all flying units
grep -r "canfly.*true" units/

# Find all commanders
grep -r "iscommander" units/
```

### Using the Codebase Structure

**Naming Conventions Help:**
- `gui_sensor_ranges_*.lua` - All sensor range visualization widgets
- `cmd_*.lua` - Custom commands
- `api_*.lua` - Shared APIs
- `game_*.lua` - Core game mechanics
- `unit_*.lua` - Unit-specific behavior

**Follow the Imports:**
```lua
-- If you see this in a widget:
if WG['api_widget_name'] then
    -- Look for: luaui/Widgets/api_widget_name.lua
end

-- If you see this in a gadget:
if GG.SomeAPI then
    -- Search: grep -r "GG.SomeAPI =" luarules/gadgets/
end
```

---

## Troubleshooting

### Widget/Gadget Not Loading

**Check:**
1. **Syntax errors** - Look in `infolog.txt` for Lua errors
2. **File location** - Must be in `luaui/Widgets/` or `luarules/gadgets/`
3. **GetInfo() function** - Must return valid table
4. **enabled = true** - Check if widget/gadget is enabled
5. **Dependencies** - Check if required APIs are available

**Debug Steps:**
```lua
-- Add to top of widget
Spring.Echo("Loading MyWidget...")

function widget:Initialize()
    Spring.Echo("MyWidget:Initialize() called")
end
```

### Changes Not Appearing In-Game

**Solutions:**
1. **Reload widgets:** `/luaui reload` in console
2. **Reload gadgets:** `/luarules reload` (may cause desync)
3. **Restart match** - Some changes require full restart
4. **Check file location** - Must be editing the correct directory
5. **Check dev mode** - Ensure `devmode.txt` exists
6. **Verify game version** - Select "Beyond All Reason Dev" in settings

### Performance Issues

**Common Causes:**
1. **Per-frame operations** - Move expensive work outside GameFrame
2. **Unnecessary iterations** - Cache unit lists, don't recreate every frame
3. **String operations** - Localize and cache string operations
4. **Drawing calls** - Batch gl.* calls when possible

**Optimization Pattern:**
```lua
-- BAD: Runs every frame
function widget:DrawScreen()
    for i = 1, 1000 do
        local units = Spring.GetAllUnits()  -- Expensive!
        -- Process units
    end
end

-- GOOD: Cache and update periodically
local cachedUnits = {}
function widget:GameFrame(frame)
    if frame % 30 == 0 then  -- Once per second
        cachedUnits = Spring.GetAllUnits()
    end
end

function widget:DrawScreen()
    for i = 1, #cachedUnits do
        -- Use cached data
    end
end
```

### Synced vs Unsynced Errors

**Error:** "Attempt to call nil value" in gadget

**Cause:** Using unsynced-only Spring API in synced code

**Solution:**
```lua
-- Check if code is synced
if gadgetHandler:IsSyncedCode() then
    -- Can only use synced Spring API here
    -- NO: Spring.GetMouseState()
    -- YES: Spring.GetGameFrame()
else
    -- Can use unsynced API
    -- YES: Spring.GetMouseState()
end
```

### Common Error Messages

| Error | Likely Cause | Solution |
|-------|--------------|----------|
| `attempt to index nil value` | Variable not initialized | Check nil before accessing: `if var then var.field end` |
| `attempt to call nil value` | Function doesn't exist | Verify API name, check if synced/unsynced |
| `bad argument #N to 'func'` | Wrong parameter type | Check API documentation for correct types |
| `stack overflow` | Infinite recursion | Check for circular function calls |
| `syntax error near 'X'` | Lua syntax error | Check for missing `end`, `,`, `)`, etc. |

### Getting Help

1. **Check infolog.txt** - Located in game install directory
2. **Search existing issues** - `gh issue list --search "your problem"`
3. **Ask on Discord** - Link in repository README
4. **Read Spring Engine docs** - https://springrts.com/wiki
5. **Review similar widgets/gadgets** - Learn from working examples

---

## Key Files Reference

### Entry Points
| File | Purpose | Lines |
|------|---------|-------|
| `init.lua` | Global initialization | 73 |
| `luarules/main.lua` | LuaRules entry point | 10 |
| `luarules/gadgets.lua` | Gadget handler | 1,700+ |
| `luaui/main.lua` | LuaUI entry point | 152 |
| `luaui/barwidgets.lua` | Widget handler | 2,300+ |

### High-Value Gadgets
| File | Purpose |
|------|---------|
| `game_logger.lua` | Game event logging |
| `unit_interceptors.lua` | Anti-nuke interception logic |
| `api_resource_spot_finder.lua` | Metal spot detection |
| `game_tax_resource_sharing.lua` | Team resource sharing |
| `AILoader.lua` | AI bot loader |

### High-Value Widgets
| File | Purpose |
|------|---------|
| `widget_selector.lua` | Enable/disable widgets UI |
| `gui_*.lua` | Various GUI components |
| `api_*.lua` | Shared APIs (drawing, unit tracking, etc.) |

### Unit Definitions
Total: ~200+ units across factions
- Basic units: `units/ArmBots/armpw.lua`, `units/CorBots/corak.lua`
- Commanders: `armcom.lua`, `corcom.lua`
- Advanced units in `T2/` subdirectories

---

## Codebase Statistics

```
Total Files:           17,347
Lua Files:            ~2,075
Repository Size:       6.4 GB

LuaRules Gadgets:     ~200+
LuaUI Widgets:        ~200+
Total Lines (Lua):    ~177,000+ (gadgets + widgets alone)

Factions:              2 (Armada, Cortex)
Unit Count:           ~200+ unique units
```

---

## Architecture Patterns

### 1. Handler Pattern
Both gadgets and widgets use a central handler that:
- Discovers available modules
- Manages enable/disable state
- Routes engine call-ins
- Maintains execution order (layers)

### 2. Shared Globals
- **GG** (Gadget Globals): `gadgetHandler.GG`
- **WG** (Widget Globals): `widgetHandler.WG`
- Allows inter-module communication

### 3. VFS (Virtual File System)
```lua
VFS.Include(path, env, mode)
-- mode: VFS.ZIP_ONLY, VFS.RAW_FIRST
```
- Abstracts file loading from archives or raw files
- Dev mode uses `VFS.RAW_FIRST` for hot reload

### 4. Synced/Unsynced Split
- Critical for multiplayer determinism
- LuaRules = synced (all clients must agree)
- LuaUI = unsynced (local only)
- Communication via:
  - `SendToUnsynced()` / `SendToSynced()`
  - Game/Team RulesParams

---

## Recommended Reading Order

For new developers:

1. **Start Here:**
   - `README.md` - Setup instructions
   - `init.lua` - See what's loaded globally
   - `modinfo.lua` - Game metadata

2. **Understand Structure:**
   - `luarules/main.lua` → `gadgets.lua`
   - `luaui/main.lua` → `barwidgets.lua`
   - Pick one simple gadget: `unit_interceptors.lua`
   - Pick one simple widget: `camera_fov_changer.lua`

3. **Explore Units:**
   - `units/ArmBots/armpw.lua` - Simple unit
   - `units/ArmBuildings/LandEconomy/armsolar.lua` - Building

4. **Deep Dive:**
   - Browse `luarules/gadgets/` for game mechanics
   - Browse `luaui/Widgets/` for UI features
   - Check `common/` for utility functions

---

## External Resources

- **Official Website:** https://www.beyondallreason.info
- **GitHub Org:** https://github.com/beyond-all-reason
- **Discord:** Listed in README badges
- **Spring Engine Wiki:** https://springrts.com/wiki (Recoil is a fork)
- **Engine Structure:** https://springrts.com/wiki/Gamedev:Structure

---

## Notes for AI Assistants (Claude)

### Code Safety
- This is a legitimate open-source game project
- All code reviewed appears to be standard game logic
- No malicious patterns detected
- Safe to analyze, document, and assist with development

### Common Tasks
1. **Adding Units:** Copy existing unit in `units/`, modify stats
2. **New Gadgets:** Copy gadget template, add to `luarules/gadgets/`
3. **New Widgets:** Copy widget template, add to `luaui/Widgets/`
4. **Modifying Game Rules:** Edit gadgets in `luarules/gadgets/`
5. **UI Changes:** Edit widgets in `luaui/Widgets/`

### Performance Considerations
- Gadgets run in synced simulation, must be deterministic
- Widgets can use GPU for rendering
- Both run every frame - optimize hot paths
- Cache API calls, use local variables

### Testing Changes
- No build step required (Lua is interpreted)
- Edit files → Restart match → See changes
- Use `/luarules reload` and `/luaui reload` for some changes
- Full restart needed for init code changes

---

**Document maintained by:** Claude (AI Assistant)
**For:** Beyond All Reason development community
**Version:** 1.0
