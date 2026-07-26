local ModuleHandler = VFS.Include("modules/module_handler.lua")

describe("module manifests", function()
	local manifests

	setup(function()
		ModuleHandler.ResetCaches()
		manifests = ModuleHandler.Discover()
	end)

	it("skips directories that ship no manifest", function()
		-- modules/ predates the module format and still holds loose files and
		-- unmarked directories; only a module.lua marker makes one a module.
		assert.is_nil(manifests.graphics)
		assert.is_nil(manifests.i18n)
	end)

	it("every declared requirement resolves to a discovered module", function()
		for name, manifest in pairs(manifests) do
			for _, required in ipairs(manifest.requires or {}) do
				assert.is_table(manifests[required], name .. " requires missing module " .. required)
			end
		end
	end)
end)
