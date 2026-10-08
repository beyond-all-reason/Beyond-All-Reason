local Modules = require("modules/enums").Modules
local ModuleHandler = require("modules/module_handler")
local Policy = require("modules/policy")

local function decide(policy, ctx)
	return ModuleHandler.Evaluate(policy, ctx)
end

describe("a transport picking a unit up, setting it down, and flying loaded", function()
	local Contract = ModuleHandler.Contract(Modules.Transport)

	describe("picks up what it can reach on dry ground, and refuses the rest for a reason it can name", function()
		local ok = { goalY = 10, height = 20, distance = 5, reach = 20, allied = true, passengerSpeed = 0 }

		it("allows an allied unit in reach on dry ground", function()
			assert.is_true(decide(Contract.Load, ok))
		end)

		it("refuses under water, out of reach, or a moving enemy — each on its own", function()
			assert.is_false(
				decide(Contract.Load, { goalY = -30, height = 10, distance = 5, reach = 20, allied = true })
			)
			assert.is_false(
				decide(Contract.Load, { goalY = 10, height = 20, distance = 25, reach = 20, allied = true })
			)
			assert.is_false(
				decide(
					Contract.Load,
					{ goalY = 10, height = 20, distance = 5, reach = 20, allied = false, passengerSpeed = 2 }
				)
			)
			assert.is_true(
				decide(
					Contract.Load,
					{ goalY = 10, height = 20, distance = 5, reach = 20, allied = false, passengerSpeed = 0.1 }
				)
			)
		end)

		it("an ally's nano stays put; your own or an enemy's may be lifted", function()
			assert.is_false(
				decide(Contract.Load, { goalY = 10, height = 20, nano = true, allied = true, ownTeam = false })
			)
			assert.is_true(
				decide(Contract.Load, { goalY = 10, height = 20, nano = true, allied = true, ownTeam = true })
			)
			assert.is_true(
				decide(Contract.Load, { goalY = 10, height = 20, nano = true, allied = false, ownTeam = false })
			)
		end)

		it("a ground transport has no reach to be out of", function()
			assert.is_true(
				decide(Contract.Load, { goalY = 10, height = 20, distance = 900, reach = nil, allied = true })
			)
		end)
	end)

	describe("sets its passenger down only where it can stand", function()
		it("sets a nano down only on dry, level ground", function()
			assert.is_true(decide(Contract.Unload, { goalY = 10, height = 0, nano = true, groundNormalY = 0.95 }))
			assert.is_false(decide(Contract.Unload, { goalY = 10, height = 0, nano = true, groundNormalY = 0.5 }))
			assert.is_true(decide(Contract.Unload, { goalY = 10, height = 0, nano = false, groundNormalY = 0.5 }))
		end)

		it("nothing is set down under water", function()
			assert.is_false(decide(Contract.Unload, { goalY = -50, height = 10 }))
		end)
	end)

	it("publishes every step name, keyed as its policies are, for the owner and for whoever contributes", function()
		for _, steps in pairs(Contract) do
			local identity = Policy.IdentityOf(steps)
			local owner = identity.contributes and identity.contributes.owner or "transport"
			local category = identity.contributes and identity.contributes.category or identity.category
			local named = {}
			for _, step in ipairs(ModuleHandler.LoadPolicies(owner)[category]) do
				named[step.name] = true
			end
			for key, name in pairs(steps) do
				assert.is_true(
					named[name],
					owner .. "." .. category .. " has no step " .. name .. " (Contract." .. key .. ")"
				)
			end
		end
	end)
end)
