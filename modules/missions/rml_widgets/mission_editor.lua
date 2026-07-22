if not RmlUi then
	return
end

local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Mission Editor",
		desc = "Form + display-notation views over the mission AST (bar-mission-kit artifact); the .lua file is the source of truth",
		author = "Beyond All Reason",
		date = "July 2026",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
		handler = true,
	}
end

-- The editor architecture (editor_architecture_plan.md): the authoritative
-- writer is the Devtools serve process; the game is a reader plus an intent
-- source. This widget renders the derived AST artifact and writes EDIT
-- INTENTS only — span edits carrying a CAS hash, validated by the recognizer
-- before any byte reaches the .lua file. Two card styles over one AST:
--   "ui"  — sentence forms; schema'd verbs read as English with real
--           controls (unit dropdowns from the game's own UnitDefNames,
--           objective dropdowns from the artifact) in the slots
--   "dsl" — the display notation: colored chain text with inline controls

local AST_PATH = "modules/missions/editor/mission_ast.json"
local STATUS_PATH = "modules/missions/editor/status.json"
-- Written via io (relative to the engine WRITE dir, e.g.
-- ~/.local/state/Beyond All Reason). bar-mission-kit serve must watch the
-- same dir — just bar::mission-serve points there.
local OPEN_REQUEST_PATH = "modules/missions/editor/open_request.json"
local EDITS_DIR = "modules/missions/editor/edits"
local RML_PATH = "modules/missions/rml_widgets/mission_editor.rml"
local POLL_SECONDS = 0.5
local EDIT_DEBOUNCE_SECONDS = 0.8

-- Engine-provided in the widget env (system.lua whitelists it). Do NOT
-- VFS.Include json.lua here: it reads `local base = _G`, and _G is nil in
-- unsynced widget sandboxes (the known trap).
local Json = Json
if not Json then
	return
end

local document
local visible = false
local mode = "form" ---@type "form"|"text"
local lastGeneration = nil
local pollAccumulator = 0
local firstMissionFile = nil
local currentAst = nil
local currentObjectives = {}
local pendingEdits = {}
local editSequence = 0
local applyViewLayout

--------------------------------------------------------------------------------
-- Rendering: the DSL's display notation + the full-UI sentence forms.
-- One AST, two projections; both write through the same intent channel.
--------------------------------------------------------------------------------

