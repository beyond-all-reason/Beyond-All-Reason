local widget = widget ---@type Widget

function widget:GetInfo()
    return {
        name    = "Analytics - Widgets",
        desc    = "Report widget usage to Analytics API",
        author  = "uBdead",
        date    = "Oct 2025",
        license = "GPL-v2",
        layer   = 0,
        enabled = true,
        handler = true,
    }
end

-- and it will filter out inconsequential matches
local REPORT_DELAY_FRAMES = 30
local MAX_WIDGETS_PER_REPORT = 50
local HASH_PER_FRAME = 1
local EXCLUDE_ZIP = true

local initialized = false
local widgets = {}
local currentWidgetIndex = 1

-- from gui_options.lua by WatchTheFort
local function GetWidgetToggleValue(widgetname)
	if widgetHandler.orderList[widgetname] == nil or widgetHandler.orderList[widgetname] == 0 then
		return false
	elseif widgetHandler.orderList[widgetname] >= 1
		and widgetHandler.knownWidgets ~= nil
		and widgetHandler.knownWidgets[widgetname] ~= nil then
		if widgetHandler.knownWidgets[widgetname].active then
			return true
		else
			return 0.5
		end
	end
end

local function processWidget(widget)
    -- I know this is redundant as we literally just defined these values ourselves, 
    -- but i want to keep the GetWidgetToggleValue the same as the original
    local state = GetWidgetToggleValue(widget.name)
    if state == false then   
        widget.state = 0 
    elseif state == 0.5 then
        widget.state = -1
    else
        widget.state = 1
    end

    if widget.filename then
        local file = io.open(widget.filename, "r")
        if file then
            local content = file:read("*a")
            file:close()

            widget.hash = VFS.CalculateHash(content, 0) --MD5 (no security needed here)
        end
        widget.filename = nil -- not important anymore
    end
end

function widget:GameFrame(frame)
    if not WG.Analytics then
        widgetHandler:RemoveWidget(self)
        return
    end

    if frame < REPORT_DELAY_FRAMES then
        return
    end

    if not initialized then
        initialized = true
        for name, data in pairs(widgetHandler.knownWidgets) do
            if not (EXCLUDE_ZIP and data.fromZip) then
                local description = data.desc
                if description and #description > 100 then
                    description = string.sub(description, 1, 100) .. "..."
                end
                widgets[#widgets + 1] = {
                    name = name,
                    author = data.author,
                    desc = description,
                    filename = data.filename, -- to be processed later and stripped out
                }
            end
        end
    end

    local hashesThisFrame = 0
    while currentWidgetIndex <= #widgets and hashesThisFrame < HASH_PER_FRAME do
        local w = widgets[currentWidgetIndex]

        processWidget(w)

        hashesThisFrame = hashesThisFrame + 1
        currentWidgetIndex = currentWidgetIndex + 1
    end

    if currentWidgetIndex > #widgets then
        -- Build truncated report
        local widgetList = {}
        local truncated = false
        for i, w in ipairs(widgets) do
            if i > MAX_WIDGETS_PER_REPORT then
                truncated = true
                break
            end
            widgetList[#widgetList + 1] = {
                name = w.name,
                author = w.author or "unknown",
                hash = w.hash or "nil",
                state = w.state,
                desc = w.desc,
            }
        end

        local customWidgetReport = {}
        customWidgetReport.widgetCount = #widgetList
        customWidgetReport.widgets = widgetList
        customWidgetReport.truncated = truncated

        -- Send to analytics API (truncated)
        -- Spring.Echo("Analytics API: Sending widget report with " .. tostring(#widgetList) .. " widgets (truncated)")
        WG.Analytics.SendEvent("widgets_report", customWidgetReport)

        widgetHandler:RemoveWidget(self)
    end
end
