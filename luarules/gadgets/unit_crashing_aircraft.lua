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

	local SetUnitSensorRadius = SpringSynced.SetUnitSensorRadius
	local SetUnitWeaponState = SpringSynced.SetUnitWeaponState
	local GetUnitHealth = SpringShared.GetUnitHealth
	local GetGameFrame = SpringShared.GetGameFrame
	local GetUnitMoveTypeData = SpringShared.GetUnitMoveTypeData
	local SetAirMoveTypeData = SpringSynced.MoveCtrl.SetAirMoveTypeData
	local SetUnitCOBValue = Spring.SetUnitCOBValue
	local GiveOrderToUnit = SpringShared.GiveOrderToUnit
	local DestroyUnit = SpringSynced.DestroyUnit
	local SendToUnsynced = SendToUnsynced
	local GetUnitRulesParam = SpringShared.GetUnitRulesParam
	local SetUnitRulesParam = SpringSynced.SetUnitRulesParam
	local SetUnitNoSelect = SpringUnsynced.SetUnitNoSelect
	local SetUnitNoMinimap = SpringUnsynced.SetUnitNoMinimap
	local SetUnitIconDraw = SpringUnsynced.SetUnitIconDraw
	local SetUnitStealth = SpringSynced.SetUnitStealth
	local SetUnitAlwaysVisible = SpringSynced.SetUnitAlwaysVisible
	local SetUnitNeutral = SpringSynced.SetUnitNeutral
	local SetUnitBlocking = SpringSynced.SetUnitBlocking
	local SetUnitCrashing = SpringSynced.SetUnitCrashing

	local COB_CRASHING = COB.CRASHING
	local COM_BLAST = WeaponDefNames.commanderexplosion.id -- used to prevent them being boosted and flying far away
	local CMD_STOP = CMD.STOP

	local crashing = {}
	local crashingCount = 0

	local isAircon = {}
	local crashable = {}
	local unitWeaponCount = {}
	for udid, UnitDef in pairs(UnitDefs) do
		if UnitDef.canFly == true and (not UnitDef.customParams.crashable or UnitDef.customParams.crashable ~= "0") then
			crashable[UnitDef.id] = true
			if UnitDef.buildSpeed > 1 then
				isAircon[udid] = true
			end
		end
		local weaponCount = #UnitDef.weapons
		if weaponCount > 0 then
			unitWeaponCount[udid] = weaponCount
		end
	end

	function gadget:UnitPreDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponDefID, projectileID, attackerID, attackerDefID, attackerTeam)
		if paralyzer then
			return damage, 1
		end
		if crashing[unitID] then
			return 0, 0
		end

		if crashable[unitDefID] and (damage > GetUnitHealth(unitID)) and weaponDefID ~= COM_BLAST then
			-- increase gravity so it crashes faster
			local moveTypeData = GetUnitMoveTypeData(unitID)
			if moveTypeData.myGravity then
				SetAirMoveTypeData(unitID, "myGravity", moveTypeData.myGravity * gravityMult)
			end
			-- make it crash
			crashingCount = crashingCount + 1
			crashing[unitID] = GetGameFrame() + 450
			SetUnitCOBValue(unitID, COB_CRASHING, 1)
			SetUnitNoSelect(unitID, true)
			SetUnitNoMinimap(unitID, true)
			SetUnitIconDraw(unitID, false)
			SetUnitStealth(unitID, true)
			SetUnitAlwaysVisible(unitID, false)
			SetUnitNeutral(unitID, true)
			SetUnitBlocking(unitID, false)
			SetUnitCrashing(unitID, true)
			local wCount = unitWeaponCount[unitDefID]
			if wCount then
				for i = 1, wCount do
					SetUnitWeaponState(unitID, i, "reloadState", 0)
					SetUnitWeaponState(unitID, i, "reloadTime", 9999)
					SetUnitWeaponState(unitID, i, "range", 0)
					SetUnitWeaponState(unitID, i, "burst", 0)
					SetUnitWeaponState(unitID, i, "aimReady", 0)
					SetUnitWeaponState(unitID, i, "salvoLeft", 0)
					SetUnitWeaponState(unitID, i, "nextSalvo", 9999)
				end
			end
			-- remove sensors
			SetUnitSensorRadius(unitID, "los", 0)
			SetUnitSensorRadius(unitID, "airLos", 0)
			SetUnitSensorRadius(unitID, "radar", 0)
			SetUnitSensorRadius(unitID, "sonar", 0)

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
		if crashingCount > 0 and gf % 44 == 1 then
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

	function gadget:UnitDestroyed(unitID, unitDefID, teamID, attackerID, attackerDefID, attackerTeamID)
		if crashing[unitID] then
			crashingCount = crashingCount - 1
			crashing[unitID] = nil
		end
	end
else -- UNSYNCED
	local GetSpectatingState = SpringUnsynced.GetSpectatingState
	local GetUnitLosState = SpringShared.GetUnitLosState
	local GetMyAllyTeamID = SpringUnsynced.GetLocalAllyTeamID

	local function notifyCrashingAircraft(unitID, unitDefID, unitTeam)
		if GG.FireSmoke and GG.FireSmoke.CrashingAircraft then
			GG.FireSmoke.CrashingAircraft(unitID, unitDefID, unitTeam)
		end
		if Script.LuaUI("CrashingAircraft") then
			Script.LuaUI.CrashingAircraft(unitID, unitDefID, unitTeam)
		end
	end

	local function crashingAircraft(_, unitID, unitDefID, unitTeam)
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
