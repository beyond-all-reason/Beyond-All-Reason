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
	"TextInput",
	"TextEditing",
	"MouseMove",
	"MousePress",
	"MouseRelease",
	"JoyAxis",
	"JoyHat",
	"JoyButtonDown",
	"JoyButtonUp",
	"IsAbove",
	"GetTooltip",
	"AddConsoleLine",
	"GroupChanged",
	"WorldTooltip",

	"GameLoadLua",
	"GameStartPlaying",
	"GameOver",
	"TeamDied",

	"UnitCreated",
	"UnitFinished",
	"UnitFromFactory",
	"UnitReverseBuilt",
	"UnitDestroyed",
	"RenderUnitDestroyed",
	"UnitTaken",
	"UnitGiven",
	"UnitIdle",
	"UnitCommand",
	"UnitSeismicPing",
	"UnitEnteredRadar",
	"UnitEnteredLos",
	"UnitLeftRadar",
	"UnitLeftLos",
	"UnitLoaded",
	"UnitUnloaded",
	"UnitHarvestStorageFull",

	"UnitEnteredWater",
	"UnitEnteredAir",
	"UnitLeftWater",
	"UnitLeftAir",

	"FeatureCreated",
	"FeatureDestroyed",

	"DrawGenesis",
	"DrawWater",
	"DrawSky",
	"DrawSun",
	"DrawGrass",
	"DrawTrees",
	"DrawWorld",
	"DrawWorldPreUnit",
	"DrawWorldPreParticles",
	"DrawWorldShadow",
	"DrawWorldReflection",
	"DrawWorldRefraction",
	"DrawGroundPreForward",
	"DrawGroundPostForward",
	"DrawGroundPreDeferred",
	"DrawGroundPostDeferred",
	"DrawUnitsPostDeferred",
	"DrawFeaturesPostDeferred",
	"DrawScreenEffects",
	"DrawScreenPost",
	"DrawScreen",
	"DrawInMiniMap",

	"SunChanged",

	"Explosion",
	"ShockFront",

	"RecvSkirmishAIMessage",

	"GameFrame",
	"CobCallback",
	"AllowCommand",
	"CommandFallback",
	"AllowUnitCreation",
	"AllowUnitTransfer",
	"AllowUnitBuildStep",
	"AllowFeatureCreation",
	"AllowFeatureBuildStep",
	"AllowResourceLevel",
	"AllowResourceTransfer",

	"GameProgress",
	"Pong",

	"DownloadQueued",
	"DownloadStarted",
	"DownloadFinished",
	"DownloadFailed",
	"DownloadProgress",
}


-- make the map
CallInsMap = {}
for _, callin in ipairs(CallInsList) do
  CallInsMap[callin] = true
end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
