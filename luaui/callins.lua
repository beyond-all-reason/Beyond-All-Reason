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
	"ActiveCommandChanged",
	"CameraRotationChanged",
	"CameraPositionChanged",
	"CommandNotify",

	"KeyPress",
	"KeyRelease",
	"TextInput",
	"TextEditing",
	"MouseMove",
	"MousePress",
	"MouseRelease",

	"ControllerAdded",
	"ControllerRemoved",
	"ControllerConnected",
	"ControllerDisconnected",
	"ControllerRemapped",
	"ControllerButtonUp",
	"ControllerButtonDown",
	"ControllerAxisMotion",

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
	"UnitDestroyedByTeam",
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

	"MetaUnitAdded",
	"MetaUnitRemoved",

	"FeatureCreated",
	"FeatureDestroyed",

	"DrawGenesis",
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

	"DrawOpaqueUnitsLua",
	"DrawOpaqueFeaturesLua",
	"DrawAlphaUnitsLua",
	"DrawAlphaFeaturesLua",
	"DrawShadowUnitsLua",
	"DrawShadowFeaturesLua",

	"FontsChanged",

	"SunChanged",

	"ShockFront",

	"RecvSkirmishAIMessage",

	"GameFrame",
	"CobCallback",
	"AllowCommand",
	"CommandFallback",
	"AllowUnitCreation",
	"AllowUnitTransfer",
	"AllowUnitBuildStep",
	"AllowUnitCaptureStep",
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

	"LanguageChanged",

	"UnitSale",
	"UnitSold",

	"VisibleExplosion",
	"Barrelfire",
	"CrashingAircraft",
	"ClearMapMarks",
}

CallInsMap = {}
for _, callin in ipairs(CallInsList) do
  CallInsMap[callin] = true
end
