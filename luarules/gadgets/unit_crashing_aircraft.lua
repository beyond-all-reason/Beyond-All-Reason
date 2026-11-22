local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Crashing Aircraft",
		desc = "Make aircraft crashing down instead of just exploding",
		author = "Beherith",
		date = "aug 2012",
		license = "GNU GPL, v2 or later",
		layer = 1000,
		enabled = true,
	}
end

if gadgetHandler:IsSyncedCode() then
	local gravityMult = 1.7
	local crashTimeoutFrames = 15 * Game.gameSpeed
	local aircraftCrashed = Game.envDamageTypes.AircraftCrashed

	local SetUnitWeaponState = Spring.SetUnitWeaponState
	local GetUnitHealth = Spring.GetUnitHealth
	local GetUnitWeaponDamages = Spring.GetUnitWeaponDamages --[[@as fun(unitID: UnitID, weapon: string, key: integer|string): number]]
	local SetUnitWeaponDamages = Spring.SetUnitWeaponDamages
	local GetGameFrame = Spring.GetGameFrame
	local GetUnitMoveTypeData = Spring.GetUnitMoveTypeData
	local SetAirMoveTypeData = Spring.MoveCtrl.SetAirMoveTypeData
	local SetUnitCOBValue = Spring.SetUnitCOBValue
	local GiveOrderToUnit = Spring.GiveOrderToUnit
	local DestroyUnit = Spring.DestroyUnit
	local SendToUnsynced = SendToUnsynced
	local GetUnitRulesParam = Spring.GetUnitRulesParam
	local SetUnitRulesParam = Spring.SetUnitRulesParam
	local SetUnitNoSelect = Spring.SetUnitNoSelect
	local SetUnitNoMinimap = Spring.SetUnitNoMinimap
	local SetUnitIconDraw = Spring.SetUnitIconDraw
	local SetUnitAlwaysVisible = Spring.SetUnitAlwaysVisible
	local SetUnitNeutral = Spring.SetUnitNeutral
	local SetUnitBlocking = Spring.SetUnitBlocking
	local SetUnitCrashing = Spring.SetUnitCrashing

	local COB_CRASHING = COB.CRASHING
	local COM_BLAST = WeaponDefNames.commanderexplosion.id -- used to prevent them being boosted and flying far away
	local CMD_STOP = CMD.STOP

	local ATTRIBUTE_SOURCE = "crashing"
	local SENSOR_ATTRIBUTES = { "losRadius", "airLosRadius", "radarRadius", "sonarRadius" }

	-- Shared membership; values are destruction deadlines, not booleans.
	-- Consumers can acquire this table before the controller loads.
	local crashing = table.ensureTable(GG, "Crashing") ---@type table<UnitID, integer?>

	local shotWhileLanded = {}
	local crashDamageCurves = {}
	local isAircon = {}
	local crashable = {}
	local unitWeaponCount = {}
	for udid, UnitDef in pairs(UnitDefs) do
		if UnitDef.canFly == true and (not UnitDef.customParams.crashable or UnitDef.customParams.crashable ~= "0") then
			crashable[UnitDef.id] = true
			-- crash_damage_speed_max opts airborne impacts into scaling (downward elmos/frame).
			-- Between the min and max speeds, the normalized speed raised to the exponent
			-- blends the normal explosion profile into the full crash profile.
			local params = UnitDef.customParams
			local maxSpeed = tonumber(params.crash_damage_speed_max)
			if maxSpeed then
				local minSpeed = tonumber(params.crash_damage_speed_min or 0)
				local exponent = tonumber(params.crash_damage_exponent or 1)
				if minSpeed and minSpeed >= 0 and maxSpeed > minSpeed and exponent and exponent > 0 then
					crashDamageCurves[udid] = { minSpeed = minSpeed, maxSpeed = maxSpeed, exponent = exponent }
				end
			end
			if UnitDef.buildSpeed > 1 then
				isAircon[udid] = true
			end
		end
		local weaponCount = #UnitDef.weapons
		if weaponCount > 0 then
			unitWeaponCount[udid] = weaponCount
		end
	end

	local function hideFromSensors(unitID)
		local setUnitModifier = GG.UnitAttributes.SetUnitModifier
		for _, attribute in ipairs(SENSOR_ATTRIBUTES) do
			setUnitModifier(unitID, attribute, 0, ATTRIBUTE_SOURCE)
		end
	end

	function gadget:UnitPreDamaged(
		unitID,
		unitDefID,
		unitTeam,
		damage,
		paralyzer,
		weaponDefID,
		projectileID,
		attackerID,
		attackerDefID,
		attackerTeam
	)
		if paralyzer then
			return damage, 1
		end
		if crashing[unitID] then
			return 0, 0
		end

		if crashable[unitDefID] and (damage > GetUnitHealth(unitID)) and weaponDefID ~= COM_BLAST then
			-- increase gravity so it crashes faster
			local moveTypeData = GetUnitMoveTypeData(unitID)
			if moveTypeData and moveTypeData.aircraftState == "landed" then
				-- Recoil can also report "landed" for an aircraft spawned above its landing surface.
				local x, y, z = Spring.GetUnitPosition(unitID)
				if x then
					local ground = Spring.GetGroundHeight(x, z)
					local surface = UnitDefs[unitDefID].canSubmerge and ground or math.max(0, ground)
					shotWhileLanded[unitID] = y <= surface + 0.01
				end
			end
			if moveTypeData and moveTypeData.myGravity then
				SetAirMoveTypeData(unitID, "myGravity", moveTypeData.myGravity * gravityMult)
			end
			-- make it crash
			crashing[unitID] = GetGameFrame() + crashTimeoutFrames
			SetUnitCOBValue(unitID, COB_CRASHING, 1)
			SetUnitNoSelect(unitID, true)
			SetUnitNoMinimap(unitID, true)
			SetUnitIconDraw(unitID, false)
			GG.UnitAttributes.SetUnitAttribute(unitID, "stealth", true, ATTRIBUTE_SOURCE)
			SetUnitAlwaysVisible(unitID, false)
			SetUnitNeutral(unitID, true)
			SetUnitBlocking(unitID, false)
			SetUnitCrashing(unitID, true)
			local wCount = unitWeaponCount[unitDefID]
			if wCount then
				local setUnitWeaponAttribute = GG.UnitAttributes.SetUnitWeaponAttribute
				setUnitWeaponAttribute(unitID, nil, "reloadTime", 9999, ATTRIBUTE_SOURCE)
				setUnitWeaponAttribute(unitID, nil, "maxWeaponRange", 0, ATTRIBUTE_SOURCE)
				for i = 1, wCount do
					SetUnitWeaponState(unitID, i, "reloadState", 0)
					SetUnitWeaponState(unitID, i, "burst", 0)
					SetUnitWeaponState(unitID, i, "aimReady", 0)
					SetUnitWeaponState(unitID, i, "salvoLeft", 0)
					SetUnitWeaponState(unitID, i, "nextSalvo", 9999)
				end
			end
			hideFromSensors(unitID)

			-- make sure aircons stop building
			if isAircon[unitDefID] then
				GiveOrderToUnit(unitID, CMD_STOP, {}, 0)
			end

			SendToUnsynced("crashingAircraft", unitID, unitDefID, unitTeam)

			if attackerID then
				local kills = GetUnitRulesParam(attackerID, "kills") or 0
				SetUnitRulesParam(attackerID, "kills", kills + 1)
			end
		end
		return damage, 1
	end

	local crashDestroyList = {}
	local crashDestroyCount = 0

	function gadget:GameFrame(gf)
		if gf % 44 == 1 and next(crashing) then
			-- Collect first: DestroyUnit triggers UnitDestroyed synchronously,
			-- which nils entries from 'crashing', invalidating the pairs() iterator
			crashDestroyCount = 0
			for unitID, deathGameFrame in pairs(crashing) do
				if gf >= deathGameFrame then
					crashDestroyCount = crashDestroyCount + 1
					crashDestroyList[crashDestroyCount] = unitID
				end
			end
			for i = 1, crashDestroyCount do
				DestroyUnit(crashDestroyList[i], false, true)
				crashDestroyList[i] = nil
			end
		end
	end

	local explosionDamageFields = {
		"paralyzeDamageTime",
		"impulseFactor",
		"impulseBoost",
		"craterMult",
		"craterBoost",
		"craterAreaOfEffect",
		"damageAreaOfEffect",
		"edgeEffectiveness",
		"explosionSpeed",
	}

	local function explosionValue(unitID, field, fraction)
		local normal = GetUnitWeaponDamages(unitID, "explode", field)
		if fraction == 0 then
			return normal
		end
		local full = GetUnitWeaponDamages(unitID, "selfDestruct", field)
		return normal + (full - normal) * fraction
	end

	function gadget:UnitDestroyed(unitID, unitDefID, teamID, attackerID, attackerDefID, attackerTeamID, weaponDefID)
		local tracked, landed = crashing[unitID], shotWhileLanded[unitID]
		crashing[unitID], shotWhileLanded[unitID] = nil, nil
		if not tracked or weaponDefID ~= aircraftCrashed then
			return
		end

		local fraction = 0 ---@type number
		if not landed then
			local curve = crashDamageCurves[unitDefID]
			if not curve then
				return
			end
			local _, vy = Spring.GetUnitVelocity(unitID)
			local speed = -vy
			if speed >= curve.maxSpeed then
				return
			end
			fraction = (math.max(0, speed - curve.minSpeed) / (curve.maxSpeed - curve.minSpeed)) ^ curve.exponent
		end

		-- The engine reads self-destruct damage after UnitDestroyed on aircraft impact.
		local damages = {}
		for armorType = 0, #Game.armorTypes do
			damages[armorType] = explosionValue(unitID, armorType, fraction)
		end
		for _, field in ipairs(explosionDamageFields) do
			damages[field] = explosionValue(unitID, field, fraction)
		end
		SetUnitWeaponDamages(unitID, "selfDestruct", damages --[[@as WeaponDamages]])
	end
