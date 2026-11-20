local SpringSyncedBuilder = VFS.Include("spec/builders/spring_synced_builder.lua")
local MissionApiBuilder = VFS.Include("spec/builders/mission_api_builder.lua")
local MissionSpecEnv = require("mission_api.spec_helper")

local env = MissionSpecEnv.new()

-- Action files read GG['MissionAPI'].Modules.ParameterTypes at load time.
MissionApiBuilder.new():Install()

local actions = MissionSpecEnv.include(env, "luarules/mission_api/actions/units/unit_color.lua")
local setColor, clearColor = actions[1], actions[2]
local unitColor = MissionSpecEnv.include(env, "luarules/mission_api/unit_color.lua")
local summarizeSchema = require("mission_api.schema_spec_helper")

---@type table[]
local sent
---@type table[]
local published

describe("mission_api.actions.unit_color", function()
	before_each(function()
		local missionApi = MissionApiBuilder.new():WithTrackedUnit("hero", 7):WithTrackedUnit("bots", 101):Install()
		missionApi.Modules.UnitColor = unitColor
		env.Spring = SpringSyncedBuilder.new():Build()
		published = {}
		env.Spring.SetUnitRulesParam = function(unitID, key, value, access)
			published[#published + 1] = { unitID = unitID, key = key, value = value, access = access }
		end
		sent = {}
		env.SendToUnsynced = function(...)
			sent[#sent + 1] = { ... }
		end
	end)

	it("declares its types and parameters", function()
		assert.are.same({
			type = "SetUnitColor",
			unitName = "UnitName!",
			color = "Color!",
		}, summarizeSchema(setColor))
		assert.are.same({
			type = "ClearUnitColor",
			unitName = "UnitName!",
		}, summarizeSchema(clearColor))
	end)

	it("is a no-op for an untracked unit name", function()
		setColor.actionFunction("unknownUnit", { 1, 0, 0 })
		clearColor.actionFunction("unknownUnit")

		assert.are.equal(0, #published)
		assert.are.equal(0, #sent)
	end)

	it("publishes the packed color on the named units only, to whoever sees them", function()
		setColor.actionFunction("hero", { 1, 128 / 255, 0 })

		assert.are.same({
			{ unitID = 7, key = "mission_unit_color", value = 0xFF8000, access = { inlos = true } },
		}, published)
	end)

	it("clamps channels and never packs black to 0", function()
		setColor.actionFunction("hero", { 1.4, 1, 3 })
		setColor.actionFunction("hero", { 0, 0, 0 })

		assert.are.equal(0xFFFFFF, published[1].value)
		assert.are.equal(1, published[2].value)
	end)

	it("tells the drawing side of every change", function()
		setColor.actionFunction("hero", { 1, 0, 0 })
		clearColor.actionFunction("hero")

		assert.are.same({ { "MissionUnitColor", 7, 0xFF0000 }, { "MissionUnitColor", 7, 0 } }, sent)
	end)
end)
