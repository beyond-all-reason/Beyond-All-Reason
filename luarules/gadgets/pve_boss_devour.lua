local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "PvE Boss Devour",
		desc = "Support for PvE bosses that eat: holds their orders while they eat, turns raised wrecks into their units, scales health by map size, reports hunger, heat and the economy the players lost",
		author = "Mat_Ba",
		date = "2026",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return
end

local eaters = {}
local bigUnits = {}
local economyCost = {}
for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.isImmobile and #unitDef.weapons == 0 then
		economyCost[unitDefID] = unitDef.metalCost
	end
	if unitDef.customParams.eaterboss then
		eaters[unitDefID] = true
	end
	if (tonumber(unitDef.customParams.techlevel) or 1) >= 3 then
		bigUnits[unitDefID] = true
	end
end

if not next(eaters) then
	return false
end

local bosses = {}
local gaiaTeam = Spring.GetGaiaTeamID()

---@type table<string, any>
local economy = { standing = {}, standingCost = 0, lostCost = 0 }
local ECONOMY_UNCOUNTED = { [Game.envDamageTypes.Reclaimed] = true, [Game.envDamageTypes.SelfD] = true }

local function IsPlayerEconomy(unitDefID, unitTeam)
	return economyCost[unitDefID] and unitTeam ~= gaiaTeam and not Spring.AreTeamsAllied(unitTeam, economy.bossTeam)
end

local function AddEconomy(unitID, unitDefID)
	if not economy.standing[unitID] then
		economy.standing[unitID] = economyCost[unitDefID]
		economy.standingCost = economy.standingCost + economyCost[unitDefID]
	end
end

local function WatchEconomy(bossID)
	economy.bossTeam = Spring.GetUnitTeam(bossID)
	economy.standing, economy.standingCost, economy.lostCost = {}, 0, 0
	for _, unitID in ipairs(Spring.GetAllUnits()) do
		local unitDefID = Spring.GetUnitDefID(unitID)
		if IsPlayerEconomy(unitDefID, Spring.GetUnitTeam(unitID)) and not Spring.GetUnitIsBeingBuilt(unitID) then
			AddEconomy(unitID, unitDefID)
		end
	end
end

local SMALL_MAP, LARGE_MAP, LARGE_MAP_HEALTH = { 12, 10 }, { 32, 32 }, 5
local mapSizeShare
do
	local small = math.sqrt(SMALL_MAP[1] ^ 2 + SMALL_MAP[2] ^ 2)
	local large = math.sqrt(LARGE_MAP[1] ^ 2 + LARGE_MAP[2] ^ 2)
	local diagonal = math.sqrt(Game.mapX ^ 2 + Game.mapY ^ 2)
	mapSizeShare = math.max(0, math.min(1, (diagonal - small) / (large - small)))
end
local mapHealthScale = 1 + (LARGE_MAP_HEALTH - 1) * mapSizeShare

local feedCount = 0
local function FeedingEffect(unitID, unitDefID, index)
	feedCount = feedCount + 1
	local baseDef = UnitDefNames[UnitDefs[unitDefID].name:gsub("_scav$", "")]
	SendToUnsynced("cob_UnitScriptDistortion", unitID, baseDef and baseDef.id or unitDefID, index, feedCount)
end

local function SetShield(unitID, on)
	Spring.GiveOrderToUnit(unitID, CMD.ONOFF, { on and 1 or 0 }, 0)
end

local function AddBoss(unitID)
	if not next(bosses) then
		WatchEconomy(unitID)
		Spring.SetGameRulesParam("scavBossOverheats", 1)
	end
	bosses[unitID] = true
end

function gadget:UnitCreated(unitID, unitDefID)
	if eaters[unitDefID] then
		AddBoss(unitID)
		local health, maxHealth = Spring.GetUnitHealth(unitID)
		Spring.SetUnitMaxHealth(unitID, maxHealth * mapHealthScale)
		Spring.SetUnitHealth(unitID, health * mapHealthScale)
	end
end

function gadget:UnitFinished(unitID, unitDefID, unitTeam)
	if next(bosses) and IsPlayerEconomy(unitDefID, unitTeam) then
		AddEconomy(unitID, unitDefID)
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
	bosses[unitID] = nil
	local cost = economy.standing[unitID]
	if cost then
		economy.standing[unitID] = nil
		economy.standingCost = economy.standingCost - cost
		if not ECONOMY_UNCOUNTED[weaponDefID] then
			economy.lostCost = economy.lostCost + cost
		end
	end
	if
		attackerID
		and bosses[attackerID]
		and bigUnits[unitDefID]
		and attackerTeam
		and not Spring.AreTeamsAllied(unitTeam, attackerTeam)
	then
		local kills = Spring.GetUnitRulesParam(attackerID, "scavboss_bigkills") or 0
		Spring.SetUnitRulesParam(attackerID, "scavboss_bigkills", kills + 1)
	end
