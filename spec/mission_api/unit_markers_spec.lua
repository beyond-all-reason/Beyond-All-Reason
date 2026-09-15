require("spec_helper")

local Builders = VFS.Include("spec/builders/index.lua")

Builders.MissionApi.new():Install()

local unitMarkers = VFS.Include("luarules/mission_api/unit_markers.lua")

describe("mission_api.unit_markers", function()
	local missionApi, sentMessages = {}, {}

	local function markerTypesOf(unitID)
		local types = {}
		for _, marker in ipairs(unitMarkers.GetUnitMarkers(unitID) or {}) do
			types[#types + 1] = marker.markerType
		end
		return types
	end

	before_each(function()
		missionApi = Builders.MissionApi.new():Install()
		missionApi.unitMarkers = {}
		_G.Spring = Builders.Spring.new():Build() ---@diagnostic disable-line: global-in-non-module
		_G.unitMarkers = {} ---@diagnostic disable-line: global-in-non-module

		sentMessages = {}
		_G.SendToUnsynced = function(action, unitID, count, types) ---@diagnostic disable-line: global-in-non-module
			sentMessages[#sentMessages + 1] = { action = action, unitID = unitID, count = count, types = types }
		end
	end)

	describe("AddUnitMarker", function()
		it("records the marker under its unit", function()
			unitMarkers.AddUnitMarker(1, "objective")
			local markers = unitMarkers.GetUnitMarkers(1)
			assert.are.equal(1, #markers)
			assert.are.equal("objective", markers[1].markerType)
		end)

		it("keeps several markers of different types on one unit", function()
			unitMarkers.AddUnitMarker(1, "objective")
			unitMarkers.AddUnitMarker(1, "alert")
			assert.are.same({ "objective", "alert" }, markerTypesOf(1))
		end)

		it("does not duplicate a marker of the same type", function()
			unitMarkers.AddUnitMarker(1, "objective")
			unitMarkers.AddUnitMarker(1, "objective")
			assert.are.same({ "objective" }, markerTypesOf(1))
			assert.are.equal(1, #sentMessages)
		end)

		it("keeps one unit's markers off another unit", function()
			unitMarkers.AddUnitMarker(1, "objective")
			unitMarkers.AddUnitMarker(2, "alert")
			assert.are.same({ "objective" }, markerTypesOf(1))
			assert.are.same({ "alert" }, markerTypesOf(2))
		end)

		it("mirrors the unit's types into the synced global", function()
			unitMarkers.AddUnitMarker(1, "objective")
			unitMarkers.AddUnitMarker(1, "alert")
			assert.are.same({ "objective", "alert" }, _G.unitMarkers[1])
		end)

		it("mirrors an untyped marker as the empty string", function()
			unitMarkers.AddUnitMarker(1, nil)
			assert.are.same({ "" }, _G.unitMarkers[1])
		end)

		it("counts an untyped marker, which joins to the same empty string as no markers", function()
			unitMarkers.AddUnitMarker(1, nil)
			assert.are.same({ action = "MissionUnitMarkers", unitID = 1, count = 1, types = "" }, sentMessages[1])
		end)

		it("sends the unit's whole current set to unsynced", function()
			unitMarkers.AddUnitMarker(1, "objective")
			unitMarkers.AddUnitMarker(1, "alert")
			assert.are.equal(2, #sentMessages)
			assert.are.same(
				{ action = "MissionUnitMarkers", unitID = 1, count = 1, types = "objective" },
				sentMessages[1]
			)
			assert.are.same(
				{ action = "MissionUnitMarkers", unitID = 1, count = 2, types = "objective\talert" },
				sentMessages[2]
			)
		end)
	end)

	describe("RemoveUnitMarker", function()
		it("removes only the named type", function()
			unitMarkers.AddUnitMarker(1, "objective")
			unitMarkers.AddUnitMarker(1, "alert")
			unitMarkers.RemoveUnitMarker(1, "objective")
			assert.are.same({ "alert" }, markerTypesOf(1))
		end)

		it("removes every marker on the unit when given no type", function()
			unitMarkers.AddUnitMarker(1, "objective")
			unitMarkers.AddUnitMarker(1, "alert")
			unitMarkers.RemoveUnitMarker(1, nil)
			assert.is_nil(unitMarkers.GetUnitMarkers(1))
		end)

		it("mirrors what is left on the unit", function()
			unitMarkers.AddUnitMarker(1, "objective")
			unitMarkers.AddUnitMarker(1, "alert")
			unitMarkers.RemoveUnitMarker(1, "objective")
			assert.are.same({ "alert" }, _G.unitMarkers[1])
		end)

		it("clears the mirror when the unit keeps nothing", function()
			unitMarkers.AddUnitMarker(1, "objective")
			unitMarkers.RemoveUnitMarker(1, "objective")
			assert.is_nil(_G.unitMarkers[1])
		end)

		it("sends what is left on the unit", function()
			unitMarkers.AddUnitMarker(1, "objective")
			unitMarkers.AddUnitMarker(1, "alert")
			unitMarkers.RemoveUnitMarker(1, "objective")
			assert.are.same(
				{ action = "MissionUnitMarkers", unitID = 1, count = 1, types = "alert" },
				sentMessages[#sentMessages]
			)
		end)

		it("sends an empty set when the last marker goes", function()
			unitMarkers.AddUnitMarker(1, "objective")
			unitMarkers.RemoveUnitMarker(1, nil)
			assert.are.same(
				{ action = "MissionUnitMarkers", unitID = 1, count = 0, types = "" },
				sentMessages[#sentMessages]
			)
		end)

		it("is a no-op for a unit with no markers", function()
			unitMarkers.RemoveUnitMarker(99, nil)
			assert.is_nil(unitMarkers.GetUnitMarkers(99))
			assert.is_nil(_G.unitMarkers[99])
			assert.are.equal(0, #sentMessages)
		end)
	end)

	describe("RemoveUnitMarkers", function()
		it("drops everything the unit carried, for when it dies", function()
			unitMarkers.AddUnitMarker(1, "objective")
			unitMarkers.AddUnitMarker(1, "alert")
			unitMarkers.RemoveUnitMarkers(1)
			assert.is_nil(unitMarkers.GetUnitMarkers(1))
			assert.is_nil(_G.unitMarkers[1])
			assert.are.same(
				{ action = "MissionUnitMarkers", unitID = 1, count = 0, types = "" },
				sentMessages[#sentMessages]
			)
		end)
	end)
end)
