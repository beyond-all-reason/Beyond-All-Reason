GenericAnimator = {}

-- SPRING API LOCALS
local spMoveCtrlDisable         = Spring.MoveCtrl.Disable
local spValidUnitID             = Spring.ValidUnitID
local spGetUnitIsDead           = Spring.GetUnitIsDead
local spSetUnitRadiusAndHeight  = Spring.SetUnitRadiusAndHeight
local spSetUnitRulesParam       = Spring.SetUnitRulesParam
local spSetUnitPhysicalStateBit = Spring.SetUnitPhysicalStateBit
local spGetUnitDefID            = Spring.GetUnitDefID
local spAddUnitDamage           = Spring.AddUnitDamage
local spGetUnitHealth           = Spring.GetUnitHealth

-- CONSTANTS
local CARGO_KILL_DAMAGE_RATIO = 2  -- fraction of current HP dealt to each passenger on transporter death, scaled by animProgress
local CARGO_KILL_WEAPON_ID    = -6 -- -CSolidObject::DAMAGE_EXTSOURCE_KILLED; skipped by engine (releaseHeld=true), applied manually here

-- VARIABLES
local thrusterPieces = {}
local jetPieces = {}
local hoverPiece, hoverScale, hoverSpeed
local moveAngles, moveSpeeds
local killedTiers = {}
local active

---------------------------------------------------------------------------
-- LOCAL HELPERS
---------------------------------------------------------------------------
-- local function resolveSFX(...)  -- Convert pipe-separated SFX key names into a combined Explode() bitmask

---@param sfxStr string  pipe-separated SFX key names (e.g. "SHATTER|EXPLODE_SHRAPNEL")
---@return number bitmask
local function resolveSFX(sfxStr)
	local val = 0
	for key in sfxStr:gmatch("[^|]+") do
		val = val + (SFX[key] or 0)
	end
	return val
end

---------------------------------------------------------------------------
-- MODULE FUNCTIONS
---------------------------------------------------------------------------
-- function GenericAnimator.Init(...)         -- Resolve piece name strings from setup; pre-compute killed tier entries
-- function GenericAnimator.Activate()        -- Show thruster smoke/flame pieces and mark unit as active
-- function GenericAnimator.Deactivate()      -- Hide thruster smoke/flame pieces and mark unit as inactive
-- function GenericAnimator.HideThrusters()   -- Explicit startup hide; identical to Deactivate (named for script.Create clarity)
-- function GenericAnimator.MoveRate(...)     -- Tilt jet nozzle pieces by angle keyed to move-rate value
-- function GenericAnimator.Killed(...)       -- Damage/release all cargo, explode pieces by severity tier, return wreck level
-- function GenericAnimator.IdleHover()       -- Continuous thread: bob the hover piece up and down for ambient animation

---@param setup table  animation config (thrusters, jets, idleHover, moveRate, killed tiers)
function GenericAnimator.Init(setup)
	thrusterPieces = {}
	for _, name in ipairs(setup.thrusters or {}) do
		thrusterPieces[#thrusterPieces+1] = piece(name)
	end

	jetPieces = {}
	for _, name in ipairs(setup.jets or {}) do
		jetPieces[#jetPieces+1] = piece(name)
	end

	hoverPiece = piece(setup.idleHover.piece)
	hoverScale = setup.idleHover.scale
	hoverSpeed = setup.idleHover.speed

	moveAngles = setup.moveRate and setup.moveRate.angles or {}
	moveSpeeds = setup.moveRate and setup.moveRate.speeds or {}

	active = false

	killedTiers = {}
	for _, tier in ipairs(setup.killed or {}) do
		local resolvedPieces = {}
		for _, entry in ipairs(tier.pieces) do
			if entry.useJets then
				for _, jp in ipairs(jetPieces) do
					resolvedPieces[#resolvedPieces+1] = { pieceID=jp, sfx=resolveSFX(entry.sfx) }
				end
			else
				resolvedPieces[#resolvedPieces+1] = { pieceID=piece(entry.name), sfx=resolveSFX(entry.sfx) }
			end
		end
		killedTiers[#killedTiers+1] = { maxSeverity=tier.maxSeverity, wreck=tier.wreck, pieces=resolvedPieces }
	end
end


function GenericAnimator.Activate()
	for _, p in ipairs(thrusterPieces) do Show(p) end
	active = true
end

function GenericAnimator.Deactivate()
	for _, p in ipairs(thrusterPieces) do Hide(p) end
	active = false
end


function GenericAnimator.HideThrusters()
	for _, p in ipairs(thrusterPieces) do Hide(p) end
end


---@param val number  move-rate index (e.g. 0=hover, 1=forward flight)
function GenericAnimator.MoveRate(val)
	local angle = math.rad(moveAngles[val] or 0)
	local speed = math.rad(moveSpeeds[val] or moveSpeeds[0] or 85)
	for _, jp in ipairs(jetPieces) do
		Turn(jp, 1, angle, speed)
	end
end



---@param severity number  damage severity value from engine
---@return number wreckLevel
function GenericAnimator.Killed(severity)
	for passengerID, passengerData in pairs(cargo.passengers) do
		spMoveCtrlDisable(passengerID) -- safe to call on attached passengers too
		if spValidUnitID(passengerID) and not spGetUnitIsDead(passengerID) then
			spSetUnitRulesParam(passengerID, "inLoadAnim", 0)
			spSetUnitRulesParam(passengerID, "inUnloadAnim", 0)
			TransportAPI.EnablePassenger(passengerID) -- re-enable if mid-unload (no-op if mid-load, abilities were never disabled)
			spSetUnitRadiusAndHeight(passengerID, passengerData.radius, passengerData.height)
			spSetUnitPhysicalStateBit(passengerID, 128 + 512)  -- PSTATE_BIT_FLYING | PSTATE_BIT_SKIDDING (matches engine ReleasePassengers releaseHeld path)
		end

		local passengerDefID = spGetUnitDefID(passengerID)
		local isParatrooper = passengerDefID and UnitDefs[passengerDefID] and UnitDefs[passengerDefID].customParams.paratrooper
		-- paratroopers survive intact; all other units take damage proportional to how far into the
		-- load/unload animation they were when the transporter died (animProgress == 1 means fully loaded)
		if not isParatrooper and passengerData.animProgress and passengerData.animProgress > 0 then
			spAddUnitDamage(passengerID, spGetUnitHealth(passengerID) * passengerData.animProgress * CARGO_KILL_DAMAGE_RATIO, 0, -1, CARGO_KILL_WEAPON_ID)
		end
	end
	-- walk severity tiers from least to most severe; use the first tier whose maxSeverity covers this death
	for _, tier in ipairs(killedTiers) do
		if severity <= tier.maxSeverity then
			for _, entry in ipairs(tier.pieces) do
				Explode(entry.pieceID, entry.sfx)
			end
			return tier.wreck
		end
	end
	local last = killedTiers[#killedTiers]
	if last then
		for _, entry in ipairs(last.pieces) do
			Explode(entry.pieceID, entry.sfx)
		end
		return last.wreck
	end
	return 1
end


function GenericAnimator.IdleHover()
	while true do
		Move(hoverPiece, 2,  (active and hoverScale) or 0, hoverSpeed)
		Sleep(math.random(200, 600))
		Move(hoverPiece, 2, (active and -hoverScale) or 0, hoverSpeed)
		Sleep(math.random(200, 600))
	end
end
