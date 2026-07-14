function gadget:GetInfo()
	return {
		name      = "Unit Restrictions Plus",
		desc      = "Improved upon maxthisunit to work across units, and even several scopes.",
		author    = "RandomGuyJunior",
		date      = "2026-07-14",
		license   = "GPLv2 or later",
		layer     = 0,
		enabled   = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return
end

--------------------------------------------------------------------------------
-- Configuration
--------------------------------------------------------------------------------

local PARAM_POOL  = "unitlimit_pool" 
local PARAM_LIMIT = "unitlimit_limit"
local PARAM_SCOPE = "unitlimit_scope"
-- customparams.unitlimit_pool = string (set to lowercase, group units based on it)
-- customparams.unitlimit_limit = int (how many units are allowed in the pool at once)
-- customparams.unitlimit_scope = string (team = per player, allyteam = per team, game = per game)

local VALID_SCOPES = {
	team     = true,
	allyteam = true,
	game     = true,
}

--------------------------------------------------------------------------------
-- Spring aliases
--------------------------------------------------------------------------------

local spEcho         = Spring.Echo
local spGetAllUnits  = Spring.GetAllUnits
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitTeam  = Spring.GetUnitTeam
local spGetTeamInfo  = Spring.GetTeamInfo

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------

-- Configuration indexed by UnitDefID.
local unitConfigs = {}

-- Used to make sure every UnitDef in a pool uses the same limit and scope.
local poolConfigs = {}

-- counts[poolName][scopeKey] = number of units
local counts = {}

-- Tracks which pool slot belongs to each live unit.
local unitRecords = {}

-- Evolution creates the new unit before removing the old one.
-- This table stores one approved replacement until UnitCreated receives it.
local pendingReplacements = {}

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

local function NormalizeString(value)
	if value == nil then
		return nil
	end

	value = tostring(value):lower():match("^%s*(.-)%s*$")
	return value ~= "" and value or nil
end

local function GetAllyTeamID(teamID)
	local _, _, _, allyTeamID = spGetTeamInfo(teamID, false)

	if allyTeamID == nil then
		spEcho(string.format(
			"[Unit Restrictions Plus] Could not get allyTeamID for team %s",
			tostring(teamID)
		))
		return teamID
	end

	return allyTeamID
end

local function GetScopeKey(scope, teamID)
	if scope == "team" then
		return teamID
	elseif scope == "allyteam" then
		return GetAllyTeamID(teamID)
	end

	-- All game-scoped pools use the same key.
	return 0
end

local function GetCount(poolName, scopeKey)
	local poolCounts = counts[poolName]
	return poolCounts and poolCounts[scopeKey] or 0
end

local function ChangeCount(poolName, scopeKey, amount)
	local poolCounts = counts[poolName]

	if not poolCounts then
		poolCounts = {}
		counts[poolName] = poolCounts
	end

	local newCount = (poolCounts[scopeKey] or 0) + amount

	if newCount > 0 then
		poolCounts[scopeKey] = newCount
	else
		poolCounts[scopeKey] = nil
	end
end

local function FindPendingReplacement(teamID, newUnitDefID)
	local teamPending = pendingReplacements[teamID]
	return teamPending and teamPending[newUnitDefID]
end

local function ClearPendingReplacement(teamID, newUnitDefID)
	local teamPending = pendingReplacements[teamID]

	if not teamPending then
		return
	end

	teamPending[newUnitDefID] = nil

	if not next(teamPending) then
		pendingReplacements[teamID] = nil
	end
end

--------------------------------------------------------------------------------
-- Pool accounting
--------------------------------------------------------------------------------

local function CanAddUnit(unitDefID, teamID)
	local config = unitConfigs[unitDefID]

	if not config then
		return true
	end

	local scopeKey = GetScopeKey(config.scope, teamID)
	return GetCount(config.pool, scopeKey) < config.limit
end

local function AddUnit(unitID, unitDefID, teamID)
	if unitRecords[unitID] then
		return
	end

	local config = unitConfigs[unitDefID]

	if not config then
		return
	end

	local scopeKey = GetScopeKey(config.scope, teamID)

	ChangeCount(config.pool, scopeKey, 1)

	unitRecords[unitID] = {
		unitDefID = unitDefID,
		teamID    = teamID,
		pool      = config.pool,
		scope     = config.scope,
		scopeKey  = scopeKey,
	}
end

local function RemoveUnit(unitID)
	local record = unitRecords[unitID]

	if not record then
		return
	end

	ChangeCount(record.pool, record.scopeKey, -1)
	unitRecords[unitID] = nil
end

local function MoveUnit(unitID, unitDefID, oldTeamID, newTeamID)
	local config = unitConfigs[unitDefID]

	if not config then
		return
	end

	local record = unitRecords[unitID]

	-- A missing record means the unit was not counted. Register it for its
	-- current owner rather than guessing which old count should be removed.
	if not record then
		AddUnit(unitID, unitDefID, newTeamID)
		return
	end

	local oldScopeKey = record.scopeKey
	local newScopeKey = GetScopeKey(config.scope, newTeamID)

	if oldScopeKey ~= newScopeKey then
		ChangeCount(record.pool, oldScopeKey, -1)
		ChangeCount(config.pool, newScopeKey, 1)
	end

	record.teamID = newTeamID
	record.scopeKey = newScopeKey
end

--------------------------------------------------------------------------------
-- Evolution support
--------------------------------------------------------------------------------

local function AuthorizeReplacement(oldUnitID, newUnitDefID, teamID)
	local oldRecord = unitRecords[oldUnitID]
	local newConfig = unitConfigs[newUnitDefID]

	-- No special handling is needed when neither form belongs to a pool.
	if not oldRecord and not newConfig then
		return false
	end

	-- A slot can only be inherited when both forms use the same pool.
	if not oldRecord or not newConfig then
		return false
	end

	local newScopeKey = GetScopeKey(newConfig.scope, teamID)

	if oldRecord.teamID ~= teamID
		or oldRecord.pool ~= newConfig.pool
		or oldRecord.scope ~= newConfig.scope
		or oldRecord.scopeKey ~= newScopeKey
	then
		return false
	end

	local teamPending = pendingReplacements[teamID]

	if not teamPending then
		teamPending = {}
		pendingReplacements[teamID] = teamPending
	end

	if teamPending[newUnitDefID] then
		spEcho(string.format(
			"[Unit Restrictions Plus] Replacement already pending for team %s and UnitDef %s",
			tostring(teamID),
			tostring(newUnitDefID)
		))
		return false
	end

	teamPending[newUnitDefID] = {
		oldUnitID = oldUnitID,
		pool      = oldRecord.pool,
		scope     = oldRecord.scope,
		scopeKey  = oldRecord.scopeKey,
		allowed   = false,
	}

	return true
end

local function CancelReplacement(oldUnitID, newUnitDefID, teamID)
	local pending = FindPendingReplacement(teamID, newUnitDefID)

	if pending and pending.oldUnitID == oldUnitID then
		ClearPendingReplacement(teamID, newUnitDefID)
	end
end

local function TransferReplacementSlot(newUnitID, newUnitDefID, teamID)
	local pending = FindPendingReplacement(teamID, newUnitDefID)

	if not pending or not pending.allowed then
		return false
	end

	local oldRecord = unitRecords[pending.oldUnitID]
	local newConfig = unitConfigs[newUnitDefID]
	local newScopeKey = newConfig and GetScopeKey(newConfig.scope, teamID)

	if not oldRecord
		or not newConfig
		or oldRecord.pool ~= pending.pool
		or oldRecord.scope ~= pending.scope
		or oldRecord.scopeKey ~= pending.scopeKey
		or newConfig.pool ~= pending.pool
		or newConfig.scope ~= pending.scope
		or newScopeKey ~= pending.scopeKey
	then
		ClearPendingReplacement(teamID, newUnitDefID)
		return false
	end

	-- The replacement inherits the old unit's existing slot.
	unitRecords[pending.oldUnitID] = nil
	unitRecords[newUnitID] = {
		unitDefID = newUnitDefID,
		teamID    = teamID,
		pool      = pending.pool,
		scope     = pending.scope,
		scopeKey  = pending.scopeKey,
	}

	ClearPendingReplacement(teamID, newUnitDefID)
	return true
end

--------------------------------------------------------------------------------
-- UnitDef parsing
--------------------------------------------------------------------------------

local function LoadUnitConfigs()
	for unitDefID, unitDef in pairs(UnitDefs) do
		local customParams = unitDef.customParams

		if customParams then
			local poolName = NormalizeString(customParams[PARAM_POOL])

			if poolName then
				local limit = tonumber(customParams[PARAM_LIMIT])
				local scope = NormalizeString(customParams[PARAM_SCOPE]) or "team"

				if not VALID_SCOPES[scope] then
					spEcho(string.format(
						"[Unit Restrictions Plus] Invalid scope '%s' on '%s'",
						tostring(scope),
						unitDef.name
					))
				elseif not limit or limit < 1 or limit ~= math.floor(limit) then
					spEcho(string.format(
						"[Unit Restrictions Plus] Invalid limit '%s' on '%s'",
						tostring(customParams[PARAM_LIMIT]),
						unitDef.name
					))
				else
					local poolConfig = poolConfigs[poolName]

					if poolConfig
						and (poolConfig.limit ~= limit or poolConfig.scope ~= scope)
					then
						spEcho(string.format(
							"[Unit Restrictions Plus] Pool '%s' has conflicting settings on '%s'",
							poolName,
							unitDef.name
						))
					else
						poolConfigs[poolName] = poolConfig or {
							limit = limit,
							scope = scope,
						}

						unitConfigs[unitDefID] = {
							pool  = poolName,
							limit = limit,
							scope = scope,
						}
					end
				end
			end
		end
	end
end

--------------------------------------------------------------------------------
-- Gadget lifecycle
--------------------------------------------------------------------------------

function gadget:Initialize()
	LoadUnitConfigs()

	GG.UnitRestrictionsPlus = GG.UnitRestrictionsPlus or {}
	GG.UnitRestrictionsPlus.AuthorizeReplacement = AuthorizeReplacement
	GG.UnitRestrictionsPlus.CancelReplacement = CancelReplacement

	-- Also count units that already exist after a gadget reload or map setup.
	local allUnits = spGetAllUnits()

	for i = 1, #allUnits do
		local unitID = allUnits[i]
		local unitDefID = spGetUnitDefID(unitID)
		local teamID = spGetUnitTeam(unitID)

		if unitDefID and teamID then
			AddUnit(unitID, unitDefID, teamID)
		end
	end
end

function gadget:Shutdown()
	if not GG.UnitRestrictionsPlus then
		return
	end

	GG.UnitRestrictionsPlus.AuthorizeReplacement = nil
	GG.UnitRestrictionsPlus.CancelReplacement = nil

	if not next(GG.UnitRestrictionsPlus) then
		GG.UnitRestrictionsPlus = nil
	end
end

--------------------------------------------------------------------------------
-- Creation
--------------------------------------------------------------------------------

function gadget:AllowUnitCreation(
	unitDefID,
	builderID,
	builderTeamID,
	x,
	y,
	z,
	facing
)
	local pending = FindPendingReplacement(builderTeamID, unitDefID)

	if pending then
		local oldRecord = unitRecords[pending.oldUnitID]
		local newConfig = unitConfigs[unitDefID]
		local newScopeKey = newConfig and GetScopeKey(newConfig.scope, builderTeamID)

		if oldRecord
			and newConfig
			and oldRecord.pool == pending.pool
			and oldRecord.scope == pending.scope
			and oldRecord.scopeKey == pending.scopeKey
			and newConfig.pool == pending.pool
			and newConfig.scope == pending.scope
			and newScopeKey == pending.scopeKey
		then
			pending.allowed = true
			return true
		end

		ClearPendingReplacement(builderTeamID, unitDefID)
	end

	return CanAddUnit(unitDefID, builderTeamID)
end

function gadget:UnitCreated(unitID, unitDefID, unitTeam)
	if not TransferReplacementSlot(unitID, unitDefID, unitTeam) then
		AddUnit(unitID, unitDefID, unitTeam)
	end
end

function gadget:UnitDestroyed(unitID)
	RemoveUnit(unitID)
end

--------------------------------------------------------------------------------
-- Ownership transfers
--------------------------------------------------------------------------------

function gadget:AllowUnitTransfer(
	unitID,
	unitDefID,
	oldTeamID,
	newTeamID,
	capture
)
	local config = unitConfigs[unitDefID]

	if not config then
		return true
	end

	local oldScopeKey = GetScopeKey(config.scope, oldTeamID)
	local newScopeKey = GetScopeKey(config.scope, newTeamID)

	if oldScopeKey == newScopeKey then
		return true
	end

	return GetCount(config.pool, newScopeKey) < config.limit
end

function gadget:UnitGiven(unitID, unitDefID, newTeamID, oldTeamID)
	MoveUnit(unitID, unitDefID, oldTeamID, newTeamID)
end
