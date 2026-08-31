local ModuleHandler = VFS.Include("modules/module_handler.lua")

describe("module manifests", function()
	local manifests

	setup(function()
		ModuleHandler.ResetCaches()
		manifests = ModuleHandler.Discover()
	end)

	it("skips directories that ship no manifest", function()
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
