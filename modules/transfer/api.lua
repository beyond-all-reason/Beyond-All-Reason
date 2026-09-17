local ModuleHandler = VFS.Include("modules/module_handler.lua")
local Modules = VFS.Include("modules/enums.lua").Modules
local UnitShared = VFS.Include("modules/transfer/unit/shared.lua")
local ResourceShared = VFS.Include("modules/transfer/resource/shared.lua")
local TransferEnums = VFS.Include("modules/transfer/enums.lua")
local Claims = VFS.Include("modules/transfer/mex_splitting/claims.lua") ---@type MexRegionsClaimsLib
local Sources = VFS.Include("modules/transfer/mex_splitting/sources.lua") ---@type MexRegionSources
local Deal = VFS.Include("modules/transfer/mex_splitting/deal.lua") ---@type MexRegionsDealLib
local state = VFS.Include("modules/transfer/state.lua") ---@type TransferState

local mayUnitScratch = {}
local mayValidationScratch = {}
local unitsValidationScratch = {}

---@param name string action file name under actions/
---@param request table
---@return any result
local function perform(name, request)
	local action = ModuleHandler.LoadActions(Modules.Transfer).byName[name]
	if action == nil then
		Spring.Log(
			"transfer",
			LOG.ERROR,
			"transfer has no action named "
				.. tostring(name)
				.. " (added since the game started? restart to pick it up)"
		)
		return nil
	end
	if action.validate then
		local allowed, reason = action.validate(request)
		if not allowed then
			Spring.Log("transfer", LOG.WARNING, "transfer." .. name .. " refused: " .. tostring(reason))
			return nil
		end
	end
	return action.execute(request)
end

---@param springRepo Spring
---@param regions MexRegion[]
---@param deal MexRegionsDeal
local function publish(springRepo, regions, deal)
	springRepo.SetGameRulesParam(Deal.PARAM, Deal.Encode(regions, deal.regions))
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
		local pipelines = ModuleHandler.LoadPolicies(Modules.Transfer) ---@type TransferPipelines
		local regions = state.mexRegions or {}
		---@type MexRegionsDealContext
		local ctx = { regions = regions, spots = spots or {}, teams = teams }
		local deal = ModuleHandler.Evaluate(pipelines.mex_splitting, ctx)
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
		local pipelines = ModuleHandler.LoadPolicies(Modules.Transfer) ---@type TransferPipelines
		local heir = ModuleHandler.Evaluate(pipelines.mex_splitting_heir, { departing = departing, heirs = heirs })
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

	---@param unitIDs integer[]
	---@param toTeamID integer
	---@param fromTeamID integer the team being asked to give them up
	---@return UnitTransferResult
	Units = function(unitIDs, toTeamID, fromTeamID)
		local grant = UnitShared.GetCachedPolicyResult(fromTeamID, toTeamID, Spring)
		return perform("units", {
			from = fromTeamID,
			to = toTeamID,
			unitIDs = unitIDs,
			grant = grant,
			validation = UnitShared.ValidateUnits(grant, unitIDs, Spring, nil, unitsValidationScratch),
		})
	end,

	---@param resource ResourceName
	---@param amount number
	---@param toTeamID integer
	---@param fromTeamID integer
	---@return ResourceTransferResult
	Resources = function(resource, amount, toTeamID, fromTeamID)
		return perform("resources", {
			from = fromTeamID,
			to = toTeamID,
			resource = resource,
			amount = amount,
			grant = ResourceShared.GetCachedPolicyResult(fromTeamID, toTeamID, resource, Spring),
		})
	end,

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
		local policyResult = UnitShared.GetCachedPolicyResult(fromTeamID, toTeamID, Spring)
		mayUnitScratch[1] = unitID
		local validation = UnitShared.ValidateUnits(policyResult, mayUnitScratch, Spring, nil, mayValidationScratch)
		return validation.status ~= TransferEnums.UnitValidationOutcome.Failure
	end,

	---@param resource ResourceName
	---@param amount number
	---@param toTeamID integer
	---@param fromTeamID integer
	---@return number moved
	GiveResources = function(resource, amount, toTeamID, fromTeamID)
		return perform("give_resources", {
			from = fromTeamID,
			to = toTeamID,
			resource = resource,
			amount = amount,
		})
	end,

	---@param unitIDs integer[]
	---@param toTeamID integer
	---@return integer transferred
	Give = function(unitIDs, toTeamID)
		return perform("give", { to = toTeamID, unitIDs = unitIDs })
	end,
}
