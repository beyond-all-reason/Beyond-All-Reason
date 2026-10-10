local Game = Game
local Spring = Spring

local Claims = require("modules/transfer/mex_splitting/claims")
local Deal = require("modules/transfer/mex_splitting/deal")
local ModuleHandler = require("modules/module_handler")
local Modules = require("modules/enums").Modules
local Sources = require("modules/transfer/mex_splitting/sources")
local TransferEnums = require("modules/transfer/enums")
local UnitShared = require("modules/transfer/unit/shared")
local state = require("modules/transfer/state")

local mayUnitScratch = {}
local mayValidationScratch = {}

---@param springRepo Spring
---@param regions MexRegion[]
---@param deal MexRegionsDeal
local function publish(springRepo, regions, deal)
	springRepo.SetGameRulesParam(Deal.PARAM, Deal.Encode(regions, deal.regions, Game.mapSizeX, Game.mapSizeZ))
end

---@class TransferMexSplittingApi Map Assigned: the layout, the deal, and who holds what
local MexSplitting = {
	---@param springRepo Spring
	---@return MexRegion[]|nil regions
	---@return string source
	---@return string|nil reason
	Load = function(springRepo)
		local regions, source, reason =
			Sources.Load(springRepo.GetModOptions(), Game.mapName, Game.mapSizeX, Game.mapSizeZ)
		state.mexRegions = regions
		state.mexRegionsSource = source
		return regions, source, reason
	end,

	---@param raw string a layout blob handed over after load
	---@param source string where it came from, for the log
	---@return MexRegion[]|nil regions
	---@return string|nil reason
	LoadBlob = function(raw, source)
		local regions, reason = Sources.FromBlob(raw, Game.mapSizeX, Game.mapSizeZ)
		if regions then
			state.mexRegions = regions
			state.mexRegionsSource = source
		end
		return regions, reason
	end,

	---@return MexRegion[] the loaded layout's regions; none before Load
	Regions = function()
		return state.mexRegions or {}
	end,

	---@param teams MexRegionsTeamStart[]
	---@param springRepo Spring
	---@param spots { x: number, z: number }[] the map's metal spots
	---@return MexRegionsDeal
	Deal = function(teams, springRepo, spots)
		---@type TransferContract
		local Transfer = ModuleHandler.Contract(Modules.Transfer)
		local regions = state.mexRegions or {}
		---@type MexRegionsDealContext
		local ctx = { regions = regions, spots = spots or {}, teams = teams }
		local deal = ModuleHandler.Evaluate(Transfer.MexSplitting, ctx)
		state.mexDeal = deal
		state.mexTeams = teams
		state.mexGifted = {}
		publish(springRepo, regions, deal)
		return deal
	end,

	---A team has left the match: its regions, and the spots in them, pass to one living ally.
	---@param departingTeamID integer
	---@param springRepo Spring
	---@return integer|nil heir the team that took them; nil when the team held nothing or nobody is left to take it
	Inherit = function(departingTeamID, springRepo)
		---@type TransferContract
		local Transfer = ModuleHandler.Contract(Modules.Transfer)
		local deal, teams = state.mexDeal, state.mexTeams or {}
		local departing ---@type MexRegionsTeamStart|nil
		for _, team in ipairs(teams) do
			if team.teamID == departingTeamID then
				departing = team
			end
		end
		if deal == nil or departing == nil then
			return nil
		end
		local gifted = state.mexGifted or {}
		local heirs = {}
		for _, team in ipairs(teams) do
			local _, _, isDead = springRepo.GetTeamInfo(team.teamID, false)
			if
				team.teamID ~= departingTeamID
				and not isDead
				and springRepo.AreTeamsAllied(departingTeamID, team.teamID)
			then
				heirs[#heirs + 1] = { teamID = team.teamID, x = team.x, z = team.z, gifted = gifted[team.teamID] or 0 }
			end
		end
		local heir = ModuleHandler.Evaluate(Transfer.MexSplittingHeir, { departing = departing, heirs = heirs })
		if not heir then
			return nil
		end
		local moved = 0
		for id, holder in pairs(deal.regions) do
			if holder == departingTeamID then
				deal.regions[id] = heir
				moved = moved + 1
			end
		end
		if moved == 0 then
			return nil
		end
		for _, holders in pairs(deal.spots) do
			for i = #holders, 1, -1 do
				if holders[i] == departingTeamID then
					table.remove(holders, i)
					if not table.contains(holders, heir) then
						table.insert(holders, heir)
					end
				end
			end
		end
		gifted[heir] = (gifted[heir] or 0) + moved
		state.mexGifted = gifted
		publish(springRepo, state.mexRegions or {}, deal)
		return heir
	end,

	---@return table<integer, string[]|nil> teamID -> the ids of the regions it holds
	Holdings = function()
		return Claims.Holdings(state.mexRegions or {}, state.mexDeal and state.mexDeal.regions or {})
	end,
}

return {
	MexSplitting = MexSplitting,

	---@param unitID integer
	---@param fromTeamID integer
	---@param toTeamID integer
	---@param capture boolean|nil engine-driven capture, never a policy question
	---@return boolean
	MayTransfer = function(unitID, fromTeamID, toTeamID, capture)
		if capture then
			return true
		end
		if Spring.GetGameRulesParam("isTakeInProgress") == 1 then
			return true
		end
		if Spring.GetGameRulesParam("isGiveInProgress") == 1 then
			return true
		end
		local policyResult = UnitShared.GetCachedTerms(fromTeamID, toTeamID, Spring)
		mayUnitScratch[1] = unitID
		local validation = UnitShared.ValidateUnits(policyResult, mayUnitScratch, Spring, nil, mayValidationScratch)
		return validation.status ~= TransferEnums.UnitValidationOutcome.Failure
	end,
}
