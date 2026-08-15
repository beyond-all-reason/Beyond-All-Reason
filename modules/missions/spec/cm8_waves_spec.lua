--- CM8's pressure file, loaded through the same sandbox the loader builds.
---
--- A trigger file is only as good as the vocabulary it can reach, and the
--- vocabulary is composed from the missions manifest's requires list at load
--- time. That composition is exactly the thing a spec can check and the
--- checker cannot: a pack name that does not resolve, or a verb the module
--- declares but does not inject, is a nil global at arm time and nothing
--- earlier.

local DSL = VFS.Include("modules/missions/lib/dsl.lua")
local ModuleHandler = VFS.Include("modules/module_handler.lua")
local TriggerEngine = VFS.Include("modules/missions/lib/trigger_engine.lua")
local Verbs = VFS.Include("modules/missions/lib/verbs.lua")

local TRIGGER_FILE = "modules/missions/cm8_ashfall/triggers/waves.lua"
local PACK = "scavengers.skirmish"

---Everything the ctx handed to a mission does, recorded rather than done.
local function recordingContext()
	local calls = {}
	local status = { waveNumber = 0, wavesCleared = 0, bossesKilled = 0, intensity = 1 }
	return {
		calls = calls,
		status = status,
		frame = 30,
		StartWaves = function(request)
			calls[#calls + 1] = { "start", request }
		end,
		StopWaves = function(pack)
			calls[#calls + 1] = { "stop", pack }
		end,
		SetWaveIntensity = function(pack, intensity)
			calls[#calls + 1] = { "intensity", pack, intensity }
		end,
		SurgeWaves = function(pack)
			calls[#calls + 1] = { "surge", pack }
		end,
		WaveStatus = function()
			return status
		end,
		IsObjectiveComplete = function()
			return true
		end,
	}
end

---Compose the trigger sandbox the loader composes, from the same manifest.
---@param engine table
---@return table env
local function sandbox(engine)
	local file = DSL.ForFile("cm8_ashfall/triggers/waves.lua", engine.Register)
	local env = {
		When = file.When,
		Team = { Player = Verbs.MakeTeam(0, 0) },
		UnitDef = Verbs.UnitDef,
		Objective = function(name)
			return {
				Complete = function()
					return { execute = function() end }
				end,
				IsComplete = function()
					return {
						inputs = { "mission.objective_changed" },
						evaluate = function(ctx)
							return ctx.IsObjectiveComplete(name)
						end,
					}
				end,
			}
		end,
	}
	for _, name in ipairs(ModuleHandler.Discover().missions.requires) do
		local path = "modules/" .. name .. "/mission_dsl.lua"
		if VFS.FileExists(path) then
			local contribution = VFS.Include(path).ForFile({
				filename = "cm8_ashfall/triggers/waves.lua",
				Register = engine.Register,
				names = {},
				groups = {},
			})
			for key, value in pairs(contribution.env) do
				assert(env[key] == nil, "two modules contribute the global " .. key)
				env[key] = value
			end
		end
	end
	return env, file
end

describe("cm8_ashfall wave pressure", function()
	local engine, triggers

	setup(function()
		ModuleHandler.ResetCaches()
		engine = TriggerEngine.New()
		local env, file = sandbox(engine)
		VFS.Include(TRIGGER_FILE, env)
		file.Finalize()
		triggers = engine.Triggers()
	end)

	it("loads through the composed sandbox — every verb and noun resolves", function()
		assert.are.equal(4, #triggers, "expected the four beats of the pressure arc")
	end)

	it("holds the opening beat back a minute", function()
		-- The director's grace period is about spawner placement; this is the
		-- mission's own beat, and only the trigger file can say how long the
		-- player gets to read the base before anything arrives.
		assert.are.equal(60 * 30, triggers[1].delayFrames)
		for i = 2, 4 do
			assert.are.equal(
				0,
				triggers[i].delayFrames or 0,
				"only the opening waits; the rest answer their objective at once"
			)
		end
	end)

	it("opens the pressure when the match starts, aimed at the player", function()
		local ctx = recordingContext()
		for _, effect in ipairs(triggers[1].effects) do
			effect.execute(ctx)
		end
		local request = ctx.calls[1][2]
		assert.are.equal("start", ctx.calls[1][1])
		assert.are.equal(PACK, request.pack)
		assert.are.equal("scavengers", request.module)
		assert.are.equal("skirmish", request.builder)
		assert.are.equal(0, request.against)
	end)

	it("brings it in from the northeast, as map fractions", function()
		local ctx = recordingContext()
		triggers[1].effects[1].execute(ctx)
		assert.are.same({ fx = 0.85, fz = 0.15 }, ctx.calls[1][2].origin)
	end)

	it("starts quiet: the first beat is background pressure, not a siege", function()
		local ctx = recordingContext()
		triggers[1].effects[1].execute(ctx)
		assert.are.equal(0.3, ctx.calls[1][2].intensity)
	end)

	it("climbs once, spikes once, then climbs again", function()
		local ctx = recordingContext()
		for i = 2, 3 do
			for _, effect in ipairs(triggers[i].effects) do
				effect.execute(ctx)
			end
		end
		assert.are.same({ "intensity", PACK, 0.6 }, ctx.calls[1])
		assert.are.same({ "surge", PACK }, ctx.calls[2])
		assert.are.same({ "intensity", PACK, 1.0 }, ctx.calls[3])
	end)

	it("ends the spawner when the commander dies, and says nothing about the field", function()
		local ctx = recordingContext()
		for _, effect in ipairs(triggers[4].effects) do
			effect.execute(ctx)
		end
		assert.are.same({ "stop", PACK }, ctx.calls[1])
		assert.are.equal(1, #ctx.calls, "ending the pressure must not also clear the map")
	end)

	it("watches the objectives it is paced by", function()
		for i = 2, 4 do
			assert.are.same({ "mission.objective_changed" }, triggers[i].condition.inputs)
		end
	end)

	it("names one pack throughout, so every dial reaches the same director", function()
		local ctx = recordingContext()
		for _, trigger in ipairs(triggers) do
			for _, effect in ipairs(trigger.effects) do
				effect.execute(ctx)
			end
		end
		for _, call in ipairs(ctx.calls) do
			local named = call[1] == "start" and call[2].pack or call[2]
			assert.are.equal(PACK, named)
		end
	end)
end)
