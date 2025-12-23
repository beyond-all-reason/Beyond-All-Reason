local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name         = "No fire on own units (full cancel)",
		desc         = "Redirects attack on allies to ground and fully exits attack mode on RMB",
		author       = "Ceddral, Floris (modified)",
		date         = "April 2018 (modified Dec 2025)",
		license      = "GNU GPL, v2 or later",
		layer        = 0,
		enabled      = true
	}
end

------------------------------------------------------------
-- Helpers
------------------------------------------------------------

local function ExitAttackMode()
	-- STOP clears queued commands
	Spring.GiveOrder(CMD.STOP, {}, {})
	-- This clears the active command cursor (THIS is the key fix)
	Spring.SetActiveCommand(0)
end

local function IssueGroundAttack(cmdOptions)
	local mx, my = Spring.GetMouseState()
	local _, pos = Spring.TraceScreenRay(mx, my, true)

	if pos and pos[1] then
		Spring.GiveOrder(CMD.ATTACK, { pos[1], pos[2], pos[3] }, cmdOptions or {})
		return true
	end
	return false
end

------------------------------------------------------------
-- Widget lifecycle
------------------------------------------------------------

function widget:Initialize()
	WG['attacknoally'] = true
	WG['manualfirennoally'] = true
	WG['guardnoally'] = true
end

function widget:Shutdown()
	WG['attacknoally'] = nil
	WG['manualfirennoally'] = nil
	WG['guardnoally'] = nil
end

------------------------------------------------------------
-- Mouse handling
------------------------------------------------------------

function widget:MousePress(x, y, button)
	-- Right mouse button
	if button ~= 3 then
		return false
	end

	local _, activeCmdID = Spring.GetActiveCommand()

	if activeCmdID == CMD.ATTACK then
		ExitAttackMode()
		return true -- swallow RMB so engine doesn't re-trigger commands
	end

	return false
end

------------------------------------------------------------
-- Command interception
------------------------------------------------------------

function widget:CommandNotify(cmdID, cmdParams, cmdOptions)
	if cmdID == CMD.ATTACK then
		-- Ground attack = 3 params; only intercept unit-target attacks
		if #cmdParams ~= 1 then
			return false
		end

		local targetUnitID = cmdParams[1]
		if not Spring.IsUnitAllied(targetUnitID) then
			return false
		end

		-- Redirect attack on allied unit → ground attack
		if not IssueGroundAttack(cmdOptions) then
			ExitAttackMode()
		end
		return true

	elseif cmdID == CMD.MANUALFIRE then
		if #cmdParams == 1 and Spring.IsUnitAllied(cmdParams[1]) then
			ExitAttackMode()
			return true
		end
		return false

	elseif cmdID == CMD.GUARD then
		if #cmdParams == 1 and Spring.IsUnitAllied(cmdParams[1]) then
			ExitAttackMode()
			return true
		end
		return false
	end

	return false
end
