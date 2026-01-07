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
local rmbDragTracking = false
local rmbDragged = false
local rmbStartX, rmbStartY = 0, 0
local rmbDragThresholdSq = 0

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
			rmbCancelPending = true
			rmbDragTracking = true
			rmbDragged = false
			rmbStartX, rmbStartY = x, y
			local dragThreshold = Spring.GetConfigInt("MouseDragFrontCommandThreshold") or 20
			rmbDragThresholdSq = dragThreshold * dragThreshold
		end
	end
	return false
end
function widget:MouseMove(x, y, dx, dy, button)
	if not rmbDragTracking or button ~= 3 then
		return false
	end

	local distSq = (x - rmbStartX)^2 + (y - rmbStartY)^2
	if distSq >= rmbDragThresholdSq then
		rmbDragged = true
	end
	return false
end

function widget:MouseRelease(x, y, button)
	if button ~= 3 then
		return false
	end

	rmbDragTracking = false
	if rmbDragged then
		rmbCancelPending = false
		rmbDragged = false
		return false
	end

	rmbCancelPending = false
	rmbDragged = false
	return false
end

-- Command interception
-- This portion is required to make sure that attack commands on allies aims at ground which ally is standing on.
-- Without this, units just follow the ally around.
function widget:CommandNotify(cmdID, cmdParams, cmdOptions)
	if cmdID == CMD.ATTACK and rmbCancelPending and not rmbDragged then
		rmbCancelPending = false
		rmbDragTracking = false
		rmbDragged = false
		Spring.SetActiveCommand(nil)
		return true
	end

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
