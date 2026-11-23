local SpecEnv = VFS.Include("spec/support/spec_env.lua")

local function systemRules(mode, features)
	local env = SpecEnv.new({
		includes = { ["init.lua"] = true },
		Script = {
			IsEngineMinVersion = function()
				return true
			end,
		},
		Engine = { FeatureSupport = features or {} },
		Spring = {
			GetModOptions = function()
				return { restrictedspectators = mode }
			end,
		},
	})
	return SpecEnv.include(env, "gamedata/modrules.lua").system
end

describe("spectator vision after elimination", function()
	it("offers the three lobby choices in order and defaults to full view", function()
		local optionsByKey = {}
		for _, option in ipairs(VFS.Include("modoptions.lua")) do
			optionsByKey[option.key] = option
		end
		local option = assert(optionsByKey.restrictedspectators)
		assert.equals("list", option.type)
		local keys = {}
		for _, item in ipairs(option.items) do
			keys[#keys + 1] = item.key
		end
		assert.same({ "allied", "optin", "full" }, keys)
		assert.equals("full", option.def)
		local rules = systemRules(option.def)
		assert.is_false(rules.spectatorFullViewOptIn)
		assert.is_false(rules.restrictSpectatorsToAllyTeam)
	end)

	it("enables explicit opt-in only for the optional Full View mode", function()
		local rules = systemRules("optin", { spectatorFullViewOptIn = true })
		assert.is_false(rules.restrictSpectatorsToAllyTeam)
		assert.is_true(rules.spectatorFullViewOptIn)
	end)

	it("keeps tournament mode locked, including saved boolean lobby settings", function()
		for _, mode in ipairs({ "allied", "1" }) do
			local rules = systemRules(mode, { restrictSpectatorsToAllyTeam = true })
			assert.is_true(rules.restrictSpectatorsToAllyTeam)
			assert.is_false(rules.spectatorFullViewOptIn)
		end
	end)

	it("requires engine support for the chosen restriction", function()
		assert.has_error(function()
			systemRules("optin", { restrictSpectatorsToAllyTeam = true })
		end)
		assert.has_error(function()
			systemRules("allied", { spectatorFullViewOptIn = true })
		end)
	end)
end)
