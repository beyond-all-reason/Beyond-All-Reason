
if not Spring.GetModOptions().emprework then
	return
end

local gadget = gadget ---@type Gadget

function gadget:GetInfo()
   return {
      name      = "Attributes",
      desc      = "Handles UnitRulesParam attributes.",
      author    = "CarRepairer & Google Frog",
      date      = "2009-11-27", --last update 2014-2-19
      license   = "GNU GPL, v2 or later",
      layer     = -1,
      enabled   = true,
   }
end


if not gadgetHandler:IsSyncedCode() then
	return
end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local UPDATE_PERIOD = 3

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
local floor = math.floor

local spValidUnitID         = Spring.ValidUnitID
local spGetUnitDefID        = Spring.GetUnitDefID
local spGetGameFrame        = Spring.GetGameFrame
local spGetUnitRulesParam  	= Spring.GetUnitRulesParam
local spSetUnitRulesParam   = Spring.SetUnitRulesParam

local spSetUnitBuildSpeed   = Spring.SetUnitBuildSpeed
local spSetUnitWeaponState  = Spring.SetUnitWeaponState
local spGetUnitWeaponState  = Spring.GetUnitWeaponState

local spGetUnitMoveTypeData    = Spring.GetUnitMoveTypeData
local spMoveCtrlGetTag         = Spring.MoveCtrl.GetTag
local spSetAirMoveTypeData     = Spring.MoveCtrl.SetAirMoveTypeData
local spSetGunshipMoveTypeData = Spring.MoveCtrl.SetGunshipMoveTypeData
local spSetGroundMoveTypeData  = Spring.MoveCtrl.SetGroundMoveTypeData

local ALLY_ACCESS = {allied = true}
local INLOS_ACCESS = {inlos = true}

--local tobool      = Spring.Utilities.tobool
local getMovetype = Spring.Utilities.getMovetype

local spSetUnitCOBValue = Spring.SetUnitCOBValue
local WACKY_CONVERSION_FACTOR_1 = 2184.53
local CMD_WAIT = CMD.WAIT

local HALF_FRAME = 1/60

local workingGroundMoveType = true -- not ((Spring.GetModOptions() and (Spring.GetModOptions().pathfinder == "classic") and true) or false)

-- For generic attributes support
GG.att_moveMult   = GG.att_moveMult   or {}
GG.att_turnMult   = GG.att_turnMult   or {}
GG.att_accelMult  = GG.att_accelMult  or {}
GG.att_reloadMult = GG.att_reloadMult or {}
GG.att_econMult   = GG.att_econMult   or {}
GG.att_buildMult  = GG.att_buildMult  or {}
GG.att_weaponMods = GG.att_weaponMods or {}

-- To tell other gadgets things without creating RulesParams
GG.att_out_buildSpeed = {}

local allowUnitCoast = {}









local function getMovetype(ud)
	if ud.canFly or ud.isAirUnit then
		if ud.isHoveringAirUnit then
			return 1 -- gunship
		else
			return 0 -- fixedwing
		end
	elseif not ud.isImmobile then
		return 2 -- ground/sea
	end
	return false -- For structures or any other invalid movetype
end



--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- UnitDefs caching

local shieldWeaponDef = {}
local buildSpeedDef = {}
local reclaimSpeedDef = {}


for i = 1, #UnitDefs do
	local ud = UnitDefs[i]
	local cur = 0
	if ud.shieldWeaponDef then
		shieldWeaponDef[i] = true
	end
	--Spring.Echo(ud.name)
	if (ud.buildSpeed or 0) ~= 0 then

		buildSpeedDef[i] = ud.buildSpeed
		reclaimSpeedDef[i] = ud.reclaimSpeed or 0



		--cur = ud.buildSpeed
		--if (ud.repairSpeed ~= cur or ud.reclaimSpeed ~= cur or ud.resurrectSpeed ~= cur) then

			----Spring.Echo(ud.name)
			--Spring.Echo(ud.buildSpeed)
			--Spring.Echo(ud.repairSpeed)
			--Spring.Echo(ud.reclaimSpeed)
			---Spring.Echo(ud.resurrectSpeed)
		---end
	--else
		--Spring.Echo(ud.name)
		--Spring.Echo(ud.buildSpeed)

	end
