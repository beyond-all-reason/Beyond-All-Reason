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

local hasRightClickAttack = {
	[CMD.ATTACK] = true,
	[CMD.MANUALFIRE] = true,
}

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

local function IssueGroundAttack(cmdOptions)
	local mx, my = Spring.GetMouseState()
	local _, pos = Spring.TraceScreenRay(mx, my, true)

	if pos and pos[1] then
		Spring.GiveOrder(CMD.ATTACK, { pos[1], pos[2], pos[3] }, cmdOptions or {})
		return true
	end
	return false
end


function widget:Initialize()
	WG['attacknoally'] = true
	WG['manualfirennoally'] = true
end

function widget:Shutdown()
	WG['attacknoally'] = nil
	WG['manualfirennoally'] = nil
end

function widget:MousePress(x, y, button)
	-- Right mouse button
	if button ~= 3 then
		return false
	end

	if WG['attacknoally'] then
		local _, activeCmdID = Spring.GetActiveCommand()
		if activeCmdID and hasRightClickAttack[activeCmdID] then
			Spring.SetActiveCommand(nil)
			return true -- swallow RMB so engine doesn't re-trigger commands
		end
	end

	return false
end
-- Command interception
-- This portion is required to make sure that attack commands on allies aims at ground which ally is standing on.
function widget:CommandNotify(cmdID, cmdParams, cmdOptions)
	local allyTarget = GetAllyTarget(cmdParams)
	if cmdID == CMD.ATTACK then
		-- Only intercept unit-target attacks against allied units.
		if not allyTarget then
			return false
		end
		if not IssueGroundAttack(cmdOptions) then
			Spring.SetActiveCommand(nil)
		end
		return true
	elseif cmdID == CMD.MANUALFIRE then
		if allyTarget then
			Spring.SetActiveCommand(nil)
			return true
		end
		return false
	end
	return false
end
