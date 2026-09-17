local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Mex Splitting",
		desc = "Map Assigned mex income: deals the map's metal regions to teams at game start and publishes the deal",
		author = "BAR modules",
		date = "September 2026",
		license = "GNU GPL, v2 or later",
		layer = 1,
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return false
end

local TransferEnums = VFS.Include("modules/transfer/enums.lua")

if Spring.GetModOptions()[TransferEnums.ModOptions.MexSplitting] ~= TransferEnums.MexSplitting.MapAssigned then
	return false
end

local MexSplitting = VFS.Include("modules/transfer/api.lua").MexSplitting ---@type TransferMexSplittingApi
local Start = VFS.Include("modules/start/api.lua") ---@type StartApi
local Shared = VFS.Include("modules/transfer/mex_splitting/shared.lua") ---@type MexRegionsShared
local Geometry = VFS.Include("modules/regions/lib/geometry.lua") ---@type RegionGeometry

local TAG = "Mex Splitting"

local ignoredTeams = { [Spring.GetGaiaTeamID()] = true } ---@type table<integer, boolean>
local scavTeamID = BAR.Utilities.GetScavTeamID()
if scavTeamID then
	ignoredTeams[scavTeamID] = true
end
local raptorTeamID = BAR.Utilities.GetRaptorTeamID()
if raptorTeamID then
	ignoredTeams[raptorTeamID] = true
end

local reasonNone ---@type string|nil
local refused ---@type string[]|nil the deal's problems, when it was refused

---@param message string
local function tellEveryone(message)
	for _, playerID in ipairs(Spring.GetPlayerList()) do
		Spring.SendMessageToPlayer(playerID, message)
	end
end

---@return MexRegionsTeamStart[]
local chosen = {} ---@type table<integer, { x: number, z: number }> where a team has asked to start, before the engine has it