end

local radarUnitDef = {}
local sonarUnitDef = {}
local jammerUnitDef = {}

for unitDefID, ud in pairs(UnitDefs) do
	if (ud.radarDistance or 0) > 0 then
		radarUnitDef[unitDefID] = ud.radarDistance
	end
	if (ud.sonarDistance or 0) > 0 then-- and tobool(ud.customParams.sonar_can_be_disabled)
		sonarUnitDef[unitDefID] = ud.sonarDistance
	end
	if (ud.radarDistanceJam or 0) > 0 then
		jammerUnitDef[unitDefID] = ud.radarDistanceJam
	end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Sensor Handling


local function UpdateSensorAndJamm(unitID, unitDefID, enabled, radarOverride, sonarOverride, jammerOverride, sightOverride)
	if radarUnitDef[unitDefID] or radarOverride then
		Spring.SetUnitSensorRadius(unitID, "radar", (enabled and (radarOverride or radarUnitDef[unitDefID])) or 0)
	end
	if sonarUnitDef[unitDefID] or sonarOverride then
		Spring.SetUnitSensorRadius(unitID, "sonar", (enabled and (sonarOverride or sonarUnitDef[unitDefID])) or 0)
	end
	if jammerUnitDef[unitDefID] or jammerOverride then
		Spring.SetUnitSensorRadius(unitID, "radarJammer", (enabled and (jammerOverride or jammerUnitDef[unitDefID])) or 0)
	end
	if sightOverride then
		Spring.SetUnitSensorRadius(unitID, "los", sightOverride)
		Spring.SetUnitSensorRadius(unitID, "airLos", sightOverride)
	end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Build Speed Handling


local function UpdateBuildSpeed(unitID, unitDefID, speedFactor)
	local buildSpeed = (buildSpeedDef[unitDefID] or 0)
	local reclaimSpeed = (reclaimSpeedDef[unitDefID] or 0)
	if buildSpeed == 0 then
		return
	end


	--Spring.Echo('hornet debug updatebuildspeed')
	--Spring.Echo(speedFactor)
	--Spring.Echo(buildSpeed*speedFactor / REPAIR_ENERGY_COST_FACTOR)
	--Spring.Echo(buildSpeed)

	GG.att_out_buildSpeed[unitID] = buildSpeed*speedFactor

	spSetUnitBuildSpeed(unitID,
		buildSpeed*speedFactor, -- build
		buildSpeed*speedFactor, -- repair
		reclaimSpeed*speedFactor, -- reclaim
		buildSpeed*speedFactor) -- rezz

end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Economy Handling

local function UpdateEconomy(unitID, unitDefID, factor)
	spSetUnitRulesParam(unitID,"resourceGenerationFactor", factor, INLOS_ACCESS)
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Reload Time Handling

local origUnitReload = {}
local unitReloadPaused = {}

local function UpdatePausedReload(unitID, unitDefID, gameFrame)
	local state = origUnitReload[unitDefID]

	for i = 1, state.weaponCount do
		local w = state.weapon[i]
		local reloadState = spGetUnitWeaponState(unitID, i , 'reloadState')
		if reloadState then
			local reloadTime  = spGetUnitWeaponState(unitID, i , 'reloadTime')
			local newReload = 100000 -- set a high reload time so healthbars don't judder. NOTE: math.huge is TOO LARGE
			if reloadState < 0 then -- unit is already reloaded, so set unit to almost reloaded
				spSetUnitWeaponState(unitID, i, {reloadTime = newReload, reloadState = gameFrame+UPDATE_PERIOD+1})
			else
				local nextReload = gameFrame+(reloadState-gameFrame)*newReload/reloadTime
				spSetUnitWeaponState(unitID, i, {reloadTime = newReload, reloadState = nextReload+UPDATE_PERIOD})
			end
		end
	end
