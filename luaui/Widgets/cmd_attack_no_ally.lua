local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name         = "Attack no Ally",
		desc         = "Redirects attack on allies to ground and fully exits attack mode on RMB press",
		author       = "Ceddral, Floris (modified by Zain M)",
		date         = "April 2018 (modified December 2025)",
		license      = "GNU GPL, v2 or later",
		layer        = 0,
		enabled      = true
	}
end

local hasRightClickAttack = {
	[CMD.ATTACK] = true,
}

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
	WG['attacknoally'] = true
end

function widget:Shutdown()
	WG['attacknoally'] = nil
end
	-- Right mouse button
function widget:MousePress(x, y, button)

	if button ~= 3 then
		return false
	end

	if WG['attacknoally'] then
		local _, activeCmdID = Spring.GetActiveCommand()
		if activeCmdID and hasRightClickAttack[activeCmdID] then
			local targetType, targetID = Spring.TraceScreenRay(x, y, false)
			if targetType == "unit" and Spring.IsUnitAllied(targetID) then
				Spring.SetActiveCommand(nil)
				rmbCancelPending = false
				return true
			end
			rmbCancelPending = true
		end
	end
	return false
end
--if right mouse button was pressed to cancel an attack command, wait for it to be released to actually cancel. 
--Allows players to drag right click for line attacks.
function widget:Update()
	if not rmbCancelPending then
		return
	end

	local _, _, _, _, rmb = Spring.GetMouseState()
	if rmb then
		return
	end

	rmbCancelPending = false
	if WG['attacknoally'] then
		local _, activeCmdID = Spring.GetActiveCommand()
		if activeCmdID and hasRightClickAttack[activeCmdID] then
			Spring.SetActiveCommand(nil)
		end
	end
end
-- Command interception
-- This portion is required to make sure that attack commands on allies aims at ground which ally is standing on.
-- Without this, units just follow the ally around.
function widget:CommandNotify(cmdID, cmdParams, cmdOptions)
	local allyTarget = GetAllyTarget(cmdParams)
	if cmdID == CMD.ATTACK then
		-- Only intercept unit-target attacks against allied units
		if not allyTarget then
			return false
		end
		if not IssueGroundCommand(cmdID, cmdOptions) then
			Spring.SetActiveCommand(nil)
		end
		return true
	end
	return false
end
