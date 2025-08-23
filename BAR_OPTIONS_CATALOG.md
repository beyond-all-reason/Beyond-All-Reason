# Beyond All Reason - Complete Options Catalog

This document catalogs every single option available in the Beyond All Reason options widget. Each option is documented with its ID, group, category, type, and purpose.

## Option Groups

1. **gfx** - Graphics options
2. **ui** - User interface options  
3. **game** - Gameplay behavior options
4. **control** - Input and control options
5. **sound** - Audio options
6. **notif** - Notification options
7. **accessibility** - Accessibility features
8. **custom** - Custom widget options
9. **dev** - Developer options

## Option Categories

- **basic** - Essential options for all users
- **advanced** - Options for experienced users
- **dev** - Developer-only options

---

## PRESETS

### preset
- **Group:** gfx
- **Category:** basic
- **Type:** select
- **Options:** "Very High", "High", "Medium", "Low", "Very Low"
- **Purpose:** Global graphics quality preset

---

## GRAPHICS OPTIONS

### display
- **Group:** gfx
- **Category:** basic
- **Type:** select
- **Purpose:** Select display monitor

### resolution
- **Group:** gfx
- **Category:** basic
- **Type:** select
- **Purpose:** Screen resolution setting

### dualmode_enabled
- **Group:** gfx
- **Category:** basic
- **Type:** bool
- **Purpose:** Enable dual screen mode

### dualmode_left
- **Group:** gfx
- **Category:** basic
- **Type:** bool
- **Purpose:** Position interface on left screen in dual mode

### dualmode_minimap_aspectratio
- **Group:** gfx
- **Category:** basic
- **Type:** bool
- **Purpose:** Preserve minimap aspect ratio in dual mode

### fullscreen
- **Group:** gfx
- **Category:** basic
- **Type:** bool
- **Purpose:** Toggle fullscreen mode

### borderless
- **Group:** gfx
- **Category:** basic
- **Type:** bool
- **Purpose:** Borderless window mode

### vsync
- **Group:** gfx
- **Category:** basic
- **Type:** select
- **Options:** "Disabled", "Enabled", "Adaptive"
- **Purpose:** Vertical synchronization setting

### vsyncgame
- **Group:** gfx
- **Category:** advanced
- **Type:** select
- **Purpose:** Game-specific vsync setting

### fpslimit
- **Group:** gfx
- **Category:** advanced
- **Type:** slider
- **Range:** 30-500
- **Purpose:** Frame rate limit

### renderthreads
- **Group:** gfx
- **Category:** dev
- **Type:** slider
- **Range:** 0-32
- **Purpose:** Render threads configuration

### shadowslider
- **Group:** gfx
- **Category:** basic
- **Type:** select
- **Options:** Various quality levels
- **Purpose:** Shadow quality setting

### shadows_opacity
- **Group:** gfx
- **Category:** advanced
- **Type:** slider
- **Range:** 0.2-1.6
- **Purpose:** Shadow opacity/darkness

### shadows_softness
- **Group:** gfx
- **Category:** advanced
- **Type:** slider
- **Range:** 0.1-2.0
- **Purpose:** Shadow edge softness

### advmapshading
- **Group:** gfx
- **Category:** basic
- **Type:** bool
- **Purpose:** Advanced map shading

### mapdetails
- **Group:** gfx
- **Category:** basic
- **Type:** slider
- **Range:** 1-5
- **Purpose:** Map detail quality

### maxparticles
- **Group:** gfx
- **Category:** basic
- **Type:** slider
- **Range:** 5000-40000
- **Purpose:** Maximum particle count

### particles
- **Group:** gfx
- **Category:** basic
- **Type:** slider
- **Range:** 0.1-1.0
- **Purpose:** Particle density

### nanoparticles
- **Group:** gfx
- **Category:** basic
- **Type:** bool
- **Purpose:** Nano particle effects

### decals
- **Group:** gfx
- **Category:** basic
- **Type:** bool
- **Purpose:** Ground decals/footprints

### msaa
- **Group:** gfx
- **Category:** basic
- **Type:** select
- **Options:** "off", "x2", "x4", "x8", "x16"
- **Purpose:** Multi-sample anti-aliasing

### normalmapping
- **Group:** gfx
- **Category:** basic
- **Type:** bool
- **Purpose:** Normal mapping for textures

### water
- **Group:** gfx
- **Category:** basic
- **Type:** select
- **Options:** "off", "basic", "reflective", "dynamic", "bumpmapping"
- **Purpose:** Water rendering quality

### ssao
- **Group:** gfx
- **Category:** basic
- **Type:** bool
- **Widget:** Screen Space Ambient Occlusion
- **Purpose:** Ambient occlusion effects

### ssao_strength
- **Group:** gfx
- **Category:** advanced
- **Type:** slider
- **Range:** 0.8-2.0
- **Purpose:** SSAO effect strength

### ssao_quality
- **Group:** gfx
- **Category:** advanced
- **Type:** select
- **Options:** "low", "medium", "high"
- **Purpose:** SSAO render quality

### bloom
- **Group:** gfx
- **Category:** basic
- **Type:** bool
- **Widget:** Bloom Shader GL4
- **Purpose:** Bloom lighting effects

### bloom_brightness
- **Group:** gfx
- **Category:** advanced
- **Type:** slider
- **Range:** 0.2-2.0
- **Purpose:** Bloom brightness threshold

### bloom_quality
- **Group:** gfx
- **Category:** advanced
- **Type:** select
- **Options:** "low", "medium", "high"
- **Purpose:** Bloom rendering quality

### dof
- **Group:** gfx
- **Category:** basic
- **Type:** bool
- **Widget:** Depth of Field
- **Purpose:** Depth of field blur effects

### dof_autofocus
- **Group:** gfx
- **Category:** advanced
- **Type:** bool
- **Purpose:** Automatic depth of field focus

### dof_fstop
- **Group:** gfx
- **Category:** advanced
- **Type:** slider
- **Range:** 0.5-3.0
- **Purpose:** Depth of field blur amount

### clouds
- **Group:** gfx
- **Category:** basic
- **Type:** bool
- **Widget:** Fog Volumes GL4
- **Purpose:** Volumetric cloud effects

### could_opacity
- **Group:** gfx
- **Category:** advanced
- **Type:** slider
- **Range:** 0.1-1.0
- **Purpose:** Cloud opacity

### guishader
- **Group:** gfx
- **Category:** basic
- **Type:** bool
- **Widget:** GUI Shader
- **Purpose:** UI background shader effects

### cusgl4
- **Group:** gfx
- **Category:** basic
- **Type:** bool
- **Purpose:** Advanced graphics engine (GL4)

