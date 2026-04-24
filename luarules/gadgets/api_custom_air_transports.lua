
local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name    = "Transport Handler API",
		desc    = "Sets up global functions and tables used by transport related scripts and gadgetry",
		author  = "DoodVanDaag",
		date    = "2026",
		license = "GNU GPL, v2 or later",
		layer   = -1, -- must be < 0: before unit_script and transport handler gadgets
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return false
end

if Spring.GetModOptions and Spring.GetModOptions().beta_tractorbeam == false then
	Spring.Echo("Custom transports disabled via modoption, skipping transport API gadget")
	return false
end

GG.TransportAPI = {}
local TransportAPI = GG.TransportAPI
local cachedUnitSizes = {}

TransportAPI.precomputedProgress = {}
for uDefID, def in pairs(UnitDefs) do
	if def.customParams and def.customParams.loadtime then
		local loadTime = tonumber(def.customParams.loadtime)
		local curve = {}
		for f = 0, loadTime do
			local t = f / loadTime
			if t < 0.5 then
				curve[f] = 4*t*t*t
			else
				local u = 2 - 2*t
				curve[f] = 1 - u*u*u * 0.5
			end
		end
		TransportAPI.precomputedProgress[uDefID] = curve
	end
end

-- Inspects the transporter's command queue to detect area-unload orders.
-- Returns all currently loaded transportees for area-unload, or {transporteeID} for single-unload.
function TransportAPI.GetUnloadTargets(transporterID, transporteeID)
	local Q = Spring.GetUnitCommands(transporterID, 2) -- we only need the first two
	local isAreaUnload = Q and Q[1] and (
		Q[1].id == CMD.UNLOAD_UNITS or
		(
			Q[1].id == CMD.UNLOAD_UNIT and
			(
				(#Q > 1 and Q[2] and Q[2].id == CMD.UNLOAD_UNITS) or
				Q[1].params[4] == nil -- no defined unitID: issued by customFormation/areaUnload widgets
			)
		)
	)
	if isAreaUnload then
		return Spring.GetUnitIsTransporting(transporterID)
	end
	return { transporteeID }
end

function TransportAPI.GetTransporteeSize(unitID) -- minimal perf improvement: cache per unitDefID
	local udefID = Spring.GetUnitDefID(unitID)
	if cachedUnitSizes[udefID] then
		return cachedUnitSizes[udefID]
	end
	local def = UnitDefs[udefID]
	if def.customParams.nseats then
		cachedUnitSizes[udefID] = tonumber(def.customParams.nseats)
		return cachedUnitSizes[udefID]
	end
	local footprint = math.max(def.xsize, def.zsize) / 2
	if     footprint <= 2  then cachedUnitSizes[udefID] = 1
	elseif footprint <= 4  then cachedUnitSizes[udefID] = 4
	elseif footprint <= 8  then cachedUnitSizes[udefID] = 8
	elseif footprint <= 16 then cachedUnitSizes[udefID] = 16
	else                        cachedUnitSizes[udefID] = 1000
	end
	return cachedUnitSizes[udefID]
end