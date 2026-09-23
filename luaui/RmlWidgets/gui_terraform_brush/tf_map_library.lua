-- Model-first controls for the project browser and the Team Sync strip. No DOM
-- writes and no Git calls here: the widget draws the tree, the companion owns
-- Git, this file decides what the buttons mean.
local M = {}
local WG = WG

local text = VFS.Include("luaui/RmlWidgets/gui_terraform_brush/tf_strings.lua").text

-- "just now" / "3 min ago" / "2 h ago" / "4 d ago" for a seconds-ago count.
local function ageText(seconds, translate)
	seconds = tonumber(seconds) or 0
	if seconds < 60 then
		return translate("ageNow")
	elseif seconds < 3600 then
		return translate("ageMin", { n = math.floor(seconds / 60) })
	elseif seconds < 86400 then
		return translate("ageHours", { n = math.floor(seconds / 3600) })
	end
	return translate("ageDays", { n = math.floor(seconds / 86400) })
end
M.ageText = ageText

-- Result codes that are good news (green, and they fade out on their own).
local SUCCESS = { published = true, downloaded = true, pulled = true, moved = true, removed = true, allLocal = true }
-- Codes that are a state rather than an outcome: the strip says these, the
-- status slot does not repeat them.
local QUIET = { offline = true, ready = true, working = true }
local STATUS_HOLD = 8 -- seconds a success stays in the status slot
-- The companion build the panel needs. An older one running (the files on
-- disk were re-extracted, the process was not restarted) refuses newer
-- requests, so it is named as the reason.
local HELPER_MIN = 2

