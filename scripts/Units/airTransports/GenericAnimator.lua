GenericAnimator = {}

local thrusterPieces = {}
local jetPieces = {}
local hoverPiece, hoverScale, hoverSpeed
local moveAngles, moveSpeeds
local killedTiers = {}
local active

-- convert a pipe-separated string of SFX key names (e.g. "SHATTER|EXPLODE_SHRAPNEL") into
-- a combined SFX bitmask for use with Explode()
local function resolveSFX(sfxStr)
	local val = 0
	for key in sfxStr:gmatch("[^|]+") do
		val = val + (SFX[key] or 0)
	end
	return val
end

-- resolve all piece name strings from setup into piece IDs; pre-compute killed tier entries
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

-- show/hide thruster smoke/flame pieces when the unit is activated or deactivated
function GenericAnimator.Activate()
	for _, p in ipairs(thrusterPieces) do Show(p) end
	active = true
end

function GenericAnimator.Deactivate()
	for _, p in ipairs(thrusterPieces) do Hide(p) end
	active = false
end

-- NOTE: identical to Deactivate; exists as an explicit "startup hide" call in script.Create
function GenericAnimator.HideThrusters()
	for _, p in ipairs(thrusterPieces) do Hide(p) end
end

-- tilt jet nozzle pieces by an angle keyed to the move-rate value (e.g. 0=hover, 1=forward flight)
function GenericAnimator.MoveRate(val)
	local angle = math.rad(moveAngles[val] or 0)
	local speed = math.rad(moveSpeeds[val] or moveSpeeds[0] or 85)
	for _, jp in ipairs(jetPieces) do
		Turn(jp, 1, angle, speed)
	end
end

local CARGO_KILL_DAMAGE_RATIO = 2  -- fraction of current HP dealt to each passenger on transporter death, scaled by animProgress
local CARGO_KILL_WEAPON_ID    = -6 -- -CSolidObject::DAMAGE_EXTSOURCE_KILLED; skipped by engine (releaseHeld=true), applied manually here

-- handle transporter death: damage or release all carried units, then explode pieces according to
-- the matching severity tier, returning the wreck level (or 1 as fallback)
function GenericAnimator.Killed(severity)
	for passengerID, passengerData in pairs(cargo.passengers) do
		SpMoveCtrl.Disable(passengerID)
		if SpValidUnitID(passengerID) and not SpGetUnitIsDead(passengerID) then
			Spring.SetUnitRulesParam(passengerID, "inTransportAnim", 0) -- release from unloading state for later loading
			TransportAnimator.EnablePassenger(passengerID) -- re-enable passenger
			SpSetUnitRadiusAndHeight(passengerID, passengerData.radius, passengerData.height) -- reset radius/height in case we were transporting a building with custom values
			Spring.SetUnitPhysicalStateBit(passengerID, 128 + 512)  -- PSTATE_BIT_FLYING | PSTATE_BIT_SKIDDING (matches engine Releasepassengers releaseHeld path)
		end

		local passengerDefID = Spring.GetUnitDefID(passengerID)
		local isParatrooper = passengerDefID and UnitDefs[passengerDefID] and UnitDefs[passengerDefID].customParams.paratrooper
		-- paratroopers survive intact; all other units take damage proportional to how far into the
		-- load/unload animation they were when the transporter died (animProgress == 1 means fully loaded)
		if not isParatrooper and passengerData.animProgress and passengerData.animProgress > 0 then
			Spring.AddUnitDamage(passengerID, Spring.GetUnitHealth(passengerID) * passengerData.animProgress * CARGO_KILL_DAMAGE_RATIO, 0, -1, CARGO_KILL_WEAPON_ID)
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

-- ambient up/down bob animation thread for the idle hover effect
function GenericAnimator.IdleHover()
	while true do
		Move(hoverPiece, 2,  (active and hoverScale) or 0, hoverSpeed)
		Sleep(math.random(200, 600))
		Move(hoverPiece, 2, (active and -hoverScale) or 0, hoverSpeed)
		Sleep(math.random(200, 600))
	end
end
