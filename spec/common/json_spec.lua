-- Escape handling in common/luaUtilities/json.lua.
--
-- Strings are unescaped by handing the literal to loadstring, so any escape Lua 5.1
-- rejects used to fail the whole decode rather than the one string. Long strings below
-- keep backslashes literal, so the JSON really does carry escapes.

local Json = VFS.Include("common/luaUtilities/json.lua")

local function value(text)
	return Json.decode(text).a
end

describe("json string escapes", function()
	describe("escapes Lua rejects", function()
		it("decodes \\uXXXX below 0x80", function()
			assert.are.equal("x&y", value([[{"a":"x\u0026y"}]]))
			assert.are.equal("it's", value([[{"a":"it\u0027s"}]]))
			assert.are.equal("<tag>", value([[{"a":"\u003ctag\u003e"}]]))
		end)

		it("decodes an escaped forward slash", function()
			assert.are.equal("a/b", value([[{"a":"a\/b"}]]))
		end)
	end)

	describe("multi-byte code points", function()
		it("encodes two- and three-byte code points as UTF-8", function()
			assert.are.equal("\195\169", value([[{"a":"\u00e9"}]]))
			assert.are.equal("\226\130\172", value([[{"a":"\u20ac"}]]))
		end)

		it("combines a surrogate pair into one 4-byte code point", function()
			assert.are.equal("\240\159\152\128", value([[{"a":"\ud83d\ude00"}]]))
		end)

		it("does not swallow a digit that follows the escape", function()
			assert.are.equal("\195\1691", value([[{"a":"\u00e91"}]]))
		end)
	end)

	describe("escapes that already worked", function()
		it("keeps handling the ones Lua shares with JSON", function()
			assert.are.equal("line\nbreak", value([[{"a":"line\nbreak"}]]))
			assert.are.equal("tab\there", value([[{"a":"tab\there"}]]))
			assert.are.equal('quote"inside', value([[{"a":"quote\"inside"}]]))
			assert.are.equal("back\\slash", value([[{"a":"back\\slash"}]]))
		end)
	end)

	describe("an escaped backslash", function()
		it("does not let the next character start an escape", function()
			-- the characters a \ u 0 0 4 1 b, not an escaped code point
			assert.are.equal("a\\u0041b", value([[{"a":"a\\u0041b"}]]))
			assert.are.equal("a\\/b", value([[{"a":"a\\/b"}]]))
		end)
	end)

	describe("a shipped file that carries these escapes", function()
		it("decodes interface.json with the escaped characters intact", function()
			local path = "language/en/interface.json"
			local f = assert(io.open(path, "r"), "cannot open " .. path)
			local body = f:read("*a")
			f:close()

			local decoded = Json.decode(body)
			assert.is_table(decoded, path .. " failed to decode")
			-- Asserting the value, not just that it parsed: an interpreter that treats an
			-- unknown escape as the bare character decodes happily but corrupts the string.
			assert.are.equal(true,
				decoded.cmd.set.AutoAddBuiltUnitsToFactoryGroup:find("factory's", 1, true) ~= nil)
		end)
	end)
end)
