--------------------------------------------------------------------------------
-- IceUI commands menu - icon mapping
--------------------------------------------------------------------------------
-- Maps a command's `action` name to an icon file name. The icon file must
-- exist in the IceUI icon folder (LuaUI/Images/iceui/) so the IceUI-GL4 host
-- packs it into the shared atlas at startup.
--
-- A command listed here is drawn with its icon (text label hidden). A command
-- NOT listed -- or whose icon file is missing from the atlas -- falls back to
-- a plain text label. So this table can grow incrementally as icons are added.
--
-- To add an icon:
--   1. drop the image (e.g. move.png) into LuaUI/Images/iceui/
--   2. add a line here:  move = "move.png",
--   3. restart BAR (new files need a VFS reindex)
--
-- The keys are command action names as reported by Spring.GetActiveCmdDescs().
-- Common ones: move, stop, attack, patrol, fight, guard, wait, repair,
-- reclaim, resurrect, capture, restore, settarget, canceltarget, areamex,
-- selfd, wantcloak, manualfire (D-Gun), onoff, repeat, movestate, firestate.
--------------------------------------------------------------------------------

return {
	-- Mapped icons (images present in LuaUI/Images/iceui/):
	move      = "move.png",
	attack    = "attack.png",
	fight     = "fight.png",
	capture   = "capture.png",
	guard     = "defend.png",     -- BAR's "Guard" order; image named defend.png
	repair    = "repair.png",
	reclaim   = "reclaim.png",
	restore   = "restore.png",
	resurrect = "revive.png",     -- BAR's "Resurrect" order; image named revive.png
	settarget = "settarget.png",
	patrol    = "patrol.png",
	wait      = "wait.png",

	-- Add more as icon images become available, for example:
	-- stop      = "stop.png",
	-- selfd     = "selfdestruct.png",
	-- wantcloak = "cloak.png",
	-- manualfire = "dgun.png",
}
