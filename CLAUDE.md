# Beyond All Reason - Codebase Documentation

**Repository:** https://github.com/beyond-all-reason/Beyond-All-Reason
**Game Engine:** Recoil (fork of Spring RTS Engine)

---

## Overview

Beyond All Reason (BAR) is an open-source RTS game built on the Recoil engine.

**Primary Language:** Lua
**License:** GNU GPL v2+ (code), various Creative Commons licenses (assets - see LICENSE.md)

**Components:**
- **Game Code** (this repository) - Game logic, units, UI
- **Lobby/Launcher** ([BYAR-Chobby](https://github.com/beyond-all-reason/BYAR-Chobby))
- **Recoil Engine** (https://github.com/beyond-all-reason/spring)

---

## Architecture

### Lua Execution Contexts

BAR uses the Spring/Recoil engine's Lua execution model with separate contexts:

1. **LuaRules** (`luarules/`)
   - Synced code (runs identically on all clients)
   - Game logic, unit behavior, economy
   - Uses **Gadgets** (modular plugins in `luarules/gadgets/`)

2. **LuaUI** (`luaui/`)
   - Unsynced code (local client only)
   - User interface, graphics, input
   - Uses **Widgets** (modular UI components in `luaui/Widgets/`)

3. **LuaIntro** (`luaintro/`)
   - Intro sequences

4. **LuaAI** (defined in `luaai.lua`)
   - AI bot definitions

---

## Directory Structure

```
Beyond-All-Reason/
├── common/             # Shared Lua utilities
├── gamedata/           # Core game data definitions
├── init.lua            # Global initialization
├── luarules/           # Game rules and logic (synced)
│   ├── gadgets/        # Game logic modules
│   ├── gadgets.lua     # Gadget handler
│   └── main.lua        # LuaRules entry point
├── luaui/              # User interface (unsynced)
│   ├── Widgets/        # UI components
│   ├── barwidgets.lua  # Widget handler
│   └── main.lua        # LuaUI entry point
├── luaintro/           # Intro sequence code
├── luaai.lua           # AI bot definitions
├── modoptions.lua      # Game mode options/settings
├── modinfo.lua         # Game metadata
├── units/              # Unit definitions
│   ├── ArmBots/
│   ├── ArmBuildings/
│   ├── ArmVehicles/
│   ├── ArmAircraft/
│   ├── CorBots/
│   ├── CorBuildings/
│   ├── CorVehicles/
│   ├── CorAircraft/
│   ├── Legion/
│   └── ...
├── weapons/            # Weapon definitions
├── objects3d/          # 3D models (.s3o)
├── scripts/            # Unit animations (.cob, .lua)
├── bitmaps/            # Textures, sprites
├── effects/            # Particle effects
├── shaders/            # GLSL shaders
└── sounds/             # Sound effects
```

---

## Core Systems

### Gadget System (LuaRules)

**Location:** `luarules/gadgets/`

Gadgets are modular game logic components:
- Each has a `GetInfo()` function with metadata
- Can be enabled/disabled
- Hook into engine call-ins (events)
- Communicate via `GG` (Gadget Globals) table

**Handler:** `luarules/gadgets.lua`

### Widget System (LuaUI)

**Location:** `luaui/Widgets/`

Widgets are modular UI components:
- Similar structure to gadgets
- Handle rendering, input, HUD
- Communicate via `WG` (Widget Globals) table

**Handler:** `luaui/barwidgets.lua`

### Unit Definitions

**Location:** `units/`

Units are defined in Lua tables organized by faction and type.

### Common Utilities

**Location:** `common/`

Shared libraries loaded by `init.lua`:
- `numberfunctions.lua`
- `stringFunctions.lua`
- `tablefunctions.lua`
- `springFunctions.lua`
- `platformFunctions.lua`

---

## Key Concepts

### Synced vs Unsynced

- **Synced** (LuaRules): Code must be deterministic, runs identically on all clients
- **Unsynced** (LuaUI): Local only, can access client-specific data (mouse, camera, etc.)

### VFS (Virtual File System)

Files are loaded via VFS (Virtual File System):
```lua
VFS.Include(path, env, mode)
```

---

## External Resources

- **Official Website:** https://www.beyondallreason.info
- **GitHub Organization:** https://github.com/beyond-all-reason
- **Spring Engine Wiki:** https://springrts.com/wiki
- **Engine Documentation:** https://springrts.com/wiki/Gamedev:Structure
