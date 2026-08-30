describe("EngineTextureAtlas", function()
	local EngineTextureAtlas
	local textureCalls

	before_each(function()
		textureCalls = {}
		_G.gl = {
			GetEngineAtlasInfo = function(name)
				assert.equals("$atlas:test", name)
				return { width = 64, height = 32, pages = 1, mipLevels = 6 }
			end,
			GetEngineAtlasTexturesV2 = function(name)
				assert.equals("$atlas:test", name)
				return { ["images/a.png"] = { 0.1, 0.2, 0.3, 0.4, 0, 8, 4 } }
			end,
			Texture = function(unit, reference)
				textureCalls[#textureCalls + 1] = { unit, reference }
			end,
		}
		EngineTextureAtlas = dofile("LuaUI/Include/EngineTextureAtlas.lua")
	end)

	after_each(function()
		_G.gl = nil
	end)

	it("caches atlas metadata and resolves case-insensitive entries", function()
		local atlas = EngineTextureAtlas.Get("TEST")
		assert.is_true(atlas == EngineTextureAtlas.Get("$atlas:test"))
		assert.same({ 0.1, 0.2, 0.3, 0.4, 0, 8, 4 }, { atlas:Get("Images/A.PNG") })
	end)

	it("binds the registry texture reference", function()
		EngineTextureAtlas.Get("test"):Bind(3)
		assert.same({ { 3, "$atlas:test" } }, textureCalls)
	end)

	it("reports missing entries as content errors", function()
		assert.has_error(function()
			EngineTextureAtlas.Get("test"):Get("missing")
		end, "engine texture atlas 'test' has no entry 'missing'")
	end)
end)
