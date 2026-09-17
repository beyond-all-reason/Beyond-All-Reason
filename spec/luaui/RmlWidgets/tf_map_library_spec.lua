local LibraryUI = VFS.Include("luaui/RmlWidgets/gui_terraform_brush/tf_map_library.lua")

-- The controller behind the Projects window: one browser over this disk and
-- the team library, the Team Sync strip and start card, the stage tray, the
-- status slot. No DOM here; the widget's seams are stubbed on widgetState.
local function fixture(options)
	options = options or {}
	local calls = {}
	local clockNow = 100
	local client = {
		state = {
			version = 1,
			helper = 2, -- the companion build the panel needs
			online = true,
			allow_push = true,
			session = "session",
			code = "ready",
			request_id = "",
			remote = "https://github.com/team/maps.git",
			branch = "main",
		},
		-- A catalogue the companion fetched moments ago, so the connect pull
		-- stays out of the way of tests that count their own requests.
		catalog = { projects = {}, stages = { "Design", "Textures" }, fetched = (not options.stale) and 950 or nil },
		generation = 1,
		isBusy = function()
			return false
		end,
		request = function(operation, source, stage)
			calls[#calls + 1] = { operation = operation, source = source, stage = stage }
			return true, "request"
		end,
	}
	local project = { library = client, isBusy = client.isBusy }
	local model = { projectHelperHint = "" }
	local state = {
		dmHandle = model,
		teamSyncEnabled = true, -- Settings > General > Team Sync, on for these tests
		projectOpenSelectedSlug = "Design/arena",
		projectOpenIsFolder = false,
		projectFileOnDisk = function()
			return true
		end,
	}
	state.projectSyncState = function()
		return state.sync or "synced"
	end
	local ui = LibraryUI.new(state, model, {
		getMapProject = function()
			return project
		end,
		translate = function(key)
			return key
		end,
		now = function()
			return 1000
		end,
		clock = function()
			return clockNow
		end,
	})
	local f = { client = client, calls = calls, model = model, state = state, ui = ui, project = project }
	-- Advance the wall clock the status slot fades by, then sync.
	f.tick = function(seconds)
		clockNow = clockNow + (seconds or 0)
		ui.sync()
	end
	f.settle = function(code, extra)
		client.state.code = code
		client.state.request_id = (client.state.request_id or "") .. "+"
		for key, value in pairs(extra or {}) do
			client.state[key] = value
		end
		ui.sync()
	end
	ui.sync()
	return f
end

describe("Projects window controller", function()
	it("initializes with its own strings and no translator override, before the data model exists", function()
		local environment = setmetatable({
			Spring = {},
			WG = {},
		}, { __index = _G })
		local runtimeUI = VFS.Include("luaui/RmlWidgets/gui_terraform_brush/tf_map_library.lua", environment)
		local model = { projectHelperHint = "" }
		local state = { projectOpenSelectedSlug = "Design/arena", projectOpenIsFolder = false, teamSyncEnabled = true }
		local ui = runtimeUI.new(state, model)
		assert(model.libraryLabel_filterAll == "Projects")
		assert(model.libraryLabel_syncName == "Team Sync")
		assert(model.libraryStatus == "Team Sync is not running. Local projects work as usual.")
		assert(model.libraryStripDot == "unset")
		assert(type(model.libraryPublish) == "function" and type(model.librarySetFilter) == "function")
		-- Initialize builds the model before OpenDataModel supplies its handle.
		state.dmHandle = model
		ui.sync()
		assert(not model.libraryOnline and not model.libraryWritable and not model.libraryConfigured)
		local f = fixture()
		environment.WG.MapProject = f.project
		ui.sync()
		assert(model.libraryOnline and model.libraryConfigured and model.libraryStage == "Design")
		assert(model.libraryStripDot == "on" and model.libraryStripText == "team/maps")
		model.libraryPublish()
		assert(model.libraryConfirming)
		-- The question names the project and the stage: placeholders are filled here, not by an engine call.
		assert(model.libraryStatus:find("Design/arena", 1, true))
		assert(model.libraryStatus:find("to 'Design'", 1, true))
		assert(not model.libraryStatus:find("%%{"))
	end)

	it("requires a second click before publishing the selected project", function()
		local f = fixture()
		f.model.libraryPublish()
		assert(#f.calls == 0 and f.model.libraryConfirming)
		f.model.libraryPublish()
		assert(#f.calls == 1 and f.calls[1].operation == "publish")
		assert(f.calls[1].source == "Design/arena" and f.calls[1].stage == "Design")
	end)

	it("changing the destination or the selection disarms the confirmation", function()
		local f = fixture()
		f.model.libraryPublish()
		f.model.libraryStageStep(nil, 1)
		assert(not f.model.libraryConfirming and f.model.libraryStage == "Textures")
		f.model.libraryPublish()
		assert(#f.calls == 0)
		f.state.projectOpenSelectedSlug = "Design/other"
		f.model.libraryPublish()
		assert(#f.calls == 0)
		f.model.libraryPublish()
		assert(#f.calls == 1 and f.calls[1].source == "Design/other")
	end)

	it("a filter chip narrows the one list and lets the selection go", function()
		local f = fixture()
		f.model.libraryPublish()
		f.state.projectLocalDirty = false
		f.model.librarySetFilter(nil, "team")
		assert(f.model.libraryFilter == "team" and f.state.projectFilter == "team")
		assert(f.state.projectOpenSelectedSlug == nil and not f.model.libraryConfirming)
		assert(f.state.projectLocalDirty and f.state.projectOpenNeedsRebuild)
		-- The chip already active changes nothing.
		f.state.projectOpenSelectedSlug = "Design/arena"
		f.model.librarySetFilter(nil, "team")
		assert(f.state.projectOpenSelectedSlug == "Design/arena")
	end)

	it("OPEN on a team-only project downloads first, and only its own download continues the open", function()
		local f = fixture()
		f.state.projectOpenAfterDownload = "Design/arena"
		f.settle("pulled")
		assert(f.state.projectOpenAfterDownload == nil, "another result drops the chain")
		f.state.projectOpenAfterDownload = "Design/arena"
		f.settle("downloaded", { local_slug = "Design/arena" })
		assert(f.state.projectOpenChainReady and f.state.projectLocalDirty and f.state.projectOpenNeedsRebuild)
		-- A download the companion refuses before it leaves drops the chain too.
		f.state.projectOpenChainReady = false
		f.state.projectOpenAfterDownload = "Design/other"
		f.client.request = function()
			return false, "busy"
		end
		assert(not f.ui.download("Design/other"))
		assert(f.state.projectOpenAfterDownload == nil)
		-- And so does the companion going away.
		f.state.projectOpenAfterDownload = "Design/other"
		f.client.state.online = false
		f.ui.sync()
		assert(f.state.projectOpenAfterDownload == nil)
	end)

	it("disarms on reopen, on a new companion session, and when the companion cannot push", function()
		local f = fixture()
		f.model.libraryPublish()
		f.ui.disarm()
		assert(not f.model.libraryConfirming)
		f.model.libraryPublish()
		assert(#f.calls == 0)
		f.ui.disarm()
		f.model.libraryPublish()
		f.client.state.session = "new-session"
		f.ui.sync()
		assert(not f.model.libraryConfirming)
		f.model.libraryPublish()
		f.client.state.allow_push = false
		f.ui.sync()
		f.model.libraryPublish()
		assert(#f.calls == 0 and not f.model.libraryConfirming)
		f.client.state.online = false
		f.ui.sync()
		assert(f.model.libraryStatus == "offline" and f.model.libraryStripDot == "off")
	end)

	it("pulls once when a companion connects, unless its catalogue is fresh", function()
		local f = fixture({ stale = true })
		assert(#f.calls == 1 and f.calls[1].operation == "pull", "stale catalogue: pulled on connect")
		f.ui.sync()
		assert(#f.calls == 1, "once")
		f.client.state.session = "second"
		f.ui.sync()
		assert(#f.calls == 2 and f.calls[2].operation == "pull", "a new session pulls again")
		local fresh = fixture()
		assert(#fresh.calls == 0, "a catalogue fetched moments ago is not fetched again")
	end)

	it("the TEAM block opens the stage tray for an upload and cancels an armed one", function()
		local f = fixture()
		assert(not f.model.libraryUploadOpen)
		f.model.projectDeleteConfirming = true
		f.state.projectDeleteConfirmExpiry = 3
		f.model.libraryUploadTo()
		assert(f.model.libraryUploadOpen and f.model.libraryTrayMode == "upload" and #f.calls == 0)
		assert(f.model.libraryStage == "Design", "the project's own folder is the default destination")
		assert(not f.model.projectDeleteConfirming and f.state.projectDeleteConfirmExpiry == 0)
		f.model.libraryTrayCommit()
		assert(f.model.libraryConfirming and #f.calls == 0)
		f.model.libraryCancelUpload()
		assert(not f.model.libraryUploadOpen and not f.model.libraryConfirming and #f.calls == 0)
		f.model.libraryUploadTo()
		f.model.libraryTrayCommit()
		f.model.libraryTrayCommit()
		assert(not f.model.libraryUploadOpen and #f.calls == 1 and f.calls[1].operation == "publish")
	end)

	it("Update team copy aims at the project's folder and arms in one click", function()
		local f = fixture()
		f.model.libraryUpdateTeam()
		assert(f.model.libraryUploadOpen and f.model.libraryStage == "Design" and f.model.libraryConfirming)
		assert(f.model.libraryStatus == "publishQuestion" and #f.calls == 0)
		f.model.libraryTrayCommit()
		assert(#f.calls == 1 and f.calls[1].operation == "publish" and f.calls[1].stage == "Design")
		-- A team project outside the pipeline has no folder to aim at: the
		-- tray opens un-armed instead.
		f = fixture()
		f.state.projectOpenSelectedSlug = "loose"
		f.model.libraryUpdateTeam()
		assert(f.model.libraryUploadOpen and not f.model.libraryConfirming)
	end)

	it("Move to... stages a move through the same tray; CONFIRM MOVES sends it", function()
		local f = fixture()
		f.model.libraryMoveTo()
		assert(f.model.libraryUploadOpen and f.model.libraryTrayMode == "move")
		assert(f.model.libraryStage == "Textures", "the first stage that is not the project's own")
		f.model.libraryTrayCommit()
		assert(not f.model.libraryUploadOpen and #f.calls == 0)
		assert(f.ui.pendingMove("Design/arena") == "Textures")
		f.ui.sync()
		assert(f.model.libraryMovesOpen and f.model.libraryMovesPending == "movesPending")
		f.model.libraryDiscardMoves()
		assert(f.ui.pendingMoveCount() == 0 and not f.model.libraryMovesOpen)
		f.model.libraryMoveTo()
		f.model.libraryTrayCommit()
		f.model.libraryConfirmMoves()
		f.ui.sync()
		assert(#f.calls == 1 and f.calls[1].operation == "move" and f.calls[1].stage == "Textures")
	end)

	it("Get team version asks first only when the copy on this disk is the newer one", function()
		local f = fixture()
		f.state.sync = "mine"
		f.model.libraryDownload()
		assert(#f.calls == 0 and f.model.libraryConfirming and f.model.libraryGetConfirming)
		assert(f.model.libraryStatus == "getTeamQuestion")
		f.model.libraryDownload()
		assert(#f.calls == 1 and f.calls[1].operation == "download" and f.calls[1].source == "Design/arena")
		f = fixture()
		f.state.sync = "theirs"
		f.model.libraryDownload()
		assert(#f.calls == 1 and f.calls[1].operation == "download")
		f = fixture()
		f.state.sync = "synced"
		f.model.libraryDownload()
		assert(#f.calls == 0, "nothing to get")
	end)

	it("keeps the tray closed without an eligible selection or a companion that can push", function()
		local f = fixture()
		f.state.projectOpenSelectedSlug = nil
		f.model.libraryUploadTo()
		assert(not f.model.libraryUploadOpen)
		f.state.projectOpenSelectedSlug = "Design/arena"
		f.state.projectOpenIsFolder = true
		f.model.libraryUploadTo()
		assert(not f.model.libraryUploadOpen)
		f.state.projectOpenIsFolder = false
		f.client.state.allow_push = false
		f.ui.sync()
		f.model.libraryUploadTo()
		assert(not f.model.libraryUploadOpen and #f.calls == 0)
	end)

	it("closes the tray if the companion becomes busy or goes away", function()
		local f = fixture()
		f.model.libraryUploadTo()
		f.model.libraryTrayCommit()
		f.client.isBusy = function()
			return true
		end
		f.ui.sync()
		assert(not f.model.libraryUploadOpen and not f.model.libraryConfirming)
		assert(f.model.libraryConnection == "workingBadge" and f.model.libraryStripDot == "busy")
		f.client.isBusy = function()
			return false
		end
		f.ui.sync()
		f.model.libraryUploadTo()
		assert(f.model.libraryUploadOpen)
		f.client.state.online = false
		f.ui.sync()
		assert(not f.model.libraryUploadOpen and f.model.libraryConnection == "offlineBadge")
	end)

	it("the strip says where Team Sync stands", function()
		local f = fixture()
		assert(f.model.libraryStripDot == "on" and f.model.libraryStripAge == "stripUpdated")
		f.client.state.online = false
		f.ui.sync()
		assert(f.model.libraryStripDot == "off" and f.model.libraryStripText == "stripOffline")
		assert(f.model.libraryStripAge == "stripAsOf", "a cached catalogue has an age")
		-- Never configured: no status, no catalogue.
		f.client.state = {}
		f.client.catalog = { projects = {}, stages = {} }
		f.ui.sync()
		assert(not f.model.libraryConfigured and f.model.libraryStripDot == "unset")
		-- Connecting: busy before the first pull is "starting".
		f = fixture({ stale = true })
		f.client.isBusy = function()
			return true
		end
		f.ui.sync()
		assert(f.model.libraryStripDot == "starting")
		f.client.isBusy = function()
			return false
		end
		f.settle("pulled")
		f.client.isBusy = function()
			return true
		end
		f.ui.sync()
		assert(f.model.libraryStripDot == "busy")
	end)

	it("the start card records the starter and closes itself when the connection appears", function()
		local f = fixture()
		f.client.state.online = false
		f.ui.sync()
		f.model.libraryCardShow()
		assert(f.model.libraryCardOpen and not f.model.libraryCardWritten)
		f.state.projectWriteRunner = function()
			return true, "C:/BAR/data/Terraform Brush/Start map library helper.bat"
		end
		f.model.libraryCardWrite()
		assert(f.model.libraryCardWritten and f.model.libraryCardPath:find("helper.bat", 1, true))
		local copied
		local hadSpring = rawget(_G, "Spring")
		_G.Spring = {
			SetClipboard = function(text)
				copied = text
			end,
		}
		f.model.libraryCardCopy()
		_G.Spring = hadSpring
		assert(copied == f.model.libraryCardPath and f.model.libraryCardCopied)
		f.client.state.online = true
		f.ui.sync()
		assert(not f.model.libraryCardOpen, "connected: the card's job is done")
	end)

	it("the runner hint clears when Team Sync comes up, unless it says to restart", function()
		local f = fixture()
		f.client.state.online = false
		f.ui.sync()
		f.model.projectHelperHint = "helperReady"
		f.client.state.online = true
		f.ui.sync()
		assert(f.model.projectHelperHint == "")
		f.model.projectHelperHint = "helperStale"
		f.state.projectHelperHintSticky = true
		f.ui.sync()
		assert(f.model.projectHelperHint == "helperStale")
	end)

	it("an older companion build serving is named as the reason to restart", function()
		local f = fixture()
		f.client.state.helper = 1
		f.ui.sync()
		assert(f.model.projectHelperHint == "helperStale" and f.state.projectHelperHintSticky)
		f.client.state.online = false
		f.ui.sync()
		f.client.state.online = true
		f.ui.sync()
		assert(f.model.projectHelperHint == "helperStale", "sticky across a reconnect")
	end)

	it("shows compact repository identity while retaining the full URL and branch", function()
		local f = fixture()
		assert(f.model.libraryRepository == "team/maps" and f.model.libraryBranch == "main")
		assert(f.model.libraryRemoteURL == f.client.state.remote)
		f.client.state.remote = "git@github.com:other/library.git"
		f.client.state.branch = "intake"
		f.ui.sync()
		assert(f.model.libraryRepository == "other/library" and f.model.libraryBranch == "intake")
		f.client.state.allow_push = false
		f.ui.sync()
		assert(f.model.libraryConnection == "readOnlyBadge" and f.model.libraryStripText:find("stripReadOnly", 1, true))
	end)

	it("the status slot shows failures until dismissed and good news until it fades", function()
		local f = fixture()
		assert(not f.model.libraryStatusVisible and f.model.libraryConnection == "onlineBadge")
		f.settle("unsupported_file")
		assert(f.model.libraryStatusVisible and f.model.libraryStatusError and not f.model.libraryStatusSuccess)
		assert(f.model.libraryStatus == "unsupported_file" and f.model.libraryStatusTime ~= "")
		f.tick(60)
		assert(f.model.libraryStatusVisible, "bad news waits to be read")
		f.model.libraryDismissStatus()
		f.ui.sync()
		assert(not f.model.libraryStatusVisible)
		f.model.libraryPublish()
		assert(not f.model.libraryStatusVisible and f.model.libraryStatus == "publishQuestion")
		f.ui.disarm()
		f.settle("published", { target = "Design/arena" })
		assert(f.model.libraryStatusVisible and f.model.libraryStatusSuccess and not f.model.libraryStatusError)
		assert(f.state.libraryOutcome and f.state.libraryOutcome.ok and f.state.libraryOutcome.text == "published")
		f.tick(9)
		assert(not f.model.libraryStatusVisible, "good news fades")
		f.settle("ready")
		assert(not f.model.libraryStatusVisible and not f.model.libraryStatusSuccess)
	end)

	it("clears an obsolete destination and cannot publish without a pipeline folder", function()
		local f = fixture()
		f.model.libraryPublish()
		f.client.catalog.stages = {}
		f.ui.sync()
		assert(f.model.libraryStage == "" and not f.model.libraryConfirming)
		f.model.libraryPublish()
		f.model.libraryPublish()
		assert(#f.calls == 0 and not f.model.libraryConfirming)
	end)

	it("with the setting off, there is no team: no catalogue, no folders, no strip, no transfers", function()
		local f = fixture()
		f.model.libraryPublish()
		f.ui.queueMove("Design/arena", "Textures")
		f.state.teamSyncEnabled = false
		f.ui.sync()
		assert(not f.model.libraryEnabled and not f.model.libraryConfigured and not f.model.libraryOnline)
		assert(f.model.libraryStripDot == "unset" and not f.model.libraryConfirming and not f.model.libraryMovesOpen)
		assert(#f.ui.projects() == 0 and #f.ui.folders() == 0 and f.ui.pendingMoveCount() == 0)
		f.model.libraryUploadTo()
		f.model.libraryPull()
		assert(not f.model.libraryUploadOpen and #f.calls == 0, "nothing reaches the companion")
		f.state.teamSyncEnabled = true
		f.ui.sync()
		assert(f.model.libraryEnabled and f.model.libraryConfigured and f.model.libraryOnline)
		assert(#f.ui.folders() == 2)
	end)

	it("keys the team catalogue by slug for the widget's union list", function()
		local f = fixture()
		f.client.catalog.projects = { { slug = "Design/arena", folder = "Design" }, { slug = "loose" } }
		local bySlug = f.ui.teamBySlug()
		assert(bySlug["Design/arena"].folder == "Design" and bySlug.loose and not bySlug.other)
	end)
end)
