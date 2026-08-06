local ModeBuilder = VFS.Include("modules/mode_builder.lua")

--- A throwaway vocabulary: one noun, one verb, two serializers, so the tests
--- exercise the builder rather than any module's real grammar.
local function grammar()
	return ModeBuilder.Grammar({
		category = "test",
		serializers = {
			["end.scripted"] = function(_params, lock)
				return { deathmode = { value = "neverend", locked = lock.structure } }
			end,
			["dial.rate"] = function(params, lock)
				return { rate = { value = params.rate or 1, locked = lock.dial } }
			end,
		},
		verbs = {
			Own = function(modeName, noun)
				return { ModeBuilder.DomainOf(modeName, "Own", noun, { ["end"] = true }, "Match.End") .. ".scripted" }
			end,
			Rate = function(_modeName, rate)
				return { "dial.rate", rate = rate }
			end,
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
			-- the earlier policy's options survive the re-derivation
			assert.are.equal("neverend", chain.modOptions.deathmode.value)
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
					serializers = {},
					verbs = { Desc = function() end },
				})("Scripted")
			end, "ModeBuilder.Grammar: verb collides with a chain field: Desc")
		end)
	end)

	describe("lock defaults", function()
		it("locks structure by default and leaves dials host-tunable", function()
			local chain = grammar()("Scripted").Own(MatchEnd).Rate(2)
			assert.is_true(chain.modOptions.deathmode.locked)
			assert.is_false(chain.modOptions.rate.locked)
		end)

		it("Unlocked opens structure, Locked pins dials", function()
			assert.is_false(grammar()("Scripted").Own(MatchEnd).Unlocked().modOptions.deathmode.locked)
			assert.is_true(grammar()("Scripted").Rate(2).Locked().modOptions.rate.locked)
		end)
	end)

	describe("serialization", function()
		it("rejects a policy no serializer owns", function()
			assert.has_error(function()
				ModeBuilder.ToModOptions({}, { "end.scripted" })
			end, "unknown mode policy: end.scripted")
		end)

		it("rejects two policies owning one modoption", function()
			local double = function()
				return { deathmode = { value = "x", locked = true } }
			end
			assert.has_error(function()
				ModeBuilder.ToModOptions({ a = double, b = double }, { "a", "b" })
			end, "two policies own modoption deathmode")
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
end)
