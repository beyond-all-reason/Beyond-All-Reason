--DEFEND FIRESTATE REWORK: Remove guard; defend targeting is always required
if not Spring.GetModOptions().experimental_defend_firestate then
	return
end

local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Firestate Defend",
		desc = "Limits defend firestate to nearby targets",
		author = "SethDGamre",
		date = "2026.06.28",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true
	}
end

if not gadgetHandler:IsSyncedCode() then
	return false
end

--increase safety margin buffer so a pawn can walk through a minefield that's exposed

local CustomFirestateDefs = VFS.Include("modules/custom_firestate_defs.lua")
local WeaponThreat = VFS.Include("modules/weaponthreat.lua")
local CMD_FIRE_STATE = CMD.FIRE_STATE
local ALWAYS_SHOOT = WeaponThreat.ALWAYS_SHOOT
local NO_THREAT = WeaponThreat.NO_THREAT
local HP_CHECK_INTERVAL_FRAMES = Game.gameSpeed * 3
local MIN_RADAR_DEFPRIORITY = 10000000 -- this is the floor of what a radar covered unit will generate for defpriorirty. If below this, it's certainly in LOS. For performance
local UNIT_DEF_ID = 1
local IS_DEFEND = 2
local NEVER_HESITATE = 3
local WEAPON_DEF_IDS = 4
local LAST_HEALTH = 5
local HP_CHECK_FRAME = 6
local RADAR_AGGRO = 7
local CLOAKED = 8
local ALWAYS_HARMLESS = 9
local defThreatRanges = {}
local neverHesitateAttackers = {}
local alwaysHarmlessUnitDefs = {}
local weaponWatchRefCount = {}
local watchedWeaponsByUnitDef = {}
local metaData = {}
local gameFrame = 0

local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitRulesParam = Spring.GetUnitRulesParam
local spGetUnitIsCloaked = Spring.GetUnitIsCloaked
local spGetAllUnits = Spring.GetAllUnits
local spGetUnitHealth = Spring.GetUnitHealth
local spGetUnitSeparation = Spring.GetUnitSeparation

local function addWeaponWatches(weaponDefIDs)
	for index = 1, #weaponDefIDs do
		local weaponDefID = weaponDefIDs[index]
		local refCount = (weaponWatchRefCount[weaponDefID] or 0) + 1
		weaponWatchRefCount[weaponDefID] = refCount
		if refCount == 1 then
			Script.SetWatchAllowTarget(weaponDefID, true)
		end
	end
end

local function removeWeaponWatches(weaponDefIDs)
	for index = 1, #weaponDefIDs do
		local weaponDefID = weaponDefIDs[index]
		local refCount = (weaponWatchRefCount[weaponDefID] or 0) - 1
		if refCount <= 0 then
			weaponWatchRefCount[weaponDefID] = nil
			Script.SetWatchAllowTarget(weaponDefID, false)
		else
			weaponWatchRefCount[weaponDefID] = refCount
		end
	end
end

local function setDefendWatch(unitID, isDefend)
	local meta = metaData[unitID]
	if not meta then
		return
	end

	if isDefend then
		if meta[IS_DEFEND] then
			meta[LAST_HEALTH] = spGetUnitHealth(unitID)
			return
		end

		local unitDefID = meta[UNIT_DEF_ID]
		local weaponDefIDs = watchedWeaponsByUnitDef[unitDefID]
		meta[IS_DEFEND] = true
		meta[NEVER_HESITATE] = neverHesitateAttackers[unitDefID] or false
		meta[WEAPON_DEF_IDS] = weaponDefIDs
		meta[LAST_HEALTH] = spGetUnitHealth(unitID)

		if weaponDefIDs then
			addWeaponWatches(weaponDefIDs)
		end
	elseif meta[IS_DEFEND] then
		if meta[WEAPON_DEF_IDS] then
			removeWeaponWatches(meta[WEAPON_DEF_IDS])
		end
		meta[IS_DEFEND] = nil
		meta[WEAPON_DEF_IDS] = nil
		meta[RADAR_AGGRO] = nil
		meta[HP_CHECK_FRAME] = nil
	end
end

