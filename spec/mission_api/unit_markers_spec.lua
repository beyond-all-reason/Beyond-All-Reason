require("spec_helper")

local Builders = VFS.Include("spec/builders/index.lua")

Builders.MissionApi.new():Install()

local unitMarkers = VFS.Include("luarules/mission_api/unit_markers.lua")

describe("mission_api.unit_markers", function()
	local missionApi, pointCalls, eraseCalls = {}, {}, {}

	before_each(function()
		missionApi = Builders.MissionApi.new():Install()
		missionApi.unitMarkers = {}
		_G.Spring = Builders.Spring.new():Build() ---@diagnostic disable-line: global-in-non-module
		Spring.GetUnitPosition = function(unitID)
			return 100 + unitID, 20, 200 + unitID ---@diagnostic disable-line: missing-return-value
		end
		pointCalls = Spring.calls.markerAddPoint
		eraseCalls = Spring.calls.markerErasePosition
	end)

	describe("AddUnitMarker", function()
		it("draws a point at the unit, local to this client", function()
			unitMarkers.AddUnitMarker(1, "objective")
			assert.are.equal(1, #pointCalls)
			assert.are.equal(101, pointCalls[1].x)
			assert.are.equal(20, pointCalls[1].y)
			assert.are.equal(201, pointCalls[1].z)
			assert.is_true(pointCalls[1].local_)
		end)

		it("records the marker under its unit", function()
			unitMarkers.AddUnitMarker(1, "objective")
			local markers = unitMarkers.GetUnitMarkers(1)
			assert.are.equal(1, #markers)
			assert.are.equal("objective", markers[1].markerType)
		end)

		it("keeps several markers of different types on one unit", function()
			unitMarkers.AddUnitMarker(1, "objective")
			unitMarkers.AddUnitMarker(1, "alert")
			assert.are.equal(2, #unitMarkers.GetUnitMarkers(1))
		end)

		it("redraws rather than duplicating a marker of the same type", function()
			unitMarkers.AddUnitMarker(1, "objective")
			unitMarkers.AddUnitMarker(1, "objective")
			assert.are.equal(1, #unitMarkers.GetUnitMarkers(1))
			assert.are.equal(2, #pointCalls)
			assert.are.equal(1, #eraseCalls)
		end)

		it("draws nothing for a unit with no position", function()
			Spring.GetUnitPosition = function()
				return nil, nil, nil, nil, nil, nil, nil, nil, nil
			end
			unitMarkers.AddUnitMarker(1, "objective")
			assert.are.equal(0, #pointCalls)
		end)
	end)

	describe("RemoveUnitMarker", function()
		it("removes only the named type", function()
			unitMarkers.AddUnitMarker(1, "objective")
			unitMarkers.AddUnitMarker(1, "alert")
			unitMarkers.RemoveUnitMarker(1, "objective")
			local markers = unitMarkers.GetUnitMarkers(1)
			assert.are.equal(1, #markers)
			assert.are.equal("alert", markers[1].markerType)
		end)

		it("removes every marker on the unit when given no type", function()
			unitMarkers.AddUnitMarker(1, "objective")
			unitMarkers.AddUnitMarker(1, "alert")
			unitMarkers.RemoveUnitMarker(1, nil)
			assert.is_nil(unitMarkers.GetUnitMarkers(1))
		end)

		it("erases the line it drew", function()
			unitMarkers.AddUnitMarker(1, "objective")
			unitMarkers.RemoveUnitMarker(1, "objective")
			assert.are.equal(1, #eraseCalls)
			assert.are.equal(101, eraseCalls[1].x)
		end)

		it("is a no-op for a unit with no markers", function()
			unitMarkers.RemoveUnitMarker(99, nil)
			assert.are.equal(0, #eraseCalls)
		end)
	end)

	describe("RemoveUnitMarkers", function()
		it("drops everything the unit carried, for when it dies", function()
			unitMarkers.AddUnitMarker(1, "objective")
			unitMarkers.AddUnitMarker(1, "alert")
			unitMarkers.RemoveUnitMarkers(1)
			assert.is_nil(unitMarkers.GetUnitMarkers(1))
			assert.are.equal(2, #eraseCalls)
		end)
	end)
end)
