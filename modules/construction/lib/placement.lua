local ModuleHandler = VFS.Include("modules/module_handler.lua")
local Modules = VFS.Include("modules/enums.lua").Modules
local Contract = VFS.Include("modules/construction/contract.lua") ---@type ConstructionContract

local extractorKind ---@type table<integer, "mex"|"geo">|nil built on first use: api.lua is included where UnitDefs is not

---@return table<integer, "mex"|"geo">
local function extractorKinds()
	if extractorKind == nil then
		extractorKind = {}
		for unitDefID, unitDef in pairs(UnitDefs) do
			if unitDef.extractsMetal > 0 then
				extractorKind[unitDefID] = "mex"
			elseif unitDef.customParams.geothermal then
				extractorKind[unitDefID] = "geo"
			end
		end
	end
	return extractorKind
end

---@param kind "mex"|"geo"
---@param myTeam integer
---@param springRepo Spring
---@return boolean
local function otherTeamsExtractorNearby(kind, myTeam, x, z, springRepo)
	local kinds = extractorKinds()
	local units = springRepo.GetUnitsInCylinder(x, z, Game.extractorRadius)
	for _, unitID in ipairs(units) do
		if kinds[springRepo.GetUnitDefID(unitID)] == kind and springRepo.GetUnitTeam(unitID) ~= myTeam then
			return true
		end
	end
	return false
end

local Placement = {}

---@param unitDefID integer
---@param builderTeam integer
---@param x number
---@param y number
---@param z number
---@param springRepo Spring
---@return boolean
function Placement.Decide(unitDefID, builderTeam, x, y, z, springRepo)
	local opts = springRepo.GetModOptions()
	local kind = extractorKinds()[unitDefID]
	local spotX, spotZ
	if kind == "mex" then
		local finder = (GG and GG.resource_spot_finder) or (WG and WG.resource_spot_finder) -- the gadgets' or the widgets'
		local spot = finder and finder.GetClosestMexSpot and finder.GetClosestMexSpot(x, z)
		if spot then
			spotX, spotZ = spot.x, spot.z
		end
	end
	---@type ConstructionPlacementContext
	local ctx = {
		modOptions = opts,
		unitDefID = unitDefID,
		builderTeam = builderTeam,
		x = x,
		y = y,
		z = z,
		extractor = kind,
		alliedExtractorNearby = kind ~= nil and otherTeamsExtractorNearby(kind, builderTeam, x, z, springRepo),
		utilitySharing = false,
		spotX = spotX,
		spotZ = spotZ,
		spotHolder = builderTeam,
		spotHolderAllied = false,
	}
	local facts = ModuleHandler.Enrich(Contract.PlacementFacts, opts, ctx, springRepo)
	ctx.spotHolder = facts[Contract.PlacementFacts.SpotHolder]
	ctx.utilitySharing = facts[Contract.PlacementFacts.UtilitySharing] == true
	ctx.spotHolderAllied = ctx.spotHolder ~= builderTeam
		and springRepo.AreTeamsAllied(builderTeam, ctx.spotHolder) == true
	local pipelines = ModuleHandler.LoadPolicies(Modules.Construction) ---@type ConstructionPipelines
	return ModuleHandler.Evaluate(pipelines.placement, ctx) == true
end

local anyMex ---@type integer|nil

---May this team put a mex on the metal spot at x, z: the same ask a build order gets, for any mex, from either side.
---@param team integer
---@param x number
---@param z number
---@param springRepo Spring
---@return boolean
function Placement.DecideMexAt(team, x, z, springRepo)
	if anyMex == nil then
		for unitDefID, kind in pairs(extractorKinds()) do
			if kind == "mex" and (anyMex == nil or unitDefID < anyMex) then
				anyMex = unitDefID
			end
		end
	end
	if anyMex == nil then
		return true
	end
	return Placement.Decide(anyMex, team, x, springRepo.GetGroundHeight(x, z) or 0, z, springRepo)
end

---@param unitDefID integer
---@return boolean
function Placement.IsExtractor(unitDefID)
	return extractorKinds()[unitDefID] ~= nil
end

return Placement
