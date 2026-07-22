if not RmlUi then
	return
end

local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Mission Editor",
		desc = "Read-only view of the mission's decorated AST (bar-mission-kit artifact); the file is the source of truth",
		author = "Beyond All Reason",
		date = "July 2026",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
		handler = true,
	}
end

-- The editor architecture (editor_architecture_plan.md): the authoritative
-- writer is the Devtools editor; the game is a READER. This widget renders the
-- derived AST artifact bar-mission-kit places in the data dir — a view over
-- the tree, which is a view over the file. It never owns state and never
-- writes source.

local AST_PATH = "modules/missions/editor/mission_ast.json"
local STATUS_PATH = "modules/missions/editor/status.json"
-- Written via io (relative to the engine WRITE dir). In dev-from-source the
-- write dir is the repo, so bar-mission-kit serve's default --editor-dir
-- sees it; with a separate write dir, point serve's --editor-dir there.
local OPEN_REQUEST_PATH = "modules/missions/editor/open_request.json"
local RML_PATH = "modules/missions/rml_widgets/mission_editor.rml"
local POLL_SECONDS = 0.5

-- Engine-provided in the widget env (system.lua whitelists it). Do NOT
-- VFS.Include json.lua here: it reads `local base = _G`, and _G is nil in
-- unsynced widget sandboxes (the known trap).
local Json = Json
if not Json then
	return
end

local document
local visible = false
local lastGeneration = nil
local pollAccumulator = 0
local firstMissionFile = nil
local mode = "form" ---@type "form"|"text"
local applyViewLayout

