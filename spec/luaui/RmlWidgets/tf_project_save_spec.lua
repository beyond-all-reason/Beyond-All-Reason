local SaveUI = VFS.Include("luaui/RmlWidgets/gui_terraform_brush/tf_map_library.lua")

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
	f.state = { dmHandle = f.model, projectSaveUnits = false }
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
	f.complete = function(ok, uploadReady)
		f.busy = false
		f.receipt.done, f.receipt.ok, f.receipt.uploadReady = true, ok, uploadReady
		f.lastSave = f.receipt
	end
	f.startUpload = function(name)
		f.model.projectSaveSetUpload(nil, true)
		assert(not f.ui.save(name or "arena"))
		assert(f.ui.save(name or "arena"))
	end
	return f
end

describe("Save As and automatic team upload", function()
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
				assert(initial.libraryLabel_saveTitle == "ui.mapLibrary.saveTitle")
				return initial
			end,
		}
		local environment = setmetatable({
			widgetState = state,
			initialModel = model,
			MODEL_NAME = "test",
			WG = {},
			BAR = {
				I18N = function(key)
					return key
				end,
			},
			RmlUi = {
				GetContext = function()
					return context
				end,
			},
		}, { __index = _G })
		environment.VFS = {
			Include = function(path)
				-- Recoil's mounted .sdd index predates the new Save As source file.
				assert(
					path == "luaui/RmlWidgets/gui_terraform_brush/tf_map_library.lua",
					"File not seen by VFS: " .. path
				)
				includes[#includes + 1] = path
				return VFS.Include(path, environment)
			end,
		}
		local chunk = assert(loadstring("return function(self)\n" .. initialize .. "\nend"))
		setfenv(chunk, environment)
		chunk()({})
		assert(#includes == 1 and state.dmHandle == model)
		assert(type(state.projectLibraryUi.sync) == "function" and type(state.projectSaveUi.save) == "function")
		state.projectSaveUi.sync()
	end)

	it("the production Save handler reads live unblurred input instead of cached text", function()
		local file = assert(io.open("luaui/RmlWidgets/gui_terraform_brush/gui_terraform_brush.lua", "r"))
		local source = file:read("*a")
		file:close()
		local callback = assert(source:match("(\tonProjectSaveConfirm = function%(_event%).-)\n\tend,")) .. "\n\tend,"
		local f = fixture()
		f.state.projectNameStr = "stale-name"
		f.state.projectSaveUi = f.ui
		f.state.document = {
			GetElementById = function(_, id)
				assert(id == "input-project-name")
				return {
					GetAttribute = function()
						return "fresh-name"
					end,
				}
			end,
		}
		local chunk = assert(loadstring("return {" .. callback .. "}"))
		setfenv(chunk, setmetatable({ widgetState = f.state, playSound = function() end }, { __index = _G }))
		chunk().onProjectSaveConfirm()
		assert(#f.saves == 1 and f.saves[1][1] == "fresh-name" and #f.requests == 0)
	end)

	it("a failed preflight drops an earlier confirmation", function()
		local f = fixture()
		f.model.projectSaveSetUpload(nil, true)
		f.ui.save("arena")
		f.ui.save("../invalid")
		assert(not f.model.projectSaveConfirming)
		assert(not f.ui.save("arena") and #f.saves == 0)
	end)

	it("installs final callbacks before the data model exists, using BAR.I18N", function()
		local environment = setmetatable(
			{ WG = {}, BAR = {
				I18N = function(key)
					return key
				end,
			} },
			{ __index = _G }
		)
		local module = VFS.Include("luaui/RmlWidgets/gui_terraform_brush/tf_map_library.lua", environment)
		local model, state = {}, {}
		local ui = module.newSave(state, model)
		ui.sync()
		assert(model.libraryLabel_saveTitle == "ui.mapLibrary.saveTitle")
		assert(type(model.projectSaveSetUpload) == "function")
	end)

	it("defaults to local-only and closes after an accepted local save", function()
		local f = fixture()
		assert(not f.model.projectSaveUpload)
		assert(f.ui.save("arena"))
		assert(#f.saves == 1 and #f.requests == 0 and not f.model.projectSaveOpen)
		f.complete(true, true)
		f.ui.sync()
		assert(#f.requests == 0)
	end)

	it("combines overwrite and units removal into one second-click confirmation", function()
		local f = fixture()
		f.exists, f.hasUnits = true, true
		assert(not f.ui.save("arena"))
		assert(f.model.projectSaveHint:find("overwriteQuestion", 1, true))
		assert(f.model.projectSaveHint:find("dropUnitsQuestion", 1, true))
		assert(f.ui.save("arena") and #f.saves == 1)
	end)

	it("preserves current-project overwrite semantics and units opt-in", function()
		local f = fixture()
		f.exists, f.hasUnits, f.current = true, true, "arena"
		f.state.projectSaveUnits = true
		assert(f.ui.save("arena"))
		assert(f.saves[1][2].saveUnits)
	end)

	it("requires confirmation then publishes the exact completed normalized save once", function()
		local f = fixture()
		f.model.projectSaveSetUpload(nil, true)
		assert(not f.ui.save(" /campaign/arena/ "))
		assert(f.model.projectSaveConfirming and #f.saves == 0 and #f.requests == 0)
		assert(f.ui.save(" /campaign/arena/ "))
		assert(f.model.projectSavePending and f.model.projectSaveOpen and #f.requests == 0)
		f.ui.sync()
		assert(#f.requests == 0)
		f.complete(true, true)
		f.ui.sync()
		f.ui.sync()
		assert(#f.requests == 1 and f.requests[1][1] == "publish")
		assert(f.requests[1][2] == "campaign/arena" and f.requests[1][3] == "Design")
		assert(f.requests[1][4].session == "session" and f.requests[1][4].remote == "repo")
	end)

	it("never uses a previous successful result to publish an in-progress save", function()
		local f = fixture()
		f.lastSave = { slug = "arena", done = true, ok = true, uploadReady = true }
		f.startUpload()
		f.busy = false -- even idle alone is not completion
		f.ui.sync()
		assert(#f.requests == 0 and f.model.projectSavePending)
	end)

	it("never uploads rejected, failed or incomplete saves", function()
		local f = fixture()
		f.accept = false
		f.model.projectSaveSetUpload(nil, true)
		f.ui.save("arena")
		assert(not f.ui.save("arena"))
		assert(#f.requests == 0 and not f.model.projectSavePending and f.model.projectSaveError)
		for _, result in ipairs({ { false, false }, { true, false } }) do
			f = fixture()
			f.startUpload()
			f.complete(result[1], result[2])
			f.ui.sync()
			assert(#f.requests == 0 and not f.model.projectSavePending and f.model.projectSaveError)
		end
	end)

	it("requires a fresh confirmation after name, units, stage or destination edits", function()
		for _, change in ipairs({
			function(f)
				f.state.projectSaveUnits = true
			end,
			function(f)
				f.model.libraryStage = "Textures"
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
			f.model.projectSaveSetUpload(nil, true)
			f.ui.save("arena")
			change(f)
			assert(not f.ui.save("arena") and #f.saves == 0)
		end
		local f = fixture()
		f.model.projectSaveSetUpload(nil, true)
		f.ui.save("arena")
		assert(not f.ui.save("other") and #f.saves == 0)
		f.ui.changed()
		assert(not f.model.projectSaveConfirming)
	end)

	it("closing or reopening before save discards confirmation and defaults local", function()
		local f = fixture()
		f.model.projectSaveSetUpload(nil, true)
		f.ui.save("arena")
		f.ui.close()
		assert(not f.model.projectSaveConfirming)
		assert(f.ui.open() and not f.model.projectSaveUpload)
		assert(#f.saves == 0 and #f.requests == 0)
	end)

	it("offline, read-only, busy and missing destinations do not start team saves", function()
		for _, change in ipairs({
			function(f)
				f.client.state.online = false
			end,
			function(f)
				f.client.state.allow_push = false
			end,
			function(f)
				f.busy = true
			end,
			function(f)
				f.model.libraryStage = ""
			end,
		}) do
			local f = fixture()
			f.model.projectSaveSetUpload(nil, true)
			change(f)
			f.ui.save("arena")
			f.ui.save("arena")
			assert(#f.saves == 0 and #f.requests == 0 and f.model.projectSaveError)
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
				f.lastSave = { done = true, ok = true, slug = "arena" }
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

	it("keeps confirmed work running when hidden and prevents duplicate clicks", function()
		local f = fixture()
		f.startUpload()
		f.ui.close()
		f.model.projectSaveOpen = false
		assert(not f.ui.open())
		f.model.projectSaveSetUpload(nil, false)
		assert(f.model.projectSaveUpload and not f.ui.save("other") and #f.saves == 1)
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
		assert(f.model.projectSaveHint == "savedUploadFailed:arena:read_only")
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
			f.client.state.request_id, f.client.state.target = "upload-1", "Design/arena--copy"
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
