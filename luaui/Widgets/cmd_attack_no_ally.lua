local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Attack no Ally",
		desc = "Redirects attack on allies to ground and fully exits attack mode on RMB press",
		author = "Ceddral, Floris (modified by Zain M)",
		date = "April 2018 (modified December 2025)",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

local hasRightClickAttack = {
	[CMD.ATTACK] = true,
}

-- Armed by an RMB press while the attack command is active; the RMB-issued
-- unit-target ATTACK that results from that click is then swallowed in
-- CommandNotify so the click acts as a cancel instead.
--
-- NOTE: this widget never owns the mouse (MousePress returns false), so the
-- widget handler never delivers MouseMove/MouseRelease to it. The flag is
-- therefore cleared from Update() as soon as RMB is no longer held, instead of
-- from a MouseRelease callin that would never fire. Without that, a formation
-- drag (orders issued via UnitCommandNotify, bypassing CommandNotify) or an RMB
-- ground click (no order at all) left the flag armed and the *next* attack
-- command was silently eaten.
local rmbCancelPending = false

local function GetAllyTarget(cmdParams)
	if #cmdParams ~= 1 then
		return nil
	end
	local targetUnitID = cmdParams[1]
	if Spring.IsUnitAllied(targetUnitID) then
		return targetUnitID
	end
	return nil
end

local function IssueGroundCommand(cmdID, cmdOptions)
	local mx, my = Spring.GetMouseState()
	local _, pos = Spring.TraceScreenRay(mx, my, true)

	if pos and pos[1] then
		Spring.GiveOrder(cmdID, { pos[1], pos[2], pos[3] }, cmdOptions or {})
		return true
	end
	return false
end

function widget:Initialize()
	WG.attacknoally = true
end

function widget:Shutdown()
	WG.attacknoally = nil
end

-- Right mouse button
function widget:MousePress(x, y, button)
	-- Every new press starts from a clean state
	rmbCancelPending = false

	if button ~= 3 then
		return false
	end

	if WG.attacknoally then
		local _, activeCmdID = Spring.GetActiveCommand()
		if activeCmdID and hasRightClickAttack[activeCmdID] then
			rmbCancelPending = true
		end
	end
	return false
end

function widget:Update()
	if not rmbCancelPending then
		return
	end
	-- Input events (and any CommandNotify they trigger) are processed before
	-- Update each frame, so once RMB reads as released here the click is over.
	local _, _, _, _, rmb = Spring.GetMouseState()
	if not rmb then
		rmbCancelPending = false
	end
end

-- Command interception
-- This portion is required to make sure that attack commands on allies aims at ground which ally is standing on.
-- Without this, units just follow the ally around.
function widget:CommandNotify(cmdID, cmdParams, cmdOptions)
	if cmdID ~= CMD.ATTACK then
		return false
	end

	-- RMB click on a unit while attack is active: cancel the command instead of
	-- issuing the attack. Only an RMB-issued, unit-targeted order qualifies; a
	-- left-click attack (right=false) or a path/formation waypoint (3 params)
	-- must never be mistaken for the cancel click.
	if rmbCancelPending and cmdOptions.right and #cmdParams == 1 then
		rmbCancelPending = false
		Spring.SetActiveCommand(nil)
		return true
	end

	local allyTarget = GetAllyTarget(cmdParams)
	-- Only intercept unit-target attacks against allied units
	if not allyTarget then
		return false
	end
	if not IssueGroundCommand(cmdID, cmdOptions) then
		Spring.SetActiveCommand(nil)
	end
	return true
end