local function checkDefendUnitHealth(attackerID, meta)
	local nextCheckFrame = meta[HP_CHECK_FRAME]
	if nextCheckFrame and gameFrame < nextCheckFrame then
		return
	end

	local currentHealth = spGetUnitHealth(attackerID)
	if not currentHealth then
		return
	end

	local lastHealth = meta[LAST_HEALTH]
	if lastHealth and currentHealth < lastHealth then
		meta[RADAR_AGGRO] = true
	elseif lastHealth and currentHealth > lastHealth then
		meta[RADAR_AGGRO] = nil
	end

	meta[LAST_HEALTH] = currentHealth
	meta[HP_CHECK_FRAME] = gameFrame + HP_CHECK_INTERVAL_FRAMES
end

local function updateDefendWatchFromRulesParam(unitID)
	local state = spGetUnitRulesParam(unitID, CustomFirestateDefs.RULES_PARAM)
	setDefendWatch(unitID, state == CustomFirestateDefs.DEFEND)
end

local function createUnitMeta(unitDefID)
	local meta = { [UNIT_DEF_ID] = unitDefID }
	if alwaysHarmlessUnitDefs[unitDefID] then
		meta[ALWAYS_HARMLESS] = true
	end
	return meta
end

function gadget:UnitCommand(unitID, unitDefID, unitTeamID, cmdID, cmdParams, cmdOptions, cmdTag, playerID, fromSynced, fromLua)
	if cmdID == CMD_FIRE_STATE then
		updateDefendWatchFromRulesParam(unitID)
	end
end

function gadget:UnitCreated(unitID, unitDefID, unitTeam)
	metaData[unitID] = createUnitMeta(unitDefID)
end

function gadget:UnitFinished(unitID, unitDefID, unitTeam)
	updateDefendWatchFromRulesParam(unitID)
end

function gadget:UnitCloaked(unitID, unitDefID, unitTeam)
	local meta = metaData[unitID]
	if meta then
		meta[CLOAKED] = true
	end
end

function gadget:UnitDecloaked(unitID, unitDefID, unitTeam)
	local meta = metaData[unitID]
	if meta then
		meta[CLOAKED] = nil
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam)
	local meta = metaData[unitID]
	if meta and meta[WEAPON_DEF_IDS] then
		removeWeaponWatches(meta[WEAPON_DEF_IDS])
	end
	metaData[unitID] = nil
end

function gadget:GameFrame(frame)
	gameFrame = frame
end

function gadget:AllowWeaponTarget(attackerID, targetID, attackerWeaponNum, attackerWeaponDefID, defPriority)
	local targetMeta = metaData[targetID]
	if not targetMeta then
		return false
	end

	local attackerMeta = metaData[attackerID]
	local isDefend = attackerMeta and attackerMeta[IS_DEFEND]

	if targetMeta[ALWAYS_HARMLESS] then
		return not isDefend
	end

	if not isDefend then
		return true
	end

	local rangesForWeapon = defThreatRanges[attackerWeaponDefID]
	if not rangesForWeapon then
		return true
	end

	local threatRange = rangesForWeapon[targetMeta[UNIT_DEF_ID]]
	if not threatRange or threatRange == NO_THREAT then
		return false
	end

	if attackerMeta[CLOAKED] then
		return false
	end

	if attackerMeta[NEVER_HESITATE] then
		return true
	end

	if (defPriority or 0) > MIN_RADAR_DEFPRIORITY then
		checkDefendUnitHealth(attackerID, attackerMeta)
		return attackerMeta[RADAR_AGGRO] or false
	end

	if threatRange == ALWAYS_SHOOT then
		return true
	end

	local separation = spGetUnitSeparation(attackerID, targetID)
	return not separation or separation <= threatRange
end

function gadget:Initialize()
	defThreatRanges, watchedWeaponsByUnitDef, neverHesitateAttackers, alwaysHarmlessUnitDefs = WeaponThreat.buildDefendData()

	for _, unitID in ipairs(spGetAllUnits()) do
		local unitDefID = spGetUnitDefID(unitID)
		local meta = createUnitMeta(unitDefID)
		metaData[unitID] = meta
		updateDefendWatchFromRulesParam(unitID)
		if spGetUnitIsCloaked(unitID) then
			meta[CLOAKED] = true
		end
	end
end
