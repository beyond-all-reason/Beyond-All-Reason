local SpringUnsyncedBuilder = VFS.Include("spec/builders/spring_unsynced_builder.lua")

local WIDGET_PATH = "luaui/Widgets/camera_shake.lua"

describe("luaui.Widgets.camera_shake", function()
	local offsetCalls ---@type integer

	local function loadWidget(scriptedShake)
		local loaded = SpringUnsyncedBuilder.new()
			:WithSpringFn("SetShockFrontFactors", function() end)
			:WithSpringFn("SetCameraOffset", function()
				offsetCalls = offsetCalls + 1
			end)
			:LoadWidget(WIDGET_PATH)
		loaded.env.widgetHandler.GetHourTimer = function()
			return 0
		end
		if scriptedShake ~= nil then
			loaded.WG.cinematicCamera = {
				IsShaking = function()
					return scriptedShake
				end,
			}
		end
		return loaded
	end

	before_each(function()
		offsetCalls = 0
	end)

	it("writes the camera offset every update", function()
		local loaded = loadWidget()
		loaded.env.widget:Update(0.016)
		assert.are.equal(1, offsetCalls)
	end)

	it("leaves the offset to a scripted shake while one plays", function()
		local loaded = loadWidget(true)
		loaded.env.widget:Update(0.016)
		assert.are.equal(0, offsetCalls)
	end)

	it("writes again once the scripted shake is over", function()
		local loaded = loadWidget(false)
		loaded.env.widget:Update(0.016)
		assert.are.equal(1, offsetCalls)
	end)
end)
