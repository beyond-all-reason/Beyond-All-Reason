# BAR Zombie Defense (Beyond All Reason Fork)

A standalone **Beyond All Reason / Recoil Engine** fork featuring an **Autonomous Military RTT vs. Continuous Zombie Horde** defense mode — zero individual unit micro-control, high-command air support, GL4 instanced laser sights, 360° TPS orbit camera, and a Minimap-congruent FlowUI command rail.

## Key Features

- **100% Autonomous Military AI (Zero Individual Unit Control):**
  - Both synced (`gadget:AllowCommand`) and client-side (`widget:CommandNotify`) locks keep infantry, MRAPs, and M1 Abrams tanks operating autonomously with Garrison, Patrol, Search & Destroy, Retreat, Morale, and Last Stand states.
  - HQ bunker deploys at the map's official Team 0 Start Position on verified flat, passable terrain (`TestBuildOrder` / `TestMoveOrder`) and mobilizes ground infantry reinforcements from HQ.
- **Continuous Zombie Horde & Combat Physics:**
  - Four zombie archetypes (`Walker`, `Infected Soldier`, `Volatile Bloater`, `Heavy Brute`) with surge waves, infection conversion of fallen soldiers, directional explosion knockback, airborne gibbing, and piece-level dismemberment.
- **High-Command Air Support:**
  - Persistent orbiting **AC-130 / C-130 Gunship** (20mm Vulcan + 105mm Howitzer + Armored reinforcement drops), **A-10 Thunderbolt II** 30mm GAU-8 low-altitude trench strafe, and **F-16V Strike Fighter** steep dive AGM missile & napalm cluster strikes.
- **GL4 Instanced 3-Color Tactical Laser Sights (`luaui/Widgets/gfx_zdef_laser_sights_gl4.lua`):**
  - Single-draw-call `#version 330` instanced camera-facing billboard laser ribbons with scrolling pulse texture and additive bloom: **Green** (Infantry), **Blue** (Tank & MRAP), **Red** (Aircraft).
- **Minimap-Congruent FlowUI Vertical HUD (`luaui/Widgets/gui_zombie_defense_hud.lua`):**
  - Pixel-locked to BAR's native Minimap geometry & FlowUI glass frame with a clean 2-tab layout:
    - **Tab 1 (`CHIẾN DỊCH`):** Telemetry, HQ HP, 3 uniform quick-action toggles (`Auto-Support`, `Full Sight/Fog`, `Camera`), Air Support deck (`[1..3]`), and live **3D Unit Scanner**.
    - **Tab 2 (`HIỂN THỊ & DEBUG [F8]`):** **Output Resolution Lock** (`720P`..`4K` — defaults to `1080P` with anti-4K boot guard across `FULL • SCALE`, `BORDERLESS`, and `WINDOWED`), HUD Scale (`0.5x`..`2x`), **16 live graphics debug toggle switches**, FPS presets, and elevation/pathability terrain debug overlays.

## Controls & Hotkeys

| Key | Action |
| --- | --- |
| `1` / `2` / `3` | Call Armored C-130 Drop / A-10 30mm Strafe / F-16V AGM & Napalm |
| `0` | Toggle Auto-Support AI |
| `5` | Toggle Full Map Sight / Fog of War |
| `T` | Toggle 360° Third-Person Orbit Camera (Right/Middle-drag or WASD to orbit, Mouse Wheel to zoom, `T`/`ESC` to exit) |
| `F8` | Switch to Display, Output Resolution & Graphics Debug Tab |
| `F11` | Cycle Display Mode (`FULL • SCALE` / `BORDERLESS` / `WINDOWED`) |
| `[` / `]` | Decrease / Increase FlowUI Scale |
| `Tab` | Overview Camera |

## How to Run on Recoil Engine

1. Clone this repository into `<recoil-engine-dir>/games/bar-zombie-defense.sdd` (checkout branch `zombie-defense`).
2. Copy `examples/_script_zombie_defense.txt` to `<recoil-engine-dir>/_script_zombie_defense.txt` (ensure map `Pinewood_Derby_V1` or another BAR map is in `<recoil-engine-dir>/maps/`).
3. Launch Recoil Engine:
   ```bat
   spring.exe --write-dir . _script_zombie_defense.txt
   ```

## License

Inherits upstream **Beyond All Reason** licensing (`GNU GPL v2 or later` for game code/Lua scripts).
