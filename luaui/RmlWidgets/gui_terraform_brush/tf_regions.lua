local M = {}

function M.attach(doc, ctx)
	if ctx.attachTBMirrorControls then
		ctx.attachTBMirrorControls(doc, "st")
	end
	local trackSliderDrag = ctx.trackSliderDrag
	for _, sid in ipairs({ "rg-allyteams", "rg-teams-per-ally", "rg-count", "rg-size", "rg-rotation" }) do
		local sl = doc:GetElementById("slider-" .. sid)
		if sl then
			trackSliderDrag(sl, sid)
		end
	end
end

local function chip(id, label, active)
	return '<div id="'
		.. id
		.. '" class="tf-overlay-chip'
		.. (active and " active" or "")
		.. '"><div class="tf-overlay-chip-label">'
		.. label
		.. "</div></div>"
end

-- One part of the panel failing must not take the rest with it, and the failure has to be seen: the infolog is
-- buffered while the game runs, chat is not.
local function safely(widgetState, what, fn)
	local ok, err = pcall(fn)
	if not ok and widgetState.rgLastError ~= err then
		widgetState.rgLastError = err
		Spring.Echo("[Regions] panel " .. what .. " failed: " .. tostring(err))
	end
end

local function listen(doc, id, fn)
	local el = doc:GetElementById(id)
	if el then
		el:AddEventListener("click", function(event)
			fn()
			event:StopPropagation()
		end, false)
	end
end

