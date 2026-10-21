-- Immediately after the UI is present and usable and before any interactive gameplay,
-- or when the mission leaves editor mode (editorMode in missionoptions).
-- Loadouts are spawned and the initial stage is active.
-- Some effects may take a single frame to occur; we may miss them here at frame 0.
return {
	type = 'MissionStarted',
	parameters = {},
	callins = {
		GameStart = function(trigger, triggerID, context)
			context.ActivateTrigger(trigger)
		end,
	},
}
