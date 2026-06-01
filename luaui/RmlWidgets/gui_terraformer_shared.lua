if not RmlUi then
    return
end

local widget = widget ---@type Widget

function widget:GetInfo()
    return {
        name = "Terraformer Shared RmlUi Helpers",
        desc = "Feature-owned shared helpers (DP-ratio, document registry, draggable panels) used by the realtime terraformer RmlUi widgets: terraform brush, weather brush, feature placer and decal placer.",
        author = "Mupersega",
        date = "2026",
        license = "GNU GPL, v2 or later",
        layer = -999999,
        enabled = true
    }
end

local WG = WG
local Spring = Spring

local function calculateDpRatio()
    local viewSizeX, viewSizeY = Spring.GetViewGeometry()
    local userScale = Spring.GetConfigFloat("ui_scale", 1)
    local baseWidth = 1920
    local baseHeight = 1080
    local resFactor = math.min(viewSizeX / baseWidth, viewSizeY / baseHeight)
    local dpRatio = resFactor * userScale
    return math.floor(dpRatio * 100) / 100
end

local currentDpRatio = calculateDpRatio()

WG.TerraformerShared = WG.TerraformerShared or {}

-- Shared accessor so widgets don't reimplement calculateDpRatio().
-- Returns the current scale factor (resolution_factor * ui_scale), matching
-- whatever the shared RmlUi context is currently using.
WG.TerraformerShared.getDpRatio = function() return currentDpRatio end

-- Cross-widget DOM-read registry. Widgets that want to be snap targets (or
-- otherwise have their rect read by a sibling widget) should register their
-- root document after LoadDocument(), and unregister on Shutdown().
-- Readers call getElementRect(docName, elementId) to pull live pixel-space
-- layout off the target element instead of mirroring position through WG.*.
local registeredDocuments = {}

WG.TerraformerShared.registerDocument = function(name, document)
    if name and document then
        registeredDocuments[name] = document
    end
end

WG.TerraformerShared.unregisterDocument = function(name)
    if name then
        registeredDocuments[name] = nil
    end
end

WG.TerraformerShared.getDocument = function(name)
    return registeredDocuments[name]
end

WG.TerraformerShared.getElementRect = function(docName, elementId)
    local doc = registeredDocuments[docName]
    if not doc then return nil end
    local el = elementId and doc:GetElementById(elementId) or nil
    if not el then return nil end
    local w = el.offset_width
    local h = el.offset_height
    if not w or w <= 0 then return nil end
    return {
        left = el.offset_left,
        top = el.offset_top,
        width = w,
        height = h or 0,
    }
end

-- Shared drag-and-drop helper for floating panels.
-- Sets up mousedown on handleId + mouseup on doc, returns a handle with tick().
-- Call handle.tick() every frame from widget:Update() while the widget is alive.
--
-- opts fields (all optional):
--   snapThreshold (number, default 30) — pixel snap distance for edges + panel snap
--   onDragStart   (function)           — called on mousedown (e.g. set userDragged)
--   snapDocName   (string, default "terraform_brush") — registered document to snap to
--   snapElementId (string, default "tf-root")         — element within that document
WG.TerraformerShared.attachDraggable = function(doc, handleId, rootEl, opts)
    if not doc or not rootEl then return { tick = function() end } end
    local handleEl = doc:GetElementById(handleId)
    if not handleEl then return { tick = function() end } end

    local snapThreshold = (opts and opts.snapThreshold) or 30
    local onDragStart   = opts and opts.onDragStart
    local snapDocName   = (opts and opts.snapDocName)   or "terraform_brush"
    local snapElementId = (opts and opts.snapElementId) or "tf-root"

    local ds = {
        active = false, rootEl = nil,
        offsetX = 0, offsetY = 0,
        ew = 0, eh = 0,
        vsx = 0, vsy = 0,
        lastX = -1, lastY = -1,
    }

    handleEl:AddEventListener("mousedown", function(event)
        local p = event.parameters
        if not p or (p.button and p.button ~= 0) then return end
        local mx, my = Spring.GetMouseState()
        local vsx, vsy = Spring.GetViewGeometry()
        ds.active  = true
        ds.rootEl  = rootEl
        ds.offsetX = mx - rootEl.offset_left
        ds.offsetY = (vsx > 0 and vsy > 0) and ((vsy - my) - rootEl.offset_top) or 0
        ds.ew      = rootEl.offset_width
        ds.eh      = rootEl.offset_height
        ds.vsx     = vsx
        ds.vsy     = vsy
        ds.lastX   = -1
        ds.lastY   = -1
        if onDragStart then onDragStart() end
        event:StopPropagation()
    end, false)

    doc:AddEventListener("mouseup", function()
        if ds.active then
            ds.active = false
            ds.rootEl = nil
        end
    end, false)

    local T = snapThreshold
    return {
        tick = function()
            if not ds.active or not ds.rootEl then return end
            local mx, my, _, _, _, offscreen = Spring.GetMouseState()
            if offscreen then return end
            local vsx, vsy = ds.vsx, ds.vsy
            local ew, eh   = ds.ew, ds.eh
            local newX = mx - ds.offsetX
            local newY = (vsy - my) - ds.offsetY

            -- Clamp to viewport
            if newX < 0 then newX = 0 elseif newX + ew > vsx then newX = vsx - ew end
            if newY < 0 then newY = 0 elseif newY + eh > vsy then newY = vsy - eh end

            -- Snap to screen edges
            if newX < T then newX = 0 elseif vsx - newX - ew < T then newX = vsx - ew end
            if newY < T then newY = 0 elseif vsy - newY - eh < T then newY = vsy - eh end

            -- Snap to registered panel
            local snapTarget = WG.TerraformerShared.getElementRect(snapDocName, snapElementId)
            if snapTarget then
                local ox, oy = snapTarget.left, snapTarget.top
                local oR = ox + (snapTarget.width  or 0)
                local oB = oy + (snapTarget.height or 0)
                local newR, newB = newX + ew, newY + eh
                if newY < oB and newB > oy then
                    local d = newX - oR
                    if d > -T and d < T then newX = oR
                    else d = newR - ox
                        if d > -T and d < T then newX = ox - ew end
                    end
                end
                if newX < oR and newR > ox then
                    local d = newY - oB
                    if d > -T and d < T then newY = oB
                    else d = newB - oy
                        if d > -T and d < T then newY = oy - eh end
                    end
                end
            end

            local ix = math.floor(newX)
            local iy = math.floor(newY)
            if ix ~= ds.lastX or iy ~= ds.lastY then
                ds.lastX = ix
                ds.lastY = iy
                ds.rootEl.style.left = ix .. "px"
                ds.rootEl.style.top  = iy .. "px"
            end
        end,
    }
end

function widget:ViewResize()
    currentDpRatio = calculateDpRatio()
end

function widget:Shutdown()
    if WG.TerraformerShared then
        WG.TerraformerShared.getDpRatio = nil
        WG.TerraformerShared.registerDocument = nil
        WG.TerraformerShared.unregisterDocument = nil
        WG.TerraformerShared.getDocument = nil
        WG.TerraformerShared.getElementRect = nil
        WG.TerraformerShared.attachDraggable = nil
    end
    registeredDocuments = {}
end