end

local function UpdateReloadSpeed(unitID, unitDefID, weaponMods, speedFactor, gameFrame)
	if not origUnitReload[unitDefID] then
		local ud = UnitDefs[unitDefID]
		origUnitReload[unitDefID] = {
			weapon = {},
			weaponCount = #ud.weapons,
		}
		local state = origUnitReload[unitDefID]

		for i = 1, state.weaponCount do
			local wd = WeaponDefs[ud.weapons[i].weaponDef]
			local reload = wd.reload
			state.weapon[i] = {
				reload = reload,
				burstRate = wd.salvoDelay,
				oldReloadFrames = floor(reload*30),
			}
			if wd.type == "BeamLaser" then
				state.weapon[i].burstRate = false -- beamlasers go screwy if you mess with their burst length
			end
		end

	end

	local state = origUnitReload[unitDefID]

	for i = 1, state.weaponCount do
		local w = state.weapon[i]
		local reloadState = spGetUnitWeaponState(unitID, i , 'reloadState')
		local reloadTime  = spGetUnitWeaponState(unitID, i , 'reloadTime')
		if speedFactor <= 0 then
			if not unitReloadPaused[unitID] then
				local newReload = 100000 -- set a high reload time so healthbars don't judder. NOTE: math.huge is TOO LARGE
				unitReloadPaused[unitID] = unitDefID
				spSetUnitRulesParam(unitID, "reloadPaused", 1, INLOS_ACCESS)
				if reloadState < gameFrame then -- unit is already reloaded, so set unit to almost reloaded
					spSetUnitWeaponState(unitID, i, {reloadTime = newReload, reloadState = gameFrame+UPDATE_PERIOD+1})
				else
					local nextReload = gameFrame+(reloadState-gameFrame)*newReload/reloadTime
					spSetUnitWeaponState(unitID, i, {reloadTime = newReload, reloadState = nextReload+UPDATE_PERIOD})
				end
				-- add UPDATE_PERIOD so that the reload time never advances past what it is now
			end
		else
			if unitReloadPaused[unitID] then
				unitReloadPaused[unitID] = nil
				spSetUnitRulesParam(unitID, "reloadPaused", 0, INLOS_ACCESS)
			end
			local moddedSpeed = ((weaponMods and weaponMods[i] and weaponMods[i].reloadMult) or 1)*speedFactor
			local newReload = w.reload/moddedSpeed
			local nextReload = gameFrame+(reloadState-gameFrame)*newReload/reloadTime
			-- Add HALF_FRAME to round reloadTime to the closest multiple of 1/30, since the the engine rounds down to a multiple of 1/30.
			if w.burstRate then
				spSetUnitWeaponState(unitID, i, {reloadTime = newReload + HALF_FRAME, reloadState = nextReload, burstRate = w.burstRate/moddedSpeed + HALF_FRAME})
			else
				spSetUnitWeaponState(unitID, i, {reloadTime = newReload + HALF_FRAME, reloadState = nextReload})
			end
		end
	end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Movement Speed Handling

local origUnitSpeed = {}