function M.new(widgetState, model, dependencies)
	local getMapProject = dependencies and dependencies.getMapProject or function()
		return WG.MapProject
	end
	local translate = dependencies and dependencies.translate or text
	local now = dependencies and dependencies.now or os.time
	local clock = dependencies and dependencies.clock or os.clock
	local ui = {}
	local generation, resultID, armed = -1, nil, nil
	local stageIndex = 1
	-- Last destination list handed to the UI, and its signature: the chips are
	-- drawn from it imperatively, so the widget is told when it moves.
	local stageList, stageKey = {}, nil
	local notice = nil
	local elapsed = 0
	local lastRemote = nil
	-- Status slot bookkeeping: what is showing, since when, and whether the
	-- user has already dismissed it or it has faded.
	local statusKey, statusShownAt, statusHidden = nil, nil, nil
	-- Team Sync strip: the session the strip last saw (a new one pulls once),
	-- and when the library was last known to be fresh.
	local lastSession, autoPull, lastPulled = nil, false, nil
	-- The last Save As outcome (from newSave), shown in the status slot until
	-- dismissed, faded, or replaced by the next companion result.
	local saveSeq, saveShowing = nil, false
	local labels = {
		"title",
		"pull",
		"upload",
		"publish",
		"confirmPublish",
		"download",
		"stage",
		"saveFirst",
		"cancel",
		"open",
		"delete",
		"confirmDelete",
		"search",
		"name",
		"size",
		"openWarning",
		"moveLater",
		"moveConfirm",
		"downloadAll",
		"deleteFolderWarning",
		"removeTeam",
		"confirmRemoveTeam",
		-- Browser chrome shared by both dialogs (column header, counts, the
		-- details pane and the two list hints).
		"filter",
		"modifiedCol",
		"createdCol",
		"detailsEmpty",
		"previewMap",
		"previewHeight",
		"saveDetailsEmpty",
		"startHelper",
		"startHelperHint",
		"legacyBadge",
		"currentBadge",
		"openListHint",
		"saveListHint",
		"filterLabel",
		"searchLabel",
		"newFolder",
		"newFolderHint",
		"create",
		"noStages",
		-- Team-view drag plan: the confirm bar and the two buttons that end it.
		"confirmMoves",
		"discardMoves",
		-- One browser: the filter chips, the two new columns, the Team Sync
		-- strip, the start card, the details pane's TEAM block.
		"filterAll",
		"filterLocal",
		"filterTeam",
		"filterAutosave",
		"quitTitle",
		"quitSaveAndGo",
		"quitSaveAs",
		"quitDiscard",
		"quitCancel",
		"mapCol",
		"syncCol",
		"syncName",
		"stripSetup",
		"cardTitle",
		"cardIntro",
		"cardStep1",
		"cardStep1Done",
		"cardStep2",
		"cardCopyPath",
		"cardCopied",
		"cardNeeds",
		"cardStep3",
		"cardClose",
		"teamHeader",
		"uploadTo",
		"updateTeam",
		"getTeam",
		"replaceMine",
		"moveTo",
		"stageMove",
		"confirmGetTeam",
		"confirmOpen",
		"deleteLocal",
		"dismiss",
		-- Rename: the button, the field's hint, the commit.
		"rename",
		"renameHint",
		"apply",
	}
	for _, key in ipairs(labels) do
		model["libraryLabel_" .. key] = translate(key)
	end
	model.libraryFilter = "all"
	model.libraryEnabled = false -- Settings > General > Team Sync
	model.libraryOnline = false
	model.libraryBusy = false
	model.libraryWritable = false
	model.libraryConfigured = false -- a companion has ever written status here
	model.libraryConfirming = false
	model.libraryUploadOpen = false
	model.libraryTrayMode = "upload" -- what the stage tray commits: upload | move
	model.libraryTrayTitle = ""
	model.libraryMoveOpen = false
	model.libraryMoveQuestion = ""
	model.libraryQueue = "" -- progress while the whole library is downloading
	model.libraryRemoveConfirming = false
	model.libraryGetConfirming = false
	-- Team moves staged by dragging, waiting to be confirmed as one act.
	model.libraryMovesPending = ""
	model.libraryMovesOpen = false
	model.libraryStage = ""
	model.libraryStatus = translate("offline")
	model.libraryStatusVisible = false
	model.libraryStatusError = false
	model.libraryStatusSuccess = false
	model.libraryStatusTime = ""
	model.libraryConnection = translate("offlineBadge")
	model.libraryRepository = ""
	model.libraryRemoteURL = ""
	model.libraryBranch = ""
	-- The strip: one dot, one line.
	model.libraryStripDot = "unset" -- unset | off | starting | on | busy
	model.libraryStripText = translate("stripUnset")
	model.libraryStripAge = ""
	-- The start card.
	model.libraryCardOpen = false
	model.libraryCardWritten = false
	model.libraryCardPath = ""
	model.libraryCardCopied = false

	local function library()
		local project = getMapProject()
		return project and project.library
	end

	local function clearSelection()
		armed = nil
		widgetState.projectOpenSelectedSlug = nil
		widgetState.projectOpenAfterDownload = nil
		widgetState.projectOpenArmed = nil
		widgetState.projectOpenNeedsRebuild = true
		local dm = widgetState.dmHandle
		if dm then
			dm.projectOpenSelected = ""
			dm.projectOpenIsFolder = false
			dm.projectInfoFolder = false
			dm.projectOpenHint = ""
			dm.projectOpenConfirming = false
			dm.projectDeleteConfirming = false
			dm.projectRenameOpen = false
			dm.libraryConfirming = false
			dm.libraryUploadOpen = false
		end
	end

	-- What the editor's own status strip should echo: the last outcome, held
	-- for a few seconds the way SAVED is.
	local function outcome(textValue, ok)
		widgetState.libraryOutcome = { text = textValue, ok = ok == true, until_ = clock() + 4 }
	end

	local function send(operation, source, stage)
		-- Nothing reaches the companion while the setting is off, whatever
		-- calls this.
		if not widgetState.teamSyncEnabled then
			return false
		end
		local client = library()
		local ok, code
		if client then
			ok, code = client.request(operation, source, stage)
		end
		notice = ok and "working" or (code or "offline")
		if not ok then
			statusShownAt = clock()
			statusHidden = nil
		end
		armed = nil
		ui.sync()
		return ok == true
	end

	-- Where the selected project stands against the team library, as the
	-- widget computes it for the Sync column: local | team | synced | mine |
	-- theirs, or nil when nothing is selected.
	local function selectedSync()
		local slug = widgetState.projectOpenSelectedSlug
		if not slug or widgetState.projectOpenIsFolder then
			return nil
		end
		local fn = widgetState.projectSyncState
		return fn and fn(slug) or nil
	end

	local function stageOf(slug)
		return tostring(slug or ""):match("^(.*)/[^/]+$") or ""
	end

	local function isStage(name)
		for _, stage in ipairs(stageList) do
			if stage == name then
				return true
			end
		end
		return false
	end

	local function openTray(mode, stage)
		local dm = widgetState.dmHandle
		armed = nil
		dm.libraryTrayMode = mode
		dm.libraryTrayTitle = translate(mode == "move" and "moveTo" or "stage")
		dm.libraryUploadOpen = true
		dm.projectDeleteConfirming = false
		dm.projectOpenConfirming = false
		widgetState.projectOpenArmed = nil
		widgetState.projectDeleteConfirmExpiry = 0
		if stage then
			ui.setStage(stage)
		end
		widgetState.projectStagesNeedsRebuild = true
	end

	-- Install FINAL function values before OpenDataModel: Recoil freezes them.
	-- The filter chips: All / On this disk / Team. Switching one changes which
	-- rows the union shows, so the browser is rebuilt and the selection let go.
	model.librarySetFilter = function(_, name)
		name = tostring(name or "all")
		if (widgetState.projectFilter or "all") == name then
			return
		end
		widgetState.projectFilter = name
		widgetState.dmHandle.libraryFilter = name
		widgetState.projectLocalDirty = true
		clearSelection()
	end
	-- Details pane, TEAM block. "Upload to team..." opens the stage tray for a
	-- project the library does not have; "Update team copy" aims at the stage
	-- it is already in and arms the confirm in one go.
	model.libraryUploadTo = function()
		local dm = widgetState.dmHandle
		local source = widgetState.projectOpenSelectedSlug
		if not source or widgetState.projectOpenIsFolder or not dm.libraryWritable or dm.libraryBusy then
			return
		end
		local home = stageOf(source)
		openTray("upload", isStage(home) and home or nil)
		ui.sync()
	end
	model.libraryUpdateTeam = function()
		local dm = widgetState.dmHandle
		local client = library()
		local source = widgetState.projectOpenSelectedSlug
		if not (client and source) or widgetState.projectOpenIsFolder or not dm.libraryWritable or dm.libraryBusy then
			return
		end
		local home = stageOf(source)
		if not isStage(home) then
			-- A team project outside the pipeline goes through the tray, where
			-- a destination is picked.
			openTray("upload", nil)
			ui.sync()
			return
		end
		openTray("upload", home)
		armed = source .. "\n" .. home .. "\n" .. tostring(client.state.session)
		dm.libraryConfirming = true
		dm.libraryStatusVisible = false
		dm.libraryStatus = translate("publishQuestion", { source = source, stage = home })
		ui.sync()
	end
	model.libraryMoveTo = function()
		local dm = widgetState.dmHandle
		local source = widgetState.projectOpenSelectedSlug
		if not source or widgetState.projectOpenIsFolder or not dm.libraryWritable or dm.libraryBusy then
			return
		end
		local home = stageOf(source)
		local first = nil
		for _, stage in ipairs(stageList) do
			if stage ~= home then
				first = stage
				break
			end
		end
		openTray("move", first)
		ui.sync()
	end
	-- The tray's primary: in move mode it stages the move (CONFIRM MOVES still
	-- sends it); in upload mode it is the two-click publish.
	model.libraryTrayCommit = function()
		local dm = widgetState.dmHandle
		if dm.libraryTrayMode == "move" then
			local source = widgetState.projectOpenSelectedSlug
			if source and dm.libraryStage ~= "" and dm.libraryStage ~= stageOf(source) then
				if ui.queueMove(source, dm.libraryStage) then
					dm.libraryUploadOpen = false
					widgetState.projectOpenNeedsRebuild = true
				end
			end
			ui.sync()
			return
		end
		model.libraryPublish()
	end
	model.libraryCancelUpload = function()
		ui.disarm()
		ui.sync()
	end
	-- CONFIRM MOVES / DISCARD, the two ends of a drag plan.
	model.libraryConfirmMoves = function()
		if ui.confirmMoves() then
			ui.sync()
		end
	end
	model.libraryDiscardMoves = function()
		ui.discardMoves()
		ui.sync()
	end
	model.libraryPull = function()
		send("pull")
	end
	model.libraryDismissStatus = function()
		statusHidden = statusKey
		widgetState.dmHandle.libraryStatusVisible = false
	end
	-- The start card. Writing the starter is the widget's job (it reads the
	-- companion out of the VFS); the card only records what it said.
	model.libraryCardShow = function()
		local dm = widgetState.dmHandle
		dm.libraryCardOpen = true
		dm.libraryCardCopied = false
	end
	model.libraryCardHide = function()
		widgetState.dmHandle.libraryCardOpen = false
	end
	model.libraryCardWrite = function()
		local dm = widgetState.dmHandle
		local write = widgetState.projectWriteRunner
		if not write or not widgetState.teamSyncEnabled then
			return
		end
		local ok, path = write()
		dm.libraryCardWritten = ok == true
		dm.libraryCardPath = ok and tostring(path or "") or ""
		dm.libraryCardCopied = false
	end
	model.libraryCardCopy = function()
		local dm = widgetState.dmHandle
		if dm.libraryCardPath ~= "" and Spring.SetClipboard then
			Spring.SetClipboard(dm.libraryCardPath)
			dm.libraryCardCopied = true
		end
	end
	model.libraryStageStep = function(_, direction)
		if widgetState.dmHandle.projectSavePending then
			return
		end
		stageIndex = stageIndex + direction
		armed = nil
		ui.sync()
		if widgetState.projectSaveUi then
			widgetState.projectSaveUi.changed()
		end
	end
	model.libraryPublish = function()
		local dm = widgetState.dmHandle
		local client = library()
		local source = widgetState.projectOpenSelectedSlug
		if
			not client
			or not source
			or widgetState.projectOpenIsFolder
			or dm.libraryBusy
			or not dm.libraryWritable
			or dm.libraryStage == ""
		then
			return
		end
		local key = source .. "\n" .. dm.libraryStage .. "\n" .. tostring(client.state.session)
		if armed == key then
			dm.libraryUploadOpen = false
			send("publish", source, dm.libraryStage)
		else
			armed = key
			dm.libraryConfirming = true
			dm.libraryStatusVisible = false
			dm.libraryStatus = translate("publishQuestion", { source = source, stage = dm.libraryStage })
		end
	end
	-- After a project has been moved between folders on this disk, the same
	-- move can be made in the team library. It is offered, never automatic.
	model.libraryMoveConfirm = function()
		local dm = widgetState.dmHandle
		local pending = widgetState.projectPendingMove
		if not pending or not dm.libraryWritable or dm.libraryBusy then
			return
		end
		widgetState.projectPendingMove = nil
		dm.libraryMoveOpen = false
		send("move", pending.source, pending.stage)
	end
	model.libraryMoveDismiss = function()
		widgetState.projectPendingMove = nil
		widgetState.dmHandle.libraryMoveOpen = false
		widgetState.dmHandle.libraryMoveQuestion = ""
	end
	-- Fetch everything in the catalogue that is not on this disk yet, one
	-- project at a time through the same request path a single download uses.
	-- Projects already here are left alone rather than re-fetched over local
	-- edits.
	model.libraryDownloadAll = function()
		local dm = widgetState.dmHandle
		local client = library()
		if not client or dm.libraryBusy or not dm.libraryOnline then
			return
		end
		local pending = {}
		for _, entry in ipairs(client.catalog.projects or {}) do
			local path = tostring(entry.slug or "")
			-- Disk truth, not the VFS view: a project downloaded earlier in this
			-- session can still be invisible to VFS.
			if path ~= "" and not widgetState.projectFileOnDisk("MapProjects/" .. path .. "/project.lua") then
				pending[#pending + 1] = path
			end
		end
		table.sort(pending)
		widgetState.projectDownloadQueue = pending
		widgetState.projectDownloadTotal = #pending
		widgetState.projectDownloadPending = 0
		if #pending == 0 then
			notice = "allLocal"
			statusShownAt = clock()
			statusHidden = nil
		end
		ui.sync()
	end
	-- Delete one project from the team library. Two clicks, like every other
	-- destructive control here. Folders are not removable: the structure is
	-- fixed.
	model.libraryRemoveRemote = function()
		local dm = widgetState.dmHandle
		local client = library()
		local source = widgetState.projectOpenSelectedSlug
		if not client or not source or not dm.libraryWritable or dm.libraryBusy then
			return
		end
		if widgetState.projectOpenIsFolder then
			return
		end
		local key = "remove\n" .. source .. "\n" .. tostring(client.state.session)
		if armed == key then
			send("remove", source)
		else
			armed = key
			dm.libraryConfirming = true
			dm.libraryStatusVisible = false
			dm.libraryStatus = translate("removeQuestion", { name = source })
		end
	end
	-- Get the team version. When the copy on this disk is the newer one this
	-- is the one transfer that can lose work, so it asks first; the companion
	-- keeps the replaced copy under MapProjects/_replaced either way.
	model.libraryDownload = function()
		local dm = widgetState.dmHandle
		local client = library()
		local source = widgetState.projectOpenSelectedSlug
		if not (client and source) or widgetState.projectOpenIsFolder or not dm.libraryOnline or dm.libraryBusy then
			return
		end
		local state = selectedSync()
		if state == "synced" then
			return
		end
		if state == "mine" then
			local key = "get\n" .. source .. "\n" .. tostring(client.state.session)
			if armed ~= key then
				armed = key
				dm.libraryConfirming = true
				dm.libraryStatusVisible = false
				dm.libraryStatus = translate("getTeamQuestion", { name = source:match("([^/]+)$") or source })
				ui.sync()
				return
			end
		end
		send("download", source)
	end

	function ui.sync(dt)
		if dt then
			elapsed = elapsed + dt
			if elapsed < 0.25 then
				return
			end
			elapsed = 0
		end
		local dm = widgetState.dmHandle
		if not dm then
			return
		end
		local client = library()
		local state = client and client.state or {}
		local project = getMapProject()
		local catalog = client and client.catalog or { projects = {}, stages = {} }
		-- Off for everyone outside the campaign team: no strip, no catalogue,
		-- no transfers. A companion that happens to be running is ignored.
		local enabled = widgetState.teamSyncEnabled == true
		if dm.libraryEnabled ~= enabled then
			dm.libraryEnabled = enabled
		end
		if not enabled then
			dm.libraryConfigured = false
			dm.libraryOnline = false
			dm.libraryWritable = false
			dm.libraryBusy = (project and project.isBusy()) or false
			dm.libraryUploadOpen = false
			dm.libraryMoveOpen = false
			dm.libraryMovesOpen = false
			dm.libraryMovesPending = ""
			dm.libraryCardOpen = false
			dm.libraryStatusVisible = false
			dm.libraryConfirming = false
			dm.libraryGetConfirming = false
			dm.libraryRemoveConfirming = false
			dm.libraryQueue = ""
			dm.libraryStripDot = "unset"
			if ui.pendingMoveCount() > 0 then
				ui.discardMoves()
			end
			widgetState.projectDownloadQueue = nil
			widgetState.projectTeamMoveQueue = nil
			widgetState.projectOpenAfterDownload = nil
			armed = nil
			return
		end
		dm.libraryOnline = state.online == true
		if dm.libraryOnline then
			-- The runner hint told the user to start Team Sync; it has started.
			-- The "restart to pick up new files" hint is the one that stays.
			if dm.projectHelperHint ~= "" and not widgetState.projectHelperHintSticky then
				dm.projectHelperHint = ""
			end
			-- The card's whole point was to get here.
			dm.libraryCardOpen = false
			if (tonumber(state.helper) or 1) < HELPER_MIN then
				local stale = translate("helperStale")
				if dm.projectHelperHint ~= stale then
					dm.projectHelperHint = stale
				end
				widgetState.projectHelperHintSticky = true
			end
		elseif widgetState.projectOpenAfterDownload then
			-- No companion, no download coming: the OPEN that waited on it is off.
			widgetState.projectOpenAfterDownload = nil
		end
		dm.libraryBusy = (client and client.isBusy()) or (project and project.isBusy()) or false
		dm.libraryWritable = state.online == true and state.allow_push == true
		dm.libraryConfigured = state.version == 1 or #(catalog.projects or {}) > 0 or #(catalog.stages or {}) > 0
		dm.libraryConnection = translate(
			not dm.libraryOnline and "offlineBadge"
				or (dm.libraryBusy and "workingBadge" or (dm.libraryWritable and "onlineBadge" or "readOnlyBadge"))
		)
		local remote = tostring(state.remote or catalog.remote or "")
		if remote ~= lastRemote then
			lastRemote = remote
			dm.libraryRemoteURL = remote
			dm.libraryRepository =
				remote:gsub("^https://github.com/", ""):gsub("^git@github.com:", ""):gsub("%.git$", "")
		end
		dm.libraryBranch = tostring(state.branch or "")
		if not dm.libraryWritable or dm.libraryBusy or not widgetState.projectOpenSelectedSlug then
			dm.libraryUploadOpen = false
		end
		-- The offer only stands while the companion could still act on it.
		if not dm.libraryWritable or dm.libraryBusy or not widgetState.projectPendingMove then
			dm.libraryMoveOpen = false
		end
		-- A drag plan only stands while the companion could still carry it out.
		local staged = ui.pendingMoveCount()
		if staged > 0 and not dm.libraryWritable then
			ui.discardMoves()
			staged = 0
		end
		dm.libraryMovesOpen = staged > 0
		dm.libraryMovesPending = staged > 0 and translate("movesPending", { count = staged }) or ""
		local stages = catalog.stages or {}
		if #stages == 0 then
			stages = state.stages or {}
		end
		stageList = stages
		if #stages > 0 then
			stageIndex = (stageIndex - 1) % #stages + 1
			dm.libraryStage = stages[stageIndex]
		else
			dm.libraryStage = ""
		end
		-- "|" cannot occur in a validated folder path, so it is a safe joiner.
		local key = table.concat(stages, "|") .. "|=" .. dm.libraryStage
		if key ~= stageKey then
			stageKey = key
			widgetState.projectStagesNeedsRebuild = true
		end
		if client and generation ~= client.generation then
			generation = client.generation
			widgetState.projectLocalDirty = true
			widgetState.projectOpenNeedsRebuild = true
			widgetState.projectSaveNeedsRebuild = true
		end
		-- A companion that has just connected pulls once, so the library on
		-- screen is today's rather than last session's. Waits its turn: the
		-- companion checks the shader first and is busy while it does.
		if dm.libraryOnline and state.session ~= lastSession then
			lastSession = state.session
			autoPull = true
		end
		if autoPull and dm.libraryOnline and not (dm.libraryBusy or state.pending or armed) and client then
			autoPull = false
			-- The companion pulls as it starts; a catalogue that fresh is not
			-- fetched again.
			local fetchedAt = tonumber(catalog.fetched)
			if not (fetchedAt and now() - fetchedAt < 120) and client.request("pull") then
				notice = "working"
			end
		end
		-- Drain the download queue: one request at a time, and only while the
		-- companion is free, so a failure stops the run where it happened.
		local queue = widgetState.projectDownloadQueue
		local moving = widgetState.projectTeamMoveQueue
		if queue and #queue > 0 then
			local total = widgetState.projectDownloadTotal or #queue
			dm.libraryQueue = translate("queueProgress", { done = total - #queue, total = total })
			if client and dm.libraryOnline and not (dm.libraryBusy or state.pending or armed) then
				local path = table.remove(queue, 1)
				local ok, code = client.request("download", path)
				if ok then
					widgetState.projectDownloadPending = (widgetState.projectDownloadPending or 0) + 1
				else
					widgetState.projectDownloadQueue = nil
					widgetState.projectDownloadPending = 0
					notice = code or "offline"
					statusShownAt = clock()
					statusHidden = nil
				end
			end
		elseif moving and #moving > 0 then
			local total = widgetState.projectTeamMoveTotal or #moving
			dm.libraryQueue = translate("moveProgress", { done = total - #moving, total = total })
			if
				client
				and dm.libraryOnline
				and dm.libraryWritable
				and not (dm.libraryBusy or state.pending or armed)
			then
				local entry = table.remove(moving, 1)
				local ok, code = client.request("move", entry.source, entry.stage, nil, entry.name)
				if not ok then
					widgetState.projectTeamMoveQueue = nil
					widgetState.projectTeamMoveTotal = nil
					notice = code or "offline"
					statusShownAt = clock()
					statusHidden = nil
				end
			end
		elseif dm.libraryQueue ~= "" then
			dm.libraryQueue = ""
			widgetState.projectDownloadQueue = nil
			widgetState.projectTeamMoveQueue = nil
			widgetState.projectTeamMoveTotal = nil
		end
		if not state.busy and state.request_id and state.request_id ~= resultID then
			resultID = state.request_id
			notice = nil
			saveShowing = false
			statusShownAt = clock()
			statusHidden = nil
			dm.libraryStatusTime = os.date("%H:%M")
			if state.code == "downloaded" and widgetState.projectOpenAfterDownload == state.local_slug then
				-- OPEN downloaded it first; the widget takes it from here,
				-- because opening restarts the session.
				widgetState.projectOpenChainReady = true
			elseif widgetState.projectOpenAfterDownload then
				-- Whatever settled, it was not that download: the OPEN waiting on
				-- it is off, not parked for the next download of the same name.
				widgetState.projectOpenAfterDownload = nil
			end
			if SUCCESS[state.code] then
				lastPulled = now()
			end
			if state.code == "downloaded" or state.code == "published" or state.code == "moved" then
				-- Something has arrived, left or been renamed; the Sync column is
				-- about to be wrong until the disk is looked at again.
				widgetState.projectLocalDirty = true
			end
			if state.code == "downloaded" then
				widgetState.projectOpenNeedsRebuild = true
				if (widgetState.projectDownloadPending or 0) > 0 then
					widgetState.projectDownloadPending = widgetState.projectDownloadPending - 1
				end
			end
		end
		local fetched = tonumber(catalog.fetched)
		if fetched and (not lastPulled or fetched > lastPulled) then
			lastPulled = fetched
		end
		local selectionKey = tostring(widgetState.projectOpenSelectedSlug)
			.. "\n"
			.. dm.libraryStage
			.. "\n"
			.. tostring(state.session)
		local getKey = "get\n" .. tostring(widgetState.projectOpenSelectedSlug) .. "\n" .. tostring(state.session)
		local removeKey = "remove\n" .. tostring(widgetState.projectOpenSelectedSlug) .. "\n" .. tostring(state.session)
		if
			(armed ~= selectionKey and armed ~= getKey and armed ~= removeKey)
			or dm.libraryBusy
			or (armed == getKey and not dm.libraryOnline)
			or (armed ~= getKey and not dm.libraryWritable)
		then
			armed = nil
		end
		dm.libraryConfirming = armed ~= nil
		dm.libraryRemoveConfirming = armed == removeKey
		dm.libraryGetConfirming = armed == getKey
		dm.libraryTrayTitle = translate(dm.libraryTrayMode == "move" and "moveTo" or "stage")
		if not armed then
			local code = not state.online and "offline"
				or (dm.libraryBusy and "working" or (notice or state.code or "ready"))
			dm.libraryStatusSuccess = SUCCESS[code] == true
			dm.libraryStatusError = not QUIET[code] and not dm.libraryStatusSuccess
			local shownKey = tostring(resultID) .. "\n" .. tostring(code)
			if shownKey ~= statusKey then
				statusKey = shownKey
				statusShownAt = statusShownAt or clock()
			end
			-- Good news fades; bad news waits to be read.
			local faded = dm.libraryStatusSuccess and statusShownAt and (clock() - statusShownAt) > STATUS_HOLD
			dm.libraryStatusVisible = (dm.libraryStatusError or dm.libraryStatusSuccess)
				and statusHidden ~= statusKey
				and not faded
			if code == "published" or code == "moved" or code == "removed" then
				dm.libraryStatus = translate(code, { target = state.target or "" })
			elseif code == "downloaded" then
				dm.libraryStatus = translate(code, { name = state.local_slug or "" })
			else
				dm.libraryStatus = translate(code)
			end
			if (dm.libraryStatusError or dm.libraryStatusSuccess) and widgetState.libraryOutcomeKey ~= shownKey then
				widgetState.libraryOutcomeKey = shownKey
				outcome(dm.libraryStatus, dm.libraryStatusSuccess)
			end
			-- A Save As that ended (uploaded, or stopped short of it) says so
			-- here as well: the window it was started from closed on save.
			local so = widgetState.librarySaveOutcome
			if so and so.seq ~= saveSeq then
				saveSeq = so.seq
				saveShowing = true
				statusHidden = nil
				statusShownAt = clock()
			end
			if saveShowing and so then
				statusKey = "save\n" .. tostring(so.seq)
				dm.libraryStatus = so.text
				dm.libraryStatusTime = so.time or ""
				dm.libraryStatusSuccess = so.ok == true
				dm.libraryStatusError = so.ok ~= true
				local faded = so.ok and statusShownAt and (clock() - statusShownAt) > STATUS_HOLD
				dm.libraryStatusVisible = statusHidden ~= statusKey and not faded
			end
		end
		-- The strip.
		local dot, line, age = "unset", translate("stripUnset"), ""
		if dm.libraryOnline then
			if dm.libraryBusy then
				dot = "busy"
				line = dm.libraryQueue ~= "" and dm.libraryQueue
					or (lastPulled and translate("stripBusy") or translate("stripStarting"))
				if not lastPulled then
					dot = "starting"
				end
			else
				dot = "on"
				line = dm.libraryRepository ~= "" and dm.libraryRepository or translate("onlineBadge")
				if not dm.libraryWritable then
					line = line .. " · " .. translate("stripReadOnly")
				end
			end
			if lastPulled then
				age = translate("stripUpdated", { age = ageText(now() - lastPulled, translate) })
			end
		elseif dm.libraryConfigured then
			dot = "off"
			line = translate("stripOffline")
			if lastPulled then
				age = translate("stripAsOf", { age = ageText(now() - lastPulled, translate) })
			end
		end
		dm.libraryStripDot = dot
		dm.libraryStripText = line
		dm.libraryStripAge = age
	end

	-- The catalogue and the team's folders, as the widget sees them: nothing
	-- at all while the setting is off, so no team row, stage or Sync cell is
	-- ever drawn.
	function ui.projects()
		local client = library()
		if not widgetState.teamSyncEnabled or not client then
			return {}
		end
		return client.catalog.projects or {}
	end

	function ui.folders()
		local client = library()
		if not widgetState.teamSyncEnabled or not client then
			return {}
		end
		return client.catalog.stages or {}
	end

	-- The team catalogue keyed by slug: the widget's union list and the Sync
	-- column both ask this.
	function ui.teamBySlug()
		local out = {}
		for _, entry in ipairs(ui.projects()) do
			out[tostring(entry.slug or "")] = entry
		end
		return out
	end

	-- Picking a destination chip by name (the widget draws one chip per folder).
	function ui.setStage(name)
		for index, stage in ipairs(stageList) do
			if stage == name then
				if stageIndex ~= index then
					stageIndex = index
					armed = nil
					ui.sync()
					if widgetState.projectSaveUi then
						widgetState.projectSaveUi.changed()
					end
				end
				return
			end
		end
	end

	-- Start one download from the widget: OPEN downloads first when the
	-- project is not on this disk yet.
	function ui.download(source)
		if source and source ~= "" and send("download", source) then
			return true
		end
		-- Refused before it left: an OPEN waiting on this download would
		-- otherwise stay armed and fire on the next download of the same name.
		if widgetState.projectOpenAfterDownload == source then
			widgetState.projectOpenAfterDownload = nil
		end
		return false
	end

	-- ===== Staged team moves =====
	-- A drag in the team view rearranges a plan, not the repository. Each move
	-- is a commit and a push on a branch other people are working in, so a
	-- handful of them should be one deliberate act rather than one push per
	-- drop.

	-- Where this project is headed (the stage, or stage/new-name for a
	-- rename), or nil if it is not being moved.
	function ui.pendingMove(source)
		for _, entry in ipairs(widgetState.projectTeamMoves or {}) do
			if entry.source == source then
				local leaf = source:match("([^/]+)$") or source
				if entry.name and entry.name ~= leaf then
					return (entry.stage ~= "" and (entry.stage .. "/") or "") .. entry.name
				end
				return entry.stage
			end
		end
		return nil
	end

	function ui.pendingMoveCount()
		return #(widgetState.projectTeamMoves or {})
	end

	-- Plan a move, replace an earlier plan for the same project, or drop it
	-- when the destination is where the project already is.
	-- `name` renames the project on the way (the same folder is then a
	-- destination too); nil keeps its name.
	function ui.queueMove(source, stage, name)
		if not source or source == "" or not stage then
			return false
		end
		local moves = widgetState.projectTeamMoves or {}
		widgetState.projectTeamMoves = moves
		local home = source:match("^(.*)/[^/]+$") or ""
		local leaf = source:match("([^/]+)$") or source
		if name == "" or name == leaf then
			name = nil
		end
		for i = #moves, 1, -1 do
			if moves[i].source == source then
				table.remove(moves, i)
			end
		end
		if stage ~= home or name then
			moves[#moves + 1] = { source = source, stage = stage, name = name }
		end
		return true
	end

	function ui.discardMoves()
		widgetState.projectTeamMoves = nil
		widgetState.projectOpenNeedsRebuild = true
	end

	-- Hand the plan to the companion. The local copies go first and all at
	-- once: moveProject refuses to run while the companion is transferring.
	function ui.confirmMoves()
		local dm = widgetState.dmHandle
		local moves = widgetState.projectTeamMoves
		if not (dm and moves and #moves > 0) or not dm.libraryWritable or dm.libraryBusy then
			return false
		end
		local project = getMapProject()
		local queued = {}
		for _, entry in ipairs(moves) do
			queued[#queued + 1] = { source = entry.source, stage = entry.stage, name = entry.name }
			local leaf = entry.name or entry.source:match("([^/]+)$") or entry.source
			local target = (entry.stage ~= "" and (entry.stage .. "/") or "") .. leaf
			if
				project
				and project.move
				and widgetState.projectFileOnDisk("MapProjects/" .. entry.source .. "/project.lua")
			then
				project.move(entry.source, target)
			end
		end
		widgetState.projectTeamMoves = nil
		widgetState.projectTeamMoveQueue = queued
		widgetState.projectTeamMoveTotal = #queued
		widgetState.projectOpenNeedsRebuild = true
		widgetState.projectSaveNeedsRebuild = true
		return true
	end

	function ui.disarm()
		armed = nil
		if widgetState.dmHandle then
			widgetState.dmHandle.libraryConfirming = false
			widgetState.dmHandle.libraryGetConfirming = false
			widgetState.dmHandle.libraryRemoveConfirming = false
			widgetState.dmHandle.libraryUploadOpen = false
		end
	end

	return ui
end

-- Keep Save As in this already-mounted module: LuaUI reload does not rescan
-- .sdd member names, so a new required Include can remove the entire panel.
function M.newSave(widgetState, model, dependencies)
	local getMapProject = dependencies and dependencies.getMapProject or function()
		return WG.MapProject
	end
	local translate = dependencies and dependencies.translate or text
	local clock = dependencies and dependencies.clock or os.clock
	local ui = {}
	local armed, pending
	local actionKey, actionName = "save", ""
	for _, key in ipairs({
		"saveTitle",
		"nameHint",
		"units",
		"unitsHelp",
		"on",
		"off",
		"saveInto",
		"rootFolder",
		"change",
		"uploadAfter",
		"sumTitle",
		"sumMap",
		"sumFolder",
		"sumUnits",
		"sumUpload",
		"sumExisting",
	}) do
		model["libraryLabel_" .. key] = translate(key)
	end
	-- The switch, not a tab: whether this save is followed by an upload.
	model.projectSaveUpload = false
	model.projectSaveIsStage = false -- the destination is one of the team's folders
	model.projectSaveUploadAllowed = false -- ... and Team Sync could upload right now
	model.projectSaveUploadNote = ""
	model.projectSavePending = false
	model.projectSaveConfirming = false
	model.projectSaveError = false
	model.projectSaveSuccess = false
	model.projectSaveAction = translate("save")

	local function message(key, values, error, success)
		local dm = widgetState.dmHandle
		dm.projectSaveHint = key and translate(key, values) or ""
		dm.projectSaveError = error == true
		dm.projectSaveSuccess = success == true
		-- The window is closed once the save starts, so the outcome is echoed
		-- where SAVED is: the editor's own status strip, in a few words.
		if key and (error or success) then
			widgetState.librarySaveSeq = (widgetState.librarySaveSeq or 0) + 1
			widgetState.librarySaveOutcome = {
				seq = widgetState.librarySaveSeq,
				text = dm.projectSaveHint,
				ok = success == true,
				time = os.date("%H:%M"),
			}
			local short = dm.projectSaveHint
			if key == "savedAndUploaded" then
				short = translate("stripUploaded", { target = values and values.target or "" })
			elseif error then
				short = translate("stripUploadFailed")
			end
			widgetState.libraryOutcome = { text = short, ok = success == true, until_ = clock() + 4 }
		end
	end

	local function sameDestination(intent, client)
		local state = client and client.state or {}
		return client == intent.client
			and state.session == intent.session
			and state.remote == intent.remote
			and state.branch == intent.branch
	end

	function ui.changed()
		if pending then
			return
		end
		armed = nil
		message(nil)
		ui.sync()
	end

	function ui.open()
		if pending then
			return false
		end
		ui.changed()
		return true
	end

	function ui.close()
		-- Closing hides progress, not an already confirmed save/upload.
		if not pending then
			ui.changed()
		end
	end

	-- The switch. Only meaningful while the destination is a team stage and
	-- Team Sync could upload; the widget keeps projectSaveUploadAllowed current.
	model.projectSaveSetUpload = function(_, upload)
		local dm = widgetState.dmHandle
		if pending or not dm.projectSaveUploadAllowed or dm.projectSaveUpload == upload then
			return
		end
		dm.projectSaveUpload = upload
		widgetState.projectSaveUploadChoice = upload
		if widgetState.projectSyncTarget then
			widgetState.projectSyncTarget()
		end
		ui.changed()
	end

	function ui.save(input)
		if pending then
			return false
		end
		local dm = widgetState.dmHandle
		local project = getMapProject()
		if not (project and project.save and project.validateSlug) then
			ui.changed()
			message("unavailable", nil, true)
			return false
		end
		local name = project.validateSlug(input:gsub("^%s+", ""):gsub("%s+$", ""))
		if not name then
			ui.changed()
			message("invalid_path", nil, true)
			return false
		end
		local client = project.library
		if client and client.update then
			client.update()
		end
		if project.isBusy() then
			ui.changed()
			message("busy", nil, true)
			return false
		end
		local state = client and client.state or {}
		-- The folder the name is in IS the destination.
		local stage = name:match("^(.*)/[^/]+$") or ""
		local upload = dm.projectSaveUpload == true and dm.projectSaveUploadAllowed == true
		if upload then
			local code = not state.online and "offline" or (not state.allow_push and "read_only")
			if code or not widgetState.projectTeamDestinations()[stage] then
				armed = nil
				message(code or "invalid_stage", nil, true)
				ui.sync()
				return false
			end
		end
		local units = widgetState.projectSaveUnits == true
		local overwrite = name ~= project.current() and project.exists(name)
		local dropUnits = not units and project.hasUnitsSection(name)
		local teamHas = upload and widgetState.projectTeamBySlug and widgetState.projectTeamBySlug()[name] ~= nil
		local key = table.concat({
			name,
			tostring(units),
			tostring(upload),
			stage,
			tostring(state.session),
			tostring(state.remote),
			tostring(state.branch),
			tostring(overwrite),
			tostring(dropUnits),
			tostring(teamHas),
		}, "\n")
		if overwrite or dropUnits or teamHas then
			if not armed or armed.key ~= key or armed.project ~= project or armed.client ~= client then
				armed = {
					key = key,
					project = project,
					client = client,
					units = units,
					stage = stage,
					upload = upload,
					overwrite = overwrite,
					session = state.session,
					remote = state.remote,
					branch = state.branch,
				}
				local hints = {}
				if overwrite then
					hints[#hints + 1] = translate("overwriteQuestion", { name = name })
				end
				if dropUnits then
					hints[#hints + 1] = translate("dropUnitsQuestion", { name = name })
				end
				if teamHas then
					hints[#hints + 1] = translate("saveUploadQuestion", { name = name, stage = stage })
				end
				message(nil)
				dm.projectSaveHint = table.concat(hints, " ")
				ui.sync()
				return false
			end
		end
		local intent = armed
			or {
				upload = upload,
				stage = stage,
				session = state.session,
				remote = state.remote,
				branch = state.branch,
				project = project,
				client = client,
			}
		armed = nil
		local ok, receipt = project.save(name, { saveUnits = units })
		if not ok then
			message("saveRejected", nil, true)
		else
			-- The window closes either way: progress and the outcome live in
			-- the editor's status strip, which is where a save has always been
			-- watched from.
			dm.projectSaveOpen = false
			if upload then
				-- Never infer completion from a previous lastSave() or an existing file.
				if type(receipt) ~= "table" then
					message("saveUntracked", nil, true)
				else
					pending = intent
					pending.receipt = receipt
					message("saving", { name = receipt.slug })
				end
			end
		end
		ui.sync()
		return ok == true
	end

	function ui.sync()
		local dm = widgetState.dmHandle
		if not dm or (not dm.projectSaveOpen and not pending and not armed) then
			return
		end
		local project = getMapProject()
		local client = project and project.library
		if
			armed
			and (
				project ~= armed.project
				or not sameDestination(armed, client)
				or (widgetState.projectSaveUnits == true) ~= armed.units
				or (dm.projectSaveUpload == true and dm.projectSaveUploadAllowed == true) ~= armed.upload
				or (armed.upload and (not client.state.online or not client.state.allow_push or project.isBusy()))
			)
		then
			armed = nil
			message(nil)
		end
		if pending then
			local intent = pending
			local state = client and client.state or {}
			if project ~= intent.project or not sameDestination(intent, client) then
				pending = nil
				widgetState.libraryProgress = nil
				message(intent.requestID and "uploadInterrupted" or "saveUploadCancelled", nil, true)
			elseif intent.requestID then
				if not state.online then
					pending = nil
					widgetState.libraryProgress = nil
					message("uploadInterrupted", nil, true)
				elseif state.request_id == intent.requestID and not state.busy and not state.pending then
					pending = nil
					widgetState.libraryProgress = nil
					if state.code == "published" then
						message(
							"savedAndUploaded",
							{ name = intent.receipt.slug, target = state.target or "" },
							false,
							true
						)
					else
						message(
							"savedUploadFailed",
							{ name = intent.receipt.slug, reason = translate(state.code or "helper_error") },
							true
						)
					end
				end
			elseif intent.receipt.done then
				-- Consume once, before attempting the mailbox write; failure never retries.
				pending = nil
				if not intent.receipt.ok then
					message("saveFailed", nil, true)
				elseif not intent.receipt.uploadReady then
					message("saveIncomplete", nil, true)
				elseif project.lastSave() ~= intent.receipt or project.isBusy() then
					message("saveUploadCancelled", nil, true)
				else
					local ok, code = client.request("publish", intent.receipt.slug, intent.stage, intent)
					if ok then
						intent.requestID = code
						pending = intent
						message("uploading", { name = intent.receipt.slug })
						widgetState.libraryProgress = intent.receipt.slug:match("([^/]+)$") or intent.receipt.slug
					else
						message("savedUploadFailed", { name = intent.receipt.slug, reason = translate(code) }, true)
					end
				end
			end
		end
		dm.projectSavePending = pending ~= nil
		dm.projectSaveConfirming = armed ~= nil
		local upload = dm.projectSaveUpload == true and dm.projectSaveUploadAllowed == true
		local nextAction, nextName
		if pending then
			nextAction = pending.requestID and "uploadingLabel" or "savingLabel"
		elseif armed and armed.overwrite then
			nextAction = upload and "replaceNameUpload" or "replaceName"
			nextName = tostring(widgetState.projectNameStr or ""):match("([^/]+)$") or ""
		elseif armed then
			nextAction = upload and "confirmSaveUpload" or "confirmSave"
		else
			nextAction = upload and "saveUpload" or "save"
		end
		nextName = nextName or ""
		if actionKey ~= nextAction or actionName ~= nextName then
			actionKey, actionName = nextAction, nextName
			dm.projectSaveAction = translate(actionKey, { name = nextName })
		end
	end

	return ui
end

return M
