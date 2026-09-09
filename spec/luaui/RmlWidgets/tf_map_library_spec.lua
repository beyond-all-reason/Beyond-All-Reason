local LibraryUI = VFS.Include("luaui/RmlWidgets/gui_terraform_brush/tf_map_library.lua")

local function fixture()
	local calls = {}
	local client = {
		state = { online = true, allow_push = true, session = "session", code = "ready", request_id = "" },
		catalog = { projects = {}, stages = { "Design", "Textures" } },
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
	local model = {}
	local state = { dmHandle = model, projectOpenSelectedSlug = "arena" }
	local ui = LibraryUI.new(state, model, {
		getMapProject = function()
			return project
		end,
		translate = function(key)
			return key
		end,
	})
	ui.sync()
	return { client = client, calls = calls, model = model, state = state, ui = ui }
end

describe("map library UI decisions", function()
	it("initializes and handles events with BAR.I18N without a translator override", function()
		local translations = {}
		local environment = setmetatable({
			Spring = {}, -- I18N belongs to BAR, not the engine API table.
			WG = {},
			BAR = {
				I18N = function(key, values)
					translations[key] = values or true
					return key
				end,
			},
		}, { __index = _G })
		local runtimeUI = VFS.Include("luaui/RmlWidgets/gui_terraform_brush/tf_map_library.lua", environment)
		local model = {}
		local state = { projectOpenSelectedSlug = "arena" }
		local ui = runtimeUI.new(state, model)
		assert(model.libraryLabel_localTab == "ui.mapLibrary.localTab")
		assert(model.libraryStatus == "ui.mapLibrary.offline")
		assert(type(model.libraryPublish) == "function")

		-- Initialize builds the model before OpenDataModel supplies its handle.
		state.dmHandle = model
		ui.sync()
		assert(not model.libraryOnline and not model.libraryWritable)
		local f = fixture()
		environment.WG.MapProject = { library = f.client, isBusy = f.client.isBusy }
		ui.sync()
		assert(model.libraryOnline and model.libraryStage == "Design")
		assert(model.libraryStatus == "ui.mapLibrary.ready")
		model.libraryPublish()
		assert(model.libraryConfirming and #f.calls == 0)
		assert(model.libraryStatus == "ui.mapLibrary.publishQuestion")
		assert(translations["ui.mapLibrary.publishQuestion"].source == "arena")
		assert(translations["ui.mapLibrary.publishQuestion"].stage == "Design")
	end)

	it("requires a second click before publishing the selected saved project", function()
		local f = fixture()
		f.model.libraryPublish()
		assert(#f.calls == 0 and f.model.libraryConfirming)
		f.model.libraryPublish()
		assert(#f.calls == 1 and f.calls[1].operation == "publish")
		assert(f.calls[1].source == "arena" and f.calls[1].stage == "Design")
	end)

	it("changing the destination disarms upload confirmation", function()
		local f = fixture()
		f.model.libraryPublish()
		f.model.libraryStageStep(nil, 1)
		assert(not f.model.libraryConfirming and f.model.libraryStage == "Textures")
		f.model.libraryPublish()
		assert(#f.calls == 0)
	end)

	it("changing the selected map cannot reuse a previous confirmation", function()
		local f = fixture()
		f.model.libraryPublish()
		f.state.projectOpenSelectedSlug = "other"
		f.model.libraryPublish()
		assert(#f.calls == 0)
		f.model.libraryPublish()
		assert(#f.calls == 1 and f.calls[1].source == "other")
	end)

	it("switching tabs drops selection and cannot publish a remote row", function()
		local f = fixture()
		f.model.libraryPublish()
		f.model.librarySetTab(nil, true)
		assert(f.state.projectOpenSelectedSlug == nil and f.model.libraryRemote)
		f.state.projectOpenSelectedSlug = "Design/arena"
		f.model.libraryPublish()
		assert(#f.calls == 0)
		f.model.libraryDownload()
		assert(#f.calls == 1 and f.calls[1].operation == "download")
	end)

	it("download completion selects a local copy without opening or restarting", function()
		local f = fixture()
		f.model.librarySetTab(nil, true)
		f.state.projectOpenFilter = "Design/arena"
		f.client.state.code = "downloaded"
		f.client.state.request_id = "done"
		f.client.state.local_slug = "arena--copy"
		f.ui.sync()
		assert(not f.model.libraryRemote and f.state.projectOpenSelectedSlug == "arena--copy")
		assert(f.state.projectOpenNeedsRebuild and #f.calls == 0)
		assert(f.state.projectOpenFilter == "")
	end)

	it("reopening the browser does not inherit an armed upload", function()
		local f = fixture()
		f.model.libraryPublish()
		f.ui.disarm()
		assert(not f.model.libraryConfirming)
		f.model.libraryPublish()
		assert(#f.calls == 0)
	end)

	it("a new helper session cannot inherit upload confirmation", function()
		local f = fixture()
		f.model.libraryPublish()
		f.client.state.session = "new-session"
		f.ui.sync()
		assert(not f.model.libraryConfirming)
		f.model.libraryPublish()
		assert(#f.calls == 0)
	end)

	it("read-only and offline states disarm publication", function()
		local f = fixture()
		f.model.libraryPublish()
		f.client.state.allow_push = false
		f.ui.sync()
		f.model.libraryPublish()
		assert(#f.calls == 0 and not f.model.libraryConfirming)
		f.client.state.online = false
		f.ui.sync()
		assert(f.model.libraryStatus == "offline")
	end)

	it("opens an upload tray without publishing and cancels an armed upload", function()
		local f = fixture()
		assert(not f.model.libraryUploadOpen and not f.model.libraryDetailsOpen)
		f.model.projectDeleteConfirming = true
		f.state.projectDeleteConfirmExpiry = 3
		f.model.libraryToggleUpload()
		assert(f.model.libraryUploadOpen and #f.calls == 0)
		assert(not f.model.projectDeleteConfirming and f.state.projectDeleteConfirmExpiry == 0)
		f.model.libraryPublish()
		assert(f.model.libraryConfirming and #f.calls == 0)
		f.model.libraryCancelUpload()
		assert(not f.model.libraryUploadOpen and not f.model.libraryConfirming and #f.calls == 0)
		f.model.libraryToggleUpload()
		f.model.libraryPublish()
		assert(f.model.libraryConfirming and #f.calls == 0)
		f.model.libraryPublish()
		assert(not f.model.libraryUploadOpen and #f.calls == 1)
	end)

	it("keeps upload controls closed without an eligible local selection", function()
		local f = fixture()
		f.state.projectOpenSelectedSlug = nil
		f.model.libraryToggleUpload()
		assert(not f.model.libraryUploadOpen)
		f.state.projectOpenSelectedSlug = "arena"
		f.client.state.allow_push = false
		f.ui.sync()
		f.model.libraryToggleUpload()
		assert(not f.model.libraryUploadOpen)
		f.client.state.allow_push = true
		f.ui.sync()
		f.model.librarySetTab(nil, true)
		f.state.projectOpenSelectedSlug = "Design/arena"
		f.model.libraryToggleUpload()
		assert(not f.model.libraryUploadOpen and #f.calls == 0)
	end)

	it("closes the upload tray if the helper becomes busy or offline", function()
		local f = fixture()
		f.model.libraryToggleUpload()
		f.model.libraryPublish()
		f.client.isBusy = function()
			return true
		end
		f.ui.sync()
		assert(not f.model.libraryUploadOpen and not f.model.libraryConfirming)
		assert(f.model.libraryConnection == "workingBadge")
		f.model.libraryToggleUpload()
		assert(not f.model.libraryUploadOpen)
		f.client.isBusy = function()
			return false
		end
		f.ui.sync()
		f.model.libraryToggleUpload()
		assert(f.model.libraryUploadOpen)
		f.client.state.online = false
		f.ui.sync()
		assert(not f.model.libraryUploadOpen and f.model.libraryConnection == "offlineBadge")
	end)

	it("clicking the active tab preserves selection and switching tabs closes the tray", function()
		local f = fixture()
		f.model.libraryToggleUpload()
		f.model.libraryPublish()
		f.state.projectOpenNeedsRebuild = false
		f.model.librarySetTab(nil, false)
		assert(f.state.projectOpenSelectedSlug == "arena" and f.model.libraryConfirming)
		assert(f.model.libraryUploadOpen and not f.state.projectOpenNeedsRebuild)
		f.model.projectOpenHint = "old hint"
		f.model.librarySetTab(nil, true)
		assert(not f.model.libraryUploadOpen and not f.model.libraryConfirming)
		assert(f.model.projectOpenHint == "" and f.state.projectOpenNeedsRebuild)
	end)

	it("toggles help without changing the current tab or selection", function()
		local f = fixture()
		f.model.libraryToggleDetails()
		assert(f.model.libraryDetailsOpen)
		f.model.libraryToggleDetails()
		assert(not f.model.libraryDetailsOpen and not f.model.libraryRemote)
		assert(f.state.projectOpenSelectedSlug == "arena" and #f.calls == 0)
	end)

	it("shows compact repository identity while retaining the full URL and branch", function()
		local f = fixture()
		f.client.state.remote = "https://github.com/team/maps.git"
		f.client.state.branch = "main"
		f.ui.sync()
		assert(f.model.libraryRepository == "team/maps" and f.model.libraryBranch == "main")
		assert(f.model.libraryRemoteURL == f.client.state.remote)
		f.client.state.remote = "git@github.com:other/library.git"
		f.client.state.branch = "intake"
		f.ui.sync()
		assert(f.model.libraryRepository == "other/library" and f.model.libraryBranch == "intake")
		f.client.state.allow_push = false
		f.ui.sync()
		assert(f.model.libraryConnection == "readOnlyBadge")
	end)

	it("hides routine status prose but keeps failures and completed transfers visible", function()
		local f = fixture()
		assert(not f.model.libraryStatusVisible and f.model.libraryConnection == "onlineBadge")
		f.client.state.code = "unsupported_file"
		f.ui.sync()
		assert(f.model.libraryStatusVisible and f.model.libraryStatusError and not f.model.libraryStatusSuccess)
		assert(f.model.libraryStatus == "unsupported_file")
		f.model.libraryPublish()
		assert(not f.model.libraryStatusVisible and f.model.libraryStatus == "publishQuestion")
		f.ui.disarm()
		f.client.state.code = "published"
		f.client.state.request_id = "uploaded"
		f.ui.sync()
		assert(f.model.libraryStatusVisible and f.model.libraryStatusSuccess and not f.model.libraryStatusError)
		f.client.state.code = "ready"
		f.ui.sync()
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
end)

-- Exercise the production browser callback without booting the rendering-heavy
-- widget. Keep its function body intact; mocks cover only the list/document seam.
local function renderBrowser(remote, projects)
	local file = assert(io.open("luaui/RmlWidgets/gui_terraform_brush/gui_terraform_brush.lua", "r"))
	local source = file:read("*a")
	file:close()
	local callback = assert(source:match("(\tonFileOpenProject = function%(_event%).-)\n\t%-%- LOAD PROJECT / DELETE"))
	local f = fixture()
	f.client.catalog.stages = {}
	f.client.catalog.projects = projects
	f.state.projectLibraryRemote = remote
	f.state.projectLibraryUi = f.ui
	f.state.relativeAge = function()
		return "2h ago"
	end
	local list = { inner_rml = "" }
	f.state.document = {
		GetElementById = function(_, id)
			return id == "tf-project-open-list" and list or nil
		end,
	}
	local translations = {}
	local environment = setmetatable({
		widgetState = f.state,
		playSound = function() end,
		Spring = {},
		BAR = {
			I18N = function(key)
				translations[#translations + 1] = key
				return "Localized <message> & text"
			end,
		},
		WG = {
			MapProject = {
				listDetailed = function()
					return projects
				end,
			},
		},
	}, { __index = _G })
	local chunk = assert(loadstring("return {\n" .. callback .. "\n}", "@project-browser-callback"))
	setfenv(chunk, environment)
	chunk().onFileOpenProject()
	return list.inner_rml, translations
end

describe("map library project browser markup", function()
	it("localizes and escapes empty local and remote lists without Spring.I18N", function()
		local markup, keys = renderBrowser(false, {})
		assert(keys[1] == "ui.mapLibrary.localEmpty")
		assert(markup:find("Localized &lt;message&gt; &amp; text", 1, true))
		markup, keys = renderBrowser(true, {})
		assert(keys[1] == "ui.mapLibrary.empty")
		assert(markup:find("Localized &lt;message&gt; &amp; text", 1, true))
	end)

	it("renders the escaped project name and size above the date", function()
		local markup = renderBrowser(false, {
			{ slug = "arena", name = "A <map> & friend", size_x = 16, size_z = 8 },
		})
		local heading = assert(markup:find('class="tf-project-row-heading"', 1, true))
		local name = assert(markup:find("A &lt;map&gt; &amp; friend", 1, true))
		local size = assert(markup:find("16x8", 1, true))
		local metadata = assert(markup:find('class="tf-project-row-meta"', 1, true))
		local date = assert(markup:find("2h ago", 1, true))
		assert(heading < name and name < size and size < metadata and metadata < date)
	end)
end)
