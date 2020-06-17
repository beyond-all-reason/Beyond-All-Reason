--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  file:    callins.lua
--  brief:   array and map of call-ins
--  author:  Dave Rodgers
--
--  Copyright (C) 2007.
--  Licensed under the terms of the GNU GPL, v2 or later.
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

CallInsList = {

  "Shutdown",
  "LayoutButtons",
  "ConfigureLayout",
  "CommandNotify",

  "KeyPress",
  "KeyRelease",
  "MouseMove",
  "MousePress",
  "MouseRelease",
  "IsAbove",
  "GetTooltip",
  "AddConsoleLine",
  "GroupChanged",

  "GamePreload",
  "GameStart",
  "GameOver",
  "TeamDied",

  "UnitCreated",
  "UnitFinished",
  "UnitFromFactory",
  "UnitDestroyed",
  "UnitTaken",
  "UnitGiven",
  "UnitCommand",
  "UnitIdle",
  "UnitSeismicPing",
  "UnitEnteredWater",
  "UnitEnteredAir",
  "UnitLeftWater",
  "UnitLeftAir",
  "UnitEnteredRadar",
  "UnitEnteredLos",
  "UnitLeftRadar",
  "UnitLeftLos",
  "UnitLoaded",
  "UnitUnloaded",
  "UnitCloaked",
  "UnitDecloaked",

  "ShieldPreDamaged",

  "FeatureCreated",
  "FeatureDestroyed",

  "ProjectileCreated",
  "ProjectileDestroyed",

  "DrawGenesis",
  "DrawWorld",
  "DrawWorldPreUnit",
  "DrawWorldShadow",
  "DrawWorldReflection",
  "DrawWorldRefraction",
  "DrawScreenEffects",
  "DrawScreen",
  "DrawInMiniMap",
  "DrawUnit",

  "SunChanged",

  "Explosion",
  "ShockFront",

  "GameFrame",
  "CobCallback",
  "AllowCommand",
  "CommandFallback",
  "AllowUnitCreation",
  "AllowUnitTransfer",
  "AllowUnitTransport",
  "AllowUnitTransportLoad",
  "AllowUnitTransportUnload",
  "AllowUnitBuildStep",
  "AllowUnitCloak",
  "AllowUnitDecloak",
  "AllowFeatureCreation",
  "AllowFeatureBuildStep",
  "AllowResourceLevel",
  "AllowResourceTransfer",
  "MoveCtrlNotify",
  "TerraformComplete",
  "UnsyncedHeightMapUpdate"
}


-- make the map
CallInsMap = {}
for _, callin in ipairs(CallInsList) do
  CallInsMap[callin] = true
end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
