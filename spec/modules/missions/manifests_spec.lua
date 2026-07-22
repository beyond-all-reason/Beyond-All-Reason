local ModuleHandler = VFS.Include("modules/module_handler.lua")

describe("mission module manifests", function()
	local manifests

	setup(function()
		ModuleHandler.ResetCaches()
		manifests = ModuleHandler.Discover()
	end)

	it("discovers missions and matchflow", function()
		assert.is_table(manifests.missions)
		assert.is_table(manifests.matchflow)
	end)

	it("missions declares its matchflow dependency", function()
		assert.are.same({ "matchflow" }, manifests.missions.requires)
	end)

	it("every declared requirement resolves to a discovered module", function()
		for name, manifest in pairs(manifests) do
			for _, required in ipairs(manifest.requires or {}) do
				assert.is_table(manifests[required],
					name .. " requires missing module " .. required)
			end
		end
	end)
end)