-- Where each team starts from: the position it chose, else the one the engine holds, else its start area's centre.
local function teamStarts()
	local centres = {} ---@type { [integer]: { x: number, z: number } }
	for _, area in ipairs(Start.Current(Spring).areas) do
		local ring = {}
		for i, a in ipairs(area.anchors) do
			ring[i] = { x = a.x, z = a.z }
		end
		local cx, cz = Geometry.Centroid(ring)
		local allyTeamID = area.allyTeam - 1 --[[@as integer]]
		centres[allyTeamID] = { x = cx, z = cz }
	end
	local teams = {} ---@type MexRegionsTeamStart[]
	for _, teamID in ipairs(Spring.GetTeamList()) do
		if not ignoredTeams[teamID] then
			local allyTeamID = Spring.GetTeamAllyTeamID(teamID) or 0
			local at = chosen[teamID]
			if at == nil then
				local x, _, z = Spring.GetTeamStartPosition(teamID)
				if x and z and x > 0 and z > 0 then
					at = { x = x, z = z }
				end
			end
			at = at or centres[allyTeamID] or { x = Game.mapSizeX * 0.5, z = Game.mapSizeZ * 0.5 }
			teams[#teams + 1] = { teamID = teamID, allyTeam = allyTeamID + 1, x = at.x, z = at.z }
		end
	end
	return teams
end

local function deal()
	local finder = GG.resource_spot_finder
	local result =
		MexSplitting.Deal(teamStarts(), Spring, finder and not finder.isMetalMap and finder.metalSpotsList or {})
	refused = nil
	if #result.problems > 0 then
		refused = result.problems
		Spring.Log(TAG, LOG.WARNING, "the deal was refused: " .. table.concat(result.problems, "; "))
	end
end

function gadget:Initialize()
	local regions, source, reason = MexSplitting.Load(Spring)
	if regions == nil then
		reasonNone = reason and (source .. ": " .. reason) or source
		Spring.Log(TAG, LOG.WARNING, reasonNone)
		return
	end
	Spring.Log(TAG, LOG.NOTICE, #regions .. " regions from " .. source)
	deal()
end

-- The regions follow the players: each start position chosen before the game deals again from where everyone now
-- stands, and the start deals once more when every position is settled. Whether the position is allowed is the spawn
-- gadget's call, not this one's.
local toldHoldings = {} ---@type table<integer, string> what each team was last told it holds

-- Tell a team's players what they hold, when that has changed.
---@param teamID integer
local function tellHoldings(teamID)
	local held = table.concat(MexSplitting.Holdings()[teamID] or {}, ", ")
	if held == toldHoldings[teamID] then
		return
	end
	toldHoldings[teamID] = held
	local line = held ~= "" and ("your mex regions: " .. held:gsub("@%d+", "")) or "you hold no mex regions"
	for _, playerID in ipairs(Spring.GetPlayerList(teamID)) do
		Spring.SendMessageToPlayer(playerID, TAG .. ": " .. line)
	end
end

function gadget:AllowStartPosition(_, teamID, _, x, _, z)
	if reasonNone == nil and not ignoredTeams[teamID] and x and z and x > 0 and z > 0 then
		chosen[teamID] = { x = x, z = z }
		deal()
		if not refused then
			tellHoldings(teamID)
		end
	end
	return true
end

function gadget:GameStart()
	if reasonNone == nil then
		chosen = {}
		deal()
		if not refused then
			for _, teamID in ipairs(Spring.GetTeamList()) do
				if not ignoredTeams[teamID] then
					tellHoldings(teamID)
				end
			end
		end
	end
end

-- A map maker trying out what they just drew: with no layout from the lobby or the map, before the start, the only
-- human in the match may hand over their terraformer save. Nobody can do that to a match other people are in.
function gadget:RecvLuaMsg(msg)
	if msg:sub(1, #Shared.LAYOUT_MSG) ~= Shared.LAYOUT_MSG then
		return
	end
	if reasonNone == nil or Spring.GetGameFrame() > 0 then
		Spring.Log(TAG, LOG.NOTICE, "a terraformer layout arrived too late, or the match already has one")
		return true
	end
	local humans = 0
	for _, playerID in ipairs(Spring.GetPlayerList()) do
		-- not "active": nobody is, before the start. Every seated player counts, connected yet or not.
		local _, _, spectator = Spring.GetPlayerInfo(playerID, false)
		if not spectator then
			humans = humans + 1
		end
	end
	if humans ~= 1 then
		Spring.Log(TAG, LOG.NOTICE, "a terraformer layout is only taken from a lone player; this match has " .. humans)
		return true
	end
	local source = "the terraformer's save, from the only player"
	local regions, reason = MexSplitting.LoadBlob(msg:sub(#Shared.LAYOUT_MSG + 1), source)
	if regions == nil then
		Spring.Log(TAG, LOG.WARNING, source .. ": " .. tostring(reason))
		return true
	end
	reasonNone = nil
	Spring.Log(TAG, LOG.NOTICE, #regions .. " regions from " .. source)
	deal()
	if refused then
		tellEveryone(TAG .. ": your terraformer layout was refused: " .. table.concat(refused, "; "))
	else
		tellEveryone(TAG .. ": Map Assigned is using your terraformer layout for this map.")
	end
	return true
end

-- Said once the match has loaded, before anyone picks a start: what the option did to this match.
function gadget:GamePreload()
	local why = refused or (reasonNone and { reasonNone }) or nil
	if why then
		tellEveryone(
			"Mex Splitting: Map Assigned is set but mex regions are not configured by the map maker. Please set the 'mex_regions_layout' mod option."
		)
		for _, problem in ipairs(why) do
			tellEveryone(TAG .. ": " .. problem)
		end
		tellEveryone(TAG .. ": mexes are unrestricted, as under Mex Splitting: None.")
		return
	end
	tellEveryone(
		"Mex Splitting: Map Assigned. You may build mexes on your own metal spots and on the enemy's, not on an ally's."
	)
end

function gadget:TeamDied(teamID)
	if refused or reasonNone or ignoredTeams[teamID] then
		return
	end
	local heir = MexSplitting.Inherit(teamID, Spring)
	if heir then
		Spring.Log(TAG, LOG.NOTICE, "team " .. teamID .. "'s regions pass to team " .. heir)
	end
end
