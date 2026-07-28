---@type Builders
local Builders = VFS.Include("spec/builders/index.lua")
local ModuleHandler = VFS.Include("modules/module_handler.lua")
local Modules = VFS.Include("modules/enums.lua").Modules
local ConstructionEnums = VFS.Include("modules/construction/enums.lua")
local TransferEnums = VFS.Include("modules/transfer/enums.lua")
local UnitShared = VFS.Include("modules/transfer/unit/shared.lua")
local ResourceShared = VFS.Include("modules/transfer/resource/shared.lua")
local Helpers = VFS.Include("modules/transfer/spec/support/action_helpers.lua")
local withSpring, unitDefsById = Helpers.withSpring, Helpers.unitDefsById

describe("transfer.give_resources", function()
	local registry ---@type { byName: table<string, ActionDescriptor>, list: ActionDescriptor[] }

	setup(function()
		ModuleHandler.ResetCaches()
		registry = ModuleHandler.LoadActions(Modules.Transfer)
	end)

	--- validate is optional on a descriptor; every transfer action registers one.
	---@param name string
	---@param request table
	---@return boolean allowed, string? reason
	local function validate(name, request)
		local fn = assert(registry.byName[name].validate, name .. " registers validate")
		return fn(request)
	end

	describe("give_resources", function()
		it("refuses a team handing to itself", function()
			local allowed, reason = validate("give_resources", {
				from = 2,
				to = 2,
				resource = "metal",
				amount = 5,
			})
			assert.is_false(allowed)
			assert.is_truthy(tostring(reason):find("itself", 1, true))
		end)

		it("moves the whole amount, both sides, untaxed", function()
			local sender = Builders.Team:new():Human():WithMetal(50):WithMetalStorage(1000)
			local receiver = Builders.Team:new():Human():WithMetal(10):WithMetalStorage(1000)
			local mock = Builders.Spring.new():WithTeam(sender):WithTeam(receiver):Build()
			withSpring(mock, function()
				local moved = registry.byName.give_resources.execute({
					from = sender.id,
					to = receiver.id,
					resource = "metal",
					amount = 40,
				})
				assert.are.equal(40, moved)
				assert.are.equal(10, mock.GetTeamResources(sender.id, "metal"))
				assert.are.equal(50, mock.GetTeamResources(receiver.id, "metal"))
			end)
		end)
	end)
end)
