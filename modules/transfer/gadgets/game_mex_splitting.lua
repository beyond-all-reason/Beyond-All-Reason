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

local MexRegions = VFS.Include("modules/transfer/api.lua").MexSplitting ---@type TransferMexSplittingApi
local Start = VFS.Include("modules/start/api.lua") ---@type StartApi
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
			local centre = centres[allyTeamID] or { x = Game.mapSizeX * 0.5, z = Game.mapSizeZ * 0.5 }
			teams[#teams + 1] = { teamID = teamID, allyTeam = allyTeamID + 1, x = centre.x, z = centre.z }
		end
	end
	return teams
end

function gadget:Initialize()
	local regions, source, reason = MexRegions.Load(Spring)
	if regions == nil then
		reasonNone = reason and (source .. ": " .. reason) or source
		Spring.Log(TAG, LOG.WARNING, reasonNone)
		return
	end
	Spring.Log(TAG, LOG.INFO, #regions .. " regions from " .. source)
	local finder = GG.resource_spot_finder
	local deal = MexRegions.Deal(teamStarts(), Spring, finder and not finder.isMetalMap and finder.metalSpotsList or {})
	if #deal.problems > 0 then
		refused = deal.problems
		Spring.Log(TAG, LOG.WARNING, "the deal was refused: " .. table.concat(deal.problems, "; "))
	end
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
	local heir = MexRegions.Inherit(teamID, Spring)
	if heir then
		Spring.Log(TAG, LOG.INFO, "team " .. teamID .. "'s regions pass to team " .. heir)
	end
end
