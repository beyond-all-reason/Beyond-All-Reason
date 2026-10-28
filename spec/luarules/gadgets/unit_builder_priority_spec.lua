---@diagnostic disable: undefined-field

local Builders = VFS.Include("spec/builders/index.lua")
local SpecEnv = VFS.Include("spec/support/spec_env.lua")

local GADGET_PATH = "luarules/gadgets/unit_builder_priority.lua"
local GameCMD = VFS.Include("modules/customcommands.lua").GameCMD

local PRIORITY_LOW = 0

-- A nano turret assisting an advanced fusion reactor.
local BUILDER_DEF_ID = 1
local TARGET_DEF_ID = 2
local BUILDER_NAME = "armnanotc"
local TARGET_NAME = "armafus"

local function toEngineUnitDef(name, def)
	local isBuilder = def.builder == true
	local canAssist = def.canassist
	if canAssist == nil then
		canAssist = isBuilder
	end
	return {
		name = name,
		isBuilder = isBuilder,
		buildSpeed = def.workertime or 0,
		canAssist = canAssist,
		canCloak = def.cancloak == true,
		buildOptions = def.buildoptions or {},
		metalCost = def.metalcost or 0,
		energyCost = def.energycost or 0,
		buildTime = def.buildtime or 100,
	}
end

-- One passive builder assisting an unfinished target on the team, then one builder priority update.
local function isRestrictedAfterUpdate(team, teamRulesParams)
	local builderID, targetID
	team:WithUnit(BUILDER_DEF_ID, function(unitID)
		builderID = unitID
	end):WithUnit(TARGET_DEF_ID, function(unitID)
		targetID = unitID
	end)

	local springBuilder = Builders.Spring.new():WithTeam(team):WithRealUnitDefs()
	local realDefs = springBuilder.unitDefs:GetUnitDefsByName()
	springBuilder
		:WithUnitDef(BUILDER_DEF_ID, toEngineUnitDef(BUILDER_NAME, realDefs[BUILDER_NAME]))
		:WithUnitDef(TARGET_DEF_ID, toEngineUnitDef(TARGET_NAME, realDefs[TARGET_NAME]))
	for key, value in pairs(teamRulesParams or {}) do
		springBuilder:WithTeamRulesParam(team.id, key, value)
	end

	local spring = springBuilder:Build()
	spring.GetAllUnits = function()
		return spring.GetTeamUnits(team.id)
	end
	spring.GetUnitRulesParam = function(unitID, name)
		if unitID == builderID and name == "builderPriority" then
			return PRIORITY_LOW
		end
	end
	spring.SetUnitRulesParam = function() end
	spring.GetUnitIsBuilding = function(unitID)
		return unitID == builderID and targetID or nil
	end
	spring.GetUnitResources = function()
		return 0, 0, 0, 0
	end
	spring.InsertUnitCmdDesc = function() end

	local restricted = false
	local env = SpecEnv.new({
		gadget = {},
		gadgetHandler = {
			IsSyncedCode = function()
				return true
			end,
			RegisterAllowCommand = function() end,
		},
		GG = {
			UnitAttributes = {
				SetUnitModifier = function(unitID, attribute, multiplier)
					if unitID == builderID and attribute == "buildSpeed" then
						restricted = multiplier == 0
					end
				end,
				SetUnitAttribute = function() end,
			},
		},
		CMDTYPE = { ICON_MODE = 5 },
		GameCMD = GameCMD,
		UnitDefs = springBuilder.unitDefs:GetUnitDefsByID(),
		Spring = spring,
	})
	SpecEnv.include(env, GADGET_PATH)

	local gadget = env.gadget
	gadget:Initialize()
	for frame = spring.GetGameFrame(), spring.GetGameFrame() + 6 do
		gadget:GameFrame(frame)
	end

	return restricted
end

describe("unit_builder_priority", function()
	it("lets passive builders build when energy income exceeds storage and overflows", function()
		local team = Builders.Team
			.new()
			:WithEnergy(1357)
			:WithEnergyStorage(1360)
			:WithEnergyIncome(4780)
			:WithEnergyPull(1830)
			:WithEnergySent(2845)
			:WithEnergyShareSlider(0.95)
			:WithMetal(981)
			:WithMetalStorage(3100)
			:WithMetalIncome(62)
			:WithMetalShareSlider(0.99)
		assert.is_false(isRestrictedAfterUpdate(team, { mmUse = 1728 }))
	end)

	it("lets passive builders build when metal overflows to allies", function()
		local team = Builders.Team
			.new()
			:WithEnergy(9500)
			:WithEnergyStorage(10000)
			:WithEnergyIncome(2000)
			:WithEnergyShareSlider(0.95)
			:WithMetal(990)
			:WithMetalStorage(1000)
			:WithMetalIncome(6000)
			:WithMetalSent(6000)
			:WithMetalShareSlider(0.99)
		assert.is_false(isRestrictedAfterUpdate(team))
	end)

	it("restricts passive builders when energy is stalling", function()
		local team = Builders.Team
			.new()
			:WithEnergy(50)
			:WithEnergyStorage(1360)
			:WithEnergyIncome(100)
			:WithEnergyPull(400)
			:WithEnergyShareSlider(0.95)
			:WithMetal(981)
			:WithMetalStorage(3100)
			:WithMetalIncome(62)
			:WithMetalShareSlider(0.99)
		assert.is_true(isRestrictedAfterUpdate(team))
	end)
end)
