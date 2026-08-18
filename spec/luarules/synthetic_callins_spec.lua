-- got tired of it, needs types:
---@diagnostic disable: undefined-field, redundant-parameter

local MODULE_PATH = "luarules/callins/synthetic_callins.lua"

local BASES = { "UnitBuildStep", "FeatureBuildStep" }

local function near(a, b)
	return a ~= nil and math.abs(a - b) < 1e-9 -- sums need to tolerate error
end

local function isEmpty(t)
	return next(t) == nil
end

for _, base in ipairs(BASES) do
	describe("synthetic_callins " .. base .. " summary views", function()
		local gh, synthetic, hook
		local marked, list, count, totals, active
		local postSeen, totalSeen, totalOrder
		local postGadget, totalGadget

		local function subscribe(g, view)
			local l = gh[base .. view .. "List"]
			l[#l + 1] = g
			gh:UpdateCallIn(base .. view)
		end

		local function unsubscribe(g, view)
			local l = gh[base .. view .. "List"]
			for i = #l, 1, -1 do
				if l[i] == g then
					table.remove(l, i)
				end
			end
			gh:UpdateCallIn(base .. view)
		end

		local function mark(id, part)
			hook(id, part)
		end

		local function sweep()
			postSeen, totalSeen, totalOrder = {}, {}, {}
			gh:GameFramePost(1)
		end

		local function stateClean()
			return isEmpty(marked) and isEmpty(totals) and (count[1] == 0 or count[1] == nil)
		end

		before_each(function()
			gh = { GG = {} }
			for _, b in ipairs(BASES) do
				gh[b .. "PostList"] = {}
				gh[b .. "TotalList"] = {}
			end
			function gh:UpdateCallIn(name) end
			function gh:GameFramePost(frameNum) end

			local env = setmetatable({
				gadgetHandler = gh,
				Script = { GetSynced = function() return true end },
				tracy = { ZoneBeginN = function() end, ZoneEnd = function() end },
				table = setmetatable({ new = function() return {} end }, { __index = table }),
			}, { __index = _G })

			local chunk = assert(loadfile(MODULE_PATH))
			setfenv(chunk, env)
			synthetic = chunk()
			synthetic.install(gh)

			hook = gh.GG["Accumulate" .. base]
			marked, list, count, totals, active = synthetic.getMarks(base)

			postSeen, totalSeen, totalOrder = {}, {}, {}
			postGadget = {
				[base .. "Post"] = function(self, id)
					postSeen[#postSeen + 1] = id
				end,
			}
			totalGadget = {
				-- Additive so a duplicate dispatch cannot mask a wrong value.
				[base .. "Total"] = function(self, id, part)
					totalOrder[#totalOrder + 1] = id
					totalSeen[id] = (totalSeen[id] or 0) + part
				end,
			}
		end)

		it("publishes an accumulator hook", function()
			assert.equals("function", type(hook))
		end)

		describe("accounting", function()
			before_each(function()
				subscribe(postGadget, "Post")
				subscribe(totalGadget, "Total")
			end)

			it("sums recorded parts once per id and sweeps clean", function()
				mark(101, 0.1)
				mark(101, 0.1)
				mark(101, 0.1)
				mark(102, -0.2)
				mark(102, -0.2)
				sweep()
				assert.is_true(near(totalSeen[101], 0.3))
				assert.is_true(near(totalSeen[102], -0.4))
				assert.same({ 101, 102 }, postSeen)
				assert.same({ 101, 102 }, totalOrder)
				assert.is_true(stateClean())
			end)

			it("adds hook amounts into the running total", function()
				mark(101, 0.1)
				hook(101, 0.25)
				mark(101, 0.1)
				sweep()
				assert.is_true(near(totalSeen[101], 0.45))
			end)

			it("registers ids reported by the hook alone", function()
				mark(101, 0.1)
				hook(102, 0.5)
				sweep()
				assert.is_true(near(totalSeen[101], 0.1))
				assert.is_true(near(totalSeen[102], 0.5))
				assert.same({ 101, 102 }, postSeen)
			end)

			it("gives each event to every subscriber in layer order", function()
				local log = {}
				local function logger(tag)
					return function(self, id)
						log[#log + 1] = tag .. id
					end
				end
				local a = { [base .. "Post"] = logger("a") }
				local b = { [base .. "Post"] = logger("b") }
				subscribe(a, "Post")
				subscribe(b, "Post")
				mark(101, 0.1)
				mark(102, 0.1)
				sweep()
				assert.same({ "a101", "b101", "a102", "b102" }, log)
			end)
		end)

		describe("activation", function()
			it("records no values in post-only mode", function()
				subscribe(postGadget, "Post")
				mark(101, 0.1)
				assert.is_true(isEmpty(totals))
				sweep()
				assert.same({ 101 }, postSeen)
				assert.is_true(isEmpty(totalSeen))
				assert.is_true(stateClean())
			end)

			it("holds membership through the total view alone", function()
				subscribe(totalGadget, "Total")
				mark(101, 0.1)
				mark(101, 0.2)
				sweep()
				assert.is_true(near(totalSeen[101], 0.3))
				assert.same({}, postSeen)
				unsubscribe(totalGadget, "Total")
				assert.is_nil(count[1])
				assert.is_true(stateClean())
			end)

			it("clears values on total unsubscribe and keeps membership", function()
				subscribe(postGadget, "Post")
				subscribe(totalGadget, "Total")
				mark(101, 0.1)
				unsubscribe(totalGadget, "Total")
				assert.is_true(isEmpty(totals))
				assert.equals(1, count[1])
				sweep()
				assert.same({ 101 }, postSeen)
				assert.is_true(isEmpty(totalSeen))
			end)

			it("accounts only from reactivation onward", function()
				subscribe(postGadget, "Post")
				subscribe(totalGadget, "Total")
				mark(101, 0.1)
				unsubscribe(totalGadget, "Total")
				mark(101, 0.2) -- unaccounted: the value layer is inactive
				subscribe(totalGadget, "Total")
				mark(101, 0.3)
				sweep()
				assert.is_true(near(totalSeen[101], 0.3))
				assert.same({ 101 }, postSeen)
			end)

			it("yields partial totals on mid-frame activation", function()
				subscribe(postGadget, "Post")
				mark(101, 0.1) -- kept by the marks, lost to the totals
				subscribe(totalGadget, "Total")
				mark(101, 0.2)
				mark(102, 0.3)
				sweep()
				assert.is_true(near(totalSeen[101], 0.2))
				assert.is_true(near(totalSeen[102], 0.3))
			end)

			it("neutralizes the hook on full stop", function()
				subscribe(postGadget, "Post")
				subscribe(totalGadget, "Total")
				unsubscribe(postGadget, "Post")
				unsubscribe(totalGadget, "Total")
				assert.is_nil(count[1])
				hook(101, 0.1)
				assert.is_true(stateClean())
				sweep()
				assert.same({}, postSeen)
				assert.is_true(isEmpty(totalSeen))
			end)

			it("stops clean regardless of update order", function()
				for _, order in ipairs({ { "Post", "Total" }, { "Total", "Post" } }) do
					subscribe(postGadget, "Post")
					subscribe(totalGadget, "Total")
					mark(101, 0.1)
					gh[base .. "PostList"] = {}
					gh[base .. "TotalList"] = {}
					gh:UpdateCallIn(base .. order[1])
					gh:UpdateCallIn(base .. order[2])
					assert.is_nil(count[1])
					assert.is_nil(active[1])
					assert.is_true(stateClean())
				end
			end)
		end)

		describe("robustness", function()
			before_each(function()
				subscribe(postGadget, "Post")
				subscribe(totalGadget, "Total")
			end)

			it("leaves no marks behind a throwing subscriber", function()
				local thrower = { [base .. "Post"] = function() error("boom") end }
				subscribe(thrower, "Post")
				mark(101, 0.1)
				postSeen, totalSeen = {}, {}
				assert.is_false(pcall(gh.GameFramePost, gh, 1))
				assert.is_true(isEmpty(marked) and isEmpty(totals))
				assert.equals(1, count[1]) -- the ghost batch redispatches once
				unsubscribe(thrower, "Post")
				mark(101, 0.4)
				sweep()
				assert.is_true(near(totalSeen[101], 0.4))
				assert.is_true(stateClean())
				sweep()
				assert.same({}, postSeen)
				assert.is_true(isEmpty(totalSeen))
			end)

			it("preserves mid-frame state across repeated updates", function()
				mark(101, 0.1)
				gh:UpdateCallIn(base .. "Post")
				gh:UpdateCallIn(base .. "Total")
				assert.equals(1, count[1])
				assert.is_true(near(totals[101], 0.1))
				sweep()
				assert.is_true(near(totalSeen[101], 0.1))
			end)
		end)

		describe("registration", function()
			it("leaves no residue after churn", function()
				subscribe(postGadget, "Post")
				subscribe(totalGadget, "Total")
				for i = 1, 3 do
					mark(100 + i, 0.1)
					unsubscribe(totalGadget, "Total")
					unsubscribe(postGadget, "Post")
					subscribe(postGadget, "Post")
					subscribe(totalGadget, "Total")
				end
				assert.equals(0, count[1])
				assert.is_true(stateClean())
				mark(101, 0.5)
				sweep()
				assert.is_true(near(totalSeen[101], 0.5))
			end)

			it("records nothing before any subscription", function()
				mark(101, 0.1)
				assert.is_true(stateClean())
				subscribe(postGadget, "Post")
				subscribe(totalGadget, "Total")
				mark(101, 0.2)
				sweep()
				assert.is_true(near(totalSeen[101], 0.2))
			end)
		end)
	end)
end
