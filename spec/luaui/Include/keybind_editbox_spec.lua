local SpecEnv = VFS.Include("spec/support/spec_env.lua")

local ignore = {
	__index = function()
		return function() end
	end,
}
local clips = {}

-- gl and FlowUI are unavailable to specs.
local env = SpecEnv.new({
	Spring = {
		GetTimer = function() end,
		DiffTimers = function()
			return 0
		end,
		GetMouseState = function()
			return -1, -1, false
		end,
		GetModKeyState = function()
			return false, false, false, false
		end,
	},
	gl = setmetatable({
		Scissor = function(...)
			clips[#clips + 1] = { ... }
		end,
	}, ignore),
	WG = {
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
	},
})

local Editbox = SpecEnv.include(env, "luaui/Include/keybind_editbox.lua")

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
