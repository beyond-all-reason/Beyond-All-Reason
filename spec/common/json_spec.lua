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

	describe("a code point that decodes to a character Lua source cares about", function()
		-- These are the ones that could break the loadstring approach: a quote or backslash
		-- arriving inside the literal would end or re-escape it. They survive because the
		-- rewrite emits three-digit decimal escapes rather than the characters themselves.
		it("keeps quotes, backslashes and control characters intact", function()
			assert.are.equal(string.char(34), value([[{"a":"\u0022"}]]))
			assert.are.equal(string.char(92), value([[{"a":"\u005C"}]]))
			assert.are.equal(string.char(10), value([[{"a":"\u000A"}]]))
			assert.are.equal(string.char(0), value([[{"a":"\u0000"}]]))
			assert.are.equal("x" .. string.char(34) .. "y", value([[{"a":"x\u0022y"}]]))
		end)

		it("does not let a decoded backslash start an escape of its own", function()
			assert.are.equal("x" .. string.char(92) .. "u0041", value([[{"a":"x\u005Cu0041"}]]))
		end)
	end)

	describe("a surrogate with no partner", function()
		-- Half a pair is not a code point. Encoding it produces bytes no UTF-8 reader accepts,
		-- and that travels on into fonts and text layout, so it is dropped instead. The pair it
		-- was meant to be half of still decodes normally.
		it("is dropped rather than encoded", function()
			assert.are.equal("", value([[{"a":"\ud83d"}]]))
			assert.are.equal("", value([[{"a":"\udc00"}]]))
			assert.are.equal("xy", value([[{"a":"x\ud83dy"}]]))
			assert.are.equal("A", value([[{"a":"\ud83dA"}]]))
		end)

		it("still decodes a complete pair", function()
			assert.are.equal("\240\159\152\128", value([[{"a":"\ud83d\ude00"}]]))
		end)
	end)

	describe("a malformed code point escape", function()
		-- Four hex digits is the only legal form. Anything shorter or non-hex either loses
		-- characters or pushes the rest of the literal out of step, so it has to be caught
		-- where it is parsed rather than surfacing as a loadstring failure later.
		it("is rejected rather than silently dropped", function()
			assert.has_error(function() Json.decode([[{"a":"\u47"}]]) end)
			assert.has_error(function() Json.decode([[{"a":"\uZZZZ"}]]) end)
			assert.has_error(function() Json.decode([[{"a":"\u"}]]) end)
			assert.has_error(function() Json.decode([[{"a":"x\u47y"}]]) end)
		end)

		it("names the escape it choked on", function()
			local ok, err = pcall(Json.decode, [[{"a":"\uZZZZ"}]])
			assert.is_false(ok)
			assert.is_truthy(tostring(err):find("\uZZZZ", 1, true))
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
