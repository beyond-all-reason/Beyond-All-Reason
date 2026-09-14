require("spec_helper")

local Builders = VFS.Include("spec/builders/index.lua")

-- Action files read GG['MissionAPI'].Modules.ParameterTypes at load time.
Builders.MissionApi.new():Install()

local actions = VFS.Include("luarules/mission_api/actions/map/unit_markers.lua")
local addAction, removeAction = actions[1], actions[2]
local summarizeSchema = require("mission_api.schema_spec_helper")

describe("mission_api.actions.unit_markers", function()
	local missionApi, added, removed = {}, {}, {}

	before_each(function()
		added, removed = {}, {}
		missionApi = Builders.MissionApi
			.new()
			:WithModule("UnitMarkers", {
				AddUnitMarker = function(unitID, markerType)
					added[#added + 1] = { unitID = unitID, markerType = markerType }
				end,
				RemoveUnitMarker = function(unitID, markerType)
					removed[#removed + 1] = { unitID = unitID, markerType = markerType }
				end,
			})
			:WithTrackedUnit("squad", 11)
			:Install()
		_G.Spring = Builders.Spring.new():Build() ---@diagnostic disable-line: global-in-non-module
		_G.UnitDefNames = { armwar = { id = 7 }, armpw = { id = 8 } } ---@diagnostic disable-line: global-in-non-module
		Spring.GetUnitDefID = function(unitID)
			return unitID == 11 and 7 or 8
		end
		Spring.GetUnitTeam = function(unitID)
			return unitID == 11 and 0 or 1
		end
		Spring.GetTeamUnits = function(teamID)
			return teamID == 0 and { 11 } or { 12 }
		end
		Spring.GetTeamUnitsByDefs = function(teamID, unitDefID)
			if teamID == 0 and unitDefID == 7 then
				return { 11 }
			end
			return {}
		end
	end)

	it("declares AddUnitMarker's type and parameters", function()
		assert.are.same({
			type = "AddUnitMarker",
			unitName = "UnitName",
			unitDefName = "UnitDefName",
			teamID = "TeamID",
			markerType = "String",
			requiresOneOf = { "unitName", "unitDefName", "teamID" },
		}, summarizeSchema(addAction))
	end)

	it("declares RemoveUnitMarker with the same parameters", function()
		local addSchema = summarizeSchema(addAction)
		local removeSchema = summarizeSchema(removeAction)
		addSchema.type, removeSchema.type = nil, nil
		assert.are.same(addSchema, removeSchema)
	end)

	describe("AddUnitMarker", function()
		it("marks each matched unit with the given type", function()
			addAction.actionFunction("squad", nil, nil, "objective")
			assert.are.same({ { unitID = 11, markerType = "objective" } }, added)
		end)

		it("marks without a type when none is given", function()
			addAction.actionFunction("squad", nil, nil, nil)
			assert.are.equal(1, #added)
			assert.is_nil(added[1].markerType)
		end)
	end)

	describe("RemoveUnitMarker", function()
		it("removes the named type from each matched unit", function()
			removeAction.actionFunction("squad", nil, nil, "objective")
			assert.are.same({ { unitID = 11, markerType = "objective" } }, removed)
		end)

		it("passes no type through, which clears every marker on the unit", function()
			removeAction.actionFunction("squad", nil, nil, nil)
			assert.are.equal(1, #removed)
			assert.is_nil(removed[1].markerType)
		end)
	end)

	describe("the unit filter", function()
		it("takes the units holding a tracked name", function()
			addAction.actionFunction("squad", nil, nil, "objective")
			assert.are.same({ { unitID = 11, markerType = "objective" } }, added)
		end)

		it("takes a whole team when only a team is given", function()
			addAction.actionFunction(nil, nil, 0, "objective")
			assert.are.same({ { unitID = 11, markerType = "objective" } }, added)
		end)

		it("takes a team's units of one definition", function()
			addAction.actionFunction(nil, "armwar", 0, "objective")
			assert.are.same({ { unitID = 11, markerType = "objective" } }, added)
		end)

		it("matches nothing when a name and a definition disagree", function()
			addAction.actionFunction("squad", "armpw", nil, "objective")
			assert.are.same({}, added)
		end)

		it("matches nothing when a name and a team disagree", function()
			addAction.actionFunction("squad", nil, 1, "objective")
			assert.are.same({}, added)
		end)

		it("matches nothing for an untracked name", function()
			addAction.actionFunction("ghosts", nil, nil, "objective")
			assert.are.same({}, added)
		end)

		it("matches nothing when no filter is given", function()
			addAction.actionFunction(nil, nil, nil, "objective")
			assert.are.same({}, added)
		end)
	end)
end)
