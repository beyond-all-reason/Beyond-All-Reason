local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name      = "Crashing Aircraft",
		desc      = "Make aircraft crashing down instead of just exploding",
		author    = "Beherith",
		date      = "aug 2012",
		license   = "GNU GPL, v2 or later",
		layer     = 1000,
		enabled   = true,
	}
end

if gadgetHandler:IsSyncedCode() then

	local gravityMult = 1.7

	local SetUnitSensorRadius = Spring.SetUnitSensorRadius
	local SetUnitWeaponState = Spring.SetUnitWeaponState

	local COB_CRASHING = COB.CRASHING
	local COM_BLAST = WeaponDefNames['commanderexplosion'].id	-- used to prevent them being boosted and flying far away

	local crashing = {}
	local crashingCount = 0

	local isAircon = {}
	local crashable  = {}
	local unitWeapons = {}
	for udid,UnitDef in pairs(UnitDefs) do
		if UnitDef.canFly == true and (not UnitDef.customParams.crashable or UnitDef.customParams.crashable ~= '0') then
			crashable[UnitDef.id] = true
			if UnitDef.buildSpeed > 1 then
				isAircon[udid] = true
			end
		end
		if #UnitDef.weapons > 0 then
			unitWeapons[udid] = UnitDef.weapons
		end
	end

	function gadget:UnitPreDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponDefID, projectileID, attackerID, attackerDefID, attackerTeam)
		if paralyzer then return damage,1 end
		if crashing[unitID] then
			return 0,0
		end

		if crashable[unitDefID] and (damage>Spring.GetUnitHealth(unitID)) and weaponDefID ~= COM_BLAST then
			-- increase gravity so it crashes faster
			local moveTypeData = Spring.GetUnitMoveTypeData(unitID)
			if moveTypeData['myGravity'] then
				Spring.MoveCtrl.SetAirMoveTypeData(unitID, 'myGravity', moveTypeData['myGravity'] * gravityMult)
			end
			-- make it crash
			crashingCount = crashingCount + 1
			crashing[unitID] = Spring.GetGameFrame() + 450
			Spring.SetUnitCOBValue(unitID, COB_CRASHING, 1)
			Spring.SetUnitNoSelect(unitID,true)
			Spring.SetUnitNoMinimap(unitID,true)
			Spring.SetUnitIconDraw(unitID, false)
			Spring.SetUnitStealth(unitID, true)
			Spring.SetUnitAlwaysVisible(unitID, false)
			Spring.SetUnitNeutral(unitID, true)
			Spring.SetUnitBlocking(unitID, false)
			Spring.SetUnitCrashing(unitID, true)
			if unitWeapons[unitDefID] then
				for weaponID, _ in pairs(unitWeapons[unitDefID]) do
					SetUnitWeaponState(unitID, weaponID, "reloadState", 0)
					SetUnitWeaponState(unitID, weaponID, "reloadTime", 9999)
					SetUnitWeaponState(unitID, weaponID, "range", 0)
					SetUnitWeaponState(unitID, weaponID, "burst", 0)
					SetUnitWeaponState(unitID, weaponID, "aimReady", 0)
					SetUnitWeaponState(unitID, weaponID, "salvoLeft", 0)
					SetUnitWeaponState(unitID, weaponID, "nextSalvo", 9999)
				end
			end
			-- remove sensors
			SetUnitSensorRadius(unitID, "los", 0)
			SetUnitSensorRadius(unitID, "airLos", 0)
			SetUnitSensorRadius(unitID, "radar", 0)
			SetUnitSensorRadius(unitID, "sonar", 0)

			-- make sure aircons stop building
			if isAircon[unitDefID] then
				Spring.GiveOrderToUnit(unitID, CMD.STOP, {}, 0)
			end

			SendToUnsynced("crashingAircraft", unitID, unitDefID, unitTeam)

			if attackerID then
				local kills = Spring.GetUnitRulesParam(attackerID, "kills") or 0
				Spring.SetUnitRulesParam(attackerID, "kills", kills + 1)
			end
		end
		return damage,1
	end

	function gadget:GameFrame(gf)
		if crashingCount > 0 and gf % 44 == 1 then
			for unitID, deathGameFrame in pairs(crashing) do
				if gf >= deathGameFrame then
					Spring.DestroyUnit(unitID, false, true) -- dont selfd, but also dont leave wreck at all
				end
			end
		end
	end

	function gadget:UnitDestroyed(unitID, unitDefID, teamID, attackerID, attackerDefID, attackerTeamID)
		if crashing[unitID] then
			crashingCount = crashingCount - 1
			crashing[unitID] = nil
		end
	end


else	-- UNSYNCED


	local IsUnitInView = Spring.IsUnitInView

	local function crashingAircraft(_, unitID, unitDefID, unitTeam)
		if select(2, Spring.GetSpectatingState()) or CallAsTeam(Spring.GetMyTeamID(), IsUnitInView, unitID) then
			if Script.LuaUI("CrashingAircraft") then
				Script.LuaUI.CrashingAircraft(unitID, unitDefID, unitTeam)
			end
		end
	end

	function gadget:Initialize()
		gadgetHandler:AddSyncAction("crashingAircraft", crashingAircraft)
	end

	function gadget:Shutdown()
		gadgetHandler:RemoveSyncAction("crashingAircraft")
	end

end
