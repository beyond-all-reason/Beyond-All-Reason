local widget = widget ---@type Widget

----------------------------------------------------------------
--  Configuration / Debug helpers
----------------------------------------------------------------
local DEBUG = true  -- set to false to silence all echoes
local function dbgEcho(...)
	if DEBUG then
		Spring.Echo("[PreserveCommands]", ...)
	end
end

function widget:GetInfo()
	return {
		name    = "Preserve Commands",
		desc    = "Restores a unit's command queue after transport, incl. unit‑target commands (with debug echoes)",
		author  = "Jazcash, Robert82",
		date    = "July 2025",
		license = "idklmao",
		layer   = 0,
		enabled = true
	}
end

----------------------------------------------------------------
--  Helpers
----------------------------------------------------------------

---Return Euclidean distance between two 3‑D points
local function distance3d(x1,y1,z1, x2,y2,z2)
	local dx,dy,dz = x1-x2, y1-y2, z1-z2
	return math.sqrt(dx*dx + dy*dy + dz*dz)
end

---Convert command params to a world‑space position.
---• xyz params     → xyz
---• single unitID  → unit's current xyz (nil if invalid/dead)
local function paramsToPos(params)
	local n = #params
	if n >= 3 then
		return params[1], params[2], params[3]
	elseif n == 1 then
		local tgt = params[1]
		if Spring.ValidUnitID(tgt) and not Spring.GetUnitIsDead(tgt) then
			return Spring.GetUnitPosition(tgt)
		end
	end
	return nil, nil, nil
end

----------------------------------------------------------------
--  Main bookkeeping
----------------------------------------------------------------
local orders = {}
local distToIgnore = 500 -- ignore first command if it is farther than this

function widget:UnitLoaded(unitID)
	orders[unitID] = Spring.GetUnitCommands(unitID, -1)
end


function widget:UnitUnloaded(unitID)
	local queue = orders[unitID]
	if (queue and #queue > 0) then
		local newOrders = {}
		local ux, uy, uz = Spring.GetUnitPosition(unitID)

		for i, cmd in ipairs(queue) do
			local keep = true

			-- First command: check distance from current unload spot
			if i == 1 then
				local px, py, pz = paramsToPos(cmd.params)
				if not px then
					keep = false
				else
					local dist = distance3d(ux, uy, uz, px, py, pz)
					if dist > distToIgnore then
						keep = false
					end
				end
			end
		end

		if keep then
			if #cmd.params == 1 then         -- unit‑target command
				local tgt = cmd.params[1]
				if Spring.ValidUnitID(tgt) and not Spring.GetUnitIsDead(tgt) then
					table.insert(newOrders, {cmd.id, {tgt}, cmd.options})
				end
			else                              -- xyz command
				table.insert(newOrders, {cmd.id, cmd.params, cmd.options})
			end
		end
	Spring.GiveOrderArrayToUnit(unitID, newOrders)
	
	orders[unitID] = nil
	end
end


---------------------------------------------------------------
--- Housekeeping to manage the widget state
---------------------------------------------------------------

local function maybeRemoveSelf()
	if Spring.IsReplay() or Spring.GetSpectatingState() and (Spring.GetGameFrame() > 0) then
		widgetHandler:RemoveWidget()
	end
end

function widget:Initialize()
	maybeRemoveSelf()
end

function widget:GameStart()
	maybeRemoveSelf()
end

function widget:PlayerChanged()
	maybeRemoveSelf()
end
