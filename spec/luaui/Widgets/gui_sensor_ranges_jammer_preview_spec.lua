local SpringUnsyncedBuilder = VFS.Include("spec/builders/spring_unsynced_builder.lua")

local WIDGET_PATH = "luaui/Widgets/gui_sensor_ranges_jammer_preview.lua"

describe("luaui.Widgets.gui_sensor_ranges_jammer_preview", function()
	it("shuts down without error after Initialize removed it before any shader existed", function()
		local loaded = SpringUnsyncedBuilder.new()
			:WithSpringFn("GetConfigString", function() end)
			:WithSpringFn("GetConfigInt", function() end)
			:WithSpringFn("GetGaiaTeamID", function() end)
			:LoadWidget(WIDGET_PATH)
		assert.has_no.errors(function()
			loaded.env.widget:Shutdown()
		end)
	end)
end)