end

function gadget:GameFrame(frame)
	if frame % Game.gameSpeed ~= 0 then
		return
	end
	---@type number, number, number
	local hunger, meal, heat = -1, -1, -1
	local venting, shielded = false, false
	for unitID in pairs(bosses) do
		heat = math.max(heat, Spring.GetUnitRulesParam(unitID, "scavboss_heat") or 0)
		venting = venting or Spring.GetUnitRulesParam(unitID, "scavboss_venting") == 1
		shielded = shielded or Spring.GetUnitRulesParam(unitID, "scavboss_healshield") == 1
		local bossHunger = Spring.GetUnitRulesParam(unitID, "scavboss_hunger") or 0
		hunger = math.max(hunger, tonumber(bossHunger) or 0)
		if (Spring.GetUnitRulesParam(unitID, "scavboss_feed_state") or 0) > 0 then
			local eaten = Spring.GetUnitRulesParam(unitID, "scavboss_feed_metal") or 0
			local goal = Spring.GetUnitRulesParam(unitID, "scavboss_feed_goal") or 1
			meal = math.max(meal, math.min(100, math.floor(100 * eaten / goal)))
		end
	end
	GG.ScavBossEconomyLost = economy.lostCost / math.max(1, economy.lostCost + economy.standingCost)
	Spring.SetGameRulesParam("scavBossHunger", hunger)
	Spring.SetGameRulesParam("scavBossMeal", meal)
	Spring.SetGameRulesParam("scavBossHealShield", shielded and 1 or 0)
	if heat >= 0 then
		Spring.SetGameRulesParam("scavBossStaggerPercentage", 100 - heat)
		Spring.SetGameRulesParam("scavBossStaggerActive", venting)
	end
end

function gadget:Initialize()
	for _, unitID in ipairs(Spring.GetAllUnits()) do
		if eaters[Spring.GetUnitDefID(unitID)] then
			AddBoss(unitID)
		end
	end
	GG.ScavBossFeedingEffect = FeedingEffect
	GG.ScavBossShield = SetShield
	GG.ScavBossMapSizeShare = mapSizeShare
	gadgetHandler:RegisterAllowCommand(CMD.ANY)
end

function gadget:Shutdown()
	GG.ScavBossFeedingEffect = nil
	GG.ScavBossShield = nil
	GG.ScavBossMapSizeShare = nil
	GG.ScavBossEconomyLost = nil
end

function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID)
	if
		eaters[unitDefID]
		and cmdID ~= CMD.RECLAIM
		and cmdID ~= CMD.ONOFF
		and cmdID ~= CMD.RESURRECT
		and Spring.GetUnitRulesParam(unitID, "scavboss_eating") == 1
	then
		return false
	end
	return true
end

local RAISE_COUNT = 1
local raised = {}

local function SizeName(unitDef)
	local size = math.ceil((unitDef.xsize / 2 + unitDef.zsize / 2) / 2)
	if size > 4.5 then
		return "huge"
	elseif size > 3.5 then
		return "large"
	elseif size > 2.5 then
		return "medium"
	elseif size > 1.5 then
		return "small"
	end
	return "tiny"
end

function gadget:AllowFeatureBuildStep(builderID, builderTeam, featureID, featureDefID, part)
	if part <= 0 or not eaters[Spring.GetUnitDefID(builderID)] then
		return true
	end
	if raised[featureID] then
		return false
	end
	local metal, maxMetal = Spring.GetFeatureResources(featureID)
	local _, _, progress = Spring.GetFeatureHealth(featureID)
	if metal < maxMetal or progress + part < 1 then
		return true
	end
	local rezName = Spring.GetFeatureResurrect(featureID)
	local unitDef = rezName and UnitDefNames[rezName]
	local x, _, z = Spring.GetFeaturePosition(featureID)
	if not unitDef or not x or not z then
		return true
	end
	raised[featureID] = true
	local spawnDef = UnitDefNames[rezName .. "_scav"] or unitDef
	local spread = math.floor(unitDef.xsize * RAISE_COUNT)
	local effect = "scav-spawnexplo-" .. SizeName(unitDef)
	Spring.DestroyFeature(featureID)
	for _ = 1, RAISE_COUNT do
		local sx, sz = x + math.random(-spread, spread), z + math.random(-spread, spread)
		local sy = Spring.GetGroundHeight(sx, sz)
		if Spring.CreateUnit(spawnDef.id, sx, sy, sz, 0, builderTeam) then
			Spring.SpawnCEG(effect, sx, sy, sz, 0, 0, 0)
		end
	end
	return false
end

function gadget:FeatureDestroyed(featureID)
	raised[featureID] = nil
end