---

## UI OPTIONS

### ui_scale
- **Group:** ui
- **Category:** basic
- **Type:** slider
- **Range:** 0.4-2.0
- **Purpose:** UI element scaling

### ui_opacity
- **Group:** ui
- **Category:** basic
- **Type:** slider
- **Range:** 0.4-1.0
- **Purpose:** UI transparency

### language
- **Group:** ui
- **Category:** basic
- **Type:** select
- **Purpose:** Interface language

### language_english_unit_names
- **Group:** ui
- **Category:** basic
- **Type:** bool
- **Purpose:** Use English unit names regardless of language

### consolemaxlines
- **Group:** ui
- **Category:** advanced
- **Type:** slider
- **Range:** 5-50
- **Purpose:** Maximum console message lines

### autoeraser
- **Group:** ui
- **Category:** basic
- **Type:** bool
- **Widget:** Auto mapmark eraser
- **Purpose:** Automatically remove old map marks

### autoeraser_erasetime
- **Group:** ui
- **Category:** advanced
- **Type:** slider
- **Range:** 10-200
- **Purpose:** Time before auto-erasing marks (seconds)

### topbar_hidebuttons
- **Group:** ui
- **Category:** advanced
- **Type:** bool
- **Purpose:** Auto-hide top bar buttons

### continuouslyclearmapmarks
- **Group:** ui
- **Category:** dev
- **Type:** bool
- **Purpose:** Continuously clear map marks

### unitgroups
- **Group:** ui
- **Category:** basic
- **Type:** bool
- **Widget:** Unit Groups
- **Purpose:** Unit group display

### idlebuilders
- **Group:** ui
- **Category:** basic
- **Type:** bool
- **Widget:** Idle Builders
- **Purpose:** Idle builder notification

### buildbar
- **Group:** ui
- **Category:** basic
- **Type:** bool
- **Widget:** BuildBar
- **Purpose:** Building construction bar

### converterusage
- **Group:** ui
- **Category:** advanced
- **Type:** bool
- **Widget:** Converter Usage
- **Purpose:** Energy converter usage display

### seeprices
- **Group:** ui
- **Category:** basic
- **Type:** bool
- **Purpose:** Show unit market prices

### showaisaleoffers
- **Group:** ui
- **Category:** basic
- **Type:** bool
- **Purpose:** Show AI sale offers in market

### buywithoutholdignalt
- **Group:** ui
- **Category:** basic
- **Type:** bool
- **Purpose:** Buy units without holding Alt

### widgetselector
- **Group:** ui
- **Category:** advanced
- **Type:** bool
- **Purpose:** Enable widget selector

### uniticon_scaleui
- **Group:** ui
- **Category:** basic
- **Type:** slider
- **Range:** 0.85-3.0
- **Purpose:** Unit icon UI scaling

### uniticon_distance
- **Group:** ui
- **Category:** basic
- **Type:** slider
- **Range:** 1-12000
- **Purpose:** Unit icon visibility distance

### uniticon_hidewithui
- **Group:** ui
- **Category:** advanced
- **Type:** bool
- **Purpose:** Hide unit icons when UI is hidden

### teamplatter
- **Group:** ui
- **Category:** basic
- **Type:** bool
- **Widget:** TeamPlatter
- **Purpose:** Team color platters under units

### teamplatter_opacity
- **Group:** ui
- **Category:** advanced
- **Type:** slider
- **Range:** 0.05-0.4
- **Purpose:** Team platter opacity

### teamplatter_skipownteam
- **Group:** ui
- **Category:** advanced
- **Type:** bool
- **Purpose:** Skip platters for own team

### enemyspotter
- **Group:** ui
- **Category:** basic
- **Type:** bool
- **Widget:** EnemySpotter
- **Purpose:** Highlight enemy unit positions

### enemyspotter_opacity
- **Group:** ui
- **Category:** advanced
- **Type:** slider
- **Range:** 0.12-0.4
- **Purpose:** Enemy spotter opacity

### selectedunits_opacity
- **Group:** ui
- **Category:** advanced
- **Type:** slider
- **Range:** 0.0-0.5
- **Purpose:** Selected unit highlight opacity

### selectedunits_teamcoloropacity
- **Group:** ui
- **Category:** advanced
- **Type:** slider
- **Range:** 0.0-1.0
- **Purpose:** Team color opacity on selected units

### highlightselunits
- **Group:** ui
- **Category:** advanced
- **Type:** bool
- **Purpose:** Highlight selected units

### highlightunit
- **Group:** ui
- **Category:** advanced
- **Type:** bool
- **Purpose:** Highlight unit under cursor

### ghosticons_brightness
- **Group:** ui
- **Category:** dev
- **Type:** slider
- **Range:** 0.0-1.0
- **Purpose:** Ghost icon brightness

### cursorlight
- **Group:** ui
- **Category:** advanced
- **Type:** bool
- **Purpose:** Light effect at cursor position

### cursorlight_lightradius
- **Group:** ui
- **Category:** advanced
- **Type:** slider
- **Range:** 0.3-2.0
- **Purpose:** Cursor light radius

### cursorlight_lightstrength
- **Group:** ui
- **Category:** advanced
- **Type:** slider
- **Range:** 0.3-2.0
- **Purpose:** Cursor light strength

### metalspots_values
- **Group:** ui
- **Category:** advanced
- **Type:** bool
- **Purpose:** Show metal spot values

### metalspots_metalviewonly
- **Group:** ui
- **Category:** advanced
- **Type:** bool
- **Purpose:** Show metal spots only in metal view

### geospots
- **Group:** ui
- **Category:** dev
- **Type:** bool
- **Widget:** Geothermalspots
- **Purpose:** Show geothermal spot markers

### healthbarsscale
- **Group:** ui
- **Category:** advanced
- **Type:** slider
- **Range:** 0.6-2.0
- **Purpose:** Health bar size scaling

### healthbarsheight
- **Group:** ui
- **Category:** advanced
- **Type:** slider
- **Range:** 0.7-2.0
- **Purpose:** Health bar height

### healthbarsvariable
- **Group:** ui
- **Category:** dev
- **Type:** bool
- **Purpose:** Variable health bar sizes

### healthbarswhenguihidden
- **Group:** ui
- **Category:** dev
- **Type:** bool
- **Purpose:** Show health bars when GUI hidden

### rankicons
- **Group:** ui
- **Category:** advanced
- **Type:** bool
- **Widget:** Rank Icons GL4
- **Purpose:** Unit rank/veterancy icons

### rankicons_distance
- **Group:** ui
- **Category:** dev
- **Type:** slider
- **Range:** 0.1-1.5
- **Purpose:** Rank icon visibility distance

