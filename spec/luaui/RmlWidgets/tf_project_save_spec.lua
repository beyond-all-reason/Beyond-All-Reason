local SaveUI = VFS.Include("luaui/RmlWidgets/gui_terraform_brush/tf_map_library.lua")

-- The Save As controller: one tree, the folder in the name is the destination,
-- and "upload to team after saving" is a switch the widget offers while the
-- folder is one of the team's stages (the widget computes that; the fixture
-- states it).
local function fixture()
	local f = { saves = {}, requests = {}, busy = false, accept = true }
	f.client = {
		state = { online = true, allow_push = true, session = "session", remote = "repo", branch = "main" },
		request = function(operation, source, stage, expected)
			f.requests[#f.requests + 1] = { operation, source, stage, expected }
			if f.requestError then
				return false, f.requestError
			end
			return true, "upload-1"
		end,
	}
	f.project = {
		library = f.client,
		validateSlug = function(name)
			if name:find("..", 1, true) or name == "" then
				return nil
			end
			return name:gsub("^/+", ""):gsub("/+$", "")
		end,
		isBusy = function()
			return f.busy
		end,
		current = function()
			return f.current
		end,
		exists = function()
			return f.exists == true
		end,
		hasUnitsSection = function()
			return f.hasUnits == true
		end,
		lastSave = function()
			return f.lastSave
		end,
		save = function(name, options)
			f.saves[#f.saves + 1] = { name, options }
			if not f.accept then
				return false
			end
			f.busy = true
			f.receipt = { slug = name, done = false }
			return true, f.receipt
		end,
	}
	f.model = { projectSaveOpen = true, libraryStage = "Design" }
	f.state = {
		dmHandle = f.model,
		projectSaveUnits = false,
		projectNameStr = "Design/arena",
		projectTeamDestinations = function()
			return { Design = true, Textures = true }
		end,
		projectTeamBySlug = function()
			return f.teamHas and { [f.teamHas] = { slug = f.teamHas } } or {}
		end,
		projectSyncTarget = function() end,
	}
	f.dependencies = {
		getMapProject = function()
			return f.project
		end,
		translate = function(key, values)
			return key
				.. (
					values
						and (":" .. (values.name or "") .. ":" .. (values.stage or values.target or values.reason or ""))
					or ""
				)
		end,
	}
	f.ui = SaveUI.newSave(f.state, f.model, f.dependencies)
	-- newSave installs its own defaults; the widget would set these from the
	-- folder in the name, so the fixture states them after construction.
	f.model.projectSaveIsStage = true
	f.model.projectSaveUploadAllowed = true
	f.complete = function(ok, uploadReady)
		f.busy = false
		f.receipt.done, f.receipt.ok, f.receipt.uploadReady = true, ok, uploadReady
		f.lastSave = f.receipt
	end
	-- A save + upload of a name the team library does not hold yet: no
	-- confirmation stands in the way, the click saves.
	f.startUpload = function(name)
		f.model.projectSaveSetUpload(nil, true)
		assert(f.ui.save(name or "Design/arena"))
	end
	return f
end

describe("Save As and the upload switch", function()
	it("initializes both project controllers when the mounted VFS cannot see newly added files", function()
		local file = assert(io.open("luaui/RmlWidgets/gui_terraform_brush/gui_terraform_brush.lua", "r"))
		local source = file:read("*a")
		file:close()
		local initialize = assert(source:match("function widget:Initialize%(%)%s*(.-)\n\t%-%- Match%-end state"))
		local model, state, includes = {}, {}, {}
		local context = {
			OpenDataModel = function(_, _, initial)
				assert(initial == model)
				assert(type(initial.libraryPublish) == "function")
				assert(type(initial.projectSaveSetUpload) == "function")
				assert(initial.libraryLabel_saveTitle == "Save Project As")
				return initial
			end,
		}
		local environment = setmetatable({
			widgetState = state,
			initialModel = model,
			MODEL_NAME = "test",
			WG = {},
			RmlUi = {
				GetContext = function()
					return context
				end,
			},
		}, { __index = _G })
		environment.VFS = {
			Include = function(path)
				-- Recoil's mounted .sdd index predates the new Save As source file,
				-- and the strings file the panel pulls in behind it.
				assert(
					path == "luaui/RmlWidgets/gui_terraform_brush/tf_map_library.lua"
						or path == "luaui/RmlWidgets/gui_terraform_brush/tf_strings.lua",
					"File not seen by VFS: " .. path
				)
				includes[#includes + 1] = path
				return VFS.Include(path, environment)
			end,
		}
		local chunk = assert(loadstring("return function(self)\n" .. initialize .. "\nend"))
		setfenv(chunk, environment)
		chunk()({})
		assert(includes[1] == "luaui/RmlWidgets/gui_terraform_brush/tf_map_library.lua")
		assert(state.dmHandle == model)
		assert(type(state.projectLibraryUi.sync) == "function" and type(state.projectSaveUi.save) == "function")
		state.projectSaveUi.sync()
	end)

	it("the production Save handler reads the live field, not the mirror", function()
		local file = assert(io.open("luaui/RmlWidgets/gui_terraform_brush/gui_terraform_brush.lua", "r"))
		local source = file:read("*a")
		file:close()
		local callback = assert(source:match("(\tonProjectSaveConfirm = function%(_event%).-)\n\tend,")) .. "\n\tend,"
		local f = fixture()
		f.state.projectNameStr = "stale-name"
		f.state.projectSaveUi = f.ui
		f.state.projectSaveFullName = function()
			return "fresh-name"
		end
		local chunk = assert(loadstring("return {" .. callback .. "}"))
		setfenv(chunk, setmetatable({ widgetState = f.state, playSound = function() end }, { __index = _G }))
		chunk().onProjectSaveConfirm()
		assert(#f.saves == 1 and f.saves[1][1] == "fresh-name" and #f.requests == 0)
		assert(f.state.projectNameStr == "fresh-name")
	end)

	it("a failed preflight drops an earlier confirmation", function()
		local f = fixture()
		f.exists = true
		f.model.projectSaveSetUpload(nil, true)
		f.ui.save("Design/arena")
		f.ui.save("../invalid")
		assert(not f.model.projectSaveConfirming)
		assert(not f.ui.save("Design/arena") and #f.saves == 0)
	end)

	it("installs final callbacks before the data model exists", function()
		local environment = setmetatable({ WG = {} }, { __index = _G })
		local module = VFS.Include("luaui/RmlWidgets/gui_terraform_brush/tf_map_library.lua", environment)
		local model, state = {}, {}
		local ui = module.newSave(state, model)
		ui.sync()
		assert(model.libraryLabel_saveTitle == "Save Project As")
		assert(model.libraryLabel_uploadAfter == "Upload to team after saving")
		assert(type(model.projectSaveSetUpload) == "function")
		assert(not model.projectSaveUpload and not model.projectSaveIsStage)
	end)

	it("saves on this disk and closes when the switch is off", function()
		local f = fixture()
		assert(not f.model.projectSaveUpload)
		assert(f.ui.save("arena"))
		assert(#f.saves == 1 and #f.requests == 0 and not f.model.projectSaveOpen)
		f.complete(true, true)
		f.ui.sync()
		assert(#f.requests == 0)
	end)

	it("the switch only turns while the widget says an upload is possible", function()
		local f = fixture()
		f.model.projectSaveUploadAllowed = false
		f.model.projectSaveSetUpload(nil, true)
		assert(not f.model.projectSaveUpload)
		f.model.projectSaveUploadAllowed = true
		f.model.projectSaveSetUpload(nil, true)
		assert(f.model.projectSaveUpload and f.state.projectSaveUploadChoice == true)
		assert(f.model.projectSaveAction == "saveUpload:" .. ":")
		f.model.projectSaveSetUpload(nil, false)
		assert(not f.model.projectSaveUpload and f.model.projectSaveAction == "save:" .. ":")
	end)

	it("combines overwrite and units removal into one second-click confirmation, named on the button", function()
		local f = fixture()
		f.exists, f.hasUnits = true, true
		assert(not f.ui.save("arena"))
		assert(f.model.projectSaveHint:find("overwriteQuestion", 1, true))
		assert(f.model.projectSaveHint:find("dropUnitsQuestion", 1, true))
		f.state.projectNameStr = "arena"
		f.ui.sync()
		assert(f.model.projectSaveAction == "replaceName:arena:")
		assert(f.ui.save("arena") and #f.saves == 1)
	end)

	it("preserves current-project overwrite semantics and units opt-in", function()
		local f = fixture()
		f.exists, f.hasUnits, f.current = true, true, "arena"
		f.state.projectSaveUnits = true
		assert(f.ui.save("arena"))
		assert(f.saves[1][2].saveUnits)
	end)

	it("a team copy at that path asks once, then saves and publishes the normalized name once", function()
		local f = fixture()
		f.teamHas = "Design/arena"
		f.model.projectSaveSetUpload(nil, true)
		assert(not f.ui.save(" /Design/arena/ "))
		assert(f.model.projectSaveConfirming and #f.saves == 0 and #f.requests == 0)
		assert(f.model.projectSaveHint:find("saveUploadQuestion", 1, true))
		assert(f.ui.save(" /Design/arena/ "))
		assert(f.model.projectSavePending and not f.model.projectSaveOpen and #f.requests == 0)
		f.ui.sync()
		assert(#f.requests == 0)
		f.complete(true, true)
		f.ui.sync()
		f.ui.sync()
		assert(#f.requests == 1 and f.requests[1][1] == "publish")
		assert(f.requests[1][2] == "Design/arena" and f.requests[1][3] == "Design")
		assert(f.requests[1][4].session == "session" and f.requests[1][4].remote == "repo")
		assert(f.state.libraryProgress ~= nil, "the editor strip shows UPLOADING")
	end)

	it("a new team path saves on the first click and uploads once the save completes", function()
		local f = fixture()
		f.startUpload()
		assert(#f.saves == 1 and f.model.projectSavePending and not f.model.projectSaveOpen)
		f.complete(true, true)
		f.ui.sync()
		assert(#f.requests == 1 and f.requests[1][3] == "Design")
		f.client.state.request_id, f.client.state.code, f.client.state.target = "upload-1", "published", "Design/arena"
		f.ui.sync()
		assert(not f.model.projectSavePending and f.model.projectSaveSuccess)
		assert(f.state.libraryOutcome and f.state.libraryOutcome.ok and f.state.libraryProgress == nil)
	end)

	it("never uses a previous successful result to publish an in-progress save", function()
		local f = fixture()
		f.lastSave = { slug = "Design/arena", done = true, ok = true, uploadReady = true }
		f.startUpload()
		f.busy = false -- even idle alone is not completion
		f.ui.sync()
		assert(#f.requests == 0 and f.model.projectSavePending)
	end)

	it("never uploads rejected, failed or incomplete saves", function()
		local f = fixture()
		f.accept = false
		f.model.projectSaveSetUpload(nil, true)
		assert(not f.ui.save("Design/arena"))
		assert(#f.requests == 0 and not f.model.projectSavePending and f.model.projectSaveError)
		for _, result in ipairs({ { false, false }, { true, false } }) do
			f = fixture()
			f.startUpload()
			f.complete(result[1], result[2])
			f.ui.sync()
			assert(#f.requests == 0 and not f.model.projectSavePending and f.model.projectSaveError)
		end
	end)

	it("requires a fresh confirmation after name, units, switch or destination edits", function()
		for _, change in ipairs({
			function(f)
				f.state.projectSaveUnits = true
			end,
			function(f)
				f.model.projectSaveSetUpload(nil, false)
			end,
			function(f)
				f.client.state.session = "new"
			end,
			function(f)
				f.client.state.remote = "other"
			end,
			function(f)
				f.client.state.branch = "other"
			end,
		}) do
			local f = fixture()
			f.exists = true
			f.model.projectSaveSetUpload(nil, true)
			f.ui.save("Design/arena")
			change(f)
			assert(not f.ui.save("Design/arena") and #f.saves == 0)
		end
		local f = fixture()
		f.exists = true
		f.model.projectSaveSetUpload(nil, true)
		f.ui.save("Design/arena")
		assert(not f.ui.save("Design/other") and #f.saves == 0)
		f.ui.changed()
		assert(not f.model.projectSaveConfirming)
	end)

	it("closing or reopening before the save discards the confirmation", function()
		local f = fixture()
		f.exists = true
		f.model.projectSaveSetUpload(nil, true)
		f.ui.save("Design/arena")
		f.ui.close()
		assert(not f.model.projectSaveConfirming)
		assert(f.ui.open())
		assert(#f.saves == 0 and #f.requests == 0)
	end)

	it("offline, read-only, busy and a folder outside the pipeline do not start team saves", function()
		for _, case in ipairs({
			{
				"Design/arena",
				function(f)
					f.client.state.online = false
				end,
			},
			{
				"Design/arena",
				function(f)
					f.client.state.allow_push = false
				end,
			},
			{
				"Design/arena",
				function(f)
					f.busy = true
				end,
			},
			{ "arena", function(_f) end },
		}) do
			local f = fixture()
			f.model.projectSaveSetUpload(nil, true)
			case[2](f)
			f.ui.save(case[1])
			f.ui.save(case[1])
			assert(#f.saves == 0 and #f.requests == 0 and f.model.projectSaveError, case[1])
		end
	end)

	it("destination or project-widget replacement during save cancels automatic publication", function()
		for _, change in ipairs({
			function(f)
				f.client.state.session = "other"
			end,
			function(f)
				f.client.state.remote = "other"
			end,
			function(f)
				f.client.state.branch = "other"
			end,
			function(f)
				f.project = nil
			end,
		}) do
			local f = fixture()
			f.startUpload()
			f.complete(true, true)
			change(f)
			f.ui.sync()
			assert(#f.requests == 0 and not f.model.projectSavePending and f.model.projectSaveError)
		end
	end)

	it("rejects superseding saves or busy project activity before enqueue", function()
		for _, change in ipairs({
			function(f)
				f.lastSave = { done = true, ok = true, slug = "Design/arena" }
			end,
			function(f)
				f.busy = true
			end,
		}) do
			local f = fixture()
			f.startUpload()
			f.complete(true, true)
			change(f)
			f.ui.sync()
			assert(#f.requests == 0 and not f.model.projectSavePending)
		end
	end)

	it("keeps confirmed work running with the window closed and ignores clicks meanwhile", function()
		local f = fixture()
		f.startUpload()
		assert(not f.model.projectSaveOpen)
		assert(not f.ui.open(), "the window will not reopen over the running upload")
		f.model.projectSaveSetUpload(nil, false)
		assert(f.model.projectSaveUpload and not f.ui.save("Design/other") and #f.saves == 1)
		f.complete(true, true)
		f.ui.sync()
		assert(#f.requests == 1)
	end)

	it("does not resurrect a pending upload after UI reload", function()
		local f = fixture()
		f.startUpload()
		local reloaded = SaveUI.newSave(f.state, f.model, f.dependencies)
		f.complete(true, true)
		reloaded.sync()
		assert(#f.requests == 0 and not f.model.projectSavePending)
	end)

	it("queue failures retain local success and never retry automatically", function()
		local f = fixture()
		f.startUpload()
		f.requestError = "read_only"
		f.complete(true, true)
		f.ui.sync()
		f.ui.sync()
		assert(#f.requests == 1 and f.model.projectSaveError and not f.model.projectSavePending)
		assert(f.model.projectSaveHint == "savedUploadFailed:Design/arena:read_only")
	end)

	it("shows only its matching upload result and preserves failure details", function()
		for _, code in ipairs({ "published", "push_rejected" }) do
			local f = fixture()
			f.startUpload()
			f.complete(true, true)
			f.ui.sync()
			f.client.state.request_id, f.client.state.code = "other-request", code
			f.ui.sync()
			assert(f.model.projectSavePending)
			f.client.state.request_id, f.client.state.target = "upload-1", "Design/arena"
			f.ui.sync()
			assert(not f.model.projectSavePending and #f.requests == 1)
			assert(f.model.projectSaveSuccess == (code == "published"))
			assert(f.model.projectSaveError == (code ~= "published"))
		end
	end)

	it("reports uncertain outcome rather than resubmitting on helper disconnect", function()
		local f = fixture()
		f.startUpload()
		f.complete(true, true)
		f.ui.sync()
		f.client.state.online = false
		f.ui.sync()
		f.client.state.online = true
		f.ui.sync()
		assert(#f.requests == 1 and f.model.projectSaveHint == "uploadInterrupted")
	end)
end)
