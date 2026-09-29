local SpecEnv = VFS.Include("spec/support/spec_env.lua")

local PROBE = "spec/fixtures/env_probe.lua"

describe("SpecEnv", function()
	it("gives the code under test the globals it was built with", function()
		local env = SpecEnv.new({ marker = "outer" })

		assert.are.equal("outer", SpecEnv.include(env, PROBE).marker)
	end)

	it("passes the same env to nested includes", function()
		local env = SpecEnv.new({ marker = "outer" })

		assert.are.equal("outer", SpecEnv.include(env, PROBE).nestedMarker)
	end)

	it("keeps what the code under test writes out of _G", function()
		SpecEnv.include(SpecEnv.new({ marker = "outer" }), PROBE)

		assert.is_nil(rawget(_G, "writtenByFixture"))
		assert.is_nil(rawget(_G, "marker"))
	end)

	it("does not let two envs see each other", function()
		local first = SpecEnv.new({ marker = "first" })
		local second = SpecEnv.new({ marker = "second" })

		SpecEnv.include(first, PROBE)

		assert.are.equal("second", SpecEnv.include(second, PROBE).marker)
	end)

	it("falls through to the real engine table for what it does not override", function()
		local env = SpecEnv.new({ Spring = { marker = "mine" } })
		local probed = SpecEnv.include(env, PROBE)

		assert.are.equal("mine", probed.springMarker)
		assert.are.equal(Spring.Echo, probed.springEcho)
	end)

	it("keeps a write to its engine table off the shared one", function()
		local env = SpecEnv.new()
		env.Spring.GetSomethingNobodyDefined = function() end

		assert.is_nil(Spring.GetSomethingNobodyDefined)
	end)

	it("serves an overridden include instead of the file", function()
		local env = SpecEnv.new({ includes = { [PROBE] = { marker = "stubbed" } } })

		assert.are.equal("stubbed", SpecEnv.include(env, PROBE).marker)
	end)

	it("serves a stubbed include to require when the file is not on disk", function()
		local env = SpecEnv.new({ includes = { ["spec/fixtures/not_on_disk.lua"] = { marker = "stubbed" } } })

		assert.are.equal("stubbed", SpecEnv.include(env, "spec/fixtures/env_probe_require.lua").marker)
	end)

	it("falls back on the VFS.Include it was given", function()
		local env = SpecEnv.new({
			VFS = {
				Include = function()
					return { marker = "given" }
				end,
			},
		})

		assert.are.equal("given", SpecEnv.include(env, PROBE).marker)
	end)

	it("leaves the tables it was given alone", function()
		local vfs = {}
		local first = SpecEnv.new({ VFS = vfs, marker = "first" })
		SpecEnv.new({ VFS = vfs, marker = "second" })

		assert.is_nil(next(vfs))
		assert.is_nil(getmetatable(vfs))
		assert.are.equal("first", SpecEnv.include(first, PROBE).marker)
	end)

	it("iterates the real engine table along with what it overrides", function()
		local env = SpecEnv.new({ Spring = { marker = "mine" } })
		local seen = {}
		for key in pairs(env.Spring) do
			seen[key] = true
		end

		assert.is_true(seen.marker)
		assert.is_true(seen.Echo)
	end)
end)
