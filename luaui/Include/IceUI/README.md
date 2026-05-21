# IceUI-GL4

A performance-focused UI framework for Beyond All Reason, rebuilding the FlowUI
menus on instanced GL4 rendering.

## Why

FlowUI's immediate-mode drawing and rmlui are too costly for menus with many
interactive elements. IceUI draws the whole UI in **one instanced draw call**
with a cached VBO — it only rebuilds when content changes, so a static menu
costs almost nothing per frame.

## Strengths

- **One draw call.** All rounded-rect UI elements are GPU instances; the SDF
  (signed-distance-field) fragment shader does rounded corners, gradients,
  borders, gloss and hover/press tint per-instance.
- **CSS-like styling.** Every menu is described in one data-driven stylesheet
  (`luaui/configs/iceui_styles.lua`); look and spacing are tweaked without
  touching draw code.
- **Cheap interaction.** Hover/press is a shader uniform with a cross-fade
  animation — it never rebuilds the VBO.
- **Cached engine textures.** Buildpics render once into an offscreen texture
  (FlowUI's trick) and blit as a single quad per frame.

## Architecture

Four layers, plus a host widget:

| File | Role |
|------|------|
| `core_gl4.lua` | Instanced GL4 renderer — geometry + shader only. |
| `style.lua`    | Resolves the CSS-like stylesheets (named styles, inheritance, states). |
| `layout.lua`   | Grid / row / column geometry. |
| `iceui.lua`    | Facade + the `Panel` object widgets build their UI with. |

`luaui/Widgets/iceui_gl4.lua` is the **host widget** that owns the single shared
renderer and exposes `WG.IceUI`. Consumer widgets do not create their own
VBO/shader — they register draw callbacks and queue elements into the shared
renderer.

A consumer widget, each frame:

```lua
panel:begin(mx, my, mouseDown)
panel:box("mainContainer", rect)
panel:button(id, "cell", rect, label)
panel:finish()
```

…and the host flushes everything in one instanced draw.

## Rebuilt on IceUI-GL4

- **Commands menu** (`gui_iceui_ordermenu.lua`)
- **Build menu** (`gui_iceui_buildmenu.lua`)
- **Info panel** (`gui_iceui_info.lua`) — selected-unit view

All three dock together in the bottom-left corner.

## Notes

- New files need a full game restart for VFS indexing; editing an existing file
  only needs an F11 widget reload.
- Any per-frame draw phase must allocate zero tables — use module-scope scratch
  tables (the profiler counts per-second garbage).