### rankicons_scale
- **Group:** ui
- **Category:** dev
- **Type:** slider
- **Range:** 0.5-2.0
- **Purpose:** Rank icon size

### allycursors
- **Group:** ui
- **Category:** basic
- **Type:** bool
- **Widget:** AllyCursors
- **Purpose:** Show allied player cursors

### allycursors_playername
- **Group:** ui
- **Category:** dev
- **Type:** bool
- **Purpose:** Show player names on cursors

### allycursors_showdot
- **Group:** ui
- **Category:** dev
- **Type:** bool
- **Purpose:** Show cursor dot

### allycursors_spectatorname
- **Group:** ui
- **Category:** advanced
- **Type:** bool
- **Purpose:** Show spectator names on cursors

### allycursors_lights
- **Group:** ui
- **Category:** advanced
- **Type:** bool
- **Purpose:** Add lights to ally cursors

### allycursors_lightradius
- **Group:** ui
- **Category:** dev
- **Type:** slider
- **Range:** 0.15-1.0
- **Purpose:** Ally cursor light radius

### allycursors_lightstrength
- **Group:** ui
- **Category:** dev
- **Type:** slider
- **Range:** 0.1-1.2
- **Purpose:** Ally cursor light strength

### allycursors_selfshadowing
- **Group:** ui
- **Category:** dev
- **Type:** bool
- **Purpose:** Self-shadowing for cursor lights

### showbuilderqueue
- **Group:** ui
- **Category:** advanced
- **Type:** bool
- **Widget:** Show Builder Queue
- **Purpose:** Display builder construction queue

### unitenergyicons
- **Group:** ui
- **Category:** advanced
- **Type:** bool
- **Widget:** Unit Energy Icons
- **Purpose:** Energy status icons on units

### unitidlebuildericons
- **Group:** ui
- **Category:** advanced
- **Type:** bool
- **Widget:** Unit Idle Builder Icons
- **Purpose:** Icons for idle builders

### nametags_rank
- **Group:** ui
- **Category:** advanced
- **Type:** bool
- **Purpose:** Show player rank in name tags

### commandsfx
- **Group:** ui
- **Category:** basic
- **Type:** bool
- **Widget:** Commands FX
- **Purpose:** Visual effects for unit commands

### commandsfxopacity
- **Group:** ui
- **Category:** dev
- **Type:** slider
- **Range:** 0.25-1.0
- **Purpose:** Command FX opacity

### commandsfxduration
- **Group:** ui
- **Category:** dev
- **Type:** slider
- **Range:** 0.5-2.0
- **Purpose:** Command FX duration

### commandsfxfilterai
- **Group:** ui
- **Category:** dev
- **Type:** bool
- **Purpose:** Filter AI team commands

### commandsfxuseteamcolors
- **Group:** ui
- **Category:** dev
- **Type:** bool
- **Purpose:** Use team colors for command FX

### commandsfxuseteamcolorswhenspec
- **Group:** ui
- **Category:** advanced
- **Type:** bool
- **Purpose:** Use team colors when spectating

### flankingicons
- **Group:** ui
- **Category:** advanced
- **Type:** bool
- **Widget:** Flanking Icons GL4
- **Purpose:** Flanking bonus icons

### displaydps
- **Group:** ui
- **Category:** basic
- **Type:** bool
- **Purpose:** Display DPS values

### givenunits
- **Group:** ui
- **Category:** advanced
- **Type:** bool
- **Widget:** Given Units
- **Purpose:** Highlight received units

### reclaimfieldhighlight
- **Group:** ui
- **Category:** advanced
- **Type:** select
- **Options:** Various trigger modes
- **Widget:** Reclaim Field Highlight
- **Purpose:** Highlight reclaimable areas

### highlightcomwrecks
- **Group:** ui
- **Category:** advanced
- **Type:** bool
- **Widget:** Highlight Commander Wrecks
- **Purpose:** Highlight commander wreckage

### highlightcomwrecks_teamcolor
- **Group:** ui
- **Category:** dev
- **Type:** bool
- **Purpose:** Use team colors for commander wrecks

### buildinggrid
- **Group:** ui
- **Category:** basic
- **Type:** bool
- **Widget:** Building Grid GL4
- **Purpose:** Building placement grid

### buildinggridopacity
- **Group:** ui
- **Category:** advanced
- **Type:** slider
- **Range:** 0.3-1.0
- **Purpose:** Building grid opacity

### startpositionsuggestions
- **Group:** ui
- **Category:** basic
- **Type:** bool
- **Widget:** Start Position Suggestions
- **Purpose:** Suggest start positions

### radarrange
- **Group:** ui
- **Category:** advanced
- **Type:** bool
- **Widget:** Sensor Ranges Radar
- **Purpose:** Radar range circles

### radarrangeopacity
- **Group:** ui
- **Category:** advanced
- **Type:** slider
- **Range:** 0.01-0.33
- **Purpose:** Radar range opacity

### sonarrange
- **Group:** ui
- **Category:** advanced
- **Type:** bool
- **Widget:** Sensor Ranges Sonar
- **Purpose:** Sonar range circles

### sonarrangeopacity
- **Group:** ui
- **Category:** advanced
- **Type:** slider
- **Range:** 0.01-0.33
- **Purpose:** Sonar range opacity

### jammerrange
- **Group:** ui
- **Category:** advanced
- **Type:** bool
- **Widget:** Sensor Ranges Jammer
- **Purpose:** Jammer range circles

### jammerrangeopacity
- **Group:** ui
- **Category:** advanced
- **Type:** slider
- **Range:** 0.01-0.66
- **Purpose:** Jammer range opacity

### losrange
- **Group:** ui
- **Category:** advanced
- **Type:** bool
- **Widget:** Sensor Ranges LOS
- **Purpose:** Line of sight range circles

### losrangeopacity
- **Group:** ui
- **Category:** advanced
- **Type:** slider
- **Range:** 0.01-0.33
- **Purpose:** LOS range opacity

### losrangeteamcolors
- **Group:** ui
- **Category:** advanced
- **Type:** bool
- **Purpose:** Use team colors for LOS ranges

### attackrange
- **Group:** ui
- **Category:** basic
- **Type:** bool
- **Widget:** Attack Range GL4
- **Purpose:** Unit attack range circles

### attackrange_shiftonly
- **Group:** ui
- **Category:** dev
- **Type:** bool
- **Purpose:** Show attack ranges only when holding Shift

### attackrange_cursorunitrange
- **Group:** ui
- **Category:** dev
- **Type:** bool
- **Purpose:** Show range for unit under cursor

