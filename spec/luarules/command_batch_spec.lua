describe("Command batch callbacks", function()
	it("shares attack inputs and preserves legacy receiver semantics", function()
		local root = "."
		local batch = dofile(root .. "/common/command_batch.lua")
		local calls, commits, legacy, marked = 0, 0, 0, 0
		local receiver = {
			UnitCommand = function()
				legacy = legacy + 1
			end,
			UnitCommandBatch = function(self, id, def, team, commands, player, synced, lua, ranges)
				assert(ranges[1] == 1 and ranges[2] == 400)
				calls = calls + 1
			end,
			AllowCommandBatch = function()
				return true
			end,
			AllowCommandBatchCommit = function()
				commits = commits + 1
			end,
		}
		local receivers = { receiver }
		local wants, notify, canNotify = batch.NotificationDispatcher(function()
			return receivers
		end, function()
			marked = marked + 1
		end)
		local allow = batch.AllowDispatcher(function()
			return receivers
		end, canNotify)
		local commands = {
			GetCount = function()
				return 400
			end,
		}
		for id = 1, 1200 do
			assert(allow(id, 7, 0, commands, -1, true, true) == true)
			assert(wants(id, 7, 0, commands, -1, true, true))
		end
		for id = 1, 1200 do
			notify(id, 7, 0, commands, -1, true, true, { 1, 400 })
		end
		assert(calls == 1200 and marked == 1200 and commits == 1200 and legacy == 0)

		-- Unknown receivers retain immediate legacy handling; no premature commits.
		receivers[2] = { UnitCommand = function() end }
		assert(not wants(1, 7, 0, commands))
		assert(allow(1, 7, 0, commands) == nil)
		assert(commits == 1200)
		receivers[2] = nil
		receiver.WantsUnitCommandBatch = function(self, id)
			return id ~= 42
		end
		assert(not wants(42, 7, 0, commands))
		assert(allow(42, 7, 0, commands) == nil)
		receiver.WantsUnitCommandBatch = nil
		receiver.AllowCommandBatch = function()
			return false
		end
		assert(allow(1, 7, 0, commands) == nil)
		receiver.AllowCommandBatch = function()
			return nil
		end
		assert(allow(1, 7, 0, commands) == nil)
		assert(commits == 1200)

		-- Membership and callback identity are captured when the receiver opts in.
		assert(wants(1, 7, 0, commands, -1, true, true))
		receiver.UnitCommandBatch = function()
			error("late replacement received an old batch")
		end
		notify(1, 7, 0, commands, -1, true, true, { 1, 400 })
		assert(calls == 1201)
		-- Unsubscribing before delivery suppresses pending notifications.
		receiver.UnitCommandBatch = function()
			error("removed receiver invoked")
		end
		assert(wants(2, 7, 0, commands))
		receivers = {}
		notify(2, 7, 0, commands, nil, nil, nil, { 1, 400 })
		assert(calls == 1201)

		-- Exercise the actual target-category gadget: one scan shared across 1200 units.
		local reads = 0
		local env = setmetatable({
			gadget = {},
			gadgetHandler = { RegisterAllowCommand = function() end },
			CMD = { ATTACK = 20 },
			UnitDefs = {
				[1] = { modCategories = { land = true }, weapons = { { onlyTargets = { vtol = true } } } },
				[2] = { modCategories = { vtol = true }, weapons = {} },
				[3] = { modCategories = { land = true }, weapons = {} },
			},
			Spring = {
				GetUnitDefID = function(id)
					return id == 999 and 3 or 2
				end,
			},
		}, { __index = _G })
		local chunk = assert(loadfile(root .. "/luarules/gadgets/unit_onlytargetcategory.lua"))
		setfenv(chunk, env)
		chunk()
		commands.GetTarget = function(self, i)
			reads = reads + 1
			return i
		end
		for id = 1, 1200 do
			assert(env.gadget:AllowCommandBatch(id, 1, 0, commands))
		end
		assert(reads == 400)
		env.gadget:UnitDestroyed()
		assert(env.gadget:AllowCommandBatch(1, 1, 0, commands))
		assert(reads == 800)
		local mixed = {
			GetCount = function()
				return 2
			end,
			GetTarget = function(self, i)
				return i == 1 and 1 or 999
			end,
		}
		assert(env.gadget:AllowCommandBatch(1, 1, 0, mixed) == false)
		assert(env.gadget:AllowCommand(1, 1, 0, 20, { 1 }))
		assert(not env.gadget:AllowCommand(1, 1, 0, 20, { 999 }))
	end)
end)
