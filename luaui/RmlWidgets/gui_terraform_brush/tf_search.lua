--- Terraform Brush search: every named control of every tool, found from one field.
---
--- The index is read off the document once: each control's label, its hint, and where it
--- lives (tool, window, section). A query lists the matches, keeps only the panel's sections
--- that hold one, and dims the tools that hold none.

local M = {}

M.MAX_ROWS = 40
local ROW_ID, ROW_PATTERN = "tf-search-row-", "^tf%-search%-row%-(%d+)$"
local FLASH_SECONDS = 2.5
-- Frames a tool switch needs before its controls are laid out.
local GO_FRAMES = 3
local TOOL_EXPR = "^activeTool == '(%w+)'$"
local LABEL_CLASSES = ".tf-btn-text, .tf-overlay-chip-label, .tf-action-btn-text"
local CONTROL_CLASSES =
	".tf-mode-btn, .tf-overlay-chip, .tf-action-btn, .tf-file-menu-item, .tf-header-btn, .tf-sample-btn"

---@class TfSearchEntry
---@field id string
---@field label string
---@field hay string lowercase text a query is matched against
---@field where string "TOOL > SECTION", for the result row
---@field tool string? the tool code its panel shows under
---@field window string? the floating window's root id
---@field frames string[] ids of the section frames around it, innermost first

--- Markup as the text a player reads.
---@param rml string?
---@return string
function M.plain(rml)
	local text =
		tostring(rml or ""):gsub("<[^>]*>", " "):gsub("{{[^}]*}}", " "):gsub("&amp;", "&"):gsub("&[%w#]+;", " ")
	return (text:gsub("%s+", " "):gsub("^ ", ""):gsub(" $", ""))
end

--- A name for a control with no text of its own, from its id.
---@param id string
---@return string
function M.nameFromId(id)
	local name = id:gsub("^btn%-", ""):gsub("^slider%-", ""):gsub("^img%-", ""):gsub("%-", " ")
	return name:upper()
end