local function UpdateMovementSpeed(unitID, unitDefID, speedFactor, turnAccelFactor, maxAccelerationFactor)
	if not origUnitSpeed[unitDefID] then
		local ud = UnitDefs[unitDefID]
		local moveData = spGetUnitMoveTypeData(unitID)

		origUnitSpeed[unitDefID] = {
			origSpeed = ud.speed,
			origReverseSpeed = (moveData.name == "ground") and moveData.maxReverseSpeed or ud.speed,
			origTurnRate = ud.turnRate,
			origMaxAcc = ud.maxAcc,
			origMaxDec = ud.maxDec,
			movetype = -1,
		}

		local state = origUnitSpeed[unitDefID]




		--Spring.Echo('hornetdebug movedata')
		--Spring.Echo(moveData)
		--for k,v in pairs(moveData) do
		 -- Spring.Echo(k,v)
		--end



		---





		state.movetype = getMovetype(ud)
	end

	local state = origUnitSpeed[unitDefID]
	local decFactor = maxAccelerationFactor
	local isSlowed = (speedFactor < 1) and not allowUnitCoast[unitID]
	if isSlowed then
		-- increase brake rate to cause units to slow down to their new max speed correctly.
		decFactor = 1000
	end
	if speedFactor <= 0 then
		speedFactor = 0

		-- Set the units velocity to zero if it is attached to the ground.
		local x, y, z = Spring.GetUnitPosition(unitID)
		if x then
			local h = Spring.GetGroundHeight(x, z)
			if h and h >= y then
				Spring.SetUnitVelocity(unitID, 0,0,0)

				-- Perhaps attributes should do this:
				--local env = Spring.UnitScript.GetScriptEnv(unitID)
				--if env and env.script.StopMoving then
				--	Spring.UnitScript.CallAsUnit(unitID,env.script.StopMoving, hx, hy, hz)
				--end
			end
		end
	end
	if turnAccelFactor <= 0 then
		turnAccelFactor = 0
	end
	local turnFactor = turnAccelFactor
	if turnFactor <= 0.001 then
		turnFactor = 0.001
	end
	if maxAccelerationFactor <= 0 then
		maxAccelerationFactor = 0.001
	end

	if spMoveCtrlGetTag(unitID) == nil then
		if state.movetype == 0 then
			local attribute = {
				maxSpeed        = state.origSpeed       *speedFactor,
				maxAcc          = state.origMaxAcc      *maxAccelerationFactor, --(speedFactor > 0.001 and speedFactor or 0.001)
			}
			spSetAirMoveTypeData (unitID, attribute)
		elseif state.movetype == 1 then
			local attribute =  {
				maxSpeed        = state.origSpeed       *speedFactor,
				--maxReverseSpeed = state.origReverseSpeed*speedFactor,
				turnRate        = state.origTurnRate    *turnFactor,
				accRate         = state.origMaxAcc      *maxAccelerationFactor,
				decRate         = state.origMaxDec      *maxAccelerationFactor
			}
			spSetGunshipMoveTypeData (unitID, attribute)
			GG.ForceUpdateWantedMaxSpeed(unitID, unitDefID)
		elseif state.movetype == 2 then
			if workingGroundMoveType then
				local accRate = state.origMaxAcc*maxAccelerationFactor
				if isSlowed and accRate > speedFactor then
					-- Clamp acceleration to mitigate prevent brief speedup when executing new order
					-- 1 is here as an arbitary factor, there is no nice conversion which means that 1 is a good value.
					accRate = speedFactor
				end
				local attribute =  {
					maxSpeed        = state.origSpeed       *speedFactor,
					maxReverseSpeed = (isSlowed and 0) or state.origReverseSpeed, --disallow reverse while slowed
					turnRate        = state.origTurnRate    *turnFactor,
					accRate         = accRate,
					decRate         = state.origMaxDec      *decFactor,
					turnAccel       = state.origTurnRate    *turnAccelFactor*1.2,
				}
				spSetGroundMoveTypeData (unitID, attribute)
				GG.ForceUpdateWantedMaxSpeed(unitID, unitDefID)
			else
				--Spring.Echo(state.origSpeed*speedFactor*WACKY_CONVERSION_FACTOR_1)
				--Spring.Echo(Spring.GetUnitCOBValue(unitID, COB.MAX_SPEED))
				spSetUnitCOBValue(unitID, COB.MAX_SPEED, math.ceil(state.origSpeed*speedFactor*WACKY_CONVERSION_FACTOR_1))
			end
		end
	end

end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- UnitRulesParam Handling

GG.att_EconomyChange = {}
GG.att_ReloadChange = {}
GG.att_MoveChange = {}

