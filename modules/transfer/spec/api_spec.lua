---@type Builders
local Builders = VFS.Include("spec/builders/index.lua")
local ModuleHandler = VFS.Include("modules/module_handler.lua")
local Modules = VFS.Include("modules/enums.lua").Modules
local ConstructionEnums = VFS.Include("modules/construction/enums.lua")
local TransferEnums = VFS.Include("modules/transfer/enums.lua")
local UnitShared = VFS.Include("modules/transfer/unit/shared.lua")
local ResourceShared = VFS.Include("modules/transfer/resource/shared.lua")

describe("transfer's action registry", function()
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

	it("declares units and resources", function()
		assert.is_table(registry.byName.units)
		assert.is_table(registry.byName.resources)
	end)

	it("declares give and give_resources, the two that skip policy", function()
		assert.is_table(registry.byName.give)
		assert.is_table(registry.byName.give_resources)
	end)

	it("every action registers an execute", function()
		for _, action in ipairs(registry.list) do
			assert.is_function(action.execute, action.name .. " must register execute")
		end
	end)
end)
