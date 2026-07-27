
local TriggerEngine = VFS.Include("modules/missions/lib/trigger_engine.lua")
local DSL = VFS.Include("modules/missions/lib/dsl.lua")
local Verbs = VFS.Include("modules/missions/lib/verbs.lua")
local Contribution = VFS.Include("modules/combat/mission_dsl.lua")
local Guard = VFS.Include("modules/combat/lib/guard.lua")

local FILE = "triggers/outpost.lua"
local Unit = Verbs.MakeUnit({ vip = true, hub = true, boss = true })

local function newFile()
	local engine = TriggerEngine.New()
	local file = DSL.ForFile(FILE, engine.Register)
	local forFile = Contribution.ForFile({ filename = FILE, Register = engine.Register })
	local guard = Guard.New()
	local dead = {}
	local unitIDs = { vip = 1, hub = 2, boss = 3 }

	local ctx = {
		IsUnitDestroyed = function(name)
			return dead[name] == true
		end,
		Protect = function(name)
			guard.Protect(unitIDs[name])
		end,
		Unprotect = function(name)
			guard.Unprotect(unitIDs[name])
		end,
	}

	local h = {
		When = file.When,
		Finalize = function()
			file.Finalize()
			if forFile.Finalize then
				forFile.Finalize()
			end
		end,
		Combat = forFile.env.Combat,
		triggers = engine.Triggers,
		event = engine.OnEvent,
		tick = function()
			engine.Evaluate(ctx)
		end,
		latch = function(name)
			dead[name] = true
		end,
		protected = function(name)
			return guard.IsProtected(unitIDs[name])
		end,
	}
	h.kill = function(name)
		h.latch(name)
		engine.OnEvent("UnitDestroyed")
	end
	return h
end

describe("combat mission verbs", function()
	it("Protect builds an effect over the roster name", function()
		local log = {}
		local ctx = {
			Protect = function(name)
				log[#log + 1] = "protect:" .. name
			end,
		}
		newFile().Combat.Protect(Unit("hub")).execute(ctx)
		assert.are.same({ "protect:hub" }, log)
	end)

	it("Unprotect builds the primitive Until sugars over", function()
		local log = {}
		local ctx = {
			Unprotect = function(name)
				log[#log + 1] = "unprotect:" .. name
			end,
		}
		newFile().Combat.Unprotect(Unit("hub")).execute(ctx)
		assert.are.same({ "unprotect:hub" }, log)
	end)

	it("Protect rejects a plain string (wants a Unit reference)", function()
		local h = newFile()
		assert.has_error(function()
			h.Combat.Protect("hub")
		end)
	end)

	it("Until rejects a non-condition", function()
		local h = newFile()
		assert.has_error(function()
			h.Combat.Protect(Unit("hub")).Until(function() end)
		end)
	end)

	describe("the lifetime .Until bounds", function()
		it("arms nothing at load: the file's own statements are all that is armed", function()
			local h = newFile()
			h.When(Unit("hub").IsDestroyed()).Do(h.Combat.Protect(Unit("vip")).Until(Unit("boss").IsDestroyed()))
			h.Finalize()
			assert.are.equal(1, #h.triggers())
		end)

		it("releases when the condition becomes true after the protection", function()
			local h = newFile()
			h.When(Unit("hub").IsDestroyed()).Do(h.Combat.Protect(Unit("vip")).Until(Unit("boss").IsDestroyed()))
			h.Finalize()

			h.kill("hub")
			h.tick()
			assert.is_true(h.protected("vip"))
			assert.are.equal(2, #h.triggers())

			h.kill("boss")
			h.tick()
			assert.is_false(h.protected("vip"))
		end)

		it("a condition that passed first does not leave the unit protected forever", function()
			-- The tense violation: a companion armed at load fires against an
			-- unprotected unit, retires, and nothing is left to release.
			local h = newFile()
			h.When(Unit("hub").IsDestroyed()).Do(h.Combat.Protect(Unit("vip")).Until(Unit("boss").IsDestroyed()))
			h.Finalize()

			h.kill("boss")
			h.tick()
			assert.is_false(h.protected("vip"))

			h.kill("hub")
			h.tick()
			-- The bound is already past, so the protection does not outlive it.
			assert.is_false(h.protected("vip"))
		end)

		it("the release keeps its inputs: the loader hooks its callin after it arms", function()
			-- Nothing in this file watches UnitDestroyed at load; a release that
			-- polled would never get the latch it reads written.
			local go = {
				inputs = { "mission.objective_changed" },
				evaluate = function()
					return true
				end,
			}
			local h = newFile()
			h.When(go).Do(h.Combat.Protect(Unit("vip")).Until(Unit("boss").IsDestroyed()))
			h.Finalize()

			h.tick()
			assert.is_true(h.protected("vip"))

			h.kill("boss")
			h.tick()
			assert.is_false(h.protected("vip"))
		end)

		it("overlapping lifetimes on one unit release independently", function()
			local ends = {}
			local firstOver = {
				evaluate = function()
					return ends.first == true
				end,
			}
			local secondOver = {
				evaluate = function()
					return ends.second == true
				end,
			}
			local h = newFile()
			h.When(Unit("hub").IsDestroyed()).Do(h.Combat.Protect(Unit("vip")).Until(firstOver))
			h.When(Unit("hub").IsDestroyed()).Do(h.Combat.Protect(Unit("vip")).Until(secondOver))
			h.Finalize()

			h.kill("hub")
			h.tick()
			assert.is_true(h.protected("vip"))
			assert.are.equal(4, #h.triggers())

			ends.first = true
			h.tick()
			-- The second lifetime is still in force.
			assert.is_true(h.protected("vip"))

			ends.second = true
			h.tick()
			assert.is_false(h.protected("vip"))
		end)
	end)
end)

describe("combat's mission DSL contribution", function()
	it("contributes the Combat vocabulary per file", function()
		local forFile = Contribution.ForFile({ filename = FILE, Register = function() end })
		assert.is_function(forFile.env.Combat.Protect)
		assert.is_function(forFile.env.Combat.Unprotect)
	end)

	it("has no load-time commit step, so a failed load leaves nothing behind", function()
		local registered = 0
		local forFile = Contribution.ForFile({
			filename = FILE,
			Register = function()
				registered = registered + 1
			end,
		})
		forFile.env.Combat.Protect(Unit("vip")).Until(Unit("boss").IsDestroyed())
		assert.is_nil(forFile.Finalize)
		assert.are.equal(0, registered)
	end)
end)
