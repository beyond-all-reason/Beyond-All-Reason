-------------------------------------------------------------------------------
-- Squad Selection -- playstyle presets
--
-- Pulled in via: VFS.Include("luaui/Include/squad_selection_presets.lua")
-- Read by unit_squad_selection.lua (applies them) and by gui_options.lua
-------------------------------------------------------------------------------

return {
	names = { "minimal", "autogroup", "squad", "custom" },

	values = {
		-- Least surprising way to use the widget
		minimal = {
			cyclingToNextSquad = false,
			leftClickAppendFiltersDomain = false,
			leftClickAlternativeSelection = false,
			mergeIntoReserves = true,
			rightClickSquadCreate = false,
			ctrlRightClickCreatesSquad = false,
			ctrlRightClickDragCreatesSquad = true,
			rightClickMoveControlsReserves = false,
			showReserveSquads = false,
			visualizationMode = "convexHull",
			squadColorMode = "player",
		},
		-- For players who mostly filter their group selections and only occasionally build a manual squad.
		autogroup = {
			cyclingToNextSquad = true,
			leftClickAppendFiltersDomain = true,
			leftClickAlternativeSelection = false,
			mergeIntoReserves = true,
			rightClickSquadCreate = false,
			ctrlRightClickCreatesSquad = false,
			ctrlRightClickDragCreatesSquad = true,
			rightClickMoveControlsReserves = false,
			showReserveSquads = true,
			visualizationMode = "convexHull",
			squadColorMode = "player",
		},
		-- For players who create and merge manual squads constantly
		squad = {
			cyclingToNextSquad = true,
			leftClickAppendFiltersDomain = true,
			leftClickAlternativeSelection = true,
			mergeIntoReserves = false,
			rightClickSquadCreate = true,
			ctrlRightClickCreatesSquad = false,
			ctrlRightClickDragCreatesSquad = false,
			rightClickMoveControlsReserves = true,
			showReserveSquads = true,
			visualizationMode = "convexHull",
			squadColorMode = "squad",
		},
		custom = {},
	},
}