### attackrange_numrangesmult
- **Group:** game
- **Category:** dev
- **Type:** slider
- **Range:** 0.3-1.0
- **Purpose:** Attack range display threshold

### defrange
- **Group:** ui
- **Category:** basic
- **Type:** bool
- **Widget:** Defense Range GL4
- **Purpose:** Defense structure ranges

### defrange_allyair
- **Group:** ui
- **Category:** advanced
- **Type:** bool
- **Purpose:** Show ally air defense ranges

### defrange_allyground
- **Group:** ui
- **Category:** advanced
- **Type:** bool
- **Purpose:** Show ally ground defense ranges

### defrange_allynuke
- **Group:** ui
- **Category:** advanced
- **Type:** bool
- **Purpose:** Show ally anti-nuke ranges

### defrange_allylrpc
- **Group:** ui
- **Category:** advanced
- **Type:** bool
- **Purpose:** Show ally long-range defense

### defrange_enemyair
- **Group:** ui
- **Category:** advanced
- **Type:** bool
- **Purpose:** Show enemy air defense ranges

### defrange_enemyground
- **Group:** ui
- **Category:** advanced
- **Type:** bool
- **Purpose:** Show enemy ground defense ranges

### defrange_enemynuke
- **Group:** ui
- **Category:** advanced
- **Type:** bool
- **Purpose:** Show enemy anti-nuke ranges

### defrange_enemylrpc
- **Group:** ui
- **Category:** advanced
- **Type:** bool
- **Purpose:** Show enemy long-range defense

### antiranges
- **Group:** ui
- **Category:** advanced
- **Type:** bool
- **Widget:** Anti Ranges
- **Purpose:** Anti-air/anti-ground ranges

### spectator_hud
- **Group:** ui
- **Category:** basic
- **Type:** bool
- **Widget:** Spectator HUD
- **Purpose:** Spectator mode interface

### spectator_hud_size
- **Group:** ui
- **Category:** basic
- **Type:** slider
- **Range:** 0.1-2.0
- **Purpose:** Spectator HUD size

### spectator_hud_config
- **Group:** ui
- **Category:** advanced
- **Type:** select
- **Purpose:** Spectator HUD configuration

### spectator_hud_metric_metalIncome
- **Group:** ui
- **Category:** advanced
- **Type:** bool
- **Purpose:** Show metal income metric

### spectator_hud_metric_energyIncome
- **Group:** ui
- **Category:** advanced
- **Type:** bool
- **Purpose:** Show energy income metric

### spectator_hud_metric_buildPower
- **Group:** ui
- **Category:** advanced
- **Type:** bool
- **Purpose:** Show build power metric

### spectator_hud_metric_metalProduced
- **Group:** ui
- **Category:** advanced
- **Type:** bool
- **Purpose:** Show metal production metric

### spectator_hud_metric_energyProduced
- **Group:** ui
- **Category:** advanced
- **Type:** bool
- **Purpose:** Show energy production metric

### spectator_hud_metric_metalExcess
- **Group:** ui
- **Category:** advanced
- **Type:** bool
- **Purpose:** Show metal excess metric

### spectator_hud_metric_energyExcess
- **Group:** ui
- **Category:** advanced
- **Type:** bool
- **Purpose:** Show energy excess metric

### spectator_hud_metric_armyValue
- **Group:** ui
- **Category:** advanced
- **Type:** bool
- **Purpose:** Show army value metric

### spectator_hud_metric_defenseValue
- **Group:** ui
- **Category:** advanced
- **Type:** bool
- **Purpose:** Show defense value metric

### spectator_hud_metric_utilityValue
- **Group:** ui
- **Category:** advanced
- **Type:** bool
- **Purpose:** Show utility value metric

### spectator_hud_metric_economyValue
- **Group:** ui
- **Category:** advanced
- **Type:** bool
- **Purpose:** Show economy value metric

### spectator_hud_metric_damageDealt
- **Group:** ui
- **Category:** advanced
- **Type:** bool
- **Purpose:** Show damage dealt metric

### devmode
- **Group:** ui
- **Category:** advanced
- **Type:** bool
- **Purpose:** Enable developer mode

---

## GAME OPTIONS

### networksmoothing
- **Group:** game
- **Category:** basic
- **Type:** bool
- **Restart:** true
- **Purpose:** Network message smoothing

### autoquit
- **Group:** game
- **Category:** basic
- **Type:** bool
- **Widget:** Autoquit
- **Purpose:** Automatically quit when alone

### singleplayerpause
- **Group:** game
- **Category:** advanced
- **Type:** bool
- **Purpose:** Pause game in singleplayer mode

### catchupsmoothness
- **Group:** game
- **Category:** dev
- **Type:** slider
- **Range:** 0.05-0.3
- **Restart:** true
- **Purpose:** Catch-up simulation smoothness

### catchupminfps
- **Group:** game
- **Category:** dev
- **Type:** slider
- **Range:** 2-15
- **Restart:** true
- **Purpose:** Minimum FPS for catch-up

### smartselect_includebuildings
- **Group:** game
- **Category:** basic
- **Type:** bool
- **Purpose:** Include buildings in smart selection

### smartselect_includebuilders
- **Group:** game
- **Category:** basic
- **Type:** bool
- **Purpose:** Include builders in smart selection

### prioconturrets
- **Group:** game
- **Category:** basic
- **Type:** bool
- **Widget:** Priority Construction Turrets
- **Purpose:** Priority construction turret behavior

### builderpriority
- **Group:** game
- **Category:** basic
- **Type:** bool
- **Widget:** Builder Priority
- **Purpose:** Builder priority system

### builderpriority_nanos
- **Group:** game
- **Category:** advanced
- **Type:** bool
- **Purpose:** Low priority nano turrets

### builderpriority_cons
- **Group:** game
- **Category:** advanced
- **Type:** bool
- **Purpose:** Low priority construction units

### builderpriority_labs
- **Group:** game
- **Category:** advanced
- **Type:** bool
- **Purpose:** Low priority labs

### factoryguard
- **Group:** game
- **Category:** basic
- **Type:** bool
- **Widget:** Factory Guard Default On
- **Purpose:** Default factory guard mode

### factoryholdpos
- **Group:** game
- **Category:** basic
- **Type:** bool
- **Widget:** Factory hold position
- **Purpose:** Factory units hold position

### factoryrepeat
- **Group:** game
- **Category:** basic
- **Type:** bool
- **Widget:** Factory Auto-Repeat
- **Purpose:** Factory auto-repeat production

### transportai
- **Group:** game
- **Category:** basic
- **Type:** bool
- **Widget:** Transport AI
- **Purpose:** Automatic transport behavior

