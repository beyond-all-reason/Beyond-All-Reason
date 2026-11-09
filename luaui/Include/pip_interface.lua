-- What the Picture-in-Picture's interface shows, whichever look draws it (pip_view.lua is the regular one):
-- which buttons are there, which are on, their tooltips, the tracked player's name and resources.

local M = {}

---@param ui table the window's state tables (render, config, uiState, ...); gets the functions below added
---@return table ui
function M.new(ui)
	local render, config, state = ui.render, ui.config, ui.state
	local uiState, interactionState, miscState = ui.uiState, ui.interactionState, ui.miscState
	local cameraState, pools, spFunc = ui.cameraState, ui.pools, ui.spFunc
	local buttons, getActionHotkey, getAliveTeammates = ui.buttons, ui.getActionHotkey, ui.getAliveTeammates
	local pipNumber, isMinimapMode, isSinglePlayer = ui.pipNumber, ui.isMinimapMode, ui.isSinglePlayer

	ui.selCount = 0 -- selected units, set once a frame

	local function buttonShown(btn, spec, fullview, showPlayerTrack)
		local command = btn.command
		if isMinimapMode then
			if config.minimapModeHideMoveResize and btn.tooltipKey == "ui.pip.move" then
				return false
			end
			if command == "pip_switch" or command == "pip_copy" or (command == "pip_view" and not fullview) then
				return false
			end
		end
		if command == "pip_track" then
			return not isMinimapMode and (ui.selCount > 0 or interactionState.areTracking ~= nil)
		elseif command == "pip_trackplayer" then
			return showPlayerTrack and not miscState.tvEnabled
		elseif command == "pip_view" then
			return spec
		elseif command == "pip_activity" then
			return not isSinglePlayer
				and not interactionState.trackingPlayerID
				and not miscState.tvEnabled
				and not (config.activityFocusHideForSpectators and cameraState.mySpecState)
		elseif command == "pip_tv" then
			return not config.tvModeSpectatorsOnly or cameraState.mySpecState
		elseif command == "pip_history" then
			return config.historyEnabled and miscState.hist.store
		end
		return true
	end

	-- fills list with the buttons on show, in order
	---@param list table
	---@return table list
	function ui.ComputeVisibleButtons(list)
		for k in pairs(list) do
			list[k] = nil
		end
		local spec, fullview = Spring.GetSpectatingState()
		local showPlayerTrack = interactionState.trackingPlayerID ~= nil
			or spec
			or #getAliveTeammates(pools.aliveTeammates) > 0
		local n = 0
		for i = 1, #buttons do
			if buttonShown(buttons[i], spec, fullview, showPlayerTrack) then
				n = n + 1
				list[n] = buttons[i]
			end
		end
		return list
	end

	-- pools.visibleButtons, at most 4 times a second (the rules query player state) or when
	-- something cheap to check says it changed
	function ui.RefreshVisibleButtons()
		local stateKey = (ui.selCount > 0 and 1 or 0)
			+ (interactionState.areTracking and 2 or 0)
			+ (interactionState.trackingPlayerID and 4 or 0)
			+ (miscState.tvEnabled and 8 or 0)
			+ (state.losViewEnabled and 16 or 0)
			+ (miscState.activityFocusEnabled and 32 or 0)
		local now = os.clock()
		if now >= (miscState.visibleButtonsNextUpdate or 0) or miscState.visibleButtonsStateKey ~= stateKey then
			miscState.visibleButtonsNextUpdate = now + 0.25
			miscState.visibleButtonsStateKey = stateKey
			ui.ComputeVisibleButtons(pools.visibleButtons)
		end
	end

	---@param btn table
	---@return boolean
	function ui.IsButtonActive(btn)
		local command = btn.command
		if command == "pip_track" then
			return interactionState.areTracking and true or false
		elseif command == "pip_trackplayer" then
			return interactionState.trackingPlayerID and true or false
		elseif command == "pip_view" then
			return state.losViewEnabled and true or false
		elseif command == "pip_activity" then
			return miscState.activityFocusEnabled and true or false
		elseif command == "pip_tv" then
			return miscState.tvEnabled and true or false
		elseif command == "pip_history" then
			return miscState.hist.shown and true or false
		end
		return false
	end

	---@param btn table
	---@return string
	function ui.ButtonTooltip(btn)
		local key = ui.IsButtonActive(btn) and btn.tooltipActiveKey or btn.tooltipKey
		local text = key and BAR.I18N(key) or ""
		if btn.command == "pip_help" and config.leftButtonPansCamera then
			text = text .. BAR.I18N("ui.pip.help_leftclick")
		end
		local suppressShortcut = isMinimapMode and btn.command == "pip_track"
		local shortcut = not suppressShortcut and btn.actionName and getActionHotkey(btn.actionName)
		if shortcut and shortcut ~= "" then
			text = text .. "\n" .. shortcut
		end
		return text
	end

	---@param text string
	function ui.ShowTooltip(text)
		if WG.tooltip then
			WG.tooltip.ShowTooltip("pip" .. pipNumber, text, nil, nil, nil)
		end
	end

	-- the buttons for a frame around the minimap to draw: { command, texture, active, tooltip } (a reused list)
	---@return table[]
	function ui.FrameButtons()
		local list, n = miscState.frameButtons, 0
		for _, btn in ipairs(pools.visibleButtons) do
			n = n + 1
			local entry = list[n] or {}
			list[n] = entry
			entry.command, entry.texture, entry.active, entry.tooltip =
				btn.command, btn.texture, ui.IsButtonActive(btn), ui.ButtonTooltip(btn)
		end
		for i = n + 1, #list do
			list[i] = nil
		end
		return list
	end

	-- the angle turning the minimize / maximize arrow towards where the window grows
	---@return number degrees
	function ui.MaximizeIconRotation()
		-- Determine expansion direction based on current or minimize button position
		local sw, sh = Spring.GetWindowGeometry()
		local posL, posB

		-- Use current position when maximized (for minimize button rotation during drag/resize)
		-- Use minMode position when minimized (for maximize button rotation)
		if uiState.inMinMode then
			posL = uiState.minModeL
			posB = uiState.minModeB
		else
			-- When maximized, determine where it would minimize to based on current position
			local buttonSize = math.floor(render.usedButtonSize * config.maximizeSizemult)
			if render.dim.l < sw * 0.5 then
				posL = render.dim.l
			else
				posL = render.dim.r - buttonSize
			end
			if render.dim.b < sh * 0.25 then
				posB = render.dim.b
			else
				posB = render.dim.t - buttonSize
			end
		end

		local onLeftSide = (posL and posL < sw * 0.5)
		local onBottomSide = (posB and posB < sh * 0.25)

		-- Default icon points to bottom-left, rotate to point toward expansion:
		if onLeftSide and onBottomSide then
			return 180 -- Bottom-left: expands toward top-right
		elseif not onLeftSide and onBottomSide then
			return 270 -- Bottom-right: expands toward top-left
		elseif not onLeftSide and not onBottomSide then
			return 0 -- Top-right: expands toward bottom-left
		else -- onLeftSide and not onBottomSide
			return 90 -- Top-left: expands toward bottom-right
		end
	end

	local timelineHover = {}

	-- what the mouse is over on the rewind timeline (a reused table): inBand, play, live, speed, track, tooltipKey
	---@param lay table the timeline's layout
	---@param mx number
	---@param my number
	---@return table
	function ui.TimelineHover(lay, mx, my)
		local hist = miscState.hist
		local h = timelineHover
		h.inBand = my >= lay.b and my <= lay.t and mx >= lay.l and mx <= lay.r
		h.play = hist.mode and h.inBand and mx >= lay.playL and mx <= lay.playR
		h.live = hist.mode and h.inBand and mx >= lay.liveL and mx <= lay.liveR
		h.speed = h.inBand and mx >= lay.speedL and mx <= lay.speedR
		h.track = h.inBand and mx >= lay.trackL and mx <= lay.trackR
		h.tooltipKey = nil
		if h.play then
			h.tooltipKey = (hist.mode and hist.playing) and "ui.pip.history_pause" or "ui.pip.history_play"
		elseif h.live then
			h.tooltipKey = "ui.pip.history_live"
		elseif h.speed then
			h.tooltipKey = "ui.pip.history_speed"
		elseif h.track then
			h.tooltipKey = "ui.pip.history_track"
		end
		return h
	end

	-- the name above the map while the mouse is over a window tracking a player
	---@return string? name
	---@return number? teamID
	function ui.TrackedPlayerName()
		if not (interactionState.trackingPlayerID and interactionState.isMouseOverPip) then
			return nil
		end
		local playerName, _, _, teamID = spFunc.GetPlayerInfo(interactionState.trackingPlayerID, false)
		if not (playerName and teamID) then
			return nil
		end
		-- Get display name (may be modified by playernames widget)
		if WG.playernames and WG.playernames.getPlayername then
			playerName = WG.playernames.getPlayername(interactionState.trackingPlayerID)
		end
		return playerName, teamID
	end

	local trackedResources = {}

	-- the tracked player's resources while the mouse is off the window (a reused table), nil when nothing to show
	---@return table?
	function ui.TrackedResources()
		if not interactionState.trackingPlayerID or interactionState.isMouseOverPip then
			return nil
		end
		local _, _, _, teamID = spFunc.GetPlayerInfo(interactionState.trackingPlayerID, false)
		if not teamID then
			return nil
		end

		local hist = miscState.hist ---@type PipHistState
		local t = trackedResources
		if hist.mode then
			-- Rewinding: the resources recorded at the viewed frame (no bars when the log has none)
			local r = hist.TeamResources(teamID)
			if not r then
				return nil
			end
			t.metalCur, t.metalMax, t.metalPull, t.metalIncome, t.metalShare = r[1], r[2], r[3], r[4], r[5]
			t.energyCur, t.energyMax, t.energyPull, t.energyIncome, t.energyShare = r[6], r[7], r[8], r[9], r[10]
			t.mmLevel = r[11]
		else
			-- Get team resources - this works for spectators viewing any team
			-- Returns: current, storage, pull, income, expense, share
			local _
			t.metalCur, t.metalMax, t.metalPull, t.metalIncome, _, t.metalShare =
				Spring.GetTeamResources(teamID, "metal")
			t.energyCur, t.energyMax, t.energyPull, t.energyIncome, _, t.energyShare =
				Spring.GetTeamResources(teamID, "energy")
			if not (t.metalCur and t.energyCur) then
				return nil
			end

			-- Get energy conversion level (mmLevel)
			t.mmLevel = Spring.GetTeamRulesParam(teamID, "mmLevel")
			if t.mmLevel == nil then
				t.mmLevel = 1
			end
		end

		-- Check if player has teammates (for share slider)
		local _, _, _, _, _, allyTeamID = Spring.GetTeamInfo(teamID, false)
		local allyTeamList = Spring.GetTeamList(allyTeamID)
		t.hasTeammates = allyTeamList and #allyTeamList > 1
		return t
	end

	return ui
end

return M
