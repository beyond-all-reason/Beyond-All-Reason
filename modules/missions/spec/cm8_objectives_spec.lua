--- The shipped board stays loadable and keeps the story's shape, through
--- the same sandbox the loader builds. Wording is asserted verbatim: the
--- titles are what the player reads.

local Objectives = VFS.Include("modules/missions/lib/objectives.lua")

local function condition()
	return {
		evaluate = function()
			return false
		end,
	}
end

describe("cm8_ashfall objectives", function()
	local decls
	local byId = {}

	setup(function()
		local file = Objectives.ForFile("cm8_ashfall/objectives.lua")
		VFS.Include("modules/missions/cm8_ashfall/objectives.lua", {
			Objective = file.Objective,
			UnitDef = function(name)
				return { name = name }
			end,
			Unit = function()
				return {
					IsSpotted = function()
						return condition()
					end,
					IsDestroyed = function()
						return condition()
					end,
				}
			end,
			Team = { Player = {
				Has = function()
					return condition()
				end,
			} },
			MatchFlow = {
				Started = function()
					return condition()
				end,
			},
		})
		decls = file.Finalize()
		for _, decl in ipairs(decls) do
			byId[decl.id] = decl
		end
	end)

	it("the board tells the story in order", function()
		local ids = {}
		for order, decl in ipairs(decls) do
			ids[order] = decl.id
		end
		assert.are.same({
			"protect_the_commander",
			"relieve_the_outpost",
			"find_the_enclave",
			"find_the_tenebrium_device",
			"kill_the_commander",
		}, ids)
	end)

	it("speaks to the player, not in ids", function()
		assert.are.equal("Relieve the outpost", byId.relieve_the_outpost.title)
		assert.are.equal("Find the Enclave", byId.find_the_enclave.title)
		assert.are.equal("Find the Tenebrium device", byId.find_the_tenebrium_device.title)
		assert.are.equal("Kill the enemy commander", byId.kill_the_commander.title)
		assert.are.equal("Protect your Commander", byId.protect_the_commander.title)
	end)

	it("the discoveries are gated on the story, the snipe is not", function()
		-- Each discovery disjunct carries the beat's own condition plus the
		-- predecessor gate. The commander is the exception on purpose — an
		-- early kill counts.
		assert.are.equal(1, #byId.relieve_the_outpost.completions)
		assert.are.equal(2, #byId.relieve_the_outpost.completions[1])
		assert.are.equal(1, #byId.kill_the_commander.completions)
		assert.are.equal(1, #byId.kill_the_commander.completions[1])
	end)

	it("a discovery destroyed unspotted still counts — both ways, both gated", function()
		-- A radar-dot bombardment never enters LOS; without the second
		-- disjunct the chain dams on a dead, unseen beacon.
		for _, id in ipairs({ "find_the_enclave", "find_the_tenebrium_device" }) do
			assert.are.equal(2, #byId[id].completions, id)
			assert.are.equal(2, #byId[id].completions[1], id)
			assert.are.equal(2, #byId[id].completions[2], id)
		end
	end)

	it("the standing objective holds the board without damming the cadence", function()
		-- It never completes, so it must not be anyone's cadence
		-- predecessor; it opens with the mission via its own moment.
		assert.are.equal("protect_the_commander", decls[1].id)
		assert.are.equal(0, #byId.protect_the_commander.completions)
		assert.is_not_nil(byId.protect_the_commander.revealedWhen)
	end)

	it("the default cadence carries the story lines", function()
		for _, decl in ipairs(decls) do
			if decl.id ~= "protect_the_commander" then
				assert.is_nil(decl.revealedWhen)
			end
			assert.is_false(decl.foreshadow)
		end
	end)
end)