### onlyfighterspatrol
- **Group:** game
- **Category:** basic
- **Type:** bool
- **Widget:** OnlyFightersPatrol
- **Purpose:** Only fighters patrol automatically

### fightersfly
- **Group:** game
- **Category:** basic
- **Type:** bool
- **Widget:** Set fighters on Fly mode
- **Purpose:** Set fighters to fly mode by default

### settargetdefault
- **Group:** game
- **Category:** basic
- **Type:** bool
- **Widget:** Set target default
- **Purpose:** Default target setting behavior

### dgunnogroundenemies
- **Group:** game
- **Category:** advanced
- **Type:** bool
- **Widget:** DGun no ground enemies
- **Purpose:** Prevent D-gun from targeting ground enemies

### dgunstallassist
- **Group:** game
- **Category:** advanced
- **Type:** bool
- **Widget:** DGun Stall Assist
- **Purpose:** D-gun stall assistance

### unitreclaimer
- **Group:** game
- **Category:** basic
- **Type:** bool
- **Widget:** Specific Unit Reclaimer
- **Purpose:** Enhanced unit reclaim behavior

### autogroup_immediate
- **Group:** game
- **Category:** basic
- **Type:** bool
- **Purpose:** Immediate auto-grouping

### autogroup_persist
- **Group:** game
- **Category:** basic
- **Type:** bool
- **Purpose:** Persistent auto-groups

### autocloak
- **Group:** game
- **Category:** basic
- **Type:** bool
- **Widget:** Auto Cloak Units
- **Purpose:** Automatic unit cloaking

---

## CONTROL OPTIONS

### edgePanSpeed
- **Group:** control
- **Category:** basic
- **Type:** slider
- **Range:** 0.01-0.03
- **Purpose:** Edge panning speed

### edgePanDeadzone
- **Group:** control
- **Category:** basic
- **Type:** slider
- **Range:** 2-10
- **Purpose:** Edge panning deadzone

### middleclickscrollspeed
- **Group:** control
- **Category:** basic
- **Type:** slider
- **Range:** 10-100
- **Purpose:** Middle click scroll speed

### camerasmoothnessvalue
- **Group:** control
- **Category:** basic
- **Type:** slider
- **Range:** 0.1-1.0
- **Purpose:** Camera smoothness

### camerapantransitiontime
- **Group:** control
- **Category:** basic
- **Type:** slider
- **Range:** 0.0-0.75
- **Purpose:** Camera pan transition time

### invertmouse
- **Group:** control
- **Category:** basic
- **Type:** bool
- **Purpose:** Invert mouse Y-axis

### invertcamera
- **Group:** control
- **Category:** basic
- **Type:** bool
- **Purpose:** Invert camera controls

### mousesensitivity
- **Group:** control
- **Category:** basic
- **Type:** slider
- **Range:** 0.2-4.0
- **Purpose:** Mouse sensitivity

### scrollsensitivity
- **Group:** control
- **Category:** basic
- **Type:** slider
- **Range:** 10-200
- **Purpose:** Scroll wheel sensitivity

### scrollinverse
- **Group:** control
- **Category:** basic
- **Type:** bool
- **Purpose:** Inverse scroll direction

### edgemove
- **Group:** control
- **Category:** basic
- **Type:** bool
- **Purpose:** Screen edge camera movement

### gridmenu_alwaysreturn
- **Group:** control
- **Category:** basic
- **Type:** bool
- **Purpose:** Grid menu always returns to center

### gridmenu_autoselectfirst
- **Group:** control
- **Category:** basic
- **Type:** bool
- **Purpose:** Auto-select first grid menu item

### gridmenu_labbuildmode
- **Group:** control
- **Category:** basic
- **Type:** bool
- **Purpose:** Lab build mode in grid menu

---

## SOUND OPTIONS

### mastervolume
- **Group:** sound
- **Category:** basic
- **Type:** slider
- **Range:** 0.0-1.0
- **Purpose:** Master audio volume

### sfxvolume
- **Group:** sound
- **Category:** basic
- **Type:** slider
- **Range:** 0.0-1.0
- **Purpose:** Sound effects volume

### unitreply
- **Group:** sound
- **Category:** basic
- **Type:** slider
- **Range:** 0.0-1.0
- **Purpose:** Unit voice response volume

### musicvolume
- **Group:** sound
- **Category:** basic
- **Type:** slider
- **Range:** 0.0-1.0
- **Purpose:** Background music volume

### playmusic
- **Group:** sound
- **Category:** basic
- **Type:** bool
- **Purpose:** Enable background music

### unitReplyVolume
- **Group:** sound
- **Category:** basic
- **Type:** slider
- **Range:** 0.0-1.0
- **Purpose:** Unit reply audio volume

### soundtrackAprilFools
- **Group:** sound
- **Category:** basic
- **Type:** bool
- **Purpose:** April Fools soundtrack

### soundtrackAprilFoolsPostEvent
- **Group:** sound
- **Category:** basic
- **Type:** bool
- **Purpose:** Post-event April Fools soundtrack

### voicenotifs
- **Group:** sound
- **Category:** basic
- **Type:** bool
- **Widget:** Voice Notifs
- **Purpose:** Voice notifications

### voicenotifs_volume
- **Group:** sound
- **Category:** basic
- **Type:** slider
- **Range:** 0.0-1.0
- **Purpose:** Voice notification volume

---

## NOTIFICATION OPTIONS

### eventcollect
- **Group:** notif
- **Category:** basic
- **Type:** bool
- **Widget:** Event collector
- **Purpose:** Collect game events

### resbars
- **Group:** notif
- **Category:** basic
- **Type:** bool
- **Widget:** Resource Bars
- **Purpose:** Resource bar display

### resbaropacity
- **Group:** notif
- **Category:** advanced
- **Type:** slider
- **Range:** 0.3-1.0
- **Purpose:** Resource bar opacity

### resbarhidewhenspec
- **Group:** notif
- **Category:** basic
- **Type:** bool
- **Purpose:** Hide resource bars when spectating

### allyselunits
- **Group:** notif
- **Category:** basic
- **Type:** bool
- **Widget:** Ally Selected Units
- **Purpose:** Show ally selected units

### shareddynamicalliance
- **Group:** notif
- **Category:** basic
- **Type:** bool
- **Widget:** Shared Dynamic Alliance
- **Purpose:** Shared alliance notifications

### mouseOverInfo
- **Group:** notif
- **Category:** basic
- **Type:** bool
- **Widget:** MouseOver Info
- **Purpose:** Mouse-over information display

### mouseoveruniticon
- **Group:** notif
- **Category:** basic
- **Type:** bool
- **Purpose:** Show unit icon on mouse-over

