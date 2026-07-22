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

---Pretty-print a recognizer Value node back to DSL text, literals wrapped in
---spans so the form can style what is form-editable.
---@param value table
---@return string
local function renderValue(value)
	local kind = value.kind
	if kind == "number" then
		local number = value.value
		if number == math.floor(number) then
			number = math.floor(number)
		end
		return '<span class="me-lit">' .. tostring(number) .. "</span>"
	elseif kind == "string" then
		return '<span class="me-lit">"' .. tostring(value.value) .. '"</span>'
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
				args[#args + 1] = renderValue(arg)
			end
			parts[#parts + 1] = "(" .. table.concat(args, ", ") .. ")"
		end
		return table.concat(parts)
	elseif kind == "table" then
		local fields = {}
		for _, field in ipairs(value.fields) do
			fields[#fields + 1] = field.key .. " = " .. renderValue(field.value)
		end
		return "{ " .. table.concat(fields, ", ") .. " }"
	end
	return '<span class="me-opaque">[' .. tostring(value.reason or "opaque") .. "]</span>"
end

---@param trigger table
---@param filePath string recognizer-relative mission file path
---@return string
local function renderTrigger(trigger, filePath)
	local rows = {
		'<div class="me-card"><div class="me-card-head"><div class="me-card-title">'
			.. (trigger.label or trigger.id)
			.. '</div><button class="me-button me-edit" data-file="'
			.. filePath
			.. '" data-line="'
			.. tostring(trigger.line or 1)
			.. '">Edit</button></div>',
	}
	for _, step in ipairs(trigger.steps) do
		if step.verb ~= "Register" then
			local args = {}
			for _, arg in ipairs(step.args) do
				args[#args + 1] = renderValue(arg)
			end
			rows[#rows + 1] = '<div class="me-step"><span class="me-step-verb">'
				.. step.verb
				.. "</span> "
				.. table.concat(args, ", ")
				.. "</div>"
		end
	end
	rows[#rows + 1] = "</div>"
	return table.concat(rows)
end

---@return string|nil rml, string|nil err
local function buildBody()
	local text = VFS.LoadFile(AST_PATH, VFS.RAW_FIRST)
	if not text then
		return nil, "no AST artifact at " .. AST_PATH .. " — run bar-mission-kit parse"
	end
	local ok, ast = pcall(Json.decode, text)
	if not ok or type(ast) ~= "table" then
		return nil, "cannot decode " .. AST_PATH
	end

	local out = {}
	for _, file in ipairs(ast.files or {}) do
		out[#out + 1] = '<div class="me-file">' .. file.path .. "</div>"
		for _, group in ipairs(file.groups or {}) do
			if group.label then
				out[#out + 1] = '<div class="me-group">' .. group.label .. "</div>"
			end
			for _, trigger in ipairs(group.triggers or {}) do
				out[#out + 1] = renderTrigger(trigger, file.path)
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
	local handle = io.open(OPEN_REQUEST_PATH, "w")
	if handle == nil then
		Spring.Echo("[mission_editor] cannot write " .. OPEN_REQUEST_PATH)
		return
	end
	handle:write(Json.encode({ file = filePath, line = tonumber(line) or 1 }))
	handle:close()
end

local function attachCardHandlers()
	local content = document:GetElementById("me-content")
	if not content then
		return
	end
	local buttons = content:GetElementsByTagName("button")
	for i = 1, #buttons do
		local button = buttons[i]
		button:AddEventListener("click", function()
			requestOpenInEditor(button:GetAttribute("data-file"), button:GetAttribute("data-line"))
		end)
	end
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

local function refresh()
	if not document then
		return
	end
	local body, err = buildBody()
	local statusLine = serveStatusLine()
	local content = document:GetElementById("me-content")
	if content then
		content.inner_rml = (statusLine or "")
			.. (body or ('<div class="me-opaque">' .. (err or "?") .. "</div>"))
		attachCardHandlers()
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
		refresh()
	end
	if not firstSight and Spring.GetGameRulesParam("mission_active") == 1 then
		Spring.SendCommands("luarules mission reload")
	end
end

function widget:Update(dt)
	pollArtifact(dt)
end

function widget:ViewResize()
	if document and visible then
		local root = document:GetElementById("me-root")
		if root then
			local vsx = Spring.GetViewGeometry()
			root.style.left = tostring(math.max(0, vsx - 500)) .. "px"
		end
	end
end

local function setVisible(on)
	visible = on
	if not document then
		return
	end
	if on then
		refresh()
		-- vw units resolve to 0 in this RmlUi build, so right-anchoring is
		-- unusable: place the panel from real view geometry instead.
		local root = document:GetElementById("me-root")
		if root then
			local vsx = Spring.GetViewGeometry()
			root.style.left = tostring(math.max(0, vsx - 500)) .. "px"
		end
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
	local closeButton = document:GetElementById("me-close")
	if closeButton then
		closeButton:AddEventListener("click", function()
			setVisible(false)
		end)
	end

	widgetHandler.actionHandler:AddAction(self, "mission_editor", function()
		setVisible(not visible)
		return true
	end, nil, "t")

	document:Hide()
	return true
end

function widget:Shutdown()
	widgetHandler.actionHandler:RemoveAction(self, "mission_editor", "t")
	if document then
		document:Close()
		document = nil
	end
end