local function fillChips(doc, id, options, isActive, onPick)
	local el = doc:GetElementById(id)
	if not el then
		return
	end
	local html = {}
	for i, option in ipairs(options) do
		html[#html + 1] = chip(id .. "-" .. i, option.label, isActive(option))
	end
	el.inner_rml = table.concat(html)
	for i, option in ipairs(options) do
		listen(doc, id .. "-" .. i, function()
			onPick(option)
		end)
	end
end

local function fieldPickers(doc, prefix, defs, values, rgState, onSet)
	local teams = rgState.teamOptions or {}
	local suggestions = rgState.suggestions or {}
	for _, field in ipairs(defs) do
		local id = prefix .. "-pick-" .. field.key
		if field.picks == "start" then
			local options = field.required and {} or { { label = "None", value = nil } }
			for _, team in ipairs(teams) do
				options[#options + 1] = { label = team.label, value = team.team }
			end
			fillChips(doc, id, options, function(option)
				return option.value == values[field.key]
			end, function(option)
				onSet(field.key, option.value and tostring(option.value) or "")
			end)
		elseif field.suggest then
			local options = {}
			for _, value in ipairs(suggestions[field.key] or {}) do
				options[#options + 1] = { label = tostring(value), value = value }
			end
			fillChips(doc, id, options, function(option)
				return option.value == values[field.key]
			end, function(option)
				local input = doc:GetElementById(prefix .. "-" .. field.key)
				if input then
					input:SetAttribute("value", tostring(option.value))
				end
				onSet(field.key, tostring(option.value))
			end)
		end
	end
end

local function problemLines(messages)
	local html = {}
	for i, message in ipairs(messages or {}) do
		local safe = tostring(message):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")
		html[i] = '<div class="ll-preset-desc" style="color: #ff8080;">' .. safe .. "</div>"
	end
	return table.concat(html)
end

-- derived: values the module fills in for fields left empty; shown selected, so one keystroke replaces them
local function renderFields(doc, widgetState, containerId, prefix, defs, values, onSet, derived)
	local container = doc:GetElementById(containerId)
	if not container then
		return
	end
	local html = {}
	for _, field in ipairs(defs) do
		local label = field.label .. ((field.required or field.unique) and "" or " (optional)")
		html[#html + 1] = '<div class="text-sm text-light">' .. label .. "</div>"
		if field.picks == "start" then
			html[#html + 1] = '<div id="'
				.. prefix
				.. "-pick-"
				.. field.key
				.. '" class="flex flex-row gap-1 mb-1 tf-chip-row"></div>'
		else
			html[#html + 1] = '<input type="text" id="'
				.. prefix
				.. "-"
				.. field.key
				.. '" class="ll-search-input mb-1" style="width:100%;" />'
			if field.suggest then
				html[#html + 1] = '<div id="'
					.. prefix
					.. "-pick-"
					.. field.key
					.. '" class="flex flex-row gap-1 mb-1 tf-chip-row"></div>'
			end
		end
	end
	container.inner_rml = table.concat(html)
	for _, field in ipairs(defs) do
		local input = doc:GetElementById(prefix .. "-" .. field.key)
		if input then
			local value = values[field.key]
			local fallback = value == nil and derived and derived[field.key] or nil
			input:SetAttribute("value", value ~= nil and tostring(value) or fallback and tostring(fallback) or "")
			if widgetState.wireTextInput then
				widgetState.wireTextInput(input)
			end
			if fallback ~= nil then
				-- Select() is the text input's own method; not every binding exposes it, and a derived name
				-- shown unselected is no reason to lose the rest of the panel.
				pcall(function()
					input:Focus()
					input:Select()
				end)
			end
			input:AddEventListener("change", function()
				onSet(field.key, input:GetAttribute("value") or "")
			end, false)
		end
	end
end

function M.sync(doc, ctx, rgState, setSummary)
	local WG = ctx.WG
	if ctx.syncTBMirrorControls then
		ctx.syncTBMirrorControls(doc, "st")
	end
	local widgetState = ctx.widgetState
	local dm = widgetState.dmHandle
	if not dm then
		return
	end
	local function setRg(f, v)
		if dm[f] ~= v then
			dm[f] = v
		end
	end
	local st = WG.RegionsTool

	setRg("rgShapeMode", rgState.shapeType or "circle")
	setRg("rgSubMode", rgState.subMode or "")
	setRg("rgStartboxMode", rgState.startboxMode or "polygon")

	if doc and widgetState.wireTextInput then
		widgetState.rgWiredInputs = widgetState.rgWiredInputs or setmetatable({}, { __mode = "k" })
		local el = doc:GetElementById("rg-tag-input")
		if el and not widgetState.rgWiredInputs[el] then
			widgetState.rgWiredInputs[el] = true
			widgetState.wireTextInput(el)
		end
	end

	local labels = rgState.regionTypeLabels or {}
	local typeLabel = labels[rgState.regionType] and labels[rgState.regionType].label or "Region"
	setRg("rgRegionType", rgState.regionType or "start")
	setRg("rgCategory", rgState.category or "start")
	setRg("rgDrawingArea", rgState.drawForTeam ~= nil)
	setRg("rgSelectedHasBox", (rgState.selected and rgState.selected.hasBox) == true)
	setRg("rgStrategy", rgState.strategy or "express")
	setRg("rgPlacing", rgState.placing or "points")
	local polygonMode = rgState.regionType ~= "start" or rgState.placing == "area"
	setRg("rgPolygonMode", polygonMode)
	setRg("rgShowShapeOptions", (not polygonMode) and rgState.strategy == "shape")
	setRg("rgGeometry", rgState.geometry or "point")
	setRg("rgEditMode", rgState.editMode or "select")
	setRg("rgGatheredSpots", tostring(rgState.gatheredSpots or 0))
	setRg("rgAreaTarget", tostring(rgState.areaTarget or ""))
	local hint
	if rgState.editMode == "select" then
		hint = "select"
	elseif rgState.geometry == "point" then
		hint = "points"
	elseif rgState.geometry == "square" then
		hint = "square"
	elseif rgState.geometry == "mexes" then
		hint = "mexes"
	else
		hint = "polygon"
	end
	setRg("rgHint", hint)

	if doc then
		local geoKey = table.concat(rgState.geometries or {}, ",") .. "|" .. tostring(rgState.geometry)
		if widgetState.rgGeometryKey ~= geoKey then
			widgetState.rgGeometryKey = geoKey
			local names = { point = "Point", square = "Square", polygon = "Polygon", mexes = "Mexes" }
			local options = {}
			for _, g in ipairs(rgState.geometries or {}) do
				options[#options + 1] = { label = names[g] or g, value = g }
			end
			fillChips(doc, "rg-geometry-chips", options, function(option)
				return option.value == rgState.geometry
			end, function(option)
				if st and st.setGeometry then
					st.setGeometry(option.value)
				end
			end)
		end
		local catKey = table.concat(rgState.categories or {}, ",") .. "|" .. tostring(rgState.category)
		if widgetState.rgCategoryKey ~= catKey then
			widgetState.rgCategoryKey = catKey
			local catLabels = rgState.categoryLabels or {}
			local options = {}
			for _, key in ipairs(rgState.categories or {}) do
				options[#options + 1] = { label = catLabels[key] and catLabels[key].label or key, value = key }
			end
			fillChips(doc, "rg-category-chips", options, function(option)
				return option.value == rgState.category
			end, function(option)
				if st and st.setCategory then
					st.setCategory(option.value)
				end
			end)
		end
	end

	setRg("rgSelected", rgState.selected ~= nil)
	setRg("rgSelectedTeam", tostring(rgState.selected and rgState.selected.team or ""))
	setRg("rgSelectedVertices", tostring(rgState.selected and rgState.selected.vertexCount or 0))
	setRg("rgRegionError", rgState.regionError or "")
	setRg("rgRegionNotice", rgState.regionNotice or "")
	setRg("rgRegionListTitle", (rgState.regionType == "start") and "STARTS" or (typeLabel:upper() .. "S"))
	local detailsMode = "prompt"
	if rgState.selected then
		detailsMode = "details"
	elseif rgState.editMode == "create" and #(rgState.regionFields or {}) > 0 then
		detailsMode = "new"
	end
	setRg("rgDetailsMode", detailsMode)
	setRg("rgDetailsTitle", (detailsMode == "new") and ("NEW " .. typeLabel:upper()) or "DETAILS")
	setRg("rgClearLabel", (rgState.regionType == "start") and "CLEAR ALL" or ("CLEAR " .. typeLabel:upper() .. "S"))

	local selKey = tostring(rgState.regionType)
		.. ":"
		.. tostring(rgState.selectedIdx)
		.. ":"
		.. tostring(rgState.selectedStart)
		.. ":"
		.. detailsMode
		.. ":"
		.. tostring(rgState.selected and rgState.selected.hasBox)
	if doc and (widgetState.rgRegionRevision ~= rgState.regionRevision or widgetState.rgSelKey ~= selKey) then
		widgetState.rgRegionRevision = rgState.regionRevision
		local selectionChanged = widgetState.rgSelKey ~= selKey
		widgetState.rgSelKey = selKey
		local defs = rgState.regionFields or {}
		local pending = rgState.pendingRegion or {}
		local selected = rgState.selected
		local function setPending(key, value)
			if st and st.setPendingField then
				st.setPendingField(key, value)
			end
		end
		local function setField(key, value)
			if st and st.setRegionField then
				st.setRegionField(key, value)
			end
		end

		safely(widgetState, "details", function()
			if selectionChanged then
				if detailsMode == "new" then
					renderFields(doc, widgetState, "rg-new-fields", "rg-new", defs, pending, setPending)
				end
				if selected and selected.hasBox then
					renderFields(
						doc,
						widgetState,
						"rg-detail-fields",
						"rg-detail",
						defs,
						selected.fields or {},
						setField,
						selected.derived
					)
				end
			end
			if detailsMode == "new" then
				fieldPickers(doc, "rg-new", defs, pending, rgState, setPending)
			end
			if selected and selected.hasBox then
				fieldPickers(doc, "rg-detail", defs, selected.fields or {}, rgState, setField)
			end

			local factsEl = doc:GetElementById("rg-detail-facts")
			if factsEl then
				local html = {}
				for _, fact in ipairs(selected and selected.facts or {}) do
					html[#html + 1] = '<div class="text-sm text-light">'
						.. fact[1]
						.. ': <span class="text-keybind">'
						.. fact[2]
						.. "</span></div>"
				end
				factsEl.inner_rml = table.concat(html) .. problemLines(selected and selected.problems)
			end

			local tags = selected and selected.tags or {}
			local tagOptions = {}
			for i, tag in ipairs(tags) do
				tagOptions[i] = { label = tag .. " ×", value = i }
			end
			fillChips(doc, "rg-tag-list", tagOptions, function()
				return false
			end, function(option)
				if st and st.removeTag then
					st.removeTag(option.value)
				end
			end)

		end)
		safely(widgetState, "list", function()
			local problems = rgState.problems or {}
			local setEl = doc:GetElementById("rg-set-problems")
			if setEl then
				local html = {}
				for i, problem in ipairs(problems.ofSet or {}) do
					local safe = tostring(problem.message):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")
					html[i] = '<div id="rg-set-problem-'
						.. i
						.. '" class="ll-preset-desc" style="color: #ff8080;'
						.. (problem.at and " cursor: pointer; text-decoration: underline;" or "")
						.. '">'
						.. safe
						.. (problem.at and " (show me)" or "")
						.. "</div>"
				end
				setEl.inner_rml = table.concat(html)
				for i, problem in ipairs(problems.ofSet or {}) do
					if problem.at then
						listen(doc, "rg-set-problem-" .. i, function()
							if st and st.lookAt then
								st.lookAt(problem.at.x, problem.at.z)
							end
						end)
					end
				end
			end
			local listEl = doc:GetElementById("rg-region-list")
			if listEl then
				local teamLabels = {}
				for _, option in ipairs(rgState.teamOptions or {}) do
					teamLabels[option.team] = option.label
				end
				local html, count, onClick = {}, 0, nil
				if rgState.regionType == "start" then
					local starts = rgState.starts or {}
					count = #starts
					for i, start in ipairs(starts) do
						local selectedClass = (start.allyTeam == rgState.selectedStart) and " selected" or ""
						local desc = start.positions
							.. " position"
							.. (start.positions == 1 and "" or "s")
							.. " · "
							.. (start.hasBox and "area drawn" or "no area")
						html[#html + 1] = '<div id="rg-region-item-'
							.. i
							.. '" class="ll-preset-item'
							.. selectedClass
							.. '"><div class="ll-preset-name">Start '
							.. start.allyTeam
							.. (start.name and (" · " .. start.name) or "")
							.. '</div><div class="ll-preset-desc">'
							.. desc
							.. "</div>"
							.. problemLines(problems.byTeam and problems.byTeam[start.allyTeam])
							.. "</div>"
					end
					onClick = function(i)
						if st and st.selectStart then
							st.selectStart(i)
						end
					end
				else
					local regions = rgState.regions or {}
					count = #regions
					local names = rgState.names or {}
					for i, region in ipairs(regions) do
						local named = names[i]
						local label = (named and named.name or region.name or "?")
							.. (region.group and (" (" .. region.group .. ")") or "")
						if region.team then
							label = (teamLabels[region.team] or ("Team " .. region.team)) .. " · " .. label
						end
						local selectedClass = (i == rgState.selectedIdx) and " selected" or ""
						html[#html + 1] = '<div id="rg-region-item-'
							.. i
							.. '" class="ll-preset-item'
							.. selectedClass
							.. '"><div class="ll-preset-name">'
							.. label
							.. '</div><div class="ll-preset-desc">'
							.. #(region.vertices or {})
							.. " pts"
							.. ((region.tags and #region.tags > 0) and (" · " .. #region.tags .. " tags") or "")
							.. "</div>"
							.. problemLines(problems.byIndex and problems.byIndex[i])
							.. "</div>"
					end
					onClick = function(i)
						if st and st.selectRegion then
							st.selectRegion(i)
						end
					end
				end
				if count == 0 then
					listEl.inner_rml =
						'<div class="text-xs text-keybind" style="padding: 4dp;">Nothing on this layer yet.</div>'
				else
					listEl.inner_rml = table.concat(html)
					for i = 1, count do
						listen(doc, "rg-region-item-" .. i, function()
							onClick(i)
						end)
					end
				end
			end
		end)
	end

	setRg("rgAllyTeamsStr", tostring(rgState.numAllyTeams))
	setRg("rgCountStr", tostring(rgState.shapeCount))
	setRg("rgSizeStr", tostring(math.floor(rgState.shapeRadius)))
	setRg("rgRotationStr", tostring(math.floor(rgState.shapeRotation)) .. "\194\176")
	setRg("rgTeamsPerAllyStr", tostring(rgState.numTeamsPerAlly or 1))
	setRg("rgPlacementModeStr", (rgState.placementMode or "roundrobin"):upper():gsub("ROUNDROBIN", "ROUND-ROBIN"))

	local getCachedEl = ctx.getCachedEl
	local function setSlider(id, value)
		local el = doc and getCachedEl(doc, id)
		if el then
			el:SetAttribute("value", tostring(value))
		end
	end
	setSlider("slider-rg-allyteams", rgState.numAllyTeams)
	setSlider("slider-rg-teams-per-ally", rgState.numTeamsPerAlly or 1)
	setSlider("slider-rg-teams-per-ally-numbox", rgState.numTeamsPerAlly or 1)
	setSlider("slider-rg-count", rgState.shapeCount)
	setSlider("slider-rg-size", math.floor(rgState.shapeRadius))
	setSlider("slider-rg-rotation", math.floor(rgState.shapeRotation))

	setSummary(
		"REGIONS",
		"#fdc04c",
		"",
		typeLabel:upper(),
		"Players ",
		tostring(rgState.totalPlayers or (rgState.numAllyTeams or 2))
			.. " ("
			.. tostring(rgState.numAllyTeams or 2)
			.. "x"
			.. tostring(rgState.numTeamsPerAlly or 1)
			.. ")"
	)

	if doc and ctx.setDisabledIds then
		local notStarts = rgState.placing == "area" or rgState.regionType ~= "start"
		ctx.setDisabledIds(doc, {
			"slider-rg-allyteams",
			"slider-rg-allyteams-numbox",
			"btn-rg-teams-up",
			"btn-rg-teams-down",
			"slider-rg-teams-per-ally",
			"slider-rg-teams-per-ally-numbox",
			"btn-rg-teams-per-ally-up",
			"btn-rg-teams-per-ally-down",
		}, notStarts)
	end
end

return M
