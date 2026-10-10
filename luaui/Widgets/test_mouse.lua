local widget = widget --- @type Widget

function widget:GetInfo()
	return {
		name    = "Mouse Input API test", 
		desc    = "test",
		author  = "uBdead",
		date    = "June 2026",
		license = "GPL-v2",
		layer   = 0, -- expose API at init arbitrarily early, hopefully before want to use the API
		enabled = true,
	}
end

local function screenToWorld(x, y)
    local kind, pos = Spring.TraceScreenRay(x, y, true)
    if kind == "ground" and pos then
        return pos[1], pos[2], pos[3]
    end
end

local function addMarker(x, y, label)
    local wx, wy, wz = screenToWorld(x, y)
    if wx then
        Spring.MarkerAddPoint(wx, wy, wz, label, true)
    end
end

function widget:Initialize()
    if not WG.Mouse then
        Spring.Log("Mouse Input API Test", LOG.ERROR, "WG.Mouse is not available. Make sure the Mouse Input API widget is loaded.")
        return
    end

    WG.Mouse.registerImmediateClickHandler("test1", function(x, y, button)
        Spring.Echo("Mouse Input API Test: Immediate click at (" .. x .. ", " .. y .. ") with button " .. button)
        -- addMarker(x, y, "Immediate click b" .. button)
    end)

    WG.Mouse.registerClickHandler("test1", function(x, y, button)
        Spring.Echo("Mouse Input API Test: Confirmed click (no drag, no double-click) at (" .. x .. ", " .. y .. ") with button " .. button)
        addMarker(x, y, "Click b" .. button)
    end)

    WG.Mouse.registerDoubleClickHandler("test1", function(x, y, button)
        Spring.Echo("Mouse Input API Test: Double-click at (" .. x .. ", " .. y .. ") with button " .. button)
        addMarker(x, y, "Double-click b" .. button)
    end)

    WG.Mouse.registerDragHandler("test1", {
        filter = function(_, _, button) return button == 1 end,
        onStart = function(x, y, button)
            Spring.Echo("Mouse Input API Test: Drag started at (" .. x .. ", " .. y .. ") with button " .. button)
            addMarker(x, y, "Drag start b" .. button)
        end,
        onEnd = function(x, y, startX, startY, button)
            Spring.Echo("Mouse Input API Test: Drag ended at (" .. x .. ", " .. y .. ") from (" .. startX .. ", " .. startY .. ") with button " .. button)
            addMarker(x, y, "Drag end b" .. button)
        end,
    })

    -- Right-click drag works exactly the same way; only the filter differs.
    -- Capturing button 3 suppresses the normal right-click command while held.
    WG.Mouse.registerDragHandler("test1_rmb", {
        filter = function(_, _, button) return button == 3 end,
        onStart = function(x, y, button)
            Spring.Echo("Mouse Input API Test: RMB drag started at (" .. x .. ", " .. y .. ") with button " .. button)
            addMarker(x, y, "RMB drag start")
        end,
        onEnd = function(x, y, startX, startY, button)
            Spring.Echo("Mouse Input API Test: RMB drag ended at (" .. x .. ", " .. y .. ") from (" .. startX .. ", " .. startY .. ") with button " .. button)
            addMarker(x, y, "RMB drag end")
        end,
        onCancel = function(x, y, button)
            Spring.Echo("Mouse Input API Test: RMB drag cancelled (plain right-click) at (" .. x .. ", " .. y .. ")")
            addMarker(x, y, "RMB cancelled")
        end,
    })
end

function widget:Shutdown()
    if not WG.Mouse then
        return
    end
    WG.Mouse.disposeImmediateClickHandler("test1")
    WG.Mouse.disposeClickHandler("test1")
    WG.Mouse.disposeDoubleClickHandler("test1")
    WG.Mouse.disposeDragHandler("test1")
    WG.Mouse.disposeDragHandler("test1_rmb")
end