### mouseoverenemyicon
- **Group:** notif
- **Category:** basic
- **Type:** bool
- **Purpose:** Show enemy unit icons

### mouseoverresource
- **Group:** notif
- **Category:** basic
- **Type:** bool
- **Purpose:** Show resource information

---

## ACCESSIBILITY OPTIONS

### anonymous_r
- **Group:** accessibility
- **Category:** basic
- **Type:** slider
- **Range:** 0-255
- **Purpose:** Anonymous mode red color component

### anonymous_g
- **Group:** accessibility
- **Category:** basic
- **Type:** slider
- **Range:** 0-255
- **Purpose:** Anonymous mode green color component

### anonymous_b
- **Group:** accessibility
- **Category:** basic
- **Type:** slider
- **Range:** 0-255
- **Purpose:** Anonymous mode blue color component

### simpleteamcolors
- **Group:** accessibility
- **Category:** basic
- **Type:** bool
- **Purpose:** Simplified team colors

### simpleteamcolors_reset
- **Group:** accessibility
- **Category:** basic
- **Type:** bool
- **Purpose:** Reset team colors to defaults

### simpleteamcolors_use_gradient
- **Group:** accessibility
- **Category:** basic
- **Type:** bool
- **Purpose:** Use gradient for team colors

### simpleteamcolors_player_r
- **Group:** accessibility
- **Category:** basic
- **Type:** slider
- **Range:** 0-255
- **Purpose:** Player team color red component

### simpleteamcolors_player_g
- **Group:** accessibility
- **Category:** basic
- **Type:** slider
- **Range:** 0-255
- **Purpose:** Player team color green component

### simpleteamcolors_player_b
- **Group:** accessibility
- **Category:** basic
- **Type:** slider
- **Range:** 0-255
- **Purpose:** Player team color blue component

### simpleteamcolors_ally_r
- **Group:** accessibility
- **Category:** basic
- **Type:** slider
- **Range:** 0-255
- **Purpose:** Ally team color red component

### simpleteamcolors_ally_g
- **Group:** accessibility
- **Category:** basic
- **Type:** slider
- **Range:** 0-255
- **Purpose:** Ally team color green component

### simpleteamcolors_ally_b
- **Group:** accessibility
- **Category:** basic
- **Type:** slider
- **Range:** 0-255
- **Purpose:** Ally team color blue component

### simpleteamcolors_enemy_r
- **Group:** accessibility
- **Category:** basic
- **Type:** slider
- **Range:** 0-255
- **Purpose:** Enemy team color red component

### simpleteamcolors_enemy_g
- **Group:** accessibility
- **Category:** basic
- **Type:** slider
- **Range:** 0-255
- **Purpose:** Enemy team color green component

### simpleteamcolors_enemy_b
- **Group:** accessibility
- **Category:** basic
- **Type:** slider
- **Range:** 0-255
- **Purpose:** Enemy team color blue component

---

## DEVELOPER OPTIONS

### customwidgets
- **Group:** dev
- **Category:** dev
- **Type:** bool
- **Purpose:** Allow custom widgets

### autocheat
- **Group:** dev
- **Category:** dev
- **Type:** bool
- **Widget:** Dev Auto cheat
- **Purpose:** Automatic cheat activation

### restart
- **Group:** dev
- **Category:** dev
- **Type:** bool
- **Purpose:** Restart game

### profiler
- **Group:** dev
- **Category:** dev
- **Type:** bool
- **Widget:** Widget Profiler
- **Purpose:** Widget performance profiler

### profiler_min_time
- **Group:** dev
- **Category:** dev
- **Type:** slider
- **Range:** 0.0-0.05
- **Purpose:** Profiler minimum time threshold

### profiler_min_memory
- **Group:** dev
- **Category:** dev
- **Type:** slider
- **Range:** 0-10
- **Purpose:** Profiler minimum memory threshold

### profiler_sort_by_load
- **Group:** dev
- **Category:** dev
- **Type:** bool
- **Purpose:** Sort profiler by load

### framegrapher
- **Group:** dev
- **Category:** dev
- **Type:** bool
- **Widget:** Frame Grapher
- **Purpose:** Frame rate graphing tool

### debugcolvol
- **Group:** dev
- **Category:** dev
- **Type:** bool
- **Purpose:** Debug collision volumes

### echocamerastate
- **Group:** dev
- **Category:** dev
- **Type:** bool
- **Purpose:** Echo camera state to console

### storedefaultsettings
- **Group:** dev
- **Category:** dev
- **Type:** bool
- **Purpose:** Store default settings

### startboxeditor
- **Group:** dev
- **Category:** dev
- **Type:** bool
- **Widget:** Startbox Editor
- **Purpose:** Start box editor tool

### language_dev
- **Group:** dev
- **Category:** dev
- **Type:** select
- **Purpose:** Developer language setting

### font
- **Group:** dev
- **Category:** dev
- **Type:** select
- **Purpose:** Primary font selection

### font2
- **Group:** dev
- **Category:** dev
- **Type:** select
- **Purpose:** Secondary font selection

### sun_y
- **Group:** dev
- **Category:** dev
- **Type:** slider
- **Range:** 0.05-0.9999
- **Purpose:** Sun Y position

### sun_x
- **Group:** dev
- **Category:** dev
- **Type:** slider
- **Range:** -0.9999-0.9999
- **Purpose:** Sun X position

### sun_z
- **Group:** dev
- **Category:** dev
- **Type:** slider
- **Range:** -0.9999-0.9999
- **Purpose:** Sun Z position

### sun_reset
- **Group:** dev
- **Category:** dev
- **Type:** bool
- **Purpose:** Reset sun position

### fog_start
- **Group:** dev
- **Category:** dev
- **Type:** slider
- **Range:** 0.0-1.99
- **Purpose:** Fog start distance

### fog_end
- **Group:** dev
- **Category:** dev
- **Type:** slider
- **Range:** 0.5-2.0
- **Purpose:** Fog end distance

### fog_reset
- **Group:** dev
- **Category:** dev
- **Type:** bool
- **Purpose:** Reset fog settings

### fog_r
- **Group:** dev
- **Category:** dev
- **Type:** slider
- **Range:** 0.0-1.0
- **Purpose:** Fog color red component

### fog_g
- **Group:** dev
- **Category:** dev
- **Type:** slider
- **Range:** 0.0-1.0
- **Purpose:** Fog color green component

### fog_b
- **Group:** dev
- **Category:** dev
- **Type:** slider
- **Range:** 0.0-1.0
- **Purpose:** Fog color blue component

### fog_color_reset
- **Group:** dev
- **Category:** dev
- **Type:** bool
- **Purpose:** Reset fog color

