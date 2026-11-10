local SpecEnv = VFS.Include("spec/support/spec_env.lua")

local env = SpecEnv.new({
	gl = {},
})

local ChatEmoji = SpecEnv.include(env, "luaui/Include/chat_emoji.lua")

local RED = "\255\255\001\001"
local GREEN = "\255\001\255\001"
local WIDE_E = "\195\169" -- two bytes, one character
local FIRE = "\240\159\148\165" -- a unicode emoji

-- Every character is one wide; color codes take no room, as in the engine's font.
local font = {
	GetTextWidth = function(_, text)
		local _, count = text:gsub("\255...", ""):gsub("\8", ""):gsub("[%z\1-\127\194-\244][\128-\191]*", "")
		return count
	end,
}

local function wrapPlain(line, maxWidth, indent)
	return ChatEmoji.WordWrapPlain({ line }, maxWidth, font, 1, indent)
end

local function wrapRich(line, maxWidth, indent)
	return ChatEmoji.WordWrapRichText({ line }, maxWidth, 1, font, indent)
end

describe("ChatEmoji word wrap", function()
	it("leaves lines that fit as they are", function()
		assert.same({ "short line" }, wrapPlain("short line", 20))
		assert.same({ "short line" }, wrapRich("short line", 20))
	end)

	it("still breaks at spaces first", function()
		assert.same({ "aaaa bbbb", "cccc" }, wrapPlain("aaaa bbbb cccc", 10))
	end)

	it("cuts a word wider than the line after its last character that fits", function()
		assert.same({ "aaaaaaaaaa", "aaaaaaaaaa", "aaaaa" }, wrapPlain(string.rep("a", 25), 10))
	end)

	it("puts a long word on its own lines, after the words before it", function()
		assert.same({ "cs=", "1234567890", "12345" }, wrapPlain("cs= 123456789012345", 10))
	end)

	it("leaves less room on the first line when it is indented", function()
		assert.same({ "aaaaaa", "aaaaaaaaaa", "aaaa" }, wrapPlain(string.rep("a", 20), 10, 4))
	end)

	it("keeps a multi-byte character whole", function()
		local lines = wrapPlain(string.rep(WIDE_E, 15), 10)
		assert.same({ string.rep(WIDE_E, 10), string.rep(WIDE_E, 5) }, lines)
	end)

	it("keeps a color code whole, with no width of its own", function()
		local lines = wrapPlain(RED .. string.rep("a", 15), 10)
		assert.same({ RED .. string.rep("a", 10), RED .. string.rep("a", 5) }, lines)
	end)

	it("continues a part in the color its text had reached", function()
		local lines = wrapPlain(RED .. string.rep("a", 8) .. GREEN .. string.rep("b", 8), 10)
		assert.same({ RED .. "aaaaaaaa" .. GREEN .. "bb", GREEN .. "bbbbbb" }, lines)
	end)

	it("goes back to no color after a color reset", function()
		local lines = wrapPlain(RED .. "aaaa\8" .. string.rep("b", 12), 10)
		assert.same({ RED .. "aaaa\8bbbbbb", "bbbbbb" }, lines)
	end)

	it("always takes a character, however narrow the line", function()
		assert.same({ "a", "a", "a" }, wrapPlain("aaa", 0.5))
	end)

	it("keeps a line break between the lines given", function()
		local lines = ChatEmoji.WordWrapPlain({ "aaaa", string.rep("b", 12) }, 10, font, 1)
		assert.same({ "aaaa", "bbbbbbbbbb", "bb" }, lines)
	end)

	describe("with emoji", function()
		it("keeps an alias whole and measures it as its picture", function()
			-- at font size 1 an emoji takes 16: its least size of 12 and 2 of padding on either side
			local lines = wrapRich(string.rep("a", 18) .. ":smile:" .. string.rep("b", 18), 20)
			assert.same({ string.rep("a", 18), ":smile:bbbb", string.rep("b", 14) }, lines)
		end)

		it("keeps a unicode emoji whole", function()
			local lines = wrapRich(string.rep("a", 18) .. FIRE .. string.rep("b", 4), 20)
			assert.same({ string.rep("a", 18), FIRE .. "bbbb" }, lines)
		end)

		it("cuts inside text that only looks like an alias", function()
			local lines = wrapRich(":notanemoji:" .. string.rep("c", 12), 10)
			assert.same({ ":notanemoj", "i:cccccccc", "cccc" }, lines)
		end)

		it("leaves a line of words with an emoji as the word wrap made it", function()
			assert.same({ "aa :smile: bb" }, wrapRich("aa :smile: bb", 40))
		end)
	end)
end)
