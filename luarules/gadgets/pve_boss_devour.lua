local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "PvE Boss Devour",
		desc = "Devour and Raise support for PvE bosses: holds their orders while they eat, turns raised wrecks into their units, reports hunger",
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
for unitDefID, unitDef in pairs(UnitDefs) do
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

local feedCount = 0
local function FeedingEffect(unitID, unitDefID, index)
	feedCount = feedCount + 1
	local baseDef = UnitDefNames[UnitDefs[unitDefID].name:gsub("_scav$", "")]
	SendToUnsynced("cob_UnitScriptDistortion", unitID, baseDef and baseDef.id or unitDefID, index, feedCount)
end

local function SetShield(unitID, on)
	Spring.GiveOrderToUnit(unitID, CMD.ONOFF, { on and 1 or 0 }, 0)
end

function gadget:UnitCreated(unitID, unitDefID)
	if eaters[unitDefID] then
		bosses[unitID] = true
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam)
	bosses[unitID] = nil
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
	---@type number, number
	local hunger, meal = -1, -1
	for unitID in pairs(bosses) do
		hunger = math.max(hunger, tonumber(Spring.GetUnitRulesParam(unitID, "scavboss_hunger")) or 0)
		if (Spring.GetUnitRulesParam(unitID, "scavboss_feed_state") or 0) > 0 then
			local eaten = Spring.GetUnitRulesParam(unitID, "scavboss_feed_metal") or 0
			local goal = Spring.GetUnitRulesParam(unitID, "scavboss_feed_goal") or 1
			meal = math.max(meal, math.min(100, math.floor(100 * eaten / goal)))
		end
	end
	Spring.SetGameRulesParam("scavBossHunger", hunger)
	Spring.SetGameRulesParam("scavBossMeal", meal)
end

function gadget:Initialize()
	for _, unitID in ipairs(Spring.GetAllUnits()) do
		if eaters[Spring.GetUnitDefID(unitID)] then
			bosses[unitID] = true
		end
	end
	GG.ScavBossFeedingEffect = FeedingEffect
	GG.ScavBossShield = SetShield
	gadgetHandler:RegisterAllowCommand(CMD.ANY)
end

function gadget:Shutdown()
	GG.ScavBossFeedingEffect = nil
	GG.ScavBossShield = nil
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
