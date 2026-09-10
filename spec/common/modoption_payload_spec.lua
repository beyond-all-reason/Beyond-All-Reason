local ModoptionPayload = VFS.Include("common/luaUtilities/modoption_payload.lua")
local base64 = VFS.Include("common/luaUtilities/base64.lua")

local function encode(json, compress)
	return base64.Encode(compress and VFS.ZlibCompress(json) or json)
end

describe("modoption payload", function()
	it("decodes a compressed payload", function()
		local decoded = ModoptionPayload.Decode(encode([[{"disableFactionPicker":true}]], true))

		assert.is_table(decoded)
		assert.is_true(decoded.disableFactionPicker)
	end)

	it("decodes an uncompressed payload", function()
		local decoded = ModoptionPayload.Decode(encode([[{"disableFactionPicker":true}]], false))

		assert.is_table(decoded)
		assert.is_true(decoded.disableFactionPicker)
	end)

	it("keeps the casing of the keys inside the payload", function()
		local decoded = ModoptionPayload.Decode(encode([[{"disableInitialCommanderSpawn":true}]], true))

		assert.is_true(decoded.disableInitialCommanderSpawn)
		assert.is_nil(decoded.disableinitialcommanderspawn)
	end)

	it("returns nil for an absent or empty option", function()
		assert.is_nil(ModoptionPayload.Decode(nil))
		assert.is_nil(ModoptionPayload.Decode(""))
	end)

	it("returns nil rather than raising on a payload that is not base64 json", function()
		assert.is_nil(ModoptionPayload.Decode("not a payload"))
		assert.is_nil(ModoptionPayload.Decode(base64.Encode("not json")))
	end)

	it("returns nil for json that is not an object", function()
		assert.is_nil(ModoptionPayload.Decode(encode("42", true)))
	end)
end)