---Pretty-print a recognizer Value node back to DSL text — the DSL's display
---notation (one renderer, many surfaces: form cards, the text-mode billboard,
---and whatever shows triggers compactly next). In editable mode, number and
---string literals become inputs carrying the span + CAS hash an edit intent
---needs.
---@param value table
---@param ctx { file: string, hash: string, editable: boolean }|nil
---@return string
local function renderValue(value, ctx)
	local kind = value.kind
	if kind == "number" then
		local number = value.value
		if number == math.floor(number) then
			number = math.floor(number)
		end
		if ctx and ctx.editable and value.span then
			return '<input type="text" class="me-input me-input-num" value="' .. tostring(number)
				.. '" data-file="' .. ctx.file
				.. '" data-start="' .. tostring(value.span[1])
				.. '" data-end="' .. tostring(value.span[2])
				.. '" data-hash="' .. ctx.hash
				.. '" data-quote="0"/>'
		end
		return '<span class="me-lit">' .. tostring(number) .. "</span>"
	elseif kind == "string" then
		local text = tostring(value.value)
		if ctx and ctx.editable and value.span and not text:find('"') then
			return '<input type="text" class="me-input" value="' .. text
				.. '" data-file="' .. ctx.file
				.. '" data-start="' .. tostring(value.span[1])
				.. '" data-end="' .. tostring(value.span[2])
				.. '" data-hash="' .. ctx.hash
				.. '" data-quote="1"/>'
		end
		return '<span class="me-lit">"' .. text .. '"</span>'
	elseif kind == "boolean" then
		return '<span class="me-lit">' .. tostring(value.value) .. "</span>"
	elseif kind == "name" then
		return '<span class="me-ref">' .. value.path .. "</span>"
	elseif kind == "verb" then
		local parts = { '<span class="me-verb">' .. value.path .. "</span>" }
		for _, call in ipairs(value.calls) do
			if call.name then
				parts[#parts + 1] = '.<span class="me-verb">' .. call.name .. "</span>"
			end
			local args = {}
			for _, arg in ipairs(call.args) do
				args[#args + 1] = renderValue(arg, ctx)
			end
			parts[#parts + 1] = "(" .. table.concat(args, ", ") .. ")"
		end
		return table.concat(parts)
	elseif kind == "table" then
		local fields = {}
		for _, field in ipairs(value.fields) do
			fields[#fields + 1] = field.key .. " = " .. renderValue(field.value, ctx)
		end
		return "{ " .. table.concat(fields, ", ") .. " }"
	end
	return '<span class="me-opaque">[' .. tostring(value.reason or "opaque") .. "]</span>"
end

---@param trigger table
---@param ctx { file: string, hash: string, editable: boolean }|nil
---@return string
local function renderTrigger(trigger, ctx)
	local rows = {
		'<div class="me-card"><div class="me-card-title">'
			.. (trigger.label or trigger.id)
			.. "</div>",
	}
	for _, step in ipairs(trigger.steps) do
		if step.verb ~= "Register" then
			local args = {}
			for _, arg in ipairs(step.args) do
				args[#args + 1] = renderValue(arg, ctx)
			end
			rows[#rows + 1] = '<div class="me-step"><span class="me-step-verb">'
				.. step.verb:upper()
				.. "</span> "
				.. table.concat(args, ", ")
				.. "</div>"
		end
	end
	rows[#rows + 1] = "</div>"
	return table.concat(rows)
end

---@param editable boolean
---@return string|nil rml, string|nil err
local function buildBody(editable)
	local text = VFS.LoadFile(AST_PATH, VFS.RAW_FIRST)
	if not text then
		return nil, "no AST artifact at " .. AST_PATH .. " — run bar-mission-kit parse"
	end
	local ok, ast = pcall(Json.decode, text)
	if not ok or type(ast) ~= "table" then
		return nil, "cannot decode " .. AST_PATH
	end

	local out = {}
	firstMissionFile = ast.files and ast.files[1] and ast.files[1].path or nil
	for _, file in ipairs(ast.files or {}) do
		local ctx = { file = file.path, hash = file.hash or "", editable = editable }
		out[#out + 1] = '<div class="me-file">' .. file.path .. "</div>"
		for _, group in ipairs(file.groups or {}) do
			if group.label then
				out[#out + 1] = '<div class="me-group">' .. group.label .. "</div>"
			end
			for _, trigger in ipairs(group.triggers or {}) do
				out[#out + 1] = renderTrigger(trigger, ctx)
			end
		end
		if file.opaque and #file.opaque > 0 then
			out[#out + 1] = '<div class="me-opaque">'
				.. #file.opaque
				.. " unrecognized span(s) — see bar-mission-kit check</div>"
		end
	end
	return table.concat(out)
end

---Mode switch to code: ask the serve process to open the file at the line.
---@param filePath string
---@param line string
local function requestOpenInEditor(filePath, line)
	Spring.CreateDir("modules/missions/editor")
	local handle = io.open(OPEN_REQUEST_PATH, "w")
	if handle == nil then
		Spring.Echo("[mission_editor] cannot write " .. OPEN_REQUEST_PATH)
		return
	end
	local absolute = VFS.GetFileAbsolutePath and VFS.GetFileAbsolutePath(OPEN_REQUEST_PATH)
	Spring.Echo("[mission_editor] open request -> " .. tostring(absolute or OPEN_REQUEST_PATH))
	handle:write(Json.encode({ file = filePath, line = tonumber(line) or 1 }))
	handle:close()
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
	return '<div class="me-opaque">' .. tostring(status.message) .. "</div>"
end

local pendingEdits = {}
local editSequence = 0

---Flush debounced field edits as CAS-protected intents for serve. The last
---value within a field's window wins; serve validates before writing.
local function flushPendingEdits()
	local now = os.clock()
	for key, edit in pairs(pendingEdits) do
		if now >= edit.deadline then
			pendingEdits[key] = nil
			Spring.CreateDir("modules/missions/editor/edits")
			editSequence = editSequence + 1
			local path = "modules/missions/editor/edits/" .. Spring.GetGameFrame() .. "_" .. editSequence .. ".json"
			local handle = io.open(path, "w")
			if handle then
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
			else
				Spring.Echo("[mission_editor] cannot write edit intent " .. path)
			end
		end
	end
end

local function attachFormInputs()
	local content = document:GetElementById("me-content")
	if not content then
		return
	end
	local inputs = content:GetElementsByTagName("input")
	for i = 1, #inputs do
		local input = inputs[i]
		input:AddEventListener("change", function()
			local start = tonumber(input:GetAttribute("data-start"))
			if start == nil then
				return
			end
			pendingEdits[input:GetAttribute("data-file") .. ":" .. start] = {
				file = input:GetAttribute("data-file"),
				start = start,
				finish = tonumber(input:GetAttribute("data-end")),
				hash = input:GetAttribute("data-hash"),
				quote = input:GetAttribute("data-quote") == "1",
				value = tostring(input:GetAttribute("value") or ""),
				deadline = os.clock() + 0.8,
			}
		end)
	end
end

local function refresh()
	if not document then
		return
	end
	local body, err = buildBody(true)
	local statusLine = serveStatusLine()
	local content = document:GetElementById("me-content")
	if content then
		content.inner_rml = (statusLine or "")
			.. (body or ('<div class="me-opaque">' .. (err or "?") .. "</div>"))
		attachFormInputs()
	end
end

---The text-mode billboard: BIG header + serve status + the mission in display
---notation, read-only — the same renderer the form uses.
local function fillBillboard()
	local strip = document:GetElementById("me-textmode")
	if not strip then
		return
	end
	local body = buildBody(false)
	strip.inner_rml = '<div class="me-bighead">EDITING IN VS CODE</div>'
		.. (serveStatusLine() or '<div class="me-followline">The form follows your saves.</div>')
		.. '<div class="me-billboard">' .. (body or "") .. "</div>"
end

local function renderCurrent()
	if mode == "form" then
		refresh()
	else
		fillBillboard()
	end
end

---Poll the derived artifact; on a new generation, re-render and hot-reload
---the running mission so the game and the panel both follow the file.
local function pollArtifact(dt)
	pollAccumulator = pollAccumulator + dt
	if pollAccumulator < POLL_SECONDS then
		return
	end
	pollAccumulator = 0
	local text = VFS.LoadFile(AST_PATH, VFS.RAW_FIRST)
	if not text then
		return
	end
	local generation = text:match('"generation"%s*:%s*(%d+)')
	if generation == lastGeneration then
		return
	end
	local firstSight = lastGeneration == nil
	lastGeneration = generation
	if visible then
		renderCurrent()
	end
	if not firstSight and Spring.GetGameRulesParam("mission_active") == 1 then
		Spring.SendCommands("luarules mission reload")
	end
end

function widget:Update(dt)
	pollArtifact(dt)
	flushPendingEdits()
end

function widget:ViewResize()
	if document and visible then
		applyViewLayout()
	end
end

---vw units resolve to 0 in this RmlUi build, so right-anchoring is unusable:
---place the panel from real view geometry, and scale the base font with the
---view height so the panel tracks resolution.
applyViewLayout = function()
	local root = document:GetElementById("me-root")
	if not root then
		return
	end
	local vsx, vsy = Spring.GetViewGeometry()
	local scale = math.max(0.85, math.min(1.6, vsy / 1200))
	local width = math.floor(480 * scale)
	root.style.left = tostring(math.max(0, vsx - width - 40)) .. "px"
	root.style.width = tostring(width) .. "px"
	root.style["font-size"] = tostring(math.floor(16 * scale)) .. "px"
end

---Form mode shows the cards; text mode collapses to a strip while the real
---IDE owns the file. Both are the same document — the panel never closes on
---a mode switch.
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
		document:Show()
	else
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

	local refreshButton = document:GetElementById("me-refresh")
	if refreshButton then
		refreshButton:AddEventListener("click", function()
			refresh()
		end)
	end
	local reloadButton = document:GetElementById("me-reload")
	if reloadButton then
		reloadButton:AddEventListener("click", function()
			-- The hot-reload path: the FILE changed (the editor wrote it);
			-- re-arm the mission, then re-read the artifact.
			Spring.SendCommands("luarules mission reload")
			refresh()
		end)
	end
	local editButton = document:GetElementById("me-edit")
	if editButton then
		editButton:AddEventListener("click", function()
			if mode == "form" then
				-- Switch to text mode: the IDE owns the file now.
				if firstMissionFile then
					requestOpenInEditor(firstMissionFile, 1)
				end
				setMode("text")
			else
				refresh()
				setMode("form")
			end
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
	return true
end

function widget:Shutdown()
	widgetHandler.actionHandler:RemoveAction(self, "mission", "t")
	if document then
		document:Close()
		document = nil
	end
end
