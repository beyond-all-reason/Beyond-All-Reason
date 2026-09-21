local base64 = VFS.Include("common/luaUtilities/base64.lua")

--- Rewrites base64url output into the standard alphabet, standing in for a producer that
--- encodes with plain base64.
local function toStandardAlphabet(text)
	return (text:gsub("[-_]", { ["-"] = "+", ["_"] = "/" }))
end

local function pad(text)
	return text .. string.rep("=", (4 - #text % 4) % 4)
end

--- Captures Spring.Log output for the duration of fn.
local function captureLogs(fn)
	local originalLog = Spring.Log
	local messages = {}

	Spring.Log = function(tag, level, message)
		messages[#messages + 1] = { tag = tag, level = level, message = message }
	end

	local ok, err = pcall(fn)

	Spring.Log = originalLog

	if not ok then
		error(err, 0)
	end

	return messages
end

describe("base64", function()
	it("round trips its own output", function()
		local text = [[{"missionFolder":"missions/campaigns/tutorial","difficulty":"Normal"}]]

		assert.are.equal(text, base64.Decode(base64.Encode(text)))
	end)

	it("round trips every byte value", function()
		local bytes = {}
		for byte = 0, 255 do
			bytes[#bytes + 1] = string.char(byte)
		end
		local text = table.concat(bytes)

		assert.are.equal(text, base64.Decode(base64.Encode(text)))
	end)

	it("round trips at every length, covering each padding case", function()
		for length = 0, 24 do
			local text = string.rep("x", length)

			assert.are.equal(text, base64.Decode(base64.Encode(text)))
		end
	end)

	describe("alphabet", function()
		-- In otherwise ascii json, '>' and '?' are the only bytes that can produce a
		-- '+' or '/' sextet, which is why this stayed hidden for so long.
		local text = [[{"missionFolder":"a>>b","difficulty":"c??d"}]]

		it("decodes the standard alphabet as well as the url alphabet", function()
			local standard = toStandardAlphabet(base64.Encode(text))
			assert.is_truthy(standard:find("[+/]"), "fixture should exercise the standard alphabet")

			assert.are.equal(text, base64.Decode(standard))
		end)

		it("does not warn about either alphabet", function()
			local messages = captureLogs(function()
				base64.Decode(base64.Encode(text))
				base64.Decode(toStandardAlphabet(base64.Encode(text)))
			end)

			assert.are.equal(0, #messages)
		end)

		it("accepts padded and unpadded input alike", function()
			local encoded = base64.Encode(text)
			local unpadded = encoded:gsub("=+$", "")

			assert.are.equal(text, base64.Decode(pad(unpadded)))
			assert.are.equal(text, base64.Decode(unpadded))
		end)

		it("does not warn about padding", function()
			local messages = captureLogs(function()
				base64.Decode(pad(base64.Encode("xyz")))
			end)

			assert.are.equal(0, #messages)
		end)
	end)

	describe("unexpected characters", function()
		it("warns that the result is truncated", function()
			local messages = captureLogs(function()
				base64.Decode("abc!def")
			end)

			assert.are.equal(1, #messages)
			assert.are.equal("base64", messages[1].tag)
			assert.are.equal(LOG.WARNING, messages[1].level)
			assert.is_truthy(messages[1].message:find("unexpected character"))
		end)

		it("names each offending character once", function()
			local messages = captureLogs(function()
				base64.Decode("abc!def!ghi#")
			end)

			assert.are.equal(1, #messages)
			assert.is_truthy(messages[1].message:find("2 unexpected", 1, true))
			assert.is_truthy(messages[1].message:find("!", 1, true))
			assert.is_truthy(messages[1].message:find("#", 1, true))
		end)

		-- Decoding is left as it was: it drops what it cannot read, and raises only where
		-- the original arithmetic already did. The warning is what makes either visible.
		it("still returns a truncated result rather than rejecting the input", function()
			local decoded
			local messages = captureLogs(function()
				decoded = base64.Decode("abc!def")
			end)

			assert.is_string(decoded)
			assert.are.equal(1, #messages)
		end)

		it("warns before raising on input it cannot decode at all", function()
			local messages = captureLogs(function()
				pcall(base64.Decode, "not a payload")
			end)

			assert.are.equal(1, #messages)
			assert.is_truthy(messages[1].message:find("unexpected character"))
		end)
	end)
end)
