require("spec_helper")

-- tracking.lua captures the four table references as upvalues at load time,
-- so they must exist in GG['MissionAPI'] *before* VFS.Include is called.
-- We keep the same table objects alive for the whole test run and wipe their
-- contents in before_each so every test starts from a clean slate.
GG['MissionAPI']                            = GG['MissionAPI'] or {}
local unitIDs      = {}; GG['MissionAPI'].trackedUnitIDs      = unitIDs
local unitNames    = {}; GG['MissionAPI'].trackedUnitNames    = unitNames
local featureIDs   = {}; GG['MissionAPI'].trackedFeatureIDs   = featureIDs
local featureNames = {}; GG['MissionAPI'].trackedFeatureNames = featureNames

local tracking = VFS.Include('luarules/mission_api/tracking.lua')

local function clearTracked()
	for _, table in ipairs({ unitIDs, unitNames, featureIDs, featureNames }) do
		for key in pairs(table) do table[key] = nil end
	end
end

-- Directly populate the internal tables without going through the module,
-- so that test setup never depends on the functions under test.
local function seedUnit(name, id)
	unitIDs[name]       = unitIDs[name] or {}
	unitIDs[name][id]   = true
	unitNames[id]       = unitNames[id] or {}
	unitNames[id][name] = true
end

local function seedFeature(name, id)
	featureIDs[name]       = featureIDs[name] or {}
	featureIDs[name][id]   = true
	featureNames[id]       = featureNames[id] or {}
	featureNames[id][name] = true
end

