local PolicyEvents = VFS.Include("common/luaUtilities/team_transfer/policy_events.lua")

describe("PolicyEvents.NotifyIfChanged", function()
	local sent

	local function recorder()
		return function(event, teamId, domain)
			sent[#sent + 1] = { event = event, teamId = teamId, domain = domain }
		end
	end

	before_each(function()
		sent = {}
	end)

	it("records the first observation silently (no event on init)", function()
		local changed = PolicyEvents.NotifyIfChanged(1, "unit", "modes=all", recorder())
		assert.is_false(changed)
		assert.are.equal(0, #sent)
	end)

	it("emits SharePolicyChanged when the signature changes", function()
		PolicyEvents.NotifyIfChanged(2, "unit", "modes=none", recorder())
		local changed = PolicyEvents.NotifyIfChanged(2, "unit", "modes=all", recorder())
		assert.is_true(changed)
		assert.are.equal(1, #sent)
		assert.are.same({ event = "SharePolicyChanged", teamId = 2, domain = "unit" }, sent[1])
	end)

	it("does not emit when the signature is unchanged", function()
		PolicyEvents.NotifyIfChanged(3, "metal", "tax=0.5", recorder())
		local changed = PolicyEvents.NotifyIfChanged(3, "metal", "tax=0.5", recorder())
		assert.is_false(changed)
		assert.are.equal(0, #sent)
	end)

	it("tracks domains independently for the same team", function()
		PolicyEvents.NotifyIfChanged(4, "unit", "a", recorder())   -- baseline unit
		PolicyEvents.NotifyIfChanged(4, "metal", "x", recorder())  -- baseline metal
		PolicyEvents.NotifyIfChanged(4, "unit", "b", recorder())   -- unit change -> emit
		assert.are.equal(1, #sent)
		assert.are.equal("unit", sent[1].domain)
	end)

	it("tracks teams independently within a domain", function()
		PolicyEvents.NotifyIfChanged(5, "energy", "e0", recorder()) -- baseline team 5
		PolicyEvents.NotifyIfChanged(6, "energy", "e0", recorder()) -- baseline team 6
		PolicyEvents.NotifyIfChanged(5, "energy", "e1", recorder()) -- team 5 change
		assert.are.equal(1, #sent)
		assert.are.equal(5, sent[1].teamId)
	end)
end)

describe("PolicyEvents build-delay debuff", function()
	it("forwards NotifyBuildDelay with unit and frame window", function()
		local args
		PolicyEvents.NotifyBuildDelay(42, 100, 190, function(...) args = { ... } end)
		assert.are.same({ "UnitBuildDelayStarted", 42, 100, 190 }, args)
	end)

	it("forwards NotifyBuildDelayEnd with the unit", function()
		local args
		PolicyEvents.NotifyBuildDelayEnd(42, function(...) args = { ... } end)
		assert.are.same({ "UnitBuildDelayEnded", 42 }, args)
	end)
end)
