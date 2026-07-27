--- The sandbox a trigger file runs in is composed from the modules the
--- missions manifest requires: each contributes a mission_dsl.lua returning a
--- per-file factory. Its types/dsl.lua is the published half of the same
--- contract, and the two can drift apart in a way no other check sees — the
--- authoring tools read the types, the game injects the runtime, and a module
--- that declares vocabulary without shipping it produces a mission that
--- validates cleanly and dies on arming.

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
end)