else -- UNSYNCED
	local GetSpectatingState = Spring.GetSpectatingState
	local GetUnitLosState = Spring.GetUnitLosState
	local GetMyAllyTeamID = Spring.GetLocalAllyTeamID
	local SetUnitNoGroup = Spring.SetUnitNoGroup

	local function notifyCrashingAircraft(unitID, unitDefID, unitTeam)
		if GG.FireSmoke and GG.FireSmoke.CrashingAircraft then
			GG.FireSmoke.CrashingAircraft(unitID, unitDefID, unitTeam)
		end
		if Script.LuaUI("CrashingAircraft") then
			Script.LuaUI.CrashingAircraft(unitID, unitDefID, unitTeam)
		end
	end

	local function crashingAircraft(_, unitID, unitDefID, unitTeam)
		SetUnitNoGroup(unitID, true)
		local _, fullView = GetSpectatingState()
		if fullView then
			notifyCrashingAircraft(unitID, unitDefID, unitTeam)
			return
		end
		-- Bitmask LOS check: bit 0 = inLos, bit 2 = inRadar
		-- Crashing aircraft have icon draw disabled, so IsUnitVisible returns false at icon distances
		local losBits = GetUnitLosState(unitID, GetMyAllyTeamID(), true)
		if losBits and (losBits % 2 >= 1 or losBits % 8 >= 4) then
			notifyCrashingAircraft(unitID, unitDefID, unitTeam)
		end
	end

	function gadget:Initialize()
		gadgetHandler:AddSyncAction("crashingAircraft", crashingAircraft)
	end

	function gadget:Shutdown()
		gadgetHandler:RemoveSyncAction("crashingAircraft")
	end
end
