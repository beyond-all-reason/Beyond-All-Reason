-- The field draws through gl and FlowUI, which the game provides and the specs do not.
rawset(_G, "utf8", rawget(_G, "utf8") or { len = string.len, sub = string.sub })
Spring.GetTimer = Spring.GetTimer or function() end
Spring.DiffTimers = Spring.DiffTimers or function()
	return 0
end
Spring.GetMouseState = Spring.GetMouseState or function()
	return -1, -1, false
end
Spring.GetModKeyState = Spring.GetModKeyState or function()
	return false, false, false, false
end

local ignore = {
	__index = function()
		return function() end
	end,
}
local clips = {}
rawset(
	_G,
	"gl",
	setmetatable({
		Scissor = function(...)
			clips[#clips + 1] = { ... }
		end,
	}, ignore)
)
rawset(_G, "WG", {
	fonts = {
		getFont = function()
			-- Every character half the font size wide, so widths are easy to reason about.
			return setmetatable({
				GetTextWidth = function(_, s)
					return #s * 0.5
				end,
				GetTextHeight = function()
					return 0.5
				end,
			}, ignore)
		end,
	},
	FlowUI = { elementCorner = 4, Draw = setmetatable({}, ignore) },
})

local Editbox = require("luaui/Include/keybind_editbox")

describe("a text field narrower than its text", function()
	local long = string.rep("select_", 30)
	local charW = 7
	local room = 400 - 6 * 2

	local function field()
		local box = Editbox.new({ maxChars = 255 })
		box:setRect(0, 0, 400, 26, 14, 6)
		box:setText(long)
		box:focus()

		return box
	end

	it("scrolls to keep the caret in view", function()
		local box = field()
		box:setCaret(#long)
		box:draw()

		assert.are.equal(#long * charW - room, box.scrollPx)
	end)

	it("draws its text inside the field only", function()
		clips = {}
		field():draw()

		assert.are.same({ 6, 0, room, 26 }, clips[1])
	end)

	it("puts a click where the scrolled text is drawn", function()
		local box = field()
		box:setCaret(#long)
		box:draw()

		assert.are.equal(#long, box:indexFromX(400 - 6))
	end)

	it("shows where the text starts once it is not being typed in", function()
		local box = field()
		box:setCaret(#long)
		box:draw()
		box:blur()
		box:draw()

		assert.are.equal(0, box.scrollPx)
	end)
end)