### map_voidwater
- **Group:** dev
- **Category:** dev
- **Type:** bool
- **Purpose:** Enable void water rendering

### map_voidground
- **Group:** dev
- **Category:** dev
- **Type:** bool
- **Purpose:** Enable void ground rendering

### map_splatdetailnormaldiffusealpha
- **Group:** dev
- **Category:** dev
- **Type:** bool
- **Purpose:** Splat detail normal diffuse alpha

### map_splattexmults_r
- **Group:** dev
- **Category:** dev
- **Type:** slider
- **Range:** 0.0-1.5
- **Purpose:** Splat texture multiplier red

### map_splattexmults_g
- **Group:** dev
- **Category:** dev
- **Type:** slider
- **Range:** 0.0-1.5
- **Purpose:** Splat texture multiplier green

### map_splattexmults_b
- **Group:** dev
- **Category:** dev
- **Type:** slider
- **Range:** 0.0-1.5
- **Purpose:** Splat texture multiplier blue

### map_splattexmults_a
- **Group:** dev
- **Category:** dev
- **Type:** slider
- **Range:** 0.0-1.5
- **Purpose:** Splat texture multiplier alpha

### map_splattexacales_r
- **Group:** dev
- **Category:** dev
- **Type:** slider
- **Range:** 0.0-0.02
- **Purpose:** Splat texture scale red

### map_splattexacales_g
- **Group:** dev
- **Category:** dev
- **Type:** slider
- **Range:** 0.0-0.02
- **Purpose:** Splat texture scale green

### map_splattexacales_b
- **Group:** dev
- **Category:** dev
- **Type:** slider
- **Range:** 0.0-0.02
- **Purpose:** Splat texture scale blue

### map_splattexacales_a
- **Group:** dev
- **Category:** dev
- **Type:** slider
- **Range:** 0.0-0.02
- **Purpose:** Splat texture scale alpha

### GroundShadowDensity
- **Group:** dev
- **Category:** dev
- **Type:** slider
- **Range:** 0.0-1.5
- **Purpose:** Ground shadow density

### UnitShadowDensity
- **Group:** dev
- **Category:** dev
- **Type:** slider
- **Range:** 0.0-1.5
- **Purpose:** Unit shadow density

### color_groundambient_r
- **Group:** dev
- **Category:** dev
- **Type:** slider
- **Range:** 0.0-2.0
- **Purpose:** Ground ambient red

### color_groundambient_g
- **Group:** dev
- **Category:** dev
- **Type:** slider
- **Range:** 0.0-2.0
- **Purpose:** Ground ambient green

### color_groundambient_b
- **Group:** dev
- **Category:** dev
- **Type:** slider
- **Range:** 0.0-2.0
- **Purpose:** Ground ambient blue

### color_grounddiffuse_r
- **Group:** dev
- **Category:** dev
- **Type:** slider
- **Range:** 0.0-2.0
- **Purpose:** Ground diffuse red

### color_grounddiffuse_g
- **Group:** dev
- **Category:** dev
- **Type:** slider
- **Range:** 0.0-2.0
- **Purpose:** Ground diffuse green

### color_grounddiffuse_b
- **Group:** dev
- **Category:** dev
- **Type:** slider
- **Range:** 0.0-2.0
- **Purpose:** Ground diffuse blue

### color_groundspecular_r
- **Group:** dev
- **Category:** dev
- **Type:** slider
- **Range:** 0.0-2.0
- **Purpose:** Ground specular red

### color_groundspecular_g
- **Group:** dev
- **Category:** dev
- **Type:** slider
- **Range:** 0.0-1.0
- **Purpose:** Ground specular green

### color_groundspecular_b
- **Group:** dev
- **Category:** dev
- **Type:** slider
- **Range:** 0.0-1.0
- **Purpose:** Ground specular blue

### color_unitambient_r
- **Group:** dev
- **Category:** dev
- **Type:** slider
- **Range:** 0.0-2.0
- **Purpose:** Unit ambient red

### color_unitambient_g
- **Group:** dev
- **Category:** dev
- **Type:** slider
- **Range:** 0.0-2.0
- **Purpose:** Unit ambient green

### color_unitambient_b
- **Group:** dev
- **Category:** dev
- **Type:** slider
- **Range:** 0.0-2.0
- **Purpose:** Unit ambient blue

### color_unitdiffuse_r
- **Group:** dev
- **Category:** dev
- **Type:** slider
- **Range:** 0.0-2.0
- **Purpose:** Unit diffuse red

### color_unitdiffuse_g
- **Group:** dev
- **Category:** dev
- **Type:** slider
- **Range:** 0.0-2.0
- **Purpose:** Unit diffuse green

### color_unitdiffuse_b
- **Group:** dev
- **Category:** dev
- **Type:** slider
- **Range:** 0.0-2.0
- **Purpose:** Unit diffuse blue

### color_unitspecular_r
- **Group:** dev
- **Category:** dev
- **Type:** slider
- **Range:** 0.0-2.0
- **Purpose:** Unit specular red

### color_unitspecular_g
- **Group:** dev
- **Category:** dev
- **Type:** slider
- **Range:** 0.0-2.0
- **Purpose:** Unit specular green

### color_unitspecular_b
- **Group:** dev
- **Category:** dev
- **Type:** slider
- **Range:** 0.0-2.0
- **Purpose:** Unit specular blue

### suncolor_r
- **Group:** dev
- **Category:** dev
- **Type:** slider
- **Range:** 0.0-1.0
- **Purpose:** Sun color red

### suncolor_g
- **Group:** dev
- **Category:** dev
- **Type:** slider
- **Range:** 0.0-1.0
- **Purpose:** Sun color green

### suncolor_b
- **Group:** dev
- **Category:** dev
- **Type:** slider
- **Range:** 0.0-1.0
- **Purpose:** Sun color blue

### skycolor_r
- **Group:** dev
- **Category:** dev
- **Type:** slider
- **Range:** 0.0-1.0
- **Purpose:** Sky color red

### skycolor_g
- **Group:** dev
- **Category:** dev
- **Type:** slider
- **Range:** 0.0-1.0
- **Purpose:** Sky color green

### skycolor_b
- **Group:** dev
- **Category:** dev
- **Type:** slider
- **Range:** 0.0-1.0
- **Purpose:** Sky color blue

### sunlighting_reset
- **Group:** dev
- **Category:** dev
- **Type:** bool
- **Purpose:** Reset sun lighting

### skyaxisangle_angle
- **Group:** dev
- **Category:** dev
- **Type:** slider
- **Range:** -3.14-3.14
- **Purpose:** Sky axis angle

