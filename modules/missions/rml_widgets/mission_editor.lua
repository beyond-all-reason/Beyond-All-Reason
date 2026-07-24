if not RmlUi then
	return
end

local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Mission Editor",
		desc = "Terminal for the bar-mission-kit view artifact: renders server-built markup, posts edit intents; the .lua file is the source of truth",
		author = "Beyond All Reason",
		date = "July 2026",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
		handler = true,
	}
end

-- Blind terminal (editor_architecture_plan.md): bar-mission-kit serve renders
-- the whole view (mission_view.json); this widget injects it via inner_rml
-- and routes events back as edit intents keyed by data-* attributes. No
-- mission grammar lives here. Game-side production (domains, live sampling,
-- hot-reload) is mission_bridge.lua — this file only displays and posts.

local VIEW_PATH = "modules/missions/editor/mission_view.json"
local STATUS_PATH = "modules/missions/editor/status.json"
local STATE_PATH = "modules/missions/editor/state.json"
-- Written via io (relative to the engine WRITE dir); serve watches the same
-- dir — just bar::mission-serve points there.
local OPEN_REQUEST_PATH = "modules/missions/editor/open_request.json"
local EDITS_DIR = "modules/missions/editor/edits"
local RML_PATH = "modules/missions/rml_widgets/mission_editor.rml"
local POLL_SECONDS = 0.5
local LIVE_PATCH_SECONDS = 1.0
local EDIT_DEBOUNCE_SECONDS = 0.8

-- Engine-provided in the widget env (system.lua whitelists it). Do NOT
-- VFS.Include json.lua: it reads `local base = _G`, nil in widget sandboxes.
local Json = Json
if not Json then
	return
end

local document
local visible = false
local lobbyHidden = false -- true while the lobby/menu overlay is up (LobbyOverlayActive)
local mode = "form" ---@type "form"|"text"
local lastGeneration = nil
local lastArmed = nil
local pollAccumulator = 0
local liveAccumulator = 0
local currentView = nil
local pendingEdits = {}
local editSequence = 0
local liveSpans = nil
local collapsedSections = {}
local pickerBypassed = false
local applyViewLayout, renderCurrent

