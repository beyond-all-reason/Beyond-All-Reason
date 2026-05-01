
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
local spGetUnitPosition = Spring.GetUnitPosition
local spGetUnitRotation = Spring.GetUnitRotation
local cachedCos, cachedSin = {}, {}
local unloadPad = {}

local function cachedCosSin(angle)
	angle = math.floor(angle*100)/100 -- round to 2 decimals to limit cache size; should be enough for smooth animations and avoid visible jumps
	if not cachedCos[angle] then
		cachedCos[angle], cachedSin[angle] = math.cos(angle), math.sin(angle)
	end
	return cachedCos[angle], cachedSin[angle]
end

local function rotationMatrixX(rx)
    local c, s = cachedCosSin(rx)
    return { {1,0,0}, {0,c,-s}, {0,s,c} }
end

local function rotationMatrixY(ry)
    local c, s = cachedCosSin(ry)
    return { {c,0,s}, {0,1,0}, {-s,0,c} }
end

local function rotationMatrixZ(rz)
    local c, s = cachedCosSin(rz)
    return { {c,-s,0}, {s,c,0}, {0,0,1} }
end

local function multiplyMatrices(a, b)
    local r = {}
    for i = 1, 3 do
        r[i] = {}
        for j = 1, 3 do
            r[i][j] = 0
            for k = 1, 3 do r[i][j] = r[i][j] + a[i][k] * b[k][j] end
        end
    end
    return r
end

local function applyRotation(m, vx, vy, vz)
    return m[1][1]*vx + m[1][2]*vy + m[1][3]*vz,
           m[2][1]*vx + m[2][2]*vy + m[2][3]*vz,
           m[3][1]*vx + m[3][2]*vy + m[3][3]*vz
end

local function transposeMatrix(m)
    return {
        { m[1][1], m[2][1], m[3][1] },
        { m[1][2], m[2][2], m[3][2] },
        { m[1][3], m[2][3], m[3][3] },
    }
end

local function shortAngle(a)
    a = a % (2 * math.pi)
    if a > math.pi then a = a - 2 * math.pi end
    return a
end

-- converts a world-space position and rotation into the transporter's unit-local space
TransportAPI.WorldToUnitSpace = function(unitID, wantedWorldSpacePosX, wantedWorldSpacePosY, wantedWorldSpacePosZ, wantedWorldSpaceRotX, wantedWorldSpaceRotY, wantedWorldSpaceRotZ, currentUnitPosX, currentUnitPosY, currentUnitPosZ, currentUnitRotX, currentUnitRotY, currentUnitRotZ)
    if not currentUnitPosX then
        currentUnitPosX, currentUnitPosY, currentUnitPosZ    = spGetUnitPosition(unitID)
        currentUnitRotX, currentUnitRotY, currentUnitRotZ = spGetUnitRotation(unitID)
    end
    local deltaX, deltaY, deltaZ = wantedWorldSpacePosX - currentUnitPosX, wantedWorldSpacePosY - currentUnitPosY, wantedWorldSpacePosZ - currentUnitPosZ
    local unitRot = multiplyMatrices(
        rotationMatrixY(-currentUnitRotY),
        multiplyMatrices(rotationMatrixX(-currentUnitRotX), rotationMatrixZ(-currentUnitRotZ))
    )
    local wantedUnitSpacePosX, wantedUnitSpacePosY, wantedUnitSpacePosZ = applyRotation(transposeMatrix(unitRot), deltaX, deltaY, deltaZ)
    return wantedUnitSpacePosX, wantedUnitSpacePosY, wantedUnitSpacePosZ,
           shortAngle(wantedWorldSpaceRotX - currentUnitRotX),
           shortAngle(currentUnitRotY - wantedWorldSpaceRotY), -- inverted in unit space
           shortAngle(wantedWorldSpaceRotZ - currentUnitRotZ)
end

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
-- Returns all currently loaded passengers for area-unload, or {passengerID} for single-unload.
function TransportAPI.GetUnloadTargets(transporterID, passengerID)
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
	return { passengerID }
end

function TransportAPI.GetPassengerSize(unitID) -- minimal perf improvement: cache per unitDefID
	local udefID = Spring.GetUnitDefID(unitID)
	if not udefID then
		-- we're being called on a unit that just died but hasn't been cleaned yet from the transporterClaims lists
		-- (ie during a releaseClaim iteration or an ExecuteSuccessiveLoadUnits or ExecuteLoadUnits) iteration, 
		-- after being flagged for removal, but not yet removed. we can safely return 0
		return 0 
	end 
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
	elseif footprint <= 8  then cachedUnitSizes[udefID] = 16 
	-- that's HUGE, sounds already way over the limit of what could be reasonably transported considering our models.
	-- but i chose to keep defining those regardless, in case of some special event unit for experimental transportations.
	elseif footprint <= 16 then cachedUnitSizes[udefID] = 64 -- ?
	else                        cachedUnitSizes[udefID] = 256 -- ?
	end
	return cachedUnitSizes[udefID]
end

function TransportAPI.GetUnloadPadType(transporterID)
	local transporterDefID = Spring.GetUnitDefID(transporterID)
	if unloadPad[transporterDefID] then
		return unloadPad[transporterDefID]
	end
	local transporterSeats = Spring.GetUnitRulesParam(transporterID, "transporterSeats")
	if not transporterSeats then
		Spring.Echo("Error, GetUnloadPadType expects a valid transporter ID as 1st arg, transporterID "..transporterID.." does not point to a valid transporter ID")
		return nil
	end
	if transporterSeats == 1 then
		unloadPad[transporterDefID] = UnitDefNames["unloadpad2x2"].id
	elseif transporterSeats == 4 then
		unloadPad[transporterDefID] = UnitDefNames["unloadpad4x4"].id
	elseif transporterSeats == 8 then
		unloadPad[transporterDefID] = UnitDefNames["unloadpad8x8"].id
	end
	return unloadPad[transporterDefID]
end