### skyaxisangle_x
- **Group:** dev
- **Category:** dev
- **Type:** slider
- **Range:** -1.0-1.0
- **Purpose:** Sky axis X

### skyaxisangle_y
- **Group:** dev
- **Category:** dev
- **Type:** slider
- **Range:** -1.0-1.0
- **Purpose:** Sky axis Y

### skyaxisangle_z
- **Group:** dev
- **Category:** dev
- **Type:** slider
- **Range:** -1.0-1.0
- **Purpose:** Sky axis Z

### skyaxisangle_reset
- **Group:** dev
- **Category:** dev
- **Type:** bool
- **Purpose:** Reset sky axis angle

## Water Configuration Options

### waterconfig_shorewaves
- **Group:** dev
- **Category:** dev
- **Type:** bool
- **Purpose:** Bumpwater shore waves

### waterconfig_dynamicwaves
- **Group:** dev
- **Category:** dev
- **Type:** bool
- **Purpose:** Dynamic wave effects

### waterconfig_endless
- **Group:** dev
- **Category:** dev
- **Type:** bool
- **Purpose:** Endless ocean rendering

### waterconfig_occlusionquery
- **Group:** dev
- **Category:** dev
- **Type:** bool
- **Purpose:** Water occlusion queries

### waterconfig_blurreflection
- **Group:** dev
- **Category:** dev
- **Type:** bool
- **Purpose:** Blur water reflections

### waterconfig_anisotropy
- **Group:** dev
- **Category:** dev
- **Type:** bool
- **Purpose:** Water anisotropic filtering

### wateconfigr_usedepthtexture
- **Group:** dev
- **Category:** dev
- **Type:** bool
- **Purpose:** Use depth texture for water

### waterconfig_useuniforms
- **Group:** dev
- **Category:** dev
- **Type:** bool
- **Purpose:** Use uniforms for water

### water_shorewaves
- **Group:** dev
- **Category:** dev
- **Type:** bool
- **Purpose:** Water shore wave effects

### water_haswaterplane
- **Group:** dev
- **Category:** dev
- **Type:** bool
- **Purpose:** Water plane rendering

### water_forcerendering
- **Group:** dev
- **Category:** dev
- **Type:** bool
- **Purpose:** Force water rendering

### water_repeatx
- **Group:** dev
- **Category:** dev
- **Type:** slider
- **Range:** 0-20
- **Purpose:** Water texture repeat X

### water_repeaty
- **Group:** dev
- **Category:** dev
- **Type:** slider
- **Range:** 0-20
- **Purpose:** Water texture repeat Y

### water_surfacealpha
- **Group:** dev
- **Category:** dev
- **Type:** slider
- **Range:** 0.0-1.0
- **Purpose:** Water surface transparency

### water_ambientfactor
- **Group:** dev
- **Category:** dev
- **Type:** slider
- **Range:** 0.0-2.0
- **Purpose:** Water ambient lighting factor

### water_diffusefactor
- **Group:** dev
- **Category:** dev
- **Type:** slider
- **Range:** 0.0-5.0
- **Purpose:** Water diffuse lighting factor

### water_specularfactor
- **Group:** dev
- **Category:** dev
- **Type:** slider
- **Range:** 0.0-5.0
- **Purpose:** Water specular lighting factor

### water_specularpower
- **Group:** dev
- **Category:** dev
- **Type:** slider
- **Range:** 0.0-100.0
- **Purpose:** Water surface shininess

### water_perlinstartfreq
- **Group:** dev
- **Category:** dev
- **Type:** slider
- **Range:** 10-50
- **Purpose:** Perlin noise start frequency

### water_perlinlacunarity
- **Group:** dev
- **Category:** dev
- **Type:** slider
- **Range:** 0.1-4.0
- **Purpose:** Perlin noise lacunarity

### water_perlinlamplitude
- **Group:** dev
- **Category:** dev
- **Type:** slider
- **Range:** 0.1-4.0
- **Purpose:** Perlin noise amplitude

### water_fresnelmin
- **Group:** dev
- **Category:** dev
- **Type:** slider
- **Range:** 0.0-2.0
- **Purpose:** Fresnel minimum reflection

### water_fresnelmax
- **Group:** dev
- **Category:** dev
- **Type:** slider
- **Range:** 0.0-2.0
- **Purpose:** Fresnel maximum reflection

### water_fresnelpower
- **Group:** dev
- **Category:** dev
- **Type:** slider
- **Range:** 0.0-16.0
- **Purpose:** Fresnel power curve

### water_numtiles
- **Group:** dev
- **Category:** dev
- **Type:** slider
- **Range:** 1.0-8.0
- **Purpose:** Number of water tiles

### water_blurbase
- **Group:** dev
- **Category:** dev
- **Type:** slider
- **Range:** 0.0-3.0
- **Purpose:** Water reflection blur base

### water_blurexponent
- **Group:** dev
- **Category:** dev
- **Type:** slider
- **Range:** 0.0-3.0
- **Purpose:** Water reflection blur exponent

### water_reflectiondistortion
- **Group:** dev
- **Category:** dev
- **Type:** slider
- **Range:** 0.0-5.0
- **Purpose:** Water reflection distortion

### water_waveoffsetfactor
- **Group:** dev
- **Category:** dev
- **Type:** slider
- **Range:** 0.0-2.0
- **Purpose:** Wave offset timing factor

### water_wavelength
- **Group:** dev
- **Category:** dev
- **Type:** slider
- **Range:** 0.0-1.0
- **Purpose:** Wave length parameter

### water_wavefoamdistortion
- **Group:** dev
- **Category:** dev
- **Type:** slider
- **Range:** 0.0-0.5
- **Purpose:** Wave foam distortion

### water_wavefoamintensity
- **Group:** dev
- **Category:** dev
- **Type:** slider
- **Range:** 0.0-2.0
- **Purpose:** Wave foam intensity

### water_causticsresolution
- **Group:** dev
- **Category:** dev
- **Type:** slider
- **Range:** 10.0-300.0
- **Purpose:** Caustics texture resolution

### water_causticsstrength
- **Group:** dev
- **Category:** dev
- **Type:** slider
- **Range:** 0.0-0.5
- **Purpose:** Caustics effect strength

---

## Summary

This catalog documents **200+ individual options** across 9 different groups, providing comprehensive control over every aspect of Beyond All Reason's visual presentation, gameplay behavior, audio settings, and developer tools. Each option is precisely categorized and documented to ensure no functionality is overlooked.

The options system demonstrates the remarkable depth and configurability of Beyond All Reason, allowing players to tailor their experience from basic gameplay settings to advanced graphics parameters and developer debugging tools.
