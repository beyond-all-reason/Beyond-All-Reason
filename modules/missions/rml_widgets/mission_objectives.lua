-- Player-facing: unlike the editor this loads for everyone — a mission's
-- objectives are the game, not tooling. It just has nothing to draw until a
-- mission arms.
if not RmlUi then
	return
end

local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Mission Objectives",
		desc = "Quest-log corner for the active mission: draws revealed objectives from rulesparams, titles from the mission manifest",
		author = "Beyond All Reason",
		date = "August 2026",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

-- Read-only terminal of the loader's rulesparams — the whole board is
-- derived, never curated here: objective_display_order says what exists and
-- in what order, objective_title_<id> how to word it, objective_revealed_<id>
-- that a line is drawn, objective_<id> that it is done, and
-- objective_foreshadow_<id> that it is drawn greyed-out even before its
-- reveal. All published by mission_loader from the mission's objectives.lua
-- declarations; nothing here decides anything.

local RML_PATH = "modules/missions/rml_widgets/mission_objectives.rml"
local POLL_SECONDS = 0.5

local document
local listElement
local shown = false
local lobbyHidden = false -- true while the lobby/menu overlay is up (LobbyOverlayActive)
local pollAccumulator = 0
local lastStateKey = nil

local function prettify(id)
	return (id:gsub("_", " "))
end

---Objectives in display order. A mission without an objectives.lua declares
---no board; any objective it reveals by hand still draws, prettified and
---ordered alphabetically.
---@return { title: string, state: "done"|"active"|"pending" }[]
local function collectRows()
	local rows = {}
	local function add(id, title, foreshadow)
		local revealed = Spring.GetGameRulesParam("objective_revealed_" .. id) == 1
		if revealed then
			rows[#rows + 1] = {
				title = title,
				state = Spring.GetGameRulesParam("objective_" .. id) == 1 and "done" or "active",
			}
		elseif foreshadow then
			rows[#rows + 1] = { title = title, state = "pending" }
		end
	end
	local order = Spring.GetGameRulesParam("objective_display_order")
	if type(order) == "string" and order ~= "" then
		for id in order:gmatch("[^,]+") do
			local title = Spring.GetGameRulesParam("objective_title_" .. id)
			add(
				id,
				type(title) == "string" and title or prettify(id),
				Spring.GetGameRulesParam("objective_foreshadow_" .. id) == 1
			)
		end
	else
		local ids = {}
		for name in pairs(Spring.GetGameRulesParams()) do
			local id = name:match("^objective_revealed_(.+)$")
			if id then
				ids[#ids + 1] = id
			end
		end
		table.sort(ids)
		for _, id in ipairs(ids) do
			add(id, prettify(id))
		end
	end
	return rows
end

local function escape(text)
	return (text:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
end

local ROW_CLASS = { done = " mo-done", active = "", pending = " mo-pending" }

local function render(rows)
	local parts = {}
	for _, row in ipairs(rows) do
		-- The mark is an empty span the stylesheet draws (a dot, colored by
		-- state) — no glyph, so no bet on the game font's coverage.
		parts[#parts + 1] = string.format(
			'<div class="mo-row%s"><span class="mo-mark"></span><span>%s</span></div>',
			ROW_CLASS[row.state],
			escape(row.title)
		)
	end
	listElement.inner_rml = table.concat(parts)
end

---vw units resolve to 0 in this RmlUi build, and `right:` anchors to the
---body box, not the viewport — so the corner is computed from real view
---geometry, the same way the editor places itself.
local function applyViewLayout()
	local root = document and document:GetElementById("mo-root")
	if not root then
		return
	end
	local vsx, vsy = Spring.GetViewGeometry()
	local scale = math.max(0.9, math.min(1.8, vsy / 1080))
	local width = math.floor(320 * scale)
	root.style.left = tostring(math.max(0, vsx - width - 32)) .. "px"
	root.style.top = tostring(math.floor(140 * scale)) .. "px"
	root.style.width = tostring(width) .. "px"
	root.style["font-size"] = tostring(math.floor(15 * scale)) .. "px"
end

local function setShown(on)
	if on == shown then
		return
	end
	shown = on
	if on then
		applyViewLayout()
		if not lobbyHidden then
			-- Never take keyboard focus on show: a focused document eats TAB
			-- (and friends) that belong to the game.
			document:Show(RmlUi.RmlModalFlag.None, RmlUi.RmlFocusFlag.None)
		end
	else
		document:Hide()
	end
end

function widget:ViewResize()
	if document and shown then
		applyViewLayout()
	end
end

local function refresh()
	if Spring.GetGameRulesParam("mission_active") ~= 1 then
		setShown(false)
		lastStateKey = nil
		return
	end
	local rows = collectRows()
	if #rows == 0 then
		setShown(false)
		lastStateKey = nil
		return
	end
	local key = {}
	for _, row in ipairs(rows) do
		key[#key + 1] = row.title .. row.state
	end
	key = table.concat(key, "\n")
	if key ~= lastStateKey then
		lastStateKey = key
		render(rows)
	end
	setShown(true)
end

function widget:Update(dt)
	if not document then
		return
	end
	pollAccumulator = pollAccumulator + dt
	if pollAccumulator < POLL_SECONDS then
		return
	end
	pollAccumulator = 0
	refresh()
end

-- Hide while the lobby/menu overlay is up so the panel never draws over
-- Chobby (LobbyOverlayActive broadcast from barwidgets.lua).
function widget:RecvLuaMsg(message)
	if not document then
		return
	end
	if message:sub(1, 19) == "LobbyOverlayActive0" then
		lobbyHidden = false
		if shown then
			document:Show(RmlUi.RmlModalFlag.None, RmlUi.RmlFocusFlag.None)
		end
	elseif message:sub(1, 19) == "LobbyOverlayActive1" then
		lobbyHidden = true
		document:Hide()
	end
end

function widget:Initialize()
	local context = RmlUi.GetContext("shared")
	if not context then
		Spring.Echo("[mission_objectives] no shared RmlUi context — widget dead")
		return false
	end
	document = context:LoadDocument(RML_PATH)
	if not document then
		Spring.Echo("[mission_objectives] LoadDocument failed: " .. RML_PATH)
		return false
	end
	listElement = document:GetElementById("mo-list")
	if not listElement then
		Spring.Echo("[mission_objectives] document has no mo-list element")
		document:Close()
		document = nil
		return false
	end
	applyViewLayout()
	refresh()
end

function widget:Shutdown()
	if document then
		document:Close()
		document = nil
	end
end
