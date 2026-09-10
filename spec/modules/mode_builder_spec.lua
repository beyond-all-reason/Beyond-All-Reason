local ModeBuilder = VFS.Include("modules/mode_builder.lua")

local function grammar()
	return ModeBuilder.Grammar({
		category = "test",
		verbs = {
			Own = ModeBuilder.Verb(function(modeName, noun)
				return { domain = ModeBuilder.DomainOf(modeName, "Own", noun, { ["end"] = true }, "Match.End") }
			end, function(_params, lock)
				return { deathmode = { value = "neverend", locked = lock.noun } }
			end),
			Rate = ModeBuilder.Verb(function(_modeName, rate)
				return { rate = rate }
			end, function(params, lock)
				return { rate = { value = params.rate or 1, locked = lock.dial } }
			end),
		},
	})
end

local MatchEnd = { domain = "end" }

describe("mode builder", function()
	describe("the chain", function()
		it("keys a mode by the snake_case of its name", function()
			assert.are.equal("easy_tax", grammar()("Easy Tax").key)
			assert.are.equal("test", grammar()("Easy Tax").category)
		end)

		it("returns the chain from every verb, so authoring stays dot-only", function()
			local Mode = grammar()
			local chain = Mode("Scripted")
			assert.are.equal(chain, chain.Desc("d"))
			assert.are.equal(chain, chain.Ranked())
			assert.are.equal(chain, chain.Own(MatchEnd))
			assert.are.equal(chain, chain.Locked())
		end)

		it("re-derives modOptions after every step, so consumers read a plain table", function()
			local chain = grammar()("Scripted").Own(MatchEnd)
			assert.are.equal("neverend", chain.modOptions.deathmode.value)
			chain.Rate(5)
			assert.are.equal(5, chain.modOptions.rate.value)
			assert.are.equal("neverend", chain.modOptions.deathmode.value)
		end)

		it("a claim carries its verb's name and writer, nothing by string", function()
			local chain = grammar()("Scripted").Own(MatchEnd)
			local claim = chain.policies[#chain.policies]
			assert.are.equal("Own", claim.verb)
			assert.is_function(claim.write)
		end)

		it("refuses a modifier before any policy", function()
			assert.has_error(function()
				grammar()("Scripted").Locked()
			end, "Scripted: .Locked before any policy")
		end)

		it("refuses a verb that collides with a chain field", function()
			assert.has_error(function()
				ModeBuilder.Grammar({
					category = "test",
					verbs = {
						Desc = ModeBuilder.Verb(function() end, function() end),
					},
				})("Scripted")
			end, "ModeBuilder.Grammar: verb collides with a chain field: Desc")
		end)

		it("refuses a bare function where a Verb belongs", function()
			assert.has_error(function()
				ModeBuilder.Grammar({ category = "test", verbs = { Own = function() end } })("Scripted")
			end, "ModeBuilder.Grammar: Own is not a ModeBuilder.Verb")
		end)
	end)

	describe("lock defaults", function()
		it("a bare policy is a suggestion: nothing locked", function()
			local chain = grammar()("Scripted").Own(MatchEnd).Rate(2)
			assert.is_false(chain.modOptions.deathmode.locked)
			assert.is_false(chain.modOptions.rate.locked)
		end)

		it("Locked pins the noun, Sealed the dials too", function()
			local chain = grammar()("Scripted").Own(MatchEnd).Locked().Rate(2).Locked()
			assert.is_true(chain.modOptions.deathmode.locked)
			assert.is_false(chain.modOptions.rate.locked)
			assert.is_true(grammar()("Scripted").Rate(2).Sealed().modOptions.rate.locked)
		end)
	end)

	describe("serialization", function()
		it("rejects a claim with no verb behind it", function()
			assert.has_error(function()
				ModeBuilder.ToModOptions({ { verb = "Stray" } })
			end, "a claim with no verb behind it: Stray")
		end)

		it("rejects two claims owning one modoption", function()
			local double = function()
				return { deathmode = { value = "x", locked = true } }
			end
			assert.has_error(function()
				ModeBuilder.ToModOptions({ { verb = "a", write = double }, { verb = "b", write = double } })
			end, "two claims own modoption deathmode")
		end)
	end)

	describe("Verbs", function()
		it("merges verb tables and refuses a name shipped twice", function()
			local a = { Own = ModeBuilder.Verb(function() end, function() end) }
			local b = { Rate = ModeBuilder.Verb(function() end, function() end) }
			local merged = ModeBuilder.Verbs(a, b)
			assert.is_not_nil(merged.Own)
			assert.is_not_nil(merged.Rate)
			assert.has_error(function()
				ModeBuilder.Verbs(a, a)
			end, "ModeBuilder.Verbs: two modules ship a verb named Own")
		end)
	end)

	describe("OneOf", function()
		it("passes a listed value and names the keys for anything else", function()
			ModeBuilder.OneOf("M", "Draft", { Random = "random", Fair = "fair" }, "fair")
			assert.has_error(function()
				ModeBuilder.OneOf("M", "Draft", { Random = "random", Fair = "fair" }, "x")
			end, "M: .Draft expects one of DraftMode.Fair, DraftMode.Random")
		end)
	end)

	describe("domain guard", function()
		it("returns the noun's domain when the verb accepts it", function()
			assert.are.equal("end", ModeBuilder.DomainOf("M", "Own", MatchEnd, { ["end"] = true }, "Match.End"))
		end)

		it("rejects a value that is not a noun", function()
			assert.has_error(function()
				ModeBuilder.DomainOf("M", "Own", "end", { ["end"] = true }, "Match.End")
			end, "M: .Own expects a noun (Match.End)")
		end)

		it("rejects a noun the verb does not apply to", function()
			assert.has_error(function()
				ModeBuilder.DomainOf("M", "Own", { domain = "share" }, { ["end"] = true }, "Match.End")
			end, "M: .Own does not apply to share")
		end)
	end)

	describe("Uses", function()
		it("names the modules a preset makes live besides its own, each by its contract", function()
			local PolicyBuilder = VFS.Include("modules/policy_builder.lua")
			local Tech = PolicyBuilder.Contract("tech", {})
			local Other = PolicyBuilder.Contract("other", {})
			local mode = grammar()("Customize").Uses(Tech).Uses(Other)
			assert.are.same({ "tech", "other" }, mode.uses)
			assert.is_nil(grammar()("Plain").uses)
		end)

		it("refuses a string: a module is its contract", function()
			assert.has_error(function()
				grammar()("Customize").Uses("tech")
			end, "Customize: .Uses expects a module's contract (VFS.Include its contract.lua)")
		end)
	end)

	describe("Ranked", function()
		it("permission is a flag: nothing pinned", function()
			local mode = grammar()("R").Ranked()
			assert.is_true(mode.allowRanked)
			assert.is_nil(mode.modOptions.ranked_game)
		end)

		it("a mode that never says Ranked is unranked, and carries the pin like any claim", function()
			local mode = grammar()("R")
			assert.is_false(mode.allowRanked)
			assert.are.same({ value = false, locked = false }, mode.modOptions.ranked_game)
		end)

		it("prohibition is a policy: ranked_game off, pinned when Locked", function()
			local mode = grammar()("R").Ranked(false).Locked()
			assert.is_false(mode.allowRanked)
			assert.are.same({ value = false, locked = true }, mode.modOptions.ranked_game)
			assert.is_false(grammar()("R").Ranked(false).modOptions.ranked_game.locked)
		end)
	end)
end)
