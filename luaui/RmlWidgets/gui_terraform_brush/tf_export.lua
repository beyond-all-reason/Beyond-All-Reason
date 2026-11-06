-- tf_export.lua: FILE > EXPORT MAP, the window that writes the open project as map archive
-- files (WG.MapProject.export, common/map_export.lua) under Terraform Brush/Exports/.
-- The export reads the SAVED project, so unsaved changes are saved first and the export runs
-- when that save's receipt says done (update(), from the panel's Update).
local M = {}
-- RmlUi listener closures can run outside the widget env: keep what they use as upvalues
local tostring, type, pcall = tostring, type, pcall
local Spring, VFS = Spring, VFS

function M.attach(doc, ctx)
	local widgetState = ctx.widgetState
	local playSound = ctx.playSound
	local WG = ctx.WG
	local text = widgetState.text
	local root = doc:GetElementById("tf-export-root")
	if not root then
		return
	end
	local el = {
		project = doc:GetElementById("tf-export-project"),
		name = doc:GetElementById("tf-export-name"),
		version = doc:GetElementById("tf-export-version"),
		go = doc:GetElementById("tf-export-go"),
		status = doc:GetElementById("tf-export-status"),
		copy = doc:GetElementById("tf-export-copy"),
	}
	-- slug -> the version last exported, so the field remembers it per project this session
	local versions = {}
	local X = { open = false, slug = nil, saving = nil, path = nil }
	widgetState.exportUi = X

	-- shown and hidden by inline display: .flex beats .hidden at equal specificity
	local function show(e, on, display)
		if e then
			e:SetAttribute("style", on and ("display: " .. (display or "block") .. ";") or "display: none;")
		end
	end
	local function setStatus(s, warn)
		if el.status then
			el.status.inner_rml = s or ""
			show(el.status, s and s ~= "")
			el.status:SetClass("border-warning", warn and true or false)
		end
	end
	local function setCanExport(can)
		if el.go then
			el.go:SetClass("disabled", not can)
		end
	end
	local function setCopy(path)
		X.path = path
		show(el.copy, path ~= nil, "flex")
	end
	local function field(e)
		local v = tostring((e and e:GetAttribute("value")) or "")
		return (v:gsub("^%s+", ""):gsub("%s+$", ""))
	end

	local function setOpen(open)
		X.open = open
		-- the inline style is the whole style: the position goes with the display
		root:SetAttribute("style", "left: 36vw; top: 16vh; display: " .. (open and "flex" or "none") .. ";")
	end

	function X.close()
		X.saving = nil
		setOpen(false)
	end

	function X.openWindow()
		local mp = WG.MapProject
		local slug = mp and mp.current and mp.current() or nil
		X.slug = slug
		X.saving = nil
		setCopy(nil)
		setStatus("")
		if not (mp and mp.export) then
			if el.project then
				el.project.inner_rml = ""
			end
			setStatus(text("exportNoWidget"), true)
			setCanExport(false)
		elseif not slug then
			if el.project then
				el.project.inner_rml = ""
			end
			setStatus(text("exportNoProject"), true)
			setCanExport(false)
		else
			local info = mp.describe and mp.describe(slug) or nil
			local leaf = slug:match("([^/]+)$") or slug
			if el.project then
				el.project.inner_rml = text("exportProject", { name = slug })
			end
			if el.name and (field(el.name) == "" or X.lastSlug ~= slug) then
				el.name:SetAttribute("value", (info and info.name) or leaf)
			end
			if el.version then
				el.version:SetAttribute("value", versions[slug] or "1.0")
			end
			X.lastSlug = slug
			setCanExport(true)
			if mp.isDirty and mp.isDirty() then
				setStatus(text("exportUnsaved"))
			end
		end
		setOpen(true)
	end

	local function runExport()
		local mp = WG.MapProject
		local name, version = field(el.name), field(el.version)
		if version == "" then
			version = "1.0"
		end
		local report, why = mp.export(X.slug, { name = name, version = version })
		if not report then
			setStatus(text("exportFailed", { reason = tostring(why) }), true)
			playSound("reset")
			return
		end
		versions[X.slug] = version
		local key = report.ok and ((#report.missing > 0) and "exportDoneMissing" or "exportDone") or "exportDoneErrors"
		setStatus(
			text(key, {
				path = report.path,
				files = #report.written,
				missing = #report.missing,
				errors = #report.errors,
			}),
			not report.ok or #report.missing > 0
		)
		setCopy(report.path)
		playSound(report.ok and "save" or "reset")
	end

	-- Called every panel Update: the export waits for the save it started.
	function X.update()
		local s = X.saving
		if s and s.done then
			X.saving = nil
			if s.ok then
				runExport()
			else
				setStatus(text("exportSaveFailed"), true)
			end
		end
	end

	local function onExport(event)
		if event then
			event:StopPropagation()
		end
		local mp = WG.MapProject
		if not (X.slug and mp and mp.export) or (el.go and el.go:IsClassSet("disabled")) then
			return
		end
		if mp.isBusy and mp.isBusy() then
			setStatus(text("exportBusy"), true)
			return
		end
		playSound("click")
		setCopy(nil)
		if mp.isDirty and mp.isDirty() and mp.save then
			local keepUnits = (mp.hasUnitsSection and mp.hasUnitsSection(X.slug)) and true or false
			local accepted, receipt = mp.save(X.slug, { saveUnits = keepUnits })
			if not accepted then
				setStatus(text("exportSaveFailed"), true)
				return
			end
			X.saving = receipt
			setStatus(text("exportSaving"))
			return
		end
		runExport()
	end

	local function on(id, fn, eventName)
		local e = doc:GetElementById(id)
		if e then
			e:AddEventListener(eventName or "click", fn, false)
		end
	end
	on("tf-export-go", onExport)
	on("tf-export-cancel", function(event)
		playSound("click")
		X.close()
		event:StopPropagation()
	end)
	on("tf-export-close", function(event)
		playSound("click")
		X.close()
		event:StopPropagation()
	end)
	on("tf-export-copy", function(event)
		event:StopPropagation()
		if not X.path then
			return
		end
		-- the absolute folder when the VFS can name it, else the path in the data folder
		local shown = X.path
		pcall(function()
			local abs = VFS.GetFileAbsolutePath and VFS.GetFileAbsolutePath(X.path .. "export_report.txt", VFS.RAW)
			if type(abs) == "string" and abs ~= "" then
				shown = abs:gsub("[/\\]export_report%.txt$", "")
			end
		end)
		Spring.SetClipboard(shown)
		playSound("click")
	end)
	-- FILE > Export Map...: the menu closes like its other items, then the window opens
	on("btn-file-export", function(event)
		playSound("click")
		local d = widgetState.dmHandle
		if d then
			d.fileMenuOpen = false
		end
		X.openWindow()
		event:StopPropagation()
	end, "mousedown")

	setOpen(false)
	setCopy(nil)
end

return M