local function escape(text)
	return (tostring(text):gsub("&", "&amp;"):gsub('"', "&quot;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
end

--------------------------------------------------------------------------------
-- The intent channel: filesystem out, regeneration back.
--------------------------------------------------------------------------------

---Mode switch to code: ask the serve process to open the file in the IDE.
local function requestOpenInEditor(filePath, line)
	Spring.CreateDir("modules/missions/editor")
	local handle = io.open(OPEN_REQUEST_PATH, "w")
	if handle == nil then
		Spring.Echo("[mission_editor] cannot write " .. OPEN_REQUEST_PATH)
		return
	end
	handle:write(Json.encode({ file = filePath, line = line or 1 }))
	handle:close()
end

---@param edit { file: string, start: number, finish: number, hash: string, quote: boolean, value: string }
local function writeEditIntent(edit)
	Spring.CreateDir(EDITS_DIR)
	editSequence = editSequence + 1
	local path = EDITS_DIR .. "/" .. Spring.GetGameFrame() .. "_" .. editSequence .. ".json"
	local handle = io.open(path, "w")
	if not handle then
		Spring.Echo("[mission_editor] cannot write edit intent " .. path)
		return
	end
	local newText = edit.value
	if edit.quote then
		newText = '"' .. newText .. '"'
	end
	handle:write(Json.encode({
		file = edit.file,
		start = edit.start,
		["end"] = edit.finish,
		new_text = newText,
		base_hash = edit.hash,
	}))
	handle:close()
end

---Flush debounced field edits; the last value within a field's window wins.
local function flushPendingEdits()
	local now = os.clock()
	for key, edit in pairs(pendingEdits) do
		if now >= edit.deadline then
			pendingEdits[key] = nil
			writeEditIntent(edit)
		end
	end
end

local function queueFieldEdit(element, value, deadline)
	local start = tonumber(element:GetAttribute("data-start"))
	if start == nil then
		return
	end
	pendingEdits[element:GetAttribute("data-file") .. ":" .. start] = {
		file = element:GetAttribute("data-file"),
		start = start,
		finish = tonumber(element:GetAttribute("data-end")),
		hash = element:GetAttribute("data-hash"),
		quote = element:GetAttribute("data-quote") == "1",
		value = value,
		deadline = deadline,
	}
end

--------------------------------------------------------------------------------
-- Live chips: patch [data-live] spans from state.json — the same artifact
-- every other terminal reads; the bridge produces it.
--------------------------------------------------------------------------------

local function collectLiveSpans()
	liveSpans = {}
	local content = document and document:GetElementById("me-content")
	if not content then
		return
	end
	local spans = content:GetElementsByTagName("span")
	for i = 1, #spans do
		local key = spans[i]:GetAttribute("data-live")
		if key then
			liveSpans[#liveSpans + 1] = { element = spans[i], key = key }
		end
	end
end

local function applyLive()
	if not (visible and mode == "form") then
		return
	end
	local text = VFS.LoadFile(STATE_PATH, VFS.RAW_FIRST)
	if not text then
		return
	end
	local ok, state = pcall(Json.decode, text)
	if not ok or type(state) ~= "table" or type(state.values) ~= "table" then
		return
	end
	if not liveSpans then
		collectLiveSpans()
	end
	for _, entry in ipairs(liveSpans) do
		local value = state.values[entry.key]
		if value then
			entry.element.inner_rml = escape(value.text)
			entry.element:SetClass("done", value.state == "done")
		end
	end
end

--------------------------------------------------------------------------------
-- Modal: rows come as structured data; kind picks the insert position from
-- the opening button's attributes.
--------------------------------------------------------------------------------

local function closeModal()
	local modal = document and document:GetElementById("me-modal")
	if modal then
		modal.style.display = "none"
	end
end

local function applyModalRow(row, button)
	local start, finish
	if row.kind == "swap" then
		start = tonumber(button:GetAttribute("data-swap-start"))
		finish = tonumber(button:GetAttribute("data-swap-end"))
	elseif row.kind == "trigger" then
		start = tonumber(button:GetAttribute("data-insert"))
		finish = start
	elseif row.kind == "andwhen" then
		start = tonumber(button:GetAttribute("data-insert-cond"))
		finish = start
	else -- effect
		start = tonumber(button:GetAttribute("data-insert-effect"))
		finish = start
	end
	if not (start and finish) then
		return
	end
	writeEditIntent({
		file = button:GetAttribute("data-file"),
		start = start,
		finish = finish,
		hash = button:GetAttribute("data-hash"),
		quote = false,
		value = row.new_text,
	})
	closeModal()
end

local function openModal(key, button)
	local payload = currentView and currentView.modals and currentView.modals[key]
	local modal = document:GetElementById("me-modal")
	local titleEl = document:GetElementById("me-modal-title")
	local rowsEl = document:GetElementById("me-modal-rows")
	if not (payload and modal and titleEl and rowsEl) then
		return
	end
	titleEl.inner_rml = escape(payload.title)
	local out = {}
	for i, row in ipairs(payload.rows) do
		if row.kind == "group" then
			out[#out + 1] = '<div class="me-modal-group">' .. escape(row.label) .. "</div>"
		else
			out[#out + 1] = '<div class="me-modal-row" data-row="' .. i .. '">' .. escape(row.label) .. "</div>"
		end
	end
	rowsEl.inner_rml = table.concat(out)
	local divs = rowsEl:GetElementsByTagName("div")
	for i = 1, #divs do
		local rowEl = divs[i]
		local index = tonumber(rowEl:GetAttribute("data-row"))
		if index then
			rowEl:AddEventListener("click", function()
				applyModalRow(payload.rows[index], button)
			end)
		end
	end
	modal.style.display = "block"
end

--------------------------------------------------------------------------------
-- Generic wiring: every control routes by data-* attributes.
--------------------------------------------------------------------------------

local function wireOpenTarget(element)
	local openFile = element:GetAttribute("data-open-file")
	if openFile then
		element:AddEventListener("click", function()
			requestOpenInEditor(openFile, tonumber(element:GetAttribute("data-open-line")) or 1)
		end)
	end
end

local function attachHandlers()
	local content = document:GetElementById("me-content")
	if not content then
		return
	end
	local sectionByKey = {}
	local divs = content:GetElementsByTagName("div")
	for i = 1, #divs do
		local div = divs[i]
		local sectionKey = div:GetAttribute("data-section")
		if sectionKey then
			sectionByKey[sectionKey] = div
			if collapsedSections[sectionKey] ~= nil then
				div:SetClass("collapsed", collapsedSections[sectionKey])
			end
		end
		wireOpenTarget(div)
	end
	local spans = content:GetElementsByTagName("span")
	for i = 1, #spans do
		wireOpenTarget(spans[i])
	end
	local inputs = content:GetElementsByTagName("input")
	for i = 1, #inputs do
		local input = inputs[i]
		-- Printable keys only reach RmlUi inputs while SDL text-input mode is
		-- on (gui_chat does the same dance).
		input:AddEventListener("focus", function()
			Spring.SDLStartTextInput()
		end)
		input:AddEventListener("blur", function()
			Spring.SDLStopTextInput()
		end)
		input:AddEventListener("change", function()
			queueFieldEdit(input, tostring(input:GetAttribute("value") or ""), os.clock() + EDIT_DEBOUNCE_SECONDS)
		end)
	end
	local buttons = content:GetElementsByTagName("button")
	for i = 1, #buttons do
		local button = buttons[i]
		local pool = button:GetAttribute("data-pool")
		local add = button:GetAttribute("data-add")
		local toggleKey = button:GetAttribute("data-toggle")
		if toggleKey then
			button:AddEventListener("click", function()
				local section = sectionByKey[toggleKey]
				if section then
					local nowCollapsed = not section:IsClassSet("collapsed")
					section:SetClass("collapsed", nowCollapsed)
					collapsedSections[toggleKey] = nowCollapsed
				end
			end)
		elseif pool then
			button:AddEventListener("click", function()
				openModal("swap_" .. pool, button)
			end)
		elseif add then
			button:AddEventListener("click", function()
				openModal(add == "statement" and "add_statement" or "add_step", button)
			end)
		elseif button:GetAttribute("data-op") == "remove" then
			button:AddEventListener("click", function()
				writeEditIntent({
					file = button:GetAttribute("data-file"),
					start = tonumber(button:GetAttribute("data-remove-start")),
					finish = tonumber(button:GetAttribute("data-remove-end")),
					hash = button:GetAttribute("data-hash"),
					quote = false,
					value = "",
				})
			end)
		end
	end
	local selects = content:GetElementsByTagName("select")
	for i = 1, #selects do
		local select = selects[i]
		-- The dropdown's own option-click listeners don't fire for
		-- inner_rml-built selects in this build; arm the options ourselves.
		local control = RmlUi.Element.As.ElementFormControlSelect(select)
		if control then
			local options = select:GetElementsByTagName("option")
			for optionIndex = 1, #options do
				local option = options[optionIndex]
				option:AddEventListener("click", function()
					control.selection = optionIndex - 1
					select:Blur()
				end)
			end
		end
		select:AddEventListener("change", function()
			queueFieldEdit(select, tostring(select:GetAttribute("value") or ""), 0)
		end)
	end
end

--------------------------------------------------------------------------------
-- Panel state
--------------------------------------------------------------------------------

local function loadView()
	local text = VFS.LoadFile(VIEW_PATH, VFS.RAW_FIRST)
	if not text then
		return nil, "no view artifact at " .. VIEW_PATH .. " — run: just bar::mission-serve"
	end
	local ok, view = pcall(Json.decode, text)
	if not ok or type(view) ~= "table" then
		return nil, "cannot decode " .. VIEW_PATH
	end
	return view
end

local function serveStatusLine()
	local text = VFS.LoadFile(STATUS_PATH, VFS.RAW_FIRST)
	if not text then
		return nil
	end
	local ok, status = pcall(Json.decode, text)
	if not ok or type(status) ~= "table" or status.ok then
		return nil
	end
	return '<div class="me-opaque">' .. escape(status.message) .. "</div>"
end

local function refresh()
	if not document then
		return
	end
	local view, err = loadView()
	currentView = view or currentView
	local content = document:GetElementById("me-content")
	if content then
		content.inner_rml = (serveStatusLine() or "") .. (view and view.form or ('<div class="me-opaque">' .. (err or "?") .. "</div>"))
		attachHandlers()
		liveSpans = nil
	end
end

---Text-mode billboard: BIG header + serve status + the read-only view.
local function fillBillboard()
	local strip = document:GetElementById("me-textmode")
	if not strip then
		return
	end
	local view = loadView()
	currentView = view or currentView
	strip.inner_rml = '<div class="me-bighead">EDITING IN VS CODE</div>' .. (serveStatusLine() or '<div class="me-followline">The form follows your saves.</div>') .. '<div class="me-billboard">' .. (view and view.billboard or "") .. "</div>"
end

---Premature entry (/mission editor with nothing armed) drops you at the
---mission list; clicking starts one through the loader's own chat action.
---The runnable list is game domain data: only the VFS knows what shipped.
local function listMissions()
	local missions = {}
	for _, dir in ipairs(VFS.SubDirs("modules/missions/") or {}) do
		local name = dir:match("([^/]+)/?$")
		if name and #VFS.DirList(dir .. "triggers/", "*.lua") > 0 then
			missions[#missions + 1] = name
		end
	end
	table.sort(missions)
	return missions
end

local function renderPicker()
	local content = document:GetElementById("me-content")
	if not content then
		return
	end
	local out = { '<div class="me-group">START A MISSION</div>' }
	for _, name in ipairs(listMissions()) do
		out[#out + 1] = '<div class="me-modal-row" data-mission="' .. escape(name) .. '">' .. escape(name) .. "</div>"
	end
	out[#out + 1] = '<div class="me-add-row"><button class="me-button me-add-btn" data-bypass="1">browse the form without starting</button></div>'
	content.inner_rml = table.concat(out)
	local divs = content:GetElementsByTagName("div")
	for i = 1, #divs do
		local row = divs[i]
		local mission = row:GetAttribute("data-mission")
		if mission then
			row:AddEventListener("click", function()
				Spring.SendCommands("luarules mission " .. mission)
			end)
		end
	end
	local buttons = content:GetElementsByTagName("button")
	for i = 1, #buttons do
		if buttons[i]:GetAttribute("data-bypass") then
			buttons[i]:AddEventListener("click", function()
				pickerBypassed = true
				refresh()
			end)
		end
	end
end

renderCurrent = function()
	if mode == "form" then
		local armed = Spring.GetGameRulesParam("mission_active") == 1
		if armed or pickerBypassed then
			refresh()
		else
			renderPicker()
		end
	else
		fillBillboard()
	end
end

---Poll the view artifact; on a new generation, re-render. (Hot-reloading the
---running mission is the bridge's job.)
local function pollArtifact(dt)
	pollAccumulator = pollAccumulator + dt
	if pollAccumulator < POLL_SECONDS then
		return
	end
	pollAccumulator = 0
	local text = VFS.LoadFile(VIEW_PATH, VFS.RAW_FIRST)
	if not text then
		return
	end
	local generation = text:match('"generation"%s*:%s*(%d+)')
	if generation == lastGeneration then
		return
	end
	lastGeneration = generation
	if visible then
		renderCurrent()
	end
end

function widget:Update(dt)
	pollArtifact(dt)
	flushPendingEdits()
	-- Arming flips the panel from the picker to the form (and back).
	local armed = Spring.GetGameRulesParam("mission_active") == 1
	if armed ~= lastArmed then
		lastArmed = armed
		if visible then
			renderCurrent()
		end
	end
	liveAccumulator = liveAccumulator + dt
	if liveAccumulator >= LIVE_PATCH_SECONDS then
		liveAccumulator = 0
		applyLive()
	end
end

---vw units resolve to 0 in this RmlUi build: place the panel from real view
---geometry, scale the base font with the view height.
applyViewLayout = function()
	local root = document:GetElementById("me-root")
	if not root then
		return
	end
	local vsx, vsy = Spring.GetViewGeometry()
	local scale = math.max(0.9, math.min(1.8, vsy / 1080))
	local width = math.floor(580 * scale)
	root.style.left = tostring(math.max(0, vsx - width - 40)) .. "px"
	root.style.width = tostring(width) .. "px"
	root.style["font-size"] = tostring(math.floor(17 * scale)) .. "px"
	-- The scroll window tracks the screen, not a hardcoded height.
	local content = document:GetElementById("me-content")
	if content then
		content.style["max-height"] = tostring(math.max(420, vsy - 330)) .. "px"
	end
end

function widget:ViewResize()
	if document and visible then
		applyViewLayout()
	end
end

---Form mode shows the cards; text mode collapses to the billboard while the
---real IDE owns the file. Same document, no close on mode switch.
local function setMode(newMode)
	mode = newMode
	local content = document:GetElementById("me-content")
	local footer = document:GetElementById("me-footer")
	local strip = document:GetElementById("me-textmode")
	local editButton = document:GetElementById("me-edit")
	local isForm = mode == "form"
	if content then
		content.style.display = isForm and "block" or "none"
	end
	if footer then
		footer.style.display = isForm and "block" or "none"
	end
	if strip then
		strip.style.display = isForm and "none" or "block"
		if not isForm then
			fillBillboard()
		end
	end
	if editButton then
		editButton.inner_rml = isForm and "Edit" or "Form"
	end
end

local function setVisible(on)
	visible = on
	if not document then
		return
	end
	if on then
		renderCurrent()
		applyViewLayout()
		if not lobbyHidden then
			document:Show()
		end
	else
		document:Hide()
	end
end

-- Hide while the lobby/menu overlay is up so the panel never draws over
-- Chobby (LobbyOverlayActive broadcast from barwidgets.lua, same handling as
-- gui_feature_placer).
function widget:RecvLuaMsg(message)
	if not document then
		return
	end
	if message:sub(1, 19) == "LobbyOverlayActive0" then
		lobbyHidden = false
		if visible then
			document:Show()
		end
	elseif message:sub(1, 19) == "LobbyOverlayActive1" then
		lobbyHidden = true
		document:Hide()
	end
end

function widget:Initialize()
	local context = RmlUi.GetContext("shared")
	if not context then
		return false
	end
	document = context:LoadDocument(RML_PATH)
	if not document then
		return false
	end

	local editButton = document:GetElementById("me-edit")
	if editButton then
		editButton:AddEventListener("click", function()
			if mode == "form" then
				local first = currentView and currentView.first_file
				if first then
					requestOpenInEditor(first, 1)
				end
				setMode("text")
			else
				setMode("form")
				refresh()
			end
		end)
	end
	local refreshButton = document:GetElementById("me-refresh")
	if refreshButton then
		refreshButton:AddEventListener("click", function()
			renderCurrent()
		end)
	end
	local reloadButton = document:GetElementById("me-reload")
	if reloadButton then
		reloadButton:AddEventListener("click", function()
			Spring.SendCommands("luarules mission reload")
			renderCurrent()
		end)
	end
	local modalCancel = document:GetElementById("me-modal-cancel")
	if modalCancel then
		modalCancel:AddEventListener("click", function()
			closeModal()
		end)
	end
	local closeButton = document:GetElementById("me-close")
	if closeButton then
		closeButton:AddEventListener("click", function()
			setVisible(false)
		end)
	end

	widgetHandler.actionHandler:AddAction(self, "mission", function(_, line)
		local subcommand = (line or ""):match("^%s*(%S*)")
		if subcommand == "editor" then
			setVisible(not visible)
		else
			Spring.Echo("[mission_editor] usage: /mission editor")
		end
		return true
	end, nil, "t")

	document:Hide()
	Spring.Echo("[mission_editor] terminal build 3")
	return true
end

function widget:Shutdown()
	widgetHandler.actionHandler:RemoveAction(self, "mission", "t")
	if document then
		document:Close()
		document = nil
	end
end
