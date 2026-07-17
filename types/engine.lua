---@meta

-- EngineSynced type surface, vendored from a recoil-lua-library generation off the
-- Engine.Synced/Engine.Shared context-split fork of RecoilEngine (see the discussion
-- linked below; the official generation still ships a flat `Spring` table).
-- Only the functions the sharing code actually calls through springRepo/springApi
-- are vendored, so the annotations keep resolving even if the submodule pin moves
-- to an official generation that lacks the split.
-- TODO: delete this file (and annotate against the library's Engine.Synced /
-- Engine.Shared directly) once
-- https://github.com/beyond-all-reason/RecoilEngine/discussions/2953 is resolved
-- and the official recoil-lua-library generation ships the context split.

---Engine API surface handed to synced-context code (gadgets): synced controls plus
---shared reads. At runtime this is the synced `Spring` table (init.lua aliases
---`EngineSynced = EngineSynced or Spring` for engines without SetupAliases).
---@class EngineSynced
---@field GetUnitDefs? fun(): table<integer, UnitDef> test-only extension injected by spec builders
EngineSynced = {}

---@return boolean enabled
function EngineSynced.IsCheatingEnabled() end

---@return integer t1 frameNum % dayFrames
---@return integer t2 frameNum / dayFrames
function EngineSynced.GetGameFrame() end

---@param teamID integer
---@param ruleRef number|string the rule index or name
---@return number|string|nil value
function EngineSynced.GetTeamRulesParam(teamID, ruleRef) end

---@return table<string, string> modOptions Table with options names as keys and values as values.
function EngineSynced.GetModOptions() end

---@return integer teamID
function EngineSynced.GetGaiaTeamID() end

---Get all team IDs.
---
---@param allyTeamID -1|nil (Default: `-1`)
---@return integer[] teamIDs List of team IDs.
function EngineSynced.GetTeamList(allyTeamID) end

---Return types corrected against LuaSyncedRead.cpp: the engine pushes booleans for
---isDead/hasAI (the generated docs say number).
---@param teamID integer
---@param getTeamKeys boolean? (Default: `true`) whether to return the customTeamKeys table
---@return integer? teamID
---@return integer leader
---@return boolean isDead
---@return boolean hasAI
---@return string side
---@return integer allyTeam
---@return number incomeMultiplier
---@return table<string, string> customTeamKeys when getTeamKeys is true, otherwise nil
function EngineSynced.GetTeamInfo(teamID, getTeamKeys) end

---@param teamID integer
---@param resource ResourceName
---@return number? currentLevel The current amount of the resource that the team has in storage at this moment
---@return number storage       The maximum storage capacity for the resource.
---@return number pull          The total amount of the resource that is being requested/used by all units and buildings per second, regardless of whether the resource is actually available.
---@return number income        The total amount of the resource being generated per second from all sources (e.g., mines, generators, reclaiming, etc.).
---@return number expense       The total amount of the resource actually being spent per second. This is the real consumption, which may be less than pull if there isn’t enough resource available.
---@return number share         The fraction (0.0 to 1.0) of the storage that the team is sharing with allied teams. A value of 0.0 means 100% of storage is shared, while 1.0 means only any excess is shared.
---@return number sent          The total amount of the resource that has actually been sent to allies (via sharing or manual transfer).
---@return number received      The total amount of the resource that has actually been received from allies (via sharing or manual transfer).
---@return number excess        The amount of the resource that was lost due to storage overflow (wasted).
function EngineSynced.GetTeamResources(teamID, resource) end

---@param teamID integer
---@return string
function EngineSynced.GetTeamLuaAI(teamID) end

---@param playerID integer
---@param getPlayerOpts boolean? (Default: `true`) whether to return custom player options
---@return string name
---@return boolean active
---@return boolean spectator
---@return integer? teamID
---@return integer allyTeamID
---@return number pingTime
---@return number cpuUsage
---@return string country
---@return number rank
---@return boolean hasSkirmishAIsInTeam
---@return { [string]: string } playerOpts when playerOpts is true
---@return boolean desynced
function EngineSynced.GetPlayerInfo(playerID, getPlayerOpts) end

---@param teamID1 integer
---@param teamID2 integer
---@return boolean?
function EngineSynced.AreTeamsAllied(teamID1, teamID2) end

---@param teamID integer
---@return integer[]? unitIDs
function EngineSynced.GetTeamUnits(teamID) end

---@param unitID integer
---@return integer? teamID nil when the unitID is invalid
function EngineSynced.GetUnitTeam(unitID) end

---@param unitID integer
---@return integer?
function EngineSynced.GetUnitDefID(unitID) end

---@param unitID integer
---@return boolean beingBuilt
---@return number buildProgress
function EngineSynced.GetUnitIsBeingBuilt(unitID) end

---Logs a message to the logfile/console.
---
---@param section string Sets an arbitrary section. Level filtering can be applied per-section
---@param logLevel LogLevel? (Default: `"notice"`)
---@param ... string messages
function EngineSynced.Log(section, logLevel, ...) end

---Adds metal or energy resources to the specified team.
---Counts as production in post-game graph statistics.
---
---@param teamID integer
---@param type ResourceName
---@param amount number
---@return nil
function EngineSynced.AddTeamResource(teamID, type, amount) end

---@param teamID integer
---@param resource ResourceName|StorageName
---@param amount number
---@return nil
function EngineSynced.SetTeamResource(teamID, resource, amount) end

---@param teamID integer
---@param paramName string
---@param paramValue (number|string|boolean)? numeric paramValues in quotes will be converted to number.
---@param losAccess losAccess?
---@return nil
function EngineSynced.SetTeamRulesParam(teamID, paramName, paramValue, losAccess) end

---@param unitID integer
---@param newTeamID integer
---@param given boolean? (Default: `true`) if false, the unit is captured.
---@param adjustUnitLimit boolean? (Default: `false`) if true, also transfer the limit slot
---@return boolean successfulTransfer
function EngineSynced.TransferUnit(unitID, newTeamID, given, adjustUnitLimit) end

-- Pending engine API from https://github.com/beyond-all-reason/RecoilEngine/pull/2642
-- (gadget:ResourceExcess + AddTeamResourceExcessStats); the sharing branch requires
-- that PR to merge. TODO: delete this stub once the PR lands and the generated
-- library documents it.

---Records resource excess for a team without moving resources.
---
---The engine normally tracks excess, but if you use `gadget:ResourceExcess`
---to handle it manually it's now also up to you to track stats.
---@param teamID integer
---@param type ResourceName
---@param excess number Amount wasted this tick.
---@return nil
function Spring.AddTeamResourceExcessStats(teamID, type, excess) end

---@param teamID integer
---@param type ResourceName
---@param excess number Amount wasted this tick.
---@return nil
function EngineSynced.AddTeamResourceExcessStats(teamID, type, excess) end
