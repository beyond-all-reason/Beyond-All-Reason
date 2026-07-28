local Economy = require("modules/economy/api")
local ModuleHandler = require("modules/module_handler")
local Modules = require("modules/enums").Modules
local SharedConfig = require("modules/transfer/economy/shared_config")
local TransferEnums = require("modules/transfer/enums")

local METAL = TransferEnums.ResourceType.METAL
local ENERGY = TransferEnums.ResourceType.ENERGY

---@class TransferResourceRequest: TransferContext the context a resource move takes
---@field resourceType ResourceName
---@field desiredAmount number
---@field terms ResourceTransferTerms the terms the move is made under

-- Two teams, sender and receiver, as a policy reads them this moment: the engine's balances, whether they are allied,
-- whether cheating is on, the match's modoptions, and the facts the live modules provide for the pairing. Formed
-- into the entry's own table on every ask of the same key, so a reader that asks every frame allocates nothing.
---@param ctx TransferContext the table to form into: empty on the first form, last frame's after
---@param spring SpringBoth
---@param senderTeamId integer
---@param receiverTeamId integer
---@param enrichers PolicyProvision[]|nil the providers to enrich with; the live modules' when nil
local function form(ctx, spring, senderTeamId, receiverTeamId, enrichers)
	---@type TransferContract
	local Transfer = ModuleHandler.Contract(Modules.Transfer)
	ctx.senderTeamId = senderTeamId
	ctx.receiverTeamId = receiverTeamId
	local sender = ctx.sender or {}
	local receiver = ctx.receiver or {}
	ctx.sender, ctx.receiver = sender, receiver
	sender.metal = Economy.Resources.Snapshot(spring, senderTeamId, METAL, sender.metal)
	sender.energy = Economy.Resources.Snapshot(spring, senderTeamId, ENERGY, sender.energy)
	receiver.metal = Economy.Resources.Snapshot(spring, receiverTeamId, METAL, receiver.metal)
	receiver.energy = Economy.Resources.Snapshot(spring, receiverTeamId, ENERGY, receiver.energy)
	ctx.springRepo = spring
	ctx.modOptions = spring.GetModOptions()
	ctx.areAlliedTeams = spring.AreTeamsAllied(senderTeamId, receiverTeamId) == true
	ctx.isCheatingEnabled = spring.IsCheatingEnabled()

	-- the facts are this moment's too: a slot a provider stops filling does not keep last frame's value
	for _, fact in pairs(Transfer.TeamPairing) do
		ctx[fact] = nil
	end
	local resolved = enrichers or ModuleHandler.LoadEnrichers(Transfer.TeamPairing)
	local live = enrichers == nil and ModuleHandler.LiveModulesFor(ctx.modOptions) or nil
	for field, value in pairs(ModuleHandler.EnrichWith(resolved, live, ctx)) do
		ctx[field] = value
	end
end

---@param ctx TransferResourceContext
---@param spring SpringBoth
---@param senderTeamId integer
---@param receiverTeamId integer
---@param resourceType ResourceName
---@param enrichers PolicyProvision[]|nil
local function formResource(ctx, spring, senderTeamId, receiverTeamId, resourceType, enrichers)
	form(ctx, spring, senderTeamId, receiverTeamId, enrichers)
	ctx.resourceType = resourceType
	local taxRate = (ctx.taxRate or SharedConfig.getTaxConfig(spring)) --[[@as number]]
	ctx.taxRate = math.min(taxRate, 1)
end

local Pairing = {}

-- The unit policy's context: the pairing, keyed by sender and receiver.
---@param ctx TransferContext
---@param spring SpringBoth
---@param senderTeamId integer
---@param receiverTeamId integer
function Pairing.ForUnits(ctx, spring, senderTeamId, receiverTeamId)
	form(ctx, spring, senderTeamId, receiverTeamId)
end

-- The resource policy's context: the pairing, the resource asked about, and the pairing's rate clamped to 0..1,
-- keyed by sender, receiver and resource.
---@param ctx TransferResourceContext
---@param spring SpringBoth
---@param senderTeamId integer
---@param receiverTeamId integer
---@param resourceType ResourceName
function Pairing.ForResource(ctx, spring, senderTeamId, receiverTeamId, resourceType)
	formResource(ctx, spring, senderTeamId, receiverTeamId, resourceType)
end

-- The context a resource move takes: the pairing for the resource, the amount asked, and the terms it is made under.
---@param spring SpringBoth
---@param senderTeamId integer
---@param receiverTeamId integer
---@param resourceType ResourceName
---@param desiredAmount number
---@param terms ResourceTransferTerms
---@param enrichers PolicyProvision[]|nil a test seam, as Isolated takes it
---@return TransferResourceRequest
function Pairing.Request(spring, senderTeamId, receiverTeamId, resourceType, desiredAmount, terms, enrichers)
	local ctx = {} --[[@as TransferResourceRequest]]
	formResource(ctx, spring, senderTeamId, receiverTeamId, resourceType, enrichers)
	ctx.desiredAmount = desiredAmount
	ctx.terms = terms
	return ctx
end

-- A test seam: the same forms, enriched by a hand-built provider list instead of the live modules', so a spec can
-- isolate one mode. Each form returns the context it formed, for a spec to evaluate outside the frame memo.
---@param enrichers PolicyProvision[] none isolates the pairing from every provider
---@return { ForUnits: fun(spring: SpringBoth, senderTeamId: integer, receiverTeamId: integer): TransferContext, ForResource: fun(spring: SpringBoth, senderTeamId: integer, receiverTeamId: integer, resourceType: ResourceName): TransferResourceContext }
function Pairing.Isolated(enrichers)
	return {
		ForUnits = function(spring, senderTeamId, receiverTeamId)
			local ctx = {} --[[@as TransferContext]]
			form(ctx, spring, senderTeamId, receiverTeamId, enrichers)
			return ctx
		end,
		ForResource = function(spring, senderTeamId, receiverTeamId, resourceType)
			local ctx = {} --[[@as TransferResourceContext]]
			formResource(ctx, spring, senderTeamId, receiverTeamId, resourceType, enrichers)
			return ctx
		end,
	}
end

return Pairing
