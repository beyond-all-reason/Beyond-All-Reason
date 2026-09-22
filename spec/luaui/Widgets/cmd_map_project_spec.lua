-- Exercise the real widget/API/pump with in-memory files. Only rendering-bound
-- section writers are skipped; prepare, heightmap, manifest and finish stay real.
local function upvalue(fn, wanted)
	for index = 1, 60 do
		local name, value = debug.getupvalue(fn, index)
		if name == wanted then
			return value
		end
	end
	error("missing upvalue " .. wanted)
end

local function fixture()
	local f = { files = {}, writes = {}, requests = {} }
	local function noop() end
	f.client = {
		state = { online = true, allow_push = true, session = "session", remote = "repo", branch = "main" },
		isBusy = function()
			return f.libraryBusy == true
		end,
		update = noop,
		request = function(operation, source)
			assert(not f.project.isBusy())
			assert(f.files["MapProjects/" .. source .. "/project.lua"])
			f.requests[#f.requests + 1] = operation
			return true, "request"
		end,
	}
	f.codec = {
		encodeGray16 = function()
			return "png-bytes"
		end,
	}
	f.environment = setmetatable({
		widget = {},
		WG = {},
		gl = {},
		Game = { mapSizeX = 512, mapSizeZ = 512, squareSize = 512, mapName = "test" },
		Spring = {
			Echo = noop,
			CreateDir = noop,
			GetMapOptions = function()
				return { blank_map_x = 1, blank_map_y = 1 }
			end,
			GetGroundHeight = function()
				return 0
			end,
		},
		widgetHandler = { AddAction = noop, RegisterGlobal = noop, RemoveAction = noop, DeregisterGlobal = noop },
		VFS = {
			Include = function(path)
				if path == "luaui/Include/map_library.lua" then
					return {
						new = function()
							return f.client
						end,
					}
				end
				assert(path == "luaui/Widgets/cmd_terraform_brush_png.lua")
				return f.codec
			end,
			-- The autosave listing walks its folder; the fixture holds no
			-- folders, so this session's journal is the only source.
			SubDirs = function()
				return {}
			end,
			DirList = function()
				return {}
			end,
		},
		io = {
			open = function(path, mode)
				if not mode:find("w", 1, true) then
					if not f.files[path] then
						return nil
					end
					return {
						read = function()
							return f.files[path]
						end,
						close = function()
							return true
						end,
						seek = function()
							return #f.files[path]
						end,
					}
				end
				local fail = path == f.failPath and f.failMode
				if fail == "open" then
					return nil
				end
				return {
					write = function(_, content)
						if fail == "write" then
							return nil
						end
						f.files[path] = content
						f.writes[#f.writes + 1] = path
						return true
					end,
					close = function()
						return fail ~= "close"
					end,
				}
			end,
		},
	}, { __index = _G })
	VFS.Include("luaui/Widgets/cmd_map_project.lua", f.environment)
	f.widget = f.environment.widget
	f.widget:Initialize()
	f.project = f.environment.WG.MapProject
	assert(f.project)
	f.steps = {}
	for _, step in ipairs(upvalue(f.widget.DrawScreenPost, "STEPS")) do
		f.steps[step.name] = { entry = step, original = step.run }
		if step.name ~= "prepare" and step.name ~= "heightmap" and step.name ~= "manifest" then
			step.run = function()
				return true
			end
		end
	end
	f.pump = function()
		for _ = 1, 100 do
			if not f.project.saveProgress() then
				return
			end
			f.widget:DrawScreenPost()
		end
		error("save did not finish")
	end
	return f
end

describe("map project completion receipts", function()
	it("returns a unique normalized receipt and completes only after the real manifest write", function()
		local f = fixture()
		local accepted, receipt = f.project.save("/campaign/arena/")
		assert(accepted and receipt.slug == "campaign/arena" and not receipt.done)
		assert(f.project.lastSave() == nil)
		f.pump()
		assert(receipt.done and receipt.ok and receipt.uploadReady and f.project.lastSave() == receipt)
		assert(f.files["MapProjects/campaign/arena/project.lua"]:find('kind = "bar-map-project"', 1, true))
		local _, nextReceipt = f.project.save("campaign/arena")
		assert(nextReceipt ~= receipt and not nextReceipt.done and f.project.lastSave() == receipt)
	end)

	it("manifest open, write and close failures cannot report save success", function()
		for _, mode in ipairs({ "open", "write", "close" }) do
			local f = fixture()
			f.project.save("arena")
			f.pump() -- an old successful manifest must not count as this save
			f.failPath, f.failMode = "MapProjects/arena/project.lua", mode
			local _, receipt = f.project.save("arena")
			f.pump()
			assert(receipt.done and not receipt.ok and not receipt.uploadReady)
			assert(f.project.lastSave() == receipt)
		end
	end)

	it("capture exceptions and reported section failures block automatic upload", function()
		local f = fixture()
		f.steps.decals.entry.run = function()
			error("capture failed")
		end
		local _, receipt = f.project.save("arena")
		f.pump()
		assert(receipt.ok and not receipt.uploadReady)
		f = fixture()
		f.environment.WG.DecalPlacer = {
			saveProject = function()
				return nil
			end,
		}
		f.steps.decals.entry.run = f.steps.decals.original
		_, receipt = f.project.save("arena")
		f.pump()
		assert(receipt.ok and not receipt.uploadReady)
	end)

	it("heightmap encoding and write failures never qualify for upload", function()
		for _, mode in ipairs({ "encode", "write", "close" }) do
			local f = fixture()
			if mode == "encode" then
				f.codec.encodeGray16 = function()
					return nil
				end
			else
				f.failPath, f.failMode = "MapProjects/arena/heightmap.png", mode
			end
			local _, receipt = f.project.save("arena")
			f.pump()
			assert(receipt.done and not receipt.uploadReady)
		end
	end)

	it("rejected starts have no receipt and shutdown marks the active receipt failed", function()
		local f = fixture()
		local accepted, receipt = f.project.save("../invalid")
		assert(not accepted and not receipt)
		accepted, receipt = f.project.save("arena")
		assert(accepted)
		local second, other = f.project.save("other")
		assert(not second and not other)
		f.widget:Shutdown()
		assert(receipt.done and not receipt.ok and not receipt.uploadReady)
	end)

	it("chains the real save pump to the UI publication once, only on complete success", function()
		for _, failure in ipairs({ false, "close" }) do
			local f = fixture()
			local model = { projectSaveOpen = true, libraryStage = "Design" }
			-- The widget's seams the controller reads: the team's folders, the
			-- team catalogue (empty, so no confirmation stands in the way), and
			-- the switch the widget would have offered for "Design/".
			local state = {
				dmHandle = model,
				projectTeamDestinations = function()
					return { Design = true }
				end,
				projectTeamBySlug = function()
					return {}
				end,
				projectSyncTarget = function() end,
			}
			local ui = VFS.Include("luaui/RmlWidgets/gui_terraform_brush/tf_map_library.lua").newSave(state, model, {
				getMapProject = function()
					return f.project
				end,
				translate = function(key)
					return key
				end,
			})
			model.projectSaveUploadAllowed = true
			model.projectSaveSetUpload(nil, true)
			assert(ui.save("Design/arena"))
			if failure then
				f.failPath, f.failMode = "MapProjects/Design/arena/project.lua", failure
			end
			for _ = 1, 100 do
				if not f.project.saveProgress() then
					break
				end
				ui.sync()
				assert(#f.requests == 0)
				f.widget:DrawScreenPost()
			end
			ui.sync()
			ui.sync()
			assert(#f.requests == (failure and 0 or 1))
		end
	end)
end)

describe("map project autosave", function()
	it("prunes old snapshots but spares the newest of each project for longer", function()
		local f = fixture()
		local day = 86400
		local now = 100 * day
		local entries = {
			{ slug = "_autosave/a-1", autosave_base = "a", autosave_stamp = now - 1 * day },
			{ slug = "_autosave/a-2", autosave_base = "a", autosave_stamp = now - 5 * day },
			{ slug = "_autosave/b-1", autosave_base = "b", autosave_stamp = now - 5 * day },
			{ slug = "_autosave/b-2", autosave_base = "b", autosave_stamp = now - 12 * day },
			{ slug = "_autosave/c-1", autosave_base = "c", autosave_stamp = now - 11 * day },
		}
		local doomed = f.project.autosavePrunePlan(entries, now, 3, 10)
		table.sort(doomed)
		-- a-2 is old and not a's newest; b-1 is b's newest and inside 10 days;
		-- b-2 is old; c-1 is c's newest but past 10 days.
		assert(#doomed == 3, "expected 3 doomed, got " .. #doomed)
		assert(doomed[1] == "_autosave/a-2" and doomed[2] == "_autosave/b-2" and doomed[3] == "_autosave/c-1")
	end)

	it("a snapshot records its origin and leaves the Save target and manual receipt alone", function()
		local f = fixture()
		local accepted, receipt = f.project.save("campaign/arena")
		assert(accepted)
		f.pump()
		assert(f.project.current() == "campaign/arena")
		local ok = f.project.autosaveNow(true)
		assert(ok, "autosave refused")
		local step, _, _, kind = f.project.saveProgress()
		assert(step and kind == "autosave")
		f.pump()
		assert(f.project.current() == "campaign/arena", "autosave must not become the Save target")
		assert(f.project.lastSave() == receipt, "autosave must not replace the manual receipt")
		local last = f.project.lastAutosave()
		assert(
			last and last.ok and last.slug:match("^_autosave/arena%-%d%d%d%d%d%d%d%d%d%d%d%d$"),
			tostring(last and last.slug)
		)
		local manifest = f.files["MapProjects/" .. last.slug .. "/project.lua"]
		assert(manifest and manifest:find('autosave_of = "campaign/arena"', 1, true))
		local list = f.project.listAutosaves()
		assert(#list == 1 and list[1].slug == last.slug and list[1].autosave_of == "campaign/arena")
		assert(list[1].folder == "" and list[1].autosave_base == "arena" and list[1].autosave_stamp > 0)
		-- The same minute again is refused rather than overwritten.
		local again, why = f.project.autosaveNow(true)
		assert(again == false, "a second snapshot in the same minute must be refused")
		assert(why == "a snapshot for this minute exists", tostring(why))
	end)
end)