local currentEcon = {}
local currentBuildpower = {}
local currentReload = {}
local currentMovement = {}
local currentTurn = {}
local currentAcc = {}

local unitSlowed = {}
local unitAbilityDisabled = {}
local unitShieldDisabled = {}

local function removeUnit(unitID)
	unitSlowed[unitID] = nil
	unitAbilityDisabled[unitID] = nil
	unitShieldDisabled[unitID] = nil
	unitReloadPaused[unitID] = nil

	currentEcon[unitID] = nil
	currentBuildpower[unitID] = nil
	currentReload[unitID] = nil
	currentMovement[unitID] = nil
	currentTurn[unitID] = nil
	currentAcc[unitID] = nil
	allowUnitCoast[unitID] = nil

	GG.att_EconomyChange[unitID] = nil
	GG.att_ReloadChange[unitID] = nil
	GG.att_MoveChange[unitID] = nil

	GG.att_out_buildSpeed[unitID] = nil
end


--Spring.Echo("Hornet debug UpdateUnitAttributes defined")

function UpdateUnitAttributes(unitID, frame)
	if not spValidUnitID(unitID) then
		removeUnit(unitID)
		return
	end

	local unitDefID = spGetUnitDefID(unitID)
	if not unitDefID then
		return
	end

	frame = frame or spGetGameFrame()
	local changedAtt = false

	-- Increased reload from CAPTURE --
	local selfReloadSpeedChange = spGetUnitRulesParam(unitID,"selfReloadSpeedChange")

	local disarmed = spGetUnitRulesParam(unitID,"disarmed") or 0
	local completeDisable = (spGetUnitRulesParam(unitID,"morphDisable") or 0)
	if spGetUnitRulesParam(unitID,"planetwarsDisable") == 1 then
		completeDisable = 1
	end
	local crashing = spGetUnitRulesParam(unitID,"crashing") or 0

	-- Unit speed change (like sprint) --
	local upgradesSpeedMult   = spGetUnitRulesParam(unitID, "upgradesSpeedMult")
	local selfMoveSpeedChange = spGetUnitRulesParam(unitID, "selfMoveSpeedChange")
	local selfTurnSpeedChange = spGetUnitRulesParam(unitID, "selfTurnSpeedChange")
	local selfIncomeChange = (spGetUnitRulesParam(unitID, "selfIncomeChange") or 1)
	local selfMaxAccelerationChange = spGetUnitRulesParam(unitID, "selfMaxAccelerationChange") --only exist in airplane??

	-- SLOW --
	local slowState = spGetUnitRulesParam(unitID,"slowState")
	local reloadslowState = slowState

	if slowState and slowState > 0.9 then
		slowState = 0.9 -- Maximum slow --maybe tie to global ?
	end
	local zombieSpeedMult = spGetUnitRulesParam(unitID,"zombieSpeedMult")
	local buildpowerMult = spGetUnitRulesParam(unitID, "buildpower_mult")

	-- Disable
	local shieldDisabled = (spGetUnitRulesParam(unitID, "shield_disabled") == 1)
	local fullDisable    = (spGetUnitRulesParam(unitID, "fulldisable") == 1)

	local weaponMods = false
	if GG.att_genericUsed and GG.att_moveMult[unitID] then
		selfMoveSpeedChange = (selfMoveSpeedChange or 1)*GG.att_moveMult[unitID]
		selfTurnSpeedChange = (selfTurnSpeedChange or 1)*GG.att_turnMult[unitID]/GG.att_moveMult[unitID]
		selfMaxAccelerationChange = (selfMaxAccelerationChange or 1)*GG.att_accelMult[unitID]

		selfReloadSpeedChange = (selfReloadSpeedChange or 1)*GG.att_reloadMult[unitID]
		selfIncomeChange = (selfIncomeChange or 1)*GG.att_econMult[unitID]
		buildpowerMult = (buildpowerMult or 1)*GG.att_buildMult[unitID]/GG.att_econMult[unitID]

		weaponMods = GG.att_weaponMods[unitID]
	end

	if weaponMods or fullDisable or selfReloadSpeedChange or selfMoveSpeedChange or slowState or zombieSpeedMult or buildpowerMult or
			selfTurnSpeedChange or selfIncomeChange or disarmed or completeDisable or selfMaxAccelerationChange then

		local baseSpeedMult   = (1 - (slowState or 0))*(zombieSpeedMult or 1)

		local econMult   = (baseSpeedMult)*(1 - disarmed)*(1 - completeDisable)*(selfIncomeChange or 1)
		local buildMult  = (baseSpeedMult)*(1 - disarmed)*(1 - completeDisable)*(selfIncomeChange or 1)*(buildpowerMult or 1)
		local moveMult   = (baseSpeedMult)*(selfMoveSpeedChange or 1)*(1 - completeDisable)*(upgradesSpeedMult or 1)
		local turnMult   = (baseSpeedMult)*(selfMoveSpeedChange or 1)*(selfTurnSpeedChange or 1)*(1 - completeDisable)
		--local reloadMult = (baseSpeedMult)*(selfReloadSpeedChange or 1)*(1 - disarmed)*(1 - completeDisable)
		local reloadMult = math.min(1, (1 - (reloadslowState*2))) *(1 - disarmed)*(1 - completeDisable)
		local maxAccMult = (baseSpeedMult)*(selfMaxAccelerationChange or 1)*(upgradesSpeedMult or 1)


		if reloadslowState then
			if reloadMult<0 then reloadMult = 0 end
		else
			reloadMult = 0
		end

		--Spring.Echo("hornet debug buildpowermult" .. (buildpowerMult or 0))
		---Spring.Echo("hornet debug buildmult" .. buildMult)
		--Spring.Echo("hornet debug reloadmult" .. reloadMult)

		if fullDisable then
			buildMult = 0
			moveMult = 0
			turnMult = 0
			reloadMult = 0
			maxAccMult = 0
		end

		-- Let other gadgets and widgets get the total effect without
		-- duplicating the pevious calculations.
		spSetUnitRulesParam(unitID, "baseSpeedMult", baseSpeedMult, INLOS_ACCESS) -- Guaranteed not to be 0
		spSetUnitRulesParam(unitID, "totalReloadSpeedChange", reloadMult, INLOS_ACCESS)
		spSetUnitRulesParam(unitID, "totalEconomyChange", econMult, INLOS_ACCESS)
		spSetUnitRulesParam(unitID, "totalBuildPowerChange", buildMult, INLOS_ACCESS)
		spSetUnitRulesParam(unitID, "totalMoveSpeedChange", moveMult, INLOS_ACCESS)

		-- GG is faster (but gadget-only). The totals are for gadgets, so should be migrated to GG eventually.
		GG.att_EconomyChange[unitID] = econMult
		GG.att_ReloadChange[unitID] = reloadMult
		GG.att_MoveChange[unitID] = moveMult

		unitSlowed[unitID] = moveMult < 1
		if weaponMods or reloadMult ~= currentReload[unitID] then
			UpdateReloadSpeed(unitID, unitDefID, weaponMods, reloadMult, frame)
			currentReload[unitID] = reloadMult
		end

		if currentMovement[unitID] ~= moveMult or currentTurn[unitID] ~= turnMult or currentAcc[unitID] ~= maxAccMult then
			UpdateMovementSpeed(unitID, unitDefID, moveMult, turnMult, maxAccMult*moveMult)
			currentMovement[unitID] = moveMult
			currentTurn[unitID] = turnMult
			currentAcc[unitID] = maxAccMult
		end

		if buildMult ~= currentBuildpower[unitID] then
			UpdateBuildSpeed(unitID, unitDefID, buildMult)
			currentBuildpower[unitID] = buildMult
		end

		if econMult ~= currentEcon[unitID] then
			UpdateEconomy(unitID, unitDefID, econMult)
			currentEcon[unitID] = econMult
		end
		if econMult ~= 1 or moveMult ~= 1 or reloadMult ~= 1 or turnMult ~= 1 or maxAccMult ~= 1 then
			changedAtt = true
		end
	else
		unitSlowed[unitID] = nil
	end

	local forcedOff = spGetUnitRulesParam(unitID, "forcedOff")
	local abilityDisabled = (forcedOff == 1 or disarmed == 1 or completeDisable == 1 or crashing == 1)
	shieldDisabled = (shieldDisabled or abilityDisabled)

	local setNewState
	if abilityDisabled ~= unitAbilityDisabled[unitID] then
		spSetUnitRulesParam(unitID, "att_abilityDisabled", abilityDisabled and 1 or 0)
		unitAbilityDisabled[unitID] = abilityDisabled
		setNewState = true
	end

	if shieldWeaponDef[unitDefID] and shieldDisabled ~= unitShieldDisabled[unitID] then
		spSetUnitRulesParam(unitID, "att_shieldDisabled", shieldDisabled and 1 or 0)
		if shieldDisabled then
			Spring.SetUnitShieldState(unitID, -1, 0)
		end
		if spGetUnitRulesParam(unitID, "comm_shield_max") ~= 0 then
			if shieldDisabled then
				Spring.SetUnitShieldState(unitID, spGetUnitRulesParam(unitID, "comm_shield_num") or -1, false)
			else
				Spring.SetUnitShieldState(unitID, spGetUnitRulesParam(unitID, "comm_shield_num") or -1, true)
			end
		end
		changedAtt = true
	end

	local radarOverride = spGetUnitRulesParam(unitID, "radarRangeOverride")
	local sonarOverride = spGetUnitRulesParam(unitID, "sonarRangeOverride")
	local jammerOverride = spGetUnitRulesParam(unitID, "jammingRangeOverride")
	local sightOverride = spGetUnitRulesParam(unitID, "sightRangeOverride")

	if setNewState or radarOverride or sonarOverride or jammerOverride or sightOverride then
		changedAtt = true
		UpdateSensorAndJamm(unitID, unitDefID, not abilityDisabled, radarOverride, sonarOverride, jammerOverride, sightOverride)
	end

	local cloakBlocked = (spGetUnitRulesParam(unitID,"on_fire") == 1) or (disarmed == 1) or (completeDisable == 1)
	if cloakBlocked then
		GG.PokeDecloakUnit(unitID, unitDefID)
	end

	-- remove the attributes if nothing is being changed
	if not changedAtt then
		removeUnit(unitID)
	end
end

-- Whatever sets this should call UpdateUnitAttributes frames afterwards too
local function SetAllowUnitCoast(unitID, allowed)
	allowUnitCoast[unitID] = allowed
end

function gadget:Initialize()
	gadgetHandler:RegisterAllowCommand(70)
	GG.UpdateUnitAttributes = UpdateUnitAttributes
	GG.SetAllowUnitCoast = SetAllowUnitCoast

	--Spring.Echo("Hornetdebug UpdateUnitAttributes pinned to GG.")

end

function gadget:GameFrame(f)
	if f % UPDATE_PERIOD == 1 then
		for unitID, unitDefID in pairs(unitReloadPaused) do
			UpdatePausedReload(unitID, unitDefID, f)
		end
	end



	if false and f % 50 == 1 then
		Spring.Echo(unitSlowed)
	end

end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
	removeUnit(unitID)
end

function gadget:AllowCommand_GetWantedCommand()
	return true --{[CMD.ONOFF] = true, [70] = true}
end

function gadget:AllowCommand_GetWantedUnitDefID()
	return true
end

function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions)
	-- accepts: 70 (SET_WANTED_MAX_SPEED, but not registered anywhere)
	if unitSlowed[unitID] then
		return false
	else
		return true
	end
end
