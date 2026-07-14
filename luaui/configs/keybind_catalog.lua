-- Hand-curated catalog of commands for the in-game keybind editor, lifted from
-- the original Keybind/Mouse Info "Keybindings" tab so categorisation + labels
-- match what players already know.
--
-- Entry kinds:
--   { action = "<bind command>", label = "<i18n key>" }  editable (chips + rebind)
--   { label = "<i18n key>", keyLabel = "<i18n key>" }     informational, read-only
--   { prefix = "<action prefix>" }                        groups every bound action whose
--                                                          id starts with prefix, by raw id
--
-- action strings are the bindable form (command + space-separated args), i.e.
-- exactly what `/bind <keyset> <action>` expects and what Spring.GetKeyBindings
-- reports as command(+extra). Anything bound but not listed here is shown by the
-- editor under an "Other" section, so nothing is ever hidden.

return {
	{ category = "ui.keybinds.chat.title", items = {
		{ action = "chat", label = "ui.keybinds.chat.send" },
		{ label = "ui.keybinds.chat.allies", keyLabel = "ui.keybinds.chat.alliesKey" },
		{ label = "ui.keybinds.chat.spectators", keyLabel = "ui.keybinds.chat.spectatorsKey" },
		{ label = "ui.keybinds.chat.ignore", keyLabel = "ui.keybinds.chat.ignoreKey" },
		{ prefix = "chatswitch" },
	} },

	{ category = "ui.keybinds.menus.title", items = {
		{ action = "options", label = "ui.keybinds.menus.settings" },
		{ action = "sharedialog", label = "ui.keybinds.menus.share" },
	} },

	{ category = "ui.keybinds.camera.title", items = {
		{ label = "ui.keybinds.camera.zoom", keyLabel = "ui.keybinds.camera.zoomKey" },
		{ label = "ui.keybinds.camera.pan", keyLabel = "ui.keybinds.camera.panKey" },
		{ label = "ui.keybinds.camera.tilt", keyLabel = "ui.keybinds.camera.tiltKey" },
		{ label = "ui.keybinds.camera.drag", keyLabel = "ui.keybinds.camera.dragKey" },
		{ action = "cameraflip", label = "ui.keybinds.camera.flip" },
	} },

	{ category = "ui.keybinds.cameraModes.title", items = {
		{ action = "viewspring", label = "ui.keybinds.cameraModes.change" },
		{ action = "toggleoverview", label = "ui.keybinds.cameraModes.overview" },
	} },

	{ category = "ui.keybinds.mapViews.title", items = {
		{ action = "togglelos", label = "ui.keybinds.cameraModes.los" },
		{ action = "showelevation", label = "ui.keybinds.cameraModes.heightmap" },
		{ action = "showpathtraversability", label = "ui.keybinds.cameraModes.traversability" },
		{ action = "showmetalmap", label = "ui.keybinds.cameraModes.resourceSpots" },
	} },

	{ category = "ui.keybinds.drawing.title", items = {
		{ label = "ui.keybinds.drawing.mapmark", keyLabel = "ui.keybinds.drawing.mapmarkKey" },
		{ label = "ui.keybinds.drawing.draw", keyLabel = "ui.keybinds.drawing.drawKey" },
		{ label = "ui.keybinds.drawing.erase", keyLabel = "ui.keybinds.drawing.eraseKey" },
		{ action = "drawinmap", label = "ui.keybinds.drawing.drawInMap" },
		{ action = "drawlabel", label = "ui.keybinds.drawing.drawLabel" },
		{ action = "clearmapmarks", label = "ui.keybinds.console.erase" },
		{ action = "lastmsgpos", label = "ui.keybinds.cameraModes.mapmarks" },
	} },

	{ category = "ui.keybinds.interfaceDisplay.title", items = {
		{ action = "hideinterface", label = "ui.keybinds.cameraModes.interface" },
		{ action = "fullscreen", label = "ui.keybinds.cameraModes.fullscreen" },
	} },

	{ category = "ui.keybinds.sound.title", items = {
		{ action = "mutesound", label = "ui.keybinds.sound.mute" },
		{ action = "snd_volume_increase", label = "ui.keybinds.sound.volumeUp" },
		{ action = "snd_volume_decrease", label = "ui.keybinds.sound.volumeDown" },
	} },

	{ category = "ui.keybinds.selection.title", items = {
		{ label = "ui.keybinds.selection.units", keyLabel = "ui.keybinds.selection.unitsKey" },
	} },

	{ category = "ui.keybinds.massSelect.title", items = {
		{ action = "select AllMap++_ClearSelection_SelectAll+", label = "ui.keybinds.massSelect.all" },
		{ action = "select AllMap+_Builder_Idle+_ClearSelection_SelectOne+", label = "ui.keybinds.massSelect.builders" },
		{ action = "select AllMap+_InPrevSel+_ClearSelection_SelectAll+", label = "ui.keybinds.massSelect.sameType" },
		{ action = "select Visible+_InPrevSel+_ClearSelection_SelectAll+", label = "ui.keybinds.massSelect.sameTypeVisible" },
		{ action = "select PrevSelection+_Not_Building_Not_RelativeHealth_60+_ClearSelection_SelectAll+", label = "ui.keybinds.massSelect.damaged" },
		{ action = "select PrevSelection++_ClearSelection_SelectPart_50+", label = "ui.keybinds.massSelect.half" },
		{ action = "select AllMap+_Transport_Idle+_ClearSelection_SelectAll+", label = "ui.keybinds.massSelect.idleTransports" },
		{ action = "select Visible+_Waiting+_ClearSelection_SelectAll+", label = "ui.keybinds.massSelect.waitingVisible" },
		{ action = "select AllMap++_ClearSelection_SelectNum_0+", label = "ui.keybinds.massSelect.deselectAll" },
	} },

	{ category = "ui.keybinds.controlGroups.title", items = {
		{ prefix = "group " },
		{ prefix = "add_to_autogroup " },
		{ action = "remove_from_autogroup", label = "ui.keybinds.massSelect.removeAutoGroup" },
		{ prefix = "load_autogroup_preset " },
	} },

	{ category = "ui.keybinds.issueContextOrders.title", items = {
		{ label = "ui.keybinds.issueContextOrders.order", keyLabel = "ui.keybinds.issueContextOrders.orderKey" },
		{ label = "ui.keybinds.issueContextOrders.formationOrder", keyLabel = "ui.keybinds.issueContextOrders.formationOrderKey" },
	} },

	{ category = "ui.keybinds.issueOrders.title", items = {
		{ label = "ui.keybinds.issueOrders.order", keyLabel = "ui.keybinds.issueOrders.orderKey" },
		{ label = "ui.keybinds.issueOrders.revert", keyLabel = "ui.keybinds.issueOrders.revertKey" },
		{ label = "ui.keybinds.issueOrders.formation", keyLabel = "ui.keybinds.issueOrders.formationKey" },
	} },

	{ category = "ui.keybinds.orders.title", items = {
		{ action = "move", label = "ui.keybinds.orders.move" },
		{ action = "attack", label = "ui.keybinds.orders.attack" },
		{ action = "settarget", label = "ui.keybinds.orders.setTarget" },
		{ action = "repair", label = "ui.keybinds.orders.repair" },
		{ action = "reclaim", label = "ui.keybinds.orders.reclaim" },
		{ action = "resurrect", label = "ui.keybinds.orders.resurrect" },
		{ action = "fight", label = "ui.keybinds.orders.fight" },
		{ action = "patrol", label = "ui.keybinds.orders.patrol" },
		{ action = "wantcloak", label = "ui.keybinds.orders.cloak" },
		{ action = "stop", label = "ui.keybinds.orders.stop" },
		{ action = "wait", label = "ui.keybinds.orders.wait" },
		{ action = "canceltarget", label = "ui.keybinds.orders.cancelTarget" },
		{ action = "manualfire", label = "ui.keybinds.orders.dGun" },
		{ action = "selfd", label = "ui.keybinds.orders.selfDestruct" },
	} },

	{ category = "ui.keybinds.moreOrders.title", items = {
		{ prefix = "areaattack" },
		{ prefix = "guard" },
		{ prefix = "capture" },
		{ prefix = "restore" },
		{ prefix = "settargetnoground" },
		{ prefix = "loadunits" },
		{ prefix = "unloadunits" },
		{ prefix = "gatherwait" },
		{ prefix = "manuallaunch" },
		{ prefix = "stopproduction" },
	} },

	{ category = "ui.keybinds.queues.title", items = {
		{ label = "ui.keybinds.queues.append", keyLabel = "ui.keybinds.queues.appendKey" },
		{ action = "commandinsert prepend_between", label = "ui.keybinds.queues.prepend" },
		{ prefix = "command_skip_current" },
		{ prefix = "command_cancel_last" },
	} },

	{ category = "ui.keybinds.unitStates.title", items = {
		{ prefix = "firestate " },
		{ prefix = "movestate " },
		{ prefix = "onoff " },
		{ prefix = "repeat " },
		{ prefix = "trajectory_toggle " },
	} },

	{ category = "ui.keybinds.buildOrders.title", items = {
		{ label = "ui.keybinds.buildOrders.selectTile", keyLabel = "ui.keybinds.buildOrders.selectTileKey" },
		{ action = "buildfacing inc", label = "ui.keybinds.buildOrders.rotate" },
		{ action = "buildfacing dec", label = "ui.keybinds.buildOrders.rotateBack" },
	} },

	{ category = "ui.keybinds.issueBuildOrders.title", items = {
		{ label = "ui.keybinds.issueBuildOrders.order", keyLabel = "ui.keybinds.issueBuildOrders.orderKey" },
		{ label = "ui.keybinds.issueBuildOrders.deselect", keyLabel = "ui.keybinds.issueBuildOrders.deselect" },
		{ label = "ui.keybinds.issueBuildOrders.line", keyLabel = "ui.keybinds.issueBuildOrders.lineKey" },
		{ label = "ui.keybinds.issueBuildOrders.grid", keyLabel = "ui.keybinds.issueBuildOrders.gridKey" },
		{ action = "buildspacing inc", label = "ui.keybinds.issueBuildOrders.spacingUp" },
		{ action = "buildspacing dec", label = "ui.keybinds.issueBuildOrders.spacingDown" },
	} },

	{ category = "ui.keybinds.gridMenu.title", items = {
		{ action = "gridmenu_category 1", label = "ui.buildMenu.category_econ" },
		{ action = "gridmenu_category 2", label = "ui.buildMenu.category_combat" },
		{ action = "gridmenu_category 3", label = "ui.buildMenu.category_utility" },
		{ action = "gridmenu_category 4", label = "ui.buildMenu.category_production" },
		{ prefix = "gridmenu_key" },
		{ prefix = "gridmenu_next_page" },
		{ prefix = "gridmenu_cycle_builder" },
	} },

	{ category = "ui.keybinds.factory.title", items = {
		{ prefix = "factory_preset" },
		{ prefix = "factoryqueuemode" },
		{ prefix = "factoryguard " },
	} },

	{ category = "ui.keybinds.gameControl.title", items = {
		{ prefix = "increasespeed" },
		{ prefix = "decreasespeed" },
		{ action = "pause", label = "ui.keybinds.console.pause" },
	} },

	{ category = "ui.keybinds.spectating.title", items = {
		{ prefix = "specteam " },
	} },

	{ category = "ui.keybinds.blueprints.title", items = {
		{ prefix = "blueprint_" },
	} },
}