describe("mission_api.tracking", function()

	before_each(function()
		clearTracked()
	end)

	-- ── Unit tracking ─────────────────────────────────────────────────────────

	describe("TrackUnit", function()
		-- Assertions read the raw tables directly so they do not depend on any
		-- other module function whose correctness has not yet been established.

		it("registers the ID under the name in trackedUnitIDs", function()
			local unitName = 'myUnit'
			local unitID   = 42
			tracking.TrackUnit(unitName, unitID)
			assert.is_true((unitIDs[unitName] or {})[unitID] == true)
		end)

		it("registers the name under the ID in trackedUnitNames", function()
			local unitName = 'myUnit'
			local unitID   = 42
			tracking.TrackUnit(unitName, unitID)
			assert.is_true((unitNames[unitID] or {})[unitName] == true)
		end)

		it("is a no-op when name is nil", function()
			local unitID = 5
			tracking.TrackUnit(nil, unitID)
			assert.is_nil(unitNames[unitID])
		end)

		it("is a no-op when ID is nil", function()
			local unitName = 'ghost'
			tracking.TrackUnit(unitName, nil)
			assert.is_nil(unitIDs[unitName])
		end)

		it("supports multiple names for the same unit ID", function()
			local unitID     = 1
			local firstName  = 'alpha'
			local secondName = 'beta'
			tracking.TrackUnit(firstName, unitID)
			tracking.TrackUnit(secondName, unitID)
			assert.is_true((unitNames[unitID] or {})[firstName]  == true)
			assert.is_true((unitNames[unitID] or {})[secondName] == true)
		end)

		it("supports multiple IDs for the same name", function()
			local unitName = 'squad'
			local firstID  = 10
			local secondID = 11
			tracking.TrackUnit(unitName, firstID)
			tracking.TrackUnit(unitName, secondID)
			assert.is_true((unitIDs[unitName] or {})[firstID]  == true)
			assert.is_true((unitIDs[unitName] or {})[secondID] == true)
		end)
	end)

	describe("IsUnitIDUntracked", function()
		it("returns true for an ID that has never been tracked", function()
			local untrackedID = 99
			local result = tracking.IsUnitIDUntracked(untrackedID)
			assert.is_true(result)
		end)

		it("returns false for a tracked ID", function()
			local unitName  = 'u'
			local unitID    = 7
			seedUnit(unitName, unitID)
			local result = tracking.IsUnitIDUntracked(unitID)
			assert.is_false(result)
		end)
	end)

	describe("IsUnitNameUntracked", function()
		it("returns true for a name that has never been tracked", function()
			local result = tracking.IsUnitNameUntracked('ghost')
			assert.is_true(result)
		end)

		it("returns false for a tracked name", function()
			local unitName = 'u'
			local unitID   = 7
			seedUnit(unitName, unitID)
			local result = tracking.IsUnitNameUntracked(unitName)
			assert.is_false(result)
		end)
	end)

	describe("DoesUnitHaveName", function()
		it("returns false for an untracked ID", function()
			local untrackedID = 1
			local result = tracking.DoesUnitHaveName(untrackedID, 'any')
			assert.is_false(result)
		end)

		it("returns true when the ID is tracked under that name", function()
			local unitName = 'alpha'
			local unitID   = 1
			seedUnit(unitName, unitID)
			local result = tracking.DoesUnitHaveName(unitID, unitName)
			assert.is_true(result)
		end)

		it("returns false when the ID is tracked under a different name", function()
			local trackedName = 'alpha'
			local otherName   = 'beta'
			local unitID      = 1
			seedUnit(trackedName, unitID)
			local result = tracking.DoesUnitHaveName(unitID, otherName)
			assert.is_false(result)
		end)
	end)

	describe("UntrackUnitID", function()
		it("removes all name associations for the given ID", function()
			local unitID     = 1
			local firstName  = 'a'
			local secondName = 'b'
			seedUnit(firstName, unitID)
			seedUnit(secondName, unitID)
			tracking.UntrackUnitID(unitID)
			assert.is_nil(unitNames[unitID])
			assert.is_nil((unitIDs[firstName]  or {})[unitID])
			assert.is_nil((unitIDs[secondName] or {})[unitID])
		end)

		it("removes the name entry entirely when it has no remaining IDs", function()
			local unitName = 'solo'
			local unitID   = 1
			seedUnit(unitName, unitID)
			tracking.UntrackUnitID(unitID)
			assert.is_nil(unitIDs[unitName])
		end)

		it("only removes the targeted ID; shared names that still have other IDs remain", function()
			local sharedName = 'squad'
			local removedID  = 10
			local keptID     = 11
			seedUnit(sharedName, removedID)
			seedUnit(sharedName, keptID)
			tracking.UntrackUnitID(removedID)
			assert.is_nil(unitNames[removedID])
			assert.is_not_nil(unitNames[keptID])
			assert.is_true((unitIDs[sharedName] or {})[keptID] == true)
		end)

		it("is a no-op for an already-untracked ID", function()
			local untrackedID = 999
			tracking.UntrackUnitID(untrackedID) -- must not error
			assert.is_nil(unitNames[untrackedID])
		end)
	end)

	describe("UntrackUnitName", function()
		it("removes all ID associations for the given name", function()
			local unitName = 'squad'
			local firstID  = 10
			local secondID = 11
			seedUnit(unitName, firstID)
			seedUnit(unitName, secondID)
			tracking.UntrackUnitName(unitName)
			assert.is_nil(unitIDs[unitName])
			assert.is_nil((unitNames[firstID]  or {})[unitName])
			assert.is_nil((unitNames[secondID] or {})[unitName])
		end)

		it("removes the ID entry entirely when it has no remaining names", function()
			local unitName = 'solo'
			local unitID   = 10
			seedUnit(unitName, unitID)
			tracking.UntrackUnitName(unitName)
			assert.is_nil(unitNames[unitID])
		end)

		it("only removes the targeted name; IDs that still have other names remain", function()
			local removedName = 'alpha'
			local keptName    = 'beta'
			local unitID      = 1
			seedUnit(removedName, unitID)
			seedUnit(keptName,    unitID)
			tracking.UntrackUnitName(removedName)
			assert.is_nil(unitIDs[removedName])
			assert.is_true((unitNames[unitID] or {})[keptName] == true)
		end)

		it("is a no-op for an already-untracked name", function()
			local untrackedName = 'ghost'
			tracking.UntrackUnitName(untrackedName) -- must not error
			assert.is_nil(unitIDs[untrackedName])
		end)
	end)

	-- ── Feature tracking ──────────────────────────────────────────────────────

	describe("TrackFeature", function()
		it("registers the ID under the name in trackedFeatureIDs", function()
			local featureName = 'myFeature'
			local featureID   = 42
			tracking.TrackFeature(featureName, featureID)
			assert.is_true((featureIDs[featureName] or {})[featureID] == true)
		end)

		it("registers the name under the ID in trackedFeatureNames", function()
			local featureName = 'myFeature'
			local featureID   = 42
			tracking.TrackFeature(featureName, featureID)
			assert.is_true((featureNames[featureID] or {})[featureName] == true)
		end)

		it("is a no-op when name is nil", function()
			local featureID = 5
			tracking.TrackFeature(nil, featureID)
			assert.is_nil(featureNames[featureID])
		end)

		it("is a no-op when ID is nil", function()
			local featureName = 'ghost'
			tracking.TrackFeature(featureName, nil)
			assert.is_nil(featureIDs[featureName])
		end)

		it("supports multiple names for the same feature ID", function()
			local featureID  = 1
			local firstName  = 'alpha'
			local secondName = 'beta'
			tracking.TrackFeature(firstName, featureID)
			tracking.TrackFeature(secondName, featureID)
			assert.is_true((featureNames[featureID] or {})[firstName]  == true)
			assert.is_true((featureNames[featureID] or {})[secondName] == true)
		end)

		it("supports multiple IDs for the same name", function()
			local featureName = 'debris'
			local firstID     = 10
			local secondID    = 11
			tracking.TrackFeature(featureName, firstID)
			tracking.TrackFeature(featureName, secondID)
			assert.is_true((featureIDs[featureName] or {})[firstID]  == true)
			assert.is_true((featureIDs[featureName] or {})[secondID] == true)
		end)
	end)

	describe("IsFeatureIDUntracked", function()
		it("returns true for an ID that has never been tracked", function()
			local untrackedID = 99
			local result = tracking.IsFeatureIDUntracked(untrackedID)
			assert.is_true(result)
		end)

		it("returns false for a tracked ID", function()
			local featureName = 'f'
			local featureID   = 7
			seedFeature(featureName, featureID)
			local result = tracking.IsFeatureIDUntracked(featureID)
			assert.is_false(result)
		end)
	end)

	describe("IsFeatureNameUntracked", function()
		it("returns true for a name that has never been tracked", function()
			local result = tracking.IsFeatureNameUntracked('ghost')
			assert.is_true(result)
		end)

		it("returns false for a tracked name", function()
			local featureName = 'rock'
			local featureID   = 3
			seedFeature(featureName, featureID)
			local result = tracking.IsFeatureNameUntracked(featureName)
			assert.is_false(result)
		end)
	end)

	describe("DoesFeatureHaveName", function()
		it("returns false for an untracked ID", function()
			local untrackedID = 1
			local result = tracking.DoesFeatureHaveName(untrackedID, 'any')
			assert.is_false(result)
		end)

		it("returns true when the ID is tracked under that name", function()
			local featureName = 'rock'
			local featureID   = 1
			seedFeature(featureName, featureID)
			local result = tracking.DoesFeatureHaveName(featureID, featureName)
			assert.is_true(result)
		end)

		it("returns false when the ID is tracked under a different name", function()
			local trackedName = 'rock'
			local otherName   = 'tree'
			local featureID   = 1
			seedFeature(trackedName, featureID)
			local result = tracking.DoesFeatureHaveName(featureID, otherName)
			assert.is_false(result)
		end)
	end)

	describe("UntrackFeatureID", function()
		it("removes all name associations for the given ID", function()
			local featureID  = 1
			local firstName  = 'a'
			local secondName = 'b'
			seedFeature(firstName, featureID)
			seedFeature(secondName, featureID)
			tracking.UntrackFeatureID(featureID)
			assert.is_nil(featureNames[featureID])
			assert.is_nil((featureIDs[firstName]  or {})[featureID])
			assert.is_nil((featureIDs[secondName] or {})[featureID])
		end)

		it("removes the name entry entirely when it has no remaining IDs", function()
			local featureName = 'solo'
			local featureID   = 1
			seedFeature(featureName, featureID)
			tracking.UntrackFeatureID(featureID)
			assert.is_nil(featureIDs[featureName])
		end)

		it("only removes the targeted ID; shared names that still have other IDs remain", function()
			local sharedName = 'debris'
			local removedID  = 10
			local keptID     = 11
			seedFeature(sharedName, removedID)
			seedFeature(sharedName, keptID)
			tracking.UntrackFeatureID(removedID)
			assert.is_nil(featureNames[removedID])
			assert.is_not_nil(featureNames[keptID])
			assert.is_true((featureIDs[sharedName] or {})[keptID] == true)
		end)

		it("is a no-op for an already-untracked ID", function()
			local untrackedID = 999
			tracking.UntrackFeatureID(untrackedID) -- must not error
			assert.is_nil(featureNames[untrackedID])
		end)
	end)

	describe("UntrackFeatureName", function()
		it("removes all ID associations for the given name", function()
			local featureName = 'debris'
			local firstID     = 10
			local secondID    = 11
			seedFeature(featureName, firstID)
			seedFeature(featureName, secondID)
			tracking.UntrackFeatureName(featureName)
			assert.is_nil(featureIDs[featureName])
			assert.is_nil((featureNames[firstID]  or {})[featureName])
			assert.is_nil((featureNames[secondID] or {})[featureName])
		end)

		it("removes the ID entry entirely when it has no remaining names", function()
			local featureName = 'solo'
			local featureID   = 10
			seedFeature(featureName, featureID)
			tracking.UntrackFeatureName(featureName)
			assert.is_nil(featureNames[featureID])
		end)

		it("only removes the targeted name; IDs that still have other names remain", function()
			local removedName = 'alpha'
			local keptName    = 'beta'
			local featureID   = 1
			seedFeature(removedName, featureID)
			seedFeature(keptName,    featureID)
			tracking.UntrackFeatureName(removedName)
			assert.is_nil(featureIDs[removedName])
			assert.is_true((featureNames[featureID] or {})[keptName] == true)
		end)

		it("is a no-op for an already-untracked name", function()
			local untrackedName = 'ghost'
			tracking.UntrackFeatureName(untrackedName) -- must not error
			assert.is_nil(featureIDs[untrackedName])
		end)
	end)

end)
