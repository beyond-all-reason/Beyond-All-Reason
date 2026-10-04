local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Scav boss eating",
		desc = "Starts the boss feeding sequence on request and keeps it on its reclaim order while it eats",
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

local function FlagAllBosses(param)
	for _, unitID in ipairs(Spring.GetAllUnits()) do
		if eaters[Spring.GetUnitDefID(unitID)] then
			Spring.SetUnitRulesParam(unitID, param, 1)
		end
	end
	return true
end

local function StartFeeding()
	return FlagAllBosses("scavboss_feed")
end

local function TestBlast()
	return FlagAllBosses("scavboss_blast")
end

local function TestShield()
	return FlagAllBosses("scavboss_shield")
end

local function TestRaise()
	return FlagAllBosses("scavboss_raise")
end

local function TestRail()
	return FlagAllBosses("scavboss_rail")
end

local function SelectWeapons(cmd, line, words)
	local group = words[1] or "all"
	for _, unitID in ipairs(Spring.GetAllUnits()) do
		if eaters[Spring.GetUnitDefID(unitID)] then
			Spring.SetUnitRulesParam(unitID, "scavboss_weapons", group)
		end
	end
	return true
end

local function SelectTurbo(cmd, line, words)
	local kind = words[1] or "auto"
	for _, unitID in ipairs(Spring.GetAllUnits()) do
		if eaters[Spring.GetUnitDefID(unitID)] then
			Spring.SetUnitRulesParam(unitID, "scavboss_turbo", kind)
		end
	end
	return true
end

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
	local hunger, meal = -1, -1
	for unitID in pairs(bosses) do
		hunger = math.max(hunger, Spring.GetUnitRulesParam(unitID, "scavboss_hunger") or 0)
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
		gadget:UnitCreated(unitID, Spring.GetUnitDefID(unitID))
	end
	GG.ScavBossFeedingEffect = FeedingEffect
	GG.ScavBossShield = SetShield
	gadgetHandler:AddChatAction("scavbosseat", StartFeeding, "Makes every scav boss start its feeding sequence")
	gadgetHandler:AddChatAction("scavbossblast", TestBlast, "Fires the scav boss blast for tuning")
	gadgetHandler:AddChatAction("scavbossshield", TestShield, "Plays the scav boss shield charge for tuning")
	gadgetHandler:AddChatAction(
		"scavbossrail",
		TestRail,
		"Ends the scav boss's current weapon turn so the next group starts"
	)
	gadgetHandler:AddChatAction("scavbossraise", TestRaise, "Makes every scav boss start raising wrecks")
	gadgetHandler:AddChatAction(
		"scavbossweapon",
		SelectWeapons,
		"Lets only one scav boss weapon group aim: gauss napalm laser volley arms barrage rain stream pods turrets railheavy railrapid rail beam aa all"
	)
	gadgetHandler:AddChatAction(
		"scavbossturbo",
		SelectTurbo,
		"Starts a scav boss turbo at once: air close far swarm beam devour raise; off stops turbos, auto resumes them"
	)
	gadgetHandler:RegisterAllowCommand(CMD.ANY)
end

function gadget:Shutdown()
	GG.ScavBossFeedingEffect = nil
	GG.ScavBossShield = nil
	gadgetHandler:RemoveChatAction("scavbosseat")
	gadgetHandler:RemoveChatAction("scavbossblast")
	gadgetHandler:RemoveChatAction("scavbossshield")
	gadgetHandler:RemoveChatAction("scavbossrail")
	gadgetHandler:RemoveChatAction("scavbossraise")
	gadgetHandler:RemoveChatAction("scavbossweapon")
	gadgetHandler:RemoveChatAction("scavbossturbo")
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
	if not unitDef or not x then
		return true
	end
	raised[featureID] = true
	local spawnDef = UnitDefNames[rezName .. "_scav"] or unitDef
	local spread = unitDef.xsize * RAISE_COUNT
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
