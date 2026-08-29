local ModuleHandler = VFS.Include("modules/module_handler.lua")
local Stages = VFS.Include("modules/transport/policy_stages.lua")

local pipelines = ModuleHandler.LoadPolicies("transport") ---@type TransportPipelines

local function decide(pipeline, ctx)
	return ModuleHandler.Evaluate(pipeline, ctx)
end

describe("transport policies", function()
	it("publishes every stage name, keyed as its pipelines are, for the owner and for whoever contributes", function()
		for category, stages in pairs(Stages) do
			local named = {}
			for _, stage in ipairs(ModuleHandler.LoadPolicies("transport")[category]) do
				named[stage.name] = true
			end
			for key, name in pairs(stages) do
				assert.is_true(named[name], category .. " has no stage " .. name .. " (Stages." .. key .. ")")
			end
		end
	end)

	describe("load", function()
		local ok = { goalY = 10, height = 20, distance = 5, reach = 20, allied = true, passengerSpeed = 0 }

		it("allows an allied unit in reach on dry ground", function()
			assert.is_true(decide(pipelines.load, ok))
		end)

		it("refuses under water, out of reach, or a moving enemy — each on its own", function()
			assert.is_false(
				decide(pipelines.load, { goalY = -30, height = 10, distance = 5, reach = 20, allied = true })
			)
			assert.is_false(
				decide(pipelines.load, { goalY = 10, height = 20, distance = 25, reach = 20, allied = true })
			)
			assert.is_false(
				decide(
					pipelines.load,
					{ goalY = 10, height = 20, distance = 5, reach = 20, allied = false, passengerSpeed = 2 }
				)
			)
			assert.is_true(
				decide(
					pipelines.load,
					{ goalY = 10, height = 20, distance = 5, reach = 20, allied = false, passengerSpeed = 0.1 }
				)
			)
		end)

		it("a ground transport has no reach to be out of", function()
			assert.is_true(
				decide(pipelines.load, { goalY = 10, height = 20, distance = 900, reach = nil, allied = true })
			)
		end)
	end)

	describe("unload", function()
		it("sets a nano down only on dry, level ground", function()
			assert.is_true(decide(pipelines.unload, { goalY = 10, height = 0, nano = true, groundNormalY = 0.95 }))
			assert.is_false(decide(pipelines.unload, { goalY = 10, height = 0, nano = true, groundNormalY = 0.5 }))
			assert.is_true(decide(pipelines.unload, { goalY = 10, height = 0, nano = false, groundNormalY = 0.5 }))
		end)

		it("nothing is set down under water", function()
			assert.is_false(decide(pipelines.unload, { goalY = -50, height = 10 }))
		end)
	end)

	describe("loaded speed", function()
		it("is the carrier's own unless a commander drags it and the rule is on", function()
			assert.are.equal(
				9,
				decide(
					pipelines.loaded_speed,
					{ carriesCommander = true, transportSpeed = 270, dragEnabled = false, framesPerSecond = 30 }
				)
			)
			assert.are.equal(
				4,
				decide(
					pipelines.loaded_speed,
					{ carriesCommander = true, transportSpeed = 270, dragEnabled = true, framesPerSecond = 30 }
				)
			)
		end)
	end)
end)
