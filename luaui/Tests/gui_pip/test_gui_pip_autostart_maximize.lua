local widgetName = "Picture-in-Picture"
local originalGetSpectatingState = nil

function skip()
	return SpringShared.GetGameFrame() <= 0 or widgetHandler.knownWidgets[widgetName] == nil
end

function setup()
	Test.clearMap()
	originalGetSpectatingState = SpringUnsynced.GetSpectatingState
	SpringUnsynced.GetSpectatingState = function()
		return false, false
	end
	widget = Test.prepareWidget(widgetName)
	assert(widget)
end

function cleanup()
	if originalGetSpectatingState ~= nil then
		SpringUnsynced.GetSpectatingState = originalGetSpectatingState
		originalGetSpectatingState = nil
	end
	Test.clearMap()
end

function test()
	local vsx, vsy = SpringUnsynced.GetViewGeometry()
	local uiScale = tonumber(SpringUnsynced.GetConfigFloat("ui_scale", 1) or 1)
	local widgetScale = (vsy / 2000) * uiScale
	local minExpandedSize = math.floor(125 * widgetScale)

	-- Recreate the regression state: pregame-minimized with no saved expanded dimensions.
	widget:SetConfigData({
		inMinMode = true,
	})
	widget:ViewResize(vsx, vsy)
	widget:GameStart()
	widget:Update(0.25)

	local data = widget:GetConfigData()
	assert(data)
	assert(data.inMinMode == false, "PIP should exit minimized mode on GameStart auto-maximize")

	local expandedWidth = (data.pr - data.pl) * vsx
	local expandedHeight = (data.pt - data.pb) * vsy
	assert(expandedWidth >= minExpandedSize, string.format("expandedWidth too small: %.2f < %d", expandedWidth, minExpandedSize))
	assert(expandedHeight >= minExpandedSize, string.format("expandedHeight too small: %.2f < %d", expandedHeight, minExpandedSize))
end
