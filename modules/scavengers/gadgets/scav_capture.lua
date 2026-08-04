local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Scavengers Capture",
		desc = "Player units standing in scavenger scum are slowly captured and converted",
		author = "Damgam, Beyond All Reason",
		date = "July 2026",
		license = "GNU GPL, v2 or later",
		layer = 5,
		enabled = true,
	}
end

if not (Spring.Utilities.Gametype.IsScavengers() and not Spring.Utilities.Gametype.IsRaptors()) then
	return false
end

if not gadgetHandler:IsSyncedCode() then
	return
end

--------------------------------------------------------------------------------
-- The scum tax.
--
-- Anything of yours standing on scavenger creep is being taken. This is the
-- pressure that makes ceding ground expensive: a forward position you cannot
-- hold does not merely die, it changes sides and shoots back.
--
-- Its own cadence, deliberately. This walks every capturable unit on the map,
-- so it runs a quarter of the roster per pass on a seven-frame beat that is
-- out of phase with everything the director does.
--------------------------------------------------------------------------------

local CAPTURE_PERIOD = 7
local CAPTURE_PHASE = 2
local CAPTURE_PASSES = 4

-- The full capture bar is never reached: converting at 99% and setting the
-- new owner's bar to 95% is what stops a unit oscillating on the boundary.
local CONVERT_AT = 0.99
local CONVERTED_LEVEL = 0.95
local MAX_PROGRESS_PER_TICK = 0.05
local BASE_RATE = 0.016667

local scavTeamID
local capturable = {} ---@type table<integer, boolean>
local pass = 0

---How fast this unit is taken.
---
---Two things drive it, and the second is the interesting one. Tougher units
---resist — the fourth root of the fourth root of health, which flattens the
---range between a solar and a fusion into something playable. And DAMAGED
---units go much faster: the cube of the health fraction in the denominator
---means a building at half health is taken eight times as quickly, so a
---raid that cannot finish a structure still costs you it.
---@param unitID integer
---@param techAnger number
---@return number
local function captureRate(unitID, techAnger)
	local health, maxHealth = Spring.GetUnitHealth(unitID)
	if not health then
		return 0
	end
	local defHealth = UnitDefs[Spring.GetUnitDefID(unitID)].health
	local toughness = math.ceil(math.sqrt(math.sqrt(defHealth)))
	local rate = BASE_RATE * (3 / toughness) * math.max(0.1, techAnger / 100)
	if health < maxHealth then
		rate = rate / math.max(0.000001, (health / maxHealth) ^ 3)
	end
	return math.min(MAX_PROGRESS_PER_TICK, rate)
end

---@param unitID integer
---@param x number
---@param y number
---@param z number
local function convert(unitID, x, y, z, maxHealth)
	Spring.SpawnCEG("scavmist", x, y + 100, z, 0, 0, 0)
	Spring.SpawnCEG("scavradiation", x, y + 100, z, 0, 0, 0)
	if GG.SpawnEnvironmentalLightning then
		GG.SpawnEnvironmentalLightning("scavradiation", x, y + 100, z)
	else
		Spring.SpawnCEG("scavradiation-lightning", x, y + 100, z, 0, 0, 0)
	end

	-- The flavor gadget's UnitGiven handler may destroy this unit and replace
	-- it with a _scav variant, so everything after this must re-check it.
	Spring.TransferUnit(unitID, scavTeamID, false)
	if not Spring.ValidUnitID(unitID) then
		return
	end
	Spring.SetUnitHealth(unitID, { capture = CONVERTED_LEVEL })
	Spring.SetUnitHealth(unitID, { health = maxHealth })
	SendToUnsynced("unitCaptureFrame", unitID, CONVERTED_LEVEL)
	if GG.ScavengersSpawnEffectUnitID then
		GG.ScavengersSpawnEffectUnitID(unitID)
	end
	if GG.addUnitToCaptureDecay then
		GG.addUnitToCaptureDecay(unitID)
	end
end

---@param unitID integer
---@param techAnger number
local function tickUnit(unitID, techAnger)
	local x, y, z = Spring.GetUnitPosition(unitID)
	if x == nil then
		return
	end
	local health, maxHealth, _, captureLevel = Spring.GetUnitHealth(unitID)
	if not health then
		return
	end

	local owned = Spring.GetUnitTeam(unitID) == scavTeamID
	local inScum = GG.IsPosInRaptorScum and GG.IsPosInRaptorScum(x, y, z)

	-- A neutral unit is nobody's and the scum does not take it: mission
	-- scenery (a derelict outpost waiting to be discovered) and anything
	-- under Combat.Protect — which sets neutral — would otherwise convert
	-- with no callin ever firing, since this is a direct TransferUnit.
	if Spring.GetUnitNeutral(unitID) then
		return
	end

	if not owned and inScum then
		local progress = captureRate(unitID, techAnger)
		if captureLevel + progress >= CONVERT_AT then
			convert(unitID, x, y, z, maxHealth)
			return
		end
		local level = math.min(captureLevel + progress, 1)
		Spring.SetUnitHealth(unitID, { capture = level })
		SendToUnsynced("unitCaptureFrame", unitID, level)
		Spring.SpawnCEG("scaspawn-trail", x, y, z, 0, 0, 0)
		if GG.ScavengersSpawnEffectUnitID then
			GG.ScavengersSpawnEffectUnitID(unitID)
		end
		if math.random() <= 0.1 then
			Spring.SpawnCEG("scavmist", x, y + 100, z, 0, 0, 0)
		end
	end

	-- Standing off the creep, or already taken: either way the bar decays,
	-- which is what makes retaking ground worth doing.
	if (not owned and inScum) or (owned and captureLevel > 0) then
		if GG.addUnitToCaptureDecay then
			GG.addUnitToCaptureDecay(unitID)
		end
	end
end

function gadget:Initialize()
	if GG.Scavengers == nil then
		Spring.Log("scav_capture", LOG.ERROR, "GG.Scavengers missing; capture disabled")
		return
	end
	scavTeamID = GG.Scavengers.teamID
	for _, unitID in ipairs(Spring.GetAllUnits()) do
		if Spring.GetUnitTeam(unitID) ~= scavTeamID then
			capturable[unitID] = true
		end
	end
end

function gadget:GameFrame(n)
	if scavTeamID == nil or n % CAPTURE_PERIOD ~= CAPTURE_PHASE then
		return
	end
	pass = (pass + 1) % CAPTURE_PASSES
	local techAnger = Spring.GetGameRulesParam("scavTechAnger") or 0
	for unitID in pairs(capturable) do
		-- A quarter of the map per pass, selected by unit id: cheap, stable,
		-- and it spreads the cost evenly however many units exist.
		if unitID % CAPTURE_PASSES == pass then
			tickUnit(unitID, techAnger)
		end
	end
end

function gadget:UnitCreated(unitID, _, unitTeam)
	capturable[unitID] = unitTeam ~= scavTeamID or nil
end

function gadget:UnitFinished(unitID, _, unitTeam)
	if unitTeam ~= scavTeamID then
		capturable[unitID] = true
	end
end

function gadget:UnitGiven(unitID, _, newTeam, oldTeam)
	if newTeam == scavTeamID then
		capturable[unitID] = nil
	elseif oldTeam == scavTeamID then
		-- The players took it back. It can be taken again.
		capturable[unitID] = true
	end
end

function gadget:UnitDestroyed(unitID)
	capturable[unitID] = nil
end
