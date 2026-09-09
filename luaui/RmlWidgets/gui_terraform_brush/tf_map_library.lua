-- Model-first controls for the existing project tree. No DOM writes or Git calls.
local M = {}
local WG = WG
local BAR = BAR

local function text(key, values)
	return BAR.I18N("ui.mapLibrary." .. key, values)
end

function M.new(widgetState, model, dependencies)
	local getMapProject = dependencies and dependencies.getMapProject or function()
		return WG.MapProject
	end
	local translate = dependencies and dependencies.translate or text
	local ui = {}
	local generation, resultID, armed = -1, nil, nil
	local stageIndex = 1
	local notice = nil
	local elapsed = 0
	local lastRemote = nil
	local labels = {
		"title",
		"localTab",
		"teamTab",
		"pull",
		"upload",
		"publish",
		"confirmPublish",
		"download",
		"stage",
		"previousStage",
		"nextStage",
		"saveFirst",
		"cancel",
		"open",
		"delete",
		"confirmDelete",
		"search",
		"recent",
		"name",
		"size",
		"selectProject",
		"openWarning",
		"downloadWarning",
	}
	for _, key in ipairs(labels) do
		model["libraryLabel_" .. key] = translate(key)
	end
	model.libraryRemote = false
	model.libraryOnline = false
	model.libraryBusy = false
	model.libraryWritable = false
	model.libraryConfirming = false
	model.libraryUploadOpen = false
	model.libraryStage = ""
	model.libraryStatus = translate("offline")
	model.libraryStatusVisible = false
	model.libraryStatusError = false
	model.libraryStatusSuccess = false
	model.libraryConnection = translate("offlineBadge")
	model.libraryRepository = ""
	model.libraryRemoteURL = ""
	model.libraryBranch = ""

	local function library()
		local project = getMapProject()
		return project and project.library
	end

	local function clearSelection()
		armed = nil
		widgetState.projectOpenSelectedSlug = nil
		widgetState.projectOpenNeedsRebuild = true
		local dm = widgetState.dmHandle
		if dm then
			dm.projectOpenSelected = ""
			dm.projectOpenHint = ""
			dm.projectDeleteConfirming = false
			dm.libraryConfirming = false
			dm.libraryUploadOpen = false
		end
	end

	local function send(operation, source, stage)
		local client = library()
		local ok, code
		if client then
			ok, code = client.request(operation, source, stage)
		end
		notice = ok and "working" or (code or "offline")
		armed = nil
		ui.sync()
	end

	-- Install FINAL function values before OpenDataModel: Recoil freezes them.
	model.librarySetTab = function(_, remote)
		if (widgetState.projectLibraryRemote == true) == remote then
			return
		end
		widgetState.projectLibraryRemote = remote
		widgetState.dmHandle.libraryRemote = remote
		clearSelection()
	end
	model.libraryToggleUpload = function()
		local dm = widgetState.dmHandle
		if
			widgetState.projectLibraryRemote
			or not widgetState.projectOpenSelectedSlug
			or not dm.libraryWritable
			or dm.libraryBusy
		then
			return
		end
		armed = nil
		dm.libraryUploadOpen = not dm.libraryUploadOpen
		dm.projectDeleteConfirming = false
		widgetState.projectDeleteConfirmExpiry = 0
		ui.sync()
	end
	model.libraryCancelUpload = function()
		ui.disarm()
		ui.sync()
	end
	model.libraryPull = function()
		send("pull")
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
			or widgetState.projectLibraryRemote
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
	model.libraryDownload = function()
		if widgetState.projectLibraryRemote and widgetState.projectOpenSelectedSlug then
			send("download", widgetState.projectOpenSelectedSlug)
		end
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
		dm.libraryOnline = state.online == true
		dm.libraryBusy = (client and client.isBusy()) or (project and project.isBusy()) or false
		dm.libraryWritable = state.online == true and state.allow_push == true
		dm.libraryConnection = translate(
			not dm.libraryOnline and "offlineBadge"
				or (dm.libraryBusy and "workingBadge" or (dm.libraryWritable and "onlineBadge" or "readOnlyBadge"))
		)
		local remote = tostring(state.remote or "")
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
		local stages = client and client.catalog.stages or {}
		if #stages == 0 then
			stages = state.stages or {}
		end
		if #stages > 0 then
			stageIndex = (stageIndex - 1) % #stages + 1
			dm.libraryStage = stages[stageIndex]
		else
			dm.libraryStage = ""
		end
		if client and generation ~= client.generation then
			generation = client.generation
			widgetState.projectOpenNeedsRebuild = true
		end
		if not state.busy and state.request_id and state.request_id ~= resultID then
			resultID = state.request_id
			notice = nil
			if state.code == "downloaded" then
				widgetState.projectLibraryRemote = false
				dm.libraryRemote = false
				-- A remote-path search cannot match a newly allocated local copy.
				if model.onProjectSearchClear then
					model.onProjectSearchClear()
				end
				widgetState.projectOpenFilter = ""
				widgetState.projectOpenSelectedSlug = state.local_slug
				widgetState.projectOpenNeedsRebuild = true
			end
		end
		local selectionKey = tostring(widgetState.projectOpenSelectedSlug)
			.. "\n"
			.. dm.libraryStage
			.. "\n"
			.. tostring(state.session)
		if armed ~= selectionKey or not dm.libraryWritable or dm.libraryBusy then
			armed = nil
		end
		dm.libraryConfirming = armed ~= nil
		if not armed then
			local code = not state.online and "offline"
				or (dm.libraryBusy and "working" or (notice or state.code or "ready"))
			dm.libraryStatusSuccess = code == "published" or code == "downloaded" or code == "pulled"
			dm.libraryStatusError = code ~= "offline"
				and code ~= "ready"
				and code ~= "working"
				and not dm.libraryStatusSuccess
			dm.libraryStatusVisible = dm.libraryStatusError or dm.libraryStatusSuccess
			if code == "published" then
				dm.libraryStatus = translate(code, { target = state.target or "" })
			elseif code == "downloaded" then
				dm.libraryStatus = translate(code, { name = state.local_slug or "" })
			else
				dm.libraryStatus = translate(code)
			end
		end
	end

	function ui.projects()
		local client = library()
		return client and client.catalog.projects or {}
	end

	function ui.folders()
		local client = library()
		return client and client.catalog.stages or {}
	end

	function ui.disarm()
		armed = nil
		if widgetState.dmHandle then
			widgetState.dmHandle.libraryConfirming = false
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
	local ui = {}
	local armed, pending
	local actionKey = "save"
	for _, key in ipairs({
		"saveTitle",
		"localOnly",
		"localAndTeam",
		"nameHint",
		"units",
		"unitsHelp",
		"on",
		"off",
		"saveCopyHint",
	}) do
		model["libraryLabel_" .. key] = translate(key)
	end
	model.projectSaveUpload = false
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
		widgetState.dmHandle.projectSaveUpload = false
		ui.changed()
		return true
	end

	function ui.close()
		-- Closing hides progress, not an already confirmed save/upload.
		if not pending then
			ui.changed()
		end
	end

	model.projectSaveSetUpload = function(_, upload)
		if pending then
			return
		end
		widgetState.dmHandle.projectSaveUpload = upload
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
		if dm.projectSaveUpload then
			local code = not state.online and "offline" or (not state.allow_push and "read_only")
			if code or dm.libraryStage == "" then
				armed = nil
				message(code or "invalid_stage", nil, true)
				ui.sync()
				return false
			end
		end
		local units = widgetState.projectSaveUnits == true
		local overwrite = name ~= project.current() and project.exists(name)
		local dropUnits = not units and project.hasUnitsSection(name)
		local key = table.concat({
			name,
			tostring(units),
			tostring(dm.projectSaveUpload),
			dm.libraryStage or "",
			tostring(state.session),
			tostring(state.remote),
			tostring(state.branch),
			tostring(overwrite),
			tostring(dropUnits),
		}, "\n")
		if overwrite or dropUnits or dm.projectSaveUpload then
			if not armed or armed.key ~= key or armed.project ~= project or armed.client ~= client then
				armed = {
					key = key,
					project = project,
					client = client,
					units = units,
					stage = dm.libraryStage,
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
				if dm.projectSaveUpload then
					hints[#hints + 1] = translate("saveUploadQuestion", { name = name, stage = dm.libraryStage })
				end
				message(nil)
				dm.projectSaveHint = table.concat(hints, " ")
				ui.sync()
				return false
			end
		end
		local intent = armed
		armed = nil
		local ok, receipt = project.save(name, { saveUnits = units })
		if not ok then
			message("saveRejected", nil, true)
		elseif dm.projectSaveUpload then
			-- Never infer completion from a previous lastSave() or an existing file.
			if type(receipt) ~= "table" then
				message("saveUntracked", nil, true)
			else
				pending = intent
				pending.receipt = receipt
				message("saving", { name = receipt.slug })
			end
		else
			dm.projectSaveOpen = false
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
				or dm.libraryStage ~= armed.stage
				or (widgetState.projectSaveUnits == true) ~= armed.units
				or (
					dm.projectSaveUpload
					and (not client.state.online or not client.state.allow_push or project.isBusy())
				)
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
				message(intent.requestID and "uploadInterrupted" or "saveUploadCancelled", nil, true)
			elseif intent.requestID then
				if not state.online then
					pending = nil
					message("uploadInterrupted", nil, true)
				elseif state.request_id == intent.requestID and not state.busy and not state.pending then
					pending = nil
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
					else
						message("savedUploadFailed", { name = intent.receipt.slug, reason = translate(code) }, true)
					end
				end
			end
		end
		dm.projectSavePending = pending ~= nil
		dm.projectSaveConfirming = armed ~= nil
		local nextAction = pending and (pending.requestID and "uploadingLabel" or "savingLabel")
			or (
				dm.projectSaveUpload and (armed and "confirmSaveUpload" or "saveUpload")
				or (armed and "confirmSave" or "save")
			)
		if actionKey ~= nextAction then
			actionKey = nextAction
			dm.projectSaveAction = translate(actionKey)
		end
	end

	return ui
end

return M