--- The query's words, lowercase.
---@param text string?
---@return string[]
function M.words(text)
	local out = {}
	for word in tostring(text or ""):lower():gmatch("%S+") do
		out[#out + 1] = word
	end
	return out
end

--- How well an entry answers the words: nil when one is missing, lower is better.
---@param entry TfSearchEntry
---@param words string[]
---@return number?
function M.score(entry, words)
	local label = entry.label:lower()
	local score = 0
	for _, word in ipairs(words) do
		local at = label:find(word, 1, true)
		-- outside the label a word must be 3 letters or more and start a word
		if not at and (#word < 3 or not entry.hay:find("%f[%w]" .. word:gsub("%p", "%%%0"))) then
			return nil
		end
		score = score + (at == 1 and 0 or at and 1 or 3)
	end
	return score
end

--- The entries a query finds, best first; all of them counted, at most `limit` returned.
---@param index TfSearchEntry[]
---@param text string?
---@param limit integer?
---@return TfSearchEntry[] hits, integer total
function M.find(index, text, limit)
	local words = M.words(text)
	if #words == 0 then
		return {}, 0
	end
	local scored = {}
	for order, entry in ipairs(index) do
		local score = M.score(entry, words)
		if score then
			scored[#scored + 1] = { entry = entry, score = score, order = order }
		end
	end
	table.sort(scored, function(a, b)
		if a.score ~= b.score then
			return a.score < b.score
		end
		return a.order < b.order
	end)
	local hits = {}
	for i = 1, math.min(#scored, limit or #scored) do
		hits[i] = scored[i].entry
	end
	return hits, #scored
end

--------------------------------------------------------------------------------
-- The document side.
--------------------------------------------------------------------------------

---@class TfSearchDeps
---@field doc fun(): table? the panel's document
---@field model fun(): table? the data model handle
---@field hints table<string, string> control id -> hint
---@field windows table<string, string> floating window root id -> its data-model flag
---@field windowTools table<string, string> floating window root id -> the tool it needs
---@field open fun(window: string) brings a floating window up
---@field call fun(handler: string) runs a data-model event handler by name

local deps ---@type TfSearchDeps?
local index ---@type TfSearchEntry[]?
local toolButtons = {} ---@type table<string, string> tool code -> button id
local modeButtons = {} ---@type { id: string, tool: string?, frames: string[] }[]
local panelFrames = {} ---@type string[] section frames of the main panel
local marked = { hits = {}, frames = {} } ---@type { hits: string[], frames: string[] }
local shownHits = {} ---@type TfSearchEntry[]
local query = ""
local pending ---@type { id: string, frames: integer, window: string?, wait: integer?, flashUntil: number? }?
local revealed = {} ---@type string[] folded window sections a result opened

local function escape(text)
	return (text:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
end

--- Where an element lives: its tool, its window and the section frames around it.
local function homeOf(el, windows)
	local tool, window, frames = nil, nil, {}
	local node = el
	while node do
		local id = node.id
		if id and id ~= "" then
			if windows[id] then
				window = window or id
			end
			if node:IsClassSet("tf-section-frame") then
				frames[#frames + 1] = id
			end
		end
		local shownIf = node:GetAttribute("data-if")
		if shownIf and not tool then
			tool = shownIf:match(TOOL_EXPR)
		end
		node = node.parent_node
	end
	return tool, window, frames
end

--- A selector's matches as a plain list (the engine hands back a 1-based proxy).
local function all(holder, selector)
	local found = holder and holder:QuerySelectorAll(selector)
	local out = {}
	for i = 1, found and #found or 0 do
		out[i] = found[i]
	end
	return out
end

--- A control's own name: its label child when it has one (a button also holds its key badge).
local function labelOf(el)
	local own = el:QuerySelector(LABEL_CLASSES)
	return M.plain((own or el).inner_rml)
end

local function titleIn(doc, id, selector)
	local holder = id and doc:GetElementById(id)
	local title = holder and holder:QuerySelector(selector)
	return title and M.plain(title.inner_rml) or ""
end

local function build()
	local doc = deps and deps.doc()
	if not (deps and doc) then
		return nil
	end
	local built = {} ---@type TfSearchEntry[]
	local seen = {} ---@type table<string, boolean>
	local titles = {} ---@type table<string, string>
	toolButtons, modeButtons, panelFrames = {}, {}, {}

	local toolNames = {} ---@type table<string, string>
	for _, button in ipairs(all(doc, ".tf-mode-btn")) do
		local id = button.id
		if id and id ~= "" then
			local tool = (button:GetAttribute("data-class-active") or ""):match(TOOL_EXPR)
			local _, _, frames = homeOf(button, deps.windows)
			modeButtons[#modeButtons + 1] = { id = id, tool = tool, frames = frames }
			if tool then
				toolButtons[tool] = id
				toolNames[tool] = labelOf(button)
			end
		end
	end

	local function title(id, selector)
		local key = id .. selector
		if titles[key] == nil then
			titles[key] = titleIn(doc, id, selector)
		end
		return titles[key]
	end

	local function add(el)
		local id = el and el.id
		if not id or id == "" or seen[id] or id:find("^tf%-search") then
			return
		end
		seen[id] = true
		local hint = deps.hints[id] or ""
		local label = labelOf(el)
		if label == "" or #label > 40 then
			label = M.nameFromId(id)
		end
		local tool, window, frames = homeOf(el, deps.windows)
		local section = frames[1] and title(frames[1], ".tf-collapsible-title") or ""
		local place = window and title(window, ".tf-drag-handle") or tool and toolNames[tool] or ""
		local where = place
		if section ~= "" and section:lower() ~= label:lower() then
			where = where ~= "" and (where .. " > " .. section) or section
		end
		built[#built + 1] = {
			id = id,
			label = label,
			hay = (label .. " " .. hint .. " " .. section .. " " .. place):lower(),
			where = where,
			tool = tool,
			window = window,
			frames = frames,
		}
	end

	for _, el in ipairs(all(doc, CONTROL_CLASSES)) do
		add(el)
	end
	for id in pairs(deps.hints) do
		add(doc:GetElementById(id))
	end

	for _, frame in ipairs(all(doc:GetElementById("tf-root"), ".tf-section-frame")) do
		if frame.id and frame.id ~= "" then
			panelFrames[#panelFrames + 1] = frame.id
		end
	end
	return built
end

local function setClass(doc, id, class, on)
	local el = doc:GetElementById(id)
	if el then
		el:SetClass(class, on)
	end
end

local function sectionOf(frameId)
	return (frameId:gsub("^frame%-", "section-", 1))
end

--- The result rows, and the panel filtered to what the query found.
local function show(doc, hits, total)
	for _, id in ipairs(marked.hits) do
		setClass(doc, id, "tf-search-hit", false)
	end
	for _, id in ipairs(marked.frames) do
		setClass(doc, sectionOf(id), "tf-search-open", false)
	end
	marked.hits, marked.frames = {}, {}

	local searching = query ~= ""
	setClass(doc, "tf-root", "tf-searching", searching)
	setClass(doc, "tf-search-hint", "hidden", searching)
	local toolHit = {} ---@type table<string, boolean>
	local frameHit = {} ---@type table<string, boolean>
	local idHit = {} ---@type table<string, boolean>
	local rows = {}
	-- panel results first, then the ones that open a window
	local ordered, firstWindow = {}, nil
	for _, entry in ipairs(hits) do
		if not entry.window then
			ordered[#ordered + 1] = entry
		end
	end
	for _, entry in ipairs(hits) do
		if entry.window then
			firstWindow = firstWindow or #ordered + 1
			ordered[#ordered + 1] = entry
		end
	end
	hits = ordered
	for n, entry in ipairs(hits) do
		if n == 1 and not entry.window then
			rows[#rows + 1] = '<div class="tf-search-group">IN THIS PANEL</div>'
		elseif n == firstWindow then
			rows[#rows + 1] = '<div class="tf-search-group">OPENS A WINDOW</div>'
		end
		idHit[entry.id] = true
		if entry.tool then
			toolHit[entry.tool] = true
		end
		if not entry.window then
			for _, frame in ipairs(entry.frames) do
				frameHit[frame] = true
			end
			setClass(doc, entry.id, "tf-search-hit", true)
			marked.hits[#marked.hits + 1] = entry.id
		end
		rows[#rows + 1] = string.format(
			'<div id="%s%d" class="tf-search-row"><div class="tf-search-row-label">%s</div><div class="tf-search-row-where">%s</div></div>',
			ROW_ID,
			n,
			escape(entry.label),
			escape(entry.where)
		)
	end
	if searching and #hits == 0 then
		rows[1] = '<div class="tf-search-none">Nothing found.</div>'
	elseif total > #hits then
		rows[#rows + 1] = string.format('<div class="tf-search-none">%d more: type another word.</div>', total - #hits)
	end
	shownHits = hits
	local list = doc:GetElementById("tf-search-results")
	if list then
		list.inner_rml = table.concat(rows)
		list:SetClass("hidden", not searching)
	end

	-- A tool that holds a match stays lit, and so its grid stays up.
	for _, button in ipairs(modeButtons) do
		local keeps = idHit[button.id] or (button.tool and toolHit[button.tool])
		setClass(doc, button.id, "tf-search-dim", searching and not keeps)
		if keeps then
			for _, frame in ipairs(button.frames) do
				frameHit[frame] = true
			end
		end
	end
	for _, frame in ipairs(panelFrames) do
		setClass(doc, frame, "tf-search-miss", searching and not frameHit[frame])
		if searching and frameHit[frame] then
			setClass(doc, sectionOf(frame), "tf-search-open", true)
			marked.frames[#marked.frames + 1] = frame
		end
	end
end

--- Takes the flash off the control the last result went to.
local function dropFlash(doc)
	if pending then
		setClass(doc, pending.id, "tf-search-flash", false)
		pending = nil
	end
end

--- The field changed: list what it finds and filter the panel.
---@param text string?
function M.setQuery(text)
	local doc = deps and deps.doc()
	if not doc then
		return
	end
	query = M.plain(text)
	if query ~= "" and not index then
		index = build()
	end
	local hits, total = M.find(index or {}, query, M.MAX_ROWS)
	show(doc, hits, total)
end

--- Empties the field and puts the panel back.
function M.clear()
	local doc = deps and deps.doc()
	local input = doc and doc:GetElementById("tf-search-input")
	if input then
		input:SetAttribute("value", "")
	end
	if doc then
		dropFlash(doc)
		for _, id in ipairs(revealed) do
			setClass(doc, id, "tf-search-reveal", false)
		end
		revealed = {}
	end
	M.setQuery("")
end

---@return string
function M.query()
	return query
end

--- Result row `n`: its tool or window opens, then the control scrolls into view and flashes.
---@param n integer
---@return boolean
function M.go(n)
	local entry = shownHits[n]
	local model = deps and deps.model()
	local doc = deps and deps.doc()
	if not (entry and deps and model and doc) then
		return false
	end
	dropFlash(doc)
	local tool = entry.tool or (entry.window and deps.windowTools[entry.window])
	local switched = tool ~= nil and model.activeTool ~= tool
	local button = switched and doc:GetElementById(toolButtons[tool] or "")
	local handler = button and (button:GetAttribute("data-event-mousedown") or ""):match("^%s*([%w_]+)%(")
	if handler then
		deps.call(handler)
	end
	if entry.window then
		for _, frame in ipairs(entry.frames) do
			local section = sectionOf(frame)
			setClass(doc, section, "tf-search-reveal", true)
			revealed[#revealed + 1] = section
		end
	end
	-- a window opens once its tool is up
	pending = { id = entry.id, frames = GO_FRAMES, window = entry.window, wait = switched and GO_FRAMES or 0 }
	return true
end

--- Each frame: a control a result asked for is scrolled to once laid out, then stops flashing.
function M.tick()
	local going = pending
	local doc = going and deps and deps.doc()
	if not (going and doc) then
		return
	end
	if going.window then
		if (going.wait or 0) > 0 then
			going.wait = going.wait - 1
			return
		end
		if deps and not (deps.model() or {})[deps.windows[going.window]] then
			deps.open(going.window)
		end
		going.window = nil
	elseif going.frames > 0 then
		going.frames = going.frames - 1
		if going.frames == 0 then
			local el = doc:GetElementById(going.id)
			if el then
				el:ScrollIntoView()
				el:SetClass("tf-search-flash", true)
			end
			going.flashUntil = os.clock() + FLASH_SECONDS
		end
	elseif os.clock() >= (going.flashUntil or 0) then
		setClass(doc, going.id, "tf-search-flash", false)
		pending = nil
	end
end

--- Once the document is up.
---@param d TfSearchDeps
function M.attach(d)
	deps, index, query, pending, revealed = d, nil, "", nil, {}
	marked, shownHits = { hits = {}, frames = {} }, {}
	local doc = d.doc()
	local list = doc and doc:GetElementById("tf-search-results")
	if not list then
		return
	end
	list:AddEventListener("mousedown", function(event)
		local node = event.target_element
		while node do
			local n = tostring(node.id or ""):match(ROW_PATTERN)
			if n then
				M.go(tonumber(n) or 0)
				return
			end
			node = node.parent_node
		end
	end, false)
end

return M
