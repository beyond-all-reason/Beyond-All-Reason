--- A module that declares mission vocabulary in its types without shipping the runtime
--- produces a mission that validates cleanly and dies on arming; nothing else checks the two agree.

local ModuleHandler = VFS.Include("modules/module_handler.lua")

describe("mission DSL contributions", function()
	local manifests

	setup(function()
		ModuleHandler.ResetCaches()
		manifests = ModuleHandler.Discover()
	end)

	it("every module missions draws vocabulary from declares that vocabulary", function()
		for _, name in ipairs(manifests.missions.requires) do
			if VFS.FileExists("modules/" .. name .. "/mission_dsl.lua") then
				assert.is_true(
					VFS.FileExists("modules/" .. name .. "/types/dsl.lua")
						or VFS.FileExists("modules/" .. name .. "/types/actions.lua"),
					name
						.. " contributes to the mission sandbox but publishes neither"
						.. " types/dsl.lua nor types/actions.lua"
				)
			end
		end
	end)

	it("every module that declares mission vocabulary also injects it", function()
		for _, name in ipairs(manifests.missions.requires) do
			if
				VFS.FileExists("modules/" .. name .. "/types/dsl.lua")
				or VFS.FileExists("modules/" .. name .. "/types/actions.lua")
			then
				assert.is_true(
					VFS.FileExists("modules/" .. name .. "/mission_dsl.lua"),
					name
						.. " declares mission vocabulary in types/dsl.lua but ships no mission_dsl.lua,"
						.. " so the loader injects nothing and a trigger using it fails at arm time"
				)
			end
		end
	end)

	it("each contribution returns a per-file factory", function()
		for _, name in ipairs(manifests.missions.requires) do
			local path = "modules/" .. name .. "/mission_dsl.lua"
			if VFS.FileExists(path) then
				local contribution = VFS.Include(path)
				assert.is_table(contribution, path .. " must return a table")
				assert.is_function(contribution.ForFile, path .. " must return a ForFile factory")
			end
		end
	end)

	it("a contribution's context is functions over the runtime, and its events are its own", function()
		local runtime = {
			UnitOf = function() end,
			GroupUnits = function() end,
			ReleaseHoldFire = function() end,
			Protections = { Get = function() end, Set = function() end },
			Log = function() end,
		}
		for _, name in ipairs(manifests.missions.requires) do
			local path = "modules/" .. name .. "/mission_dsl.lua"
			if VFS.FileExists(path) then
				local contribution = VFS.Include(path)
				if contribution.Context ~= nil then
					for key, fn in pairs(contribution.Context(runtime)) do
						assert.is_function(fn, path .. " Context." .. tostring(key) .. " must be a function")
					end
				end
				for key, event in pairs(contribution.Events or {}) do
					assert.is_string(event, path .. " Events." .. tostring(key) .. " must be an event name")
					assert.are.equal(
						name .. ".",
						event:sub(1, #name + 1),
						path .. " raises " .. event .. " under another module's name"
					)
				end
			end
		end
	end)
end)