local function escapeRml(text)
	return (tostring(text):gsub("&", "&amp;"):gsub('"', "&quot;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
end

local unitNamesSorted = nil

---Options for the unit dropdown. The GAME supplies the domain list — the
---server only stamped "this is a unit definition"; UnitDefNames is right here.
---@param selected string
---@return string
local function unitOptionsRml(selected)
	if not unitNamesSorted then
		unitNamesSorted = {}
		-- UnitDefNames is an engine proxy; ipairs(UnitDefs) is the idiom that
		-- actually iterates (same as game_end's commander scan).
		for _, def in ipairs(UnitDefs) do
			if def.name then
				unitNamesSorted[#unitNamesSorted + 1] = def.name
			end
		end
		table.sort(unitNamesSorted)
	end
	local out = {}
	for _, name in ipairs(unitNamesSorted) do
		local def = UnitDefNames[name]
		local human = def and def.translatedHumanName or name
		-- Untranslated units leak raw i18n keys (units.names.x); fall back.
		if human:find("^units%.names%.") then
			human = name
		end
		local label = human .. "  [" .. name .. "]"
		out[#out + 1] = '<option value="' .. name .. '"'
			.. (name == selected and ' selected="true"' or "")
			.. ">" .. escapeRml(label) .. "</option>"
	end
	return table.concat(out)
end

---@param value table a literal node with a span
---@param ctx { file: string, hash: string, editable: boolean }
---@return string
local function editAttrs(value, ctx)
	return ' data-file="' .. ctx.file .. '" data-start="' .. tostring(value.span[1])
		.. '" data-end="' .. tostring(value.span[2]) .. '" data-hash="' .. ctx.hash .. '"'
end

---The control for one literal leaf, chosen by the semantic the annotator
---stamped: unit_def_name -> unit dropdown, objective_name -> objective
---dropdown, number -> number field, plain string -> text field.
---@return string|nil
local function controlFor(value, ctx)
	if not (ctx and ctx.editable) or not value.span then
		return nil
	end
	if value.kind == "string" and value.semantic == "unit_def_name" then
		return '<select class="me-select me-select-unit"' .. editAttrs(value, ctx) .. ' data-quote="1">'
			.. unitOptionsRml(value.value) .. "</select>"
	elseif value.kind == "string" and value.semantic == "objective_name" then
		-- Free text: new objective names must be creatable; a master list
		-- would make this a dropdown, overkill for now.
		return '<input type="text" class="me-input me-input-obj" value="' .. escapeRml(value.value) .. '"'
			.. editAttrs(value, ctx) .. ' data-quote="1"/>'
	elseif value.kind == "number" then
		local number = value.value
		if number == math.floor(number) then
			number = math.floor(number)
		end
		return '<input type="text" class="me-input me-input-num" value="' .. tostring(number) .. '"'
			.. editAttrs(value, ctx) .. ' data-quote="0"/>'
	elseif value.kind == "string" and not value.value:find('"') then
		return '<input type="text" class="me-input" value="' .. escapeRml(value.value) .. '"'
			.. editAttrs(value, ctx) .. ' data-quote="1"/>'
	end
	return nil
end

---Display notation: pretty-print a Value node back to DSL text (one
---renderer, many surfaces — see editor_architecture_plan.md). Editable
---literals become controls in place.
---@param value table
---@param ctx { file: string, hash: string, editable: boolean }|nil
---@return string
local function renderValue(value, ctx)
	local kind = value.kind
	local control = ctx and ctx.editable and controlFor(value, ctx) or nil
	if kind == "number" then
		if control then
			return control
		end
		local number = value.value
		if number == math.floor(number) then
			number = math.floor(number)
		end
		return '<span class="me-lit">' .. tostring(number) .. "</span>"
	elseif kind == "string" then
		if control then
			return control
		end
		return '<span class="me-lit">"' .. escapeRml(value.value) .. '"</span>'
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
	return '<span class="me-opaque">[' .. escapeRml(value.reason or "opaque") .. "]</span>"
end

---Sentence templates for the full-UI card style: schema'd verb shapes read
---as English; {semantic} slots bind to the annotated leaves underneath.
local PHRASES = {
	["Team.Player.Has"] = "Player has {count} × {unit_def_name}",
	["Objective.IsComplete"] = "objective {objective_name} is complete",
	["Objective.Complete"] = "complete objective {objective_name}",
	["MatchFlow.Victory"] = "victory for the player team",
	["MatchFlow.Defeat"] = "defeat for the player team",
}

local function phraseKey(verbValue)
	local chained = nil
	for _, call in ipairs(verbValue.calls or {}) do
		if call.name then
			chained = call.name
		end
	end
	return verbValue.path .. (chained and ("." .. chained) or "")
end

local function findSemanticLeaf(value, semantic)
	if (value.kind == "number" or value.kind == "string") and value.semantic == semantic then
		return value
	end
	if value.kind == "verb" then
		for _, call in ipairs(value.calls) do
			for _, arg in ipairs(call.args) do
				local found = findSemanticLeaf(arg, semantic)
				if found then
					return found
				end
			end
		end
	elseif value.kind == "table" then
		for _, field in ipairs(value.fields) do
			local found = findSemanticLeaf(field.value, semantic)
			if found then
				return found
			end
		end
	end
	return nil
end

---Full-UI rendering of one step argument: the sentence with controls in the
---slots, falling back to display notation for shapes no phrase covers.
local function renderArgUi(value, ctx)
	if value.kind == "verb" then
		local phrase = PHRASES[phraseKey(value)]
		if phrase then
			return (phrase:gsub("{([%w_]+)}", function(semantic)
				local leaf = findSemanticLeaf(value, semantic)
				local control = leaf and controlFor(leaf, ctx)
				if control then
					return control
				end
				if leaf then
					return '<span class="me-lit">' .. escapeRml(tostring(leaf.value)) .. "</span>"
				end
				return "{" .. semantic .. "}"
			end))
		end
	end
	return renderValue(value, ctx)
end

-- Badge category per chain verb: conditions, effects, modifiers.
local STEP_CLASS = {
	When = "cond",
	AndWhen = "cond",
	Do = "effect",
	Once = "mod",
	Debounce = "mod",
}

---@param trigger table
---@param ctx { file: string, hash: string, editable: boolean }
---@param style "ui"|"dsl"
---@return string
local function renderTrigger(trigger, ctx, style)
	local removeButton = ""
	if ctx.editable and trigger.remove_span then
		removeButton = '<button class="me-button me-x" data-op="remove" data-remove-start="'
			.. tostring(trigger.remove_span[1]) .. '" data-remove-end="' .. tostring(trigger.remove_span[2])
			.. '" data-file="' .. ctx.file .. '" data-hash="' .. ctx.hash .. '">×</button>'
	end
	local rows = {
		'<div class="me-card"><div class="me-card-head"><span class="me-card-title">'
			.. escapeRml(trigger.label or trigger.id)
			.. "</span>" .. removeButton .. "</div>",
	}
	for _, step in ipairs(trigger.steps) do
		if step.verb ~= "Register" then
			local badge = STEP_CLASS[step.verb] or "mod"
			local args = {}
			for _, arg in ipairs(step.args) do
				args[#args + 1] = (style == "ui") and renderArgUi(arg, ctx) or renderValue(arg, ctx)
			end
			-- Decomposition controls: swap this step's content for another
			-- template of its kind; remove Do lines outright.
			local tail = {}
			if ctx.editable and currentAst and currentAst.surface then
				local pool = (badge == "cond") and currentAst.surface.conditions
					or (badge == "effect") and currentAst.surface.effects or nil
				if pool and #pool > 0 and step.span then
					tail[#tail + 1] = '<button class="me-button me-x-btn me-swap-btn" data-pool="'
						.. (badge == "cond" and "conditions" or "effects")
						.. '" data-swap-start="' .. tostring(step.span[1])
						.. '" data-swap-end="' .. tostring(step.span[2])
						.. '" data-file="' .. ctx.file .. '" data-hash="' .. ctx.hash .. '"><img src="/luaui/images/repeat.png" width="11" height="11"/></button>'
				end
				if step.verb == "Do" and step.remove_span then
					tail[#tail + 1] = '<button class="me-button me-x" data-op="remove" data-remove-start="'
						.. tostring(step.remove_span[1]) .. '" data-remove-end="' .. tostring(step.remove_span[2])
						.. '" data-file="' .. ctx.file .. '" data-hash="' .. ctx.hash .. '">×</button>'
				end
			end
			rows[#rows + 1] = '<div class="me-step"><span class="me-step-verb me-verb-' .. badge .. '">'
				.. step.verb:upper()
				.. '</span><span class="me-step-body">'
				.. table.concat(args, ", ")
				.. '</span><span class="me-step-tools">'
				.. table.concat(tail, "")
				.. "</span></div>"
		end
	end
	-- The add palette: effects the current surface offers, from the schema
	-- artifact. Choosing one inserts a .Do(...) line through the same
	-- CAS-gated channel; the file comes back re-parsed with fresh controls.
	if ctx.editable and currentAst and currentAst.surface then
		rows[#rows + 1] = '<div class="me-add-row"><button class="me-button me-add-btn" data-add="step" data-insert-cond="'
			.. tostring(trigger.insert_condition_at or 0)
			.. '" data-insert-effect="' .. tostring(trigger.insert_effect_at or trigger.span[2])
			.. '" data-file="' .. ctx.file .. '" data-hash="' .. ctx.hash .. '">+ add</button></div>'
	end
	rows[#rows + 1] = "</div>"
	return table.concat(rows)
end

---@param editable boolean
---@return string|nil rml, string|nil err
local function buildBody(editable)
	local text = VFS.LoadFile(AST_PATH, VFS.RAW_FIRST)
	if not text then
		return nil, "no AST artifact at " .. AST_PATH .. " — run: just bar::mission-serve"
	end
	local ok, ast = pcall(Json.decode, text)
	if not ok or type(ast) ~= "table" then
		return nil, "cannot decode " .. AST_PATH
	end
	currentAst = ast
	currentObjectives = {}
	local seen = {}
	for _, file in ipairs(ast.files or {}) do
		for _, objective in ipairs(file.objectives or {}) do
			if not seen[objective] then
				seen[objective] = true
				currentObjectives[#currentObjectives + 1] = objective
			end
		end
	end
	table.sort(currentObjectives)

	-- The form is full-UI; the billboard reads in display notation.
	local style = editable and "ui" or "dsl"
	local out = {}
	firstMissionFile = ast.files and ast.files[1] and ast.files[1].path or nil
	for _, file in ipairs(ast.files or {}) do
		local ctx = { file = file.path, hash = file.hash or "", editable = editable }
		out[#out + 1] = '<div class="me-file">' .. file.path .. "</div>"
		for _, group in ipairs(file.groups or {}) do
			if group.label then
				out[#out + 1] = '<div class="me-group">' .. escapeRml(group.label) .. "</div>"
			end
			for _, trigger in ipairs(group.triggers or {}) do
				out[#out + 1] = renderTrigger(trigger, ctx, style)
			end
		end
		-- Top-level: add a whole statement (a new trigger chain) to the file.
		local conditions = editable and ast.surface and ast.surface.conditions
		if conditions and #conditions > 0 and file.insert_trigger_at then
			out[#out + 1] = '<div class="me-add-row me-add-statement-row"><button class="me-button me-add-btn" data-add="statement" data-insert="'
				.. tostring(file.insert_trigger_at)
				.. '" data-file="' .. ctx.file .. '" data-hash="' .. ctx.hash .. '">+ add statement</button></div>'
		end
		if file.opaque and #file.opaque > 0 then
			out[#out + 1] = '<div class="me-opaque">' .. #file.opaque
				.. " unrecognized span(s) — see bar-mission-kit check</div>"
		end
	end
	return table.concat(out)
end

--------------------------------------------------------------------------------
-- The intent channel: filesystem out, regeneration back.
--------------------------------------------------------------------------------

---Mode switch to code: ask the serve process to open the file in the IDE.
---@param filePath string
---@param line number
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

---Flush debounced field edits. The last value within a field's window wins;
---serve validates through the recognizer before any byte lands.
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

local function closeModal()
	local modal = document and document:GetElementById("me-modal")
	if modal then
		modal.style.display = "none"
	end
end

---The swap modal: pick a new shape for this step from the surface pool.
---Replacing is destructive to the step's current content, so it gets a
---deliberate modal moment rather than an inline dropdown.
local function openSwapModal(button)
	local modal = document:GetElementById("me-modal")
	local titleEl = document:GetElementById("me-modal-title")
	local rowsEl = document:GetElementById("me-modal-rows")
	if not (modal and titleEl and rowsEl and currentAst and currentAst.surface) then
		return
	end
	local poolName = button:GetAttribute("data-pool")
	local pool = currentAst.surface[poolName]
	if not pool then
		return
	end
	titleEl.inner_rml = poolName == "conditions" and "Swap condition" or "Swap effect"
	local out = {}
	for _, entry in ipairs(pool) do
		out[#out + 1] = '<div class="me-modal-row" data-value="' .. escapeRml(entry.template) .. '">'
			.. escapeRml(entry.label) .. "</div>"
	end
	rowsEl.inner_rml = table.concat(out)
	local swap = {
		file = button:GetAttribute("data-file"),
		start = tonumber(button:GetAttribute("data-swap-start")),
		finish = tonumber(button:GetAttribute("data-swap-end")),
		hash = button:GetAttribute("data-hash"),
	}
	local divs = rowsEl:GetElementsByTagName("div")
	for i = 1, #divs do
		local row = divs[i]
		row:AddEventListener("click", function()
			writeEditIntent({
				file = swap.file,
				start = swap.start,
				finish = swap.finish,
				hash = swap.hash,
				quote = false,
				value = "(" .. tostring(row:GetAttribute("data-value") or "") .. ")",
			})
			closeModal()
		end)
	end
	modal.style.display = "block"
end

---The add modal: the whole vocabulary in one structured place. Step mode
---offers WHEN rows (AndWhen into this trigger) and DO rows (effects);
---statement mode starts a new chain from a condition. Grouped headers keep
---it legible as the surface vocabulary grows.
local function openAddModal(button)
	local modal = document:GetElementById("me-modal")
	local titleEl = document:GetElementById("me-modal-title")
	local rowsEl = document:GetElementById("me-modal-rows")
	if not (modal and titleEl and rowsEl and currentAst and currentAst.surface) then
		return
	end
	local mode = button:GetAttribute("data-add")
	local surface = currentAst.surface
	local out = {}
	if mode == "statement" then
		titleEl.inner_rml = "New statement"
		out[#out + 1] = '<div class="me-modal-group">STARTS WHEN...</div>'
		for _, condition in ipairs(surface.conditions or {}) do
			out[#out + 1] = '<div class="me-modal-row" data-kind="trigger" data-value="'
				.. escapeRml(condition.template) .. '">' .. escapeRml(condition.label) .. "</div>"
		end
	else
		titleEl.inner_rml = "Add to this trigger"
		out[#out + 1] = '<div class="me-modal-group">WHEN &#183; more conditions (all must hold)</div>'
		for _, condition in ipairs(surface.conditions or {}) do
			out[#out + 1] = '<div class="me-modal-row" data-kind="andwhen" data-value="'
				.. escapeRml(condition.template) .. '">' .. escapeRml(condition.label) .. "</div>"
		end
		out[#out + 1] = '<div class="me-modal-group">DO &#183; effects</div>'
		for _, effect in ipairs(surface.effects or {}) do
			out[#out + 1] = '<div class="me-modal-row" data-kind="effect" data-value="'
				.. escapeRml(effect.template) .. '">' .. escapeRml(effect.label) .. "</div>"
		end
	end
	rowsEl.inner_rml = table.concat(out)
	local target = {
		file = button:GetAttribute("data-file"),
		hash = button:GetAttribute("data-hash"),
		insert = tonumber(button:GetAttribute("data-insert")),
		insertCond = tonumber(button:GetAttribute("data-insert-cond")),
		insertEffect = tonumber(button:GetAttribute("data-insert-effect")),
	}
	local divs = rowsEl:GetElementsByTagName("div")
	for i = 1, #divs do
		local row = divs[i]
		if tostring(row:GetAttribute("class") or ""):find("me-modal-row", 1, true) then
			row:AddEventListener("click", function()
				local value = tostring(row:GetAttribute("data-value") or "")
				local kind = row:GetAttribute("data-kind")
				local at, newText
				if kind == "trigger" then
					at = target.insert
					newText = "\nT.When(" .. value .. ")\n"
						.. '\t.Do(Objective("new_objective").Complete())\n'
						.. "\t.Register()\n"
				elseif kind == "andwhen" then
					at = target.insertCond
					newText = "\t.AndWhen(" .. value .. ")\n"
				else
					at = target.insertEffect
					newText = "\t.Do(" .. value .. ")\n"
				end
				if at then
					writeEditIntent({
						file = target.file,
						start = at,
						finish = at,
						hash = target.hash,
						quote = false,
						value = newText,
					})
				end
				closeModal()
			end)
		end
	end
	modal.style.display = "block"
end

local function attachFormControls()
	local content = document:GetElementById("me-content")
	if not content then
		return
	end
	local inputs = content:GetElementsByTagName("input")
	for i = 1, #inputs do
		local input = inputs[i]
		-- Printable keys only reach RmlUi inputs while SDL text-input mode
		-- is on (gui_chat does the same dance); backspace is a plain keydown,
		-- which is why deleting worked while typing did not.
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
		if button:GetAttribute("data-pool") then
			button:AddEventListener("click", function()
				openSwapModal(button)
			end)
		elseif button:GetAttribute("data-add") then
			button:AddEventListener("click", function()
				openAddModal(button)
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
		-- The dropdown widget's own option-click listeners don't fire for
		-- inner_rml-built selects in this build; selection driven
		-- programmatically works (verified), so arm the options ourselves.
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
			local value = tostring(select:GetAttribute("value") or "")
			Spring.Echo("[mission_editor] select -> " .. value)
			local insertAt = tonumber(select:GetAttribute("data-insert"))
			if insertAt then
				if value == "" then
					return
				end
				local kind = select:GetAttribute("data-kind")
				local newText
				if kind == "andwhen" then
					newText = "\t.AndWhen(" .. value .. ")\n"
				elseif kind == "trigger" then
					-- A whole new statement: complete legal chain, so the
					-- recognizer gate accepts it and the form re-renders it
					-- as an editable card.
					newText = "\nT.When(" .. value .. ")\n"
						.. '\t.Do(Objective("new_objective").Complete())\n'
						.. "\t.Register()\n"
				else
					newText = "\t.Do(" .. value .. ")\n"
				end
				writeEditIntent({
					file = select:GetAttribute("data-file"),
					start = insertAt,
					finish = insertAt,
					hash = select:GetAttribute("data-hash"),
					quote = false,
					value = newText,
				})
				return
			end
			-- Dropdown value edits apply on the next Update tick.
			queueFieldEdit(select, value, 0)
		end)
	end
end

--------------------------------------------------------------------------------
-- Panel state
--------------------------------------------------------------------------------

local function serveStatusLine()
	local text = VFS.LoadFile(STATUS_PATH, VFS.RAW_FIRST)
	if not text then
		return nil
	end
	local ok, status = pcall(Json.decode, text)
	if not ok or type(status) ~= "table" or status.ok then
		return nil
	end
	return '<div class="me-opaque">' .. escapeRml(status.message) .. "</div>"
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
		attachFormControls()
	end
end

---The text-mode billboard: BIG header + serve status + the mission in
---display notation, read-only — the same renderer the form uses.
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
	local width = math.floor(500 * scale)
	root.style.left = tostring(math.max(0, vsx - width - 40)) .. "px"
	root.style.width = tostring(width) .. "px"
	root.style["font-size"] = tostring(math.floor(16 * scale)) .. "px"
end

function widget:ViewResize()
	if document and visible then
		applyViewLayout()
	end
end

---Form mode shows the cards; text mode collapses to the billboard while the
---real IDE owns the file. Both are the same document — the panel never
---closes on a mode switch.
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
	Spring.Echo("[mission_editor] build bcfda03646")
	return true
end

function widget:Shutdown()
	widgetHandler.actionHandler:RemoveAction(self, "mission", "t")
	if document then
		document:Close()
		document = nil
	end
end
