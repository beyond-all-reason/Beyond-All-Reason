function widget:GetInfo()
	return {
		name = "Area Mex",
		desc = "Adds a command to cap mexes in an area.",
		author = "Google Frog, NTG (file handling), Chojin (metal map), Doo (multiple enhancements), Floris (mex placer/upgrader), Tarte (maintenance)",
		date = "Oct 23, 2010, (last update: March 3, 2022)",
		license = "GNU GPL, v2 or later",
		handler = true,
		layer = 0,
		enabled = true  --  loaded by default?
	}
end

local CMD_GUARD = CMD.GUARD
local CMD_AREA_MEX = 10100

local spGetActiveCommand = Spring.GetActiveCommand
local spGetMapDrawMode = Spring.GetMapDrawMode
local spSendCommands = Spring.SendCommands
local spGetUnitDefID = Spring.GetUnitDefID

local toggledMetal, retoggleLos, chobbyInterface


function widget:Update(dt)
	if chobbyInterface then return end

	--local drawUnitShape = false
	local _, cmd, _ = spGetActiveCommand()
	if cmd == CMD_AREA_MEX then
		if spGetMapDrawMode() ~= 'metal' then
			if Spring.GetMapDrawMode() == "los" then
				retoggleLos = true
			end
			spSendCommands('ShowMetalMap')
			toggledMetal = true
		end
	else
		if toggledMetal then
			spSendCommands('ShowStandard')
			if retoggleLos then
				Spring.SendCommands("togglelos")
				retoggleLos = nil
			end
			toggledMetal = false
		end
	end
end

function widget:CommandNotify(id, params, options)
	local isGuard = (id == CMD_GUARD)
	if not (id == CMD_AREA_MEX or isGuard) then
		return
	end
	if isGuard then
		local mx, my, mb = Spring.GetMouseState()
		local type, unitID = Spring.TraceScreenRay(mx, my)
		if not (type == 'unit' and WG['helperBuildResourceSpot'].GetMexIds()[spGetUnitDefID(unitID)] and WG['helperBuildResourceSpot'].GetMexIds()[spGetUnitDefID(unitID)] < 0.002) then
			return
		end
	end

	if id == CMD_AREA_MEX then
		local queuedMexes = WG['helperBuildResourceSpot'].BuildMetalExtractors(params, options, isGuard)
		if moveReturn and not queuedMexes[1] then	-- used when area_mex isnt queuing a mex, to let the move cmd still pass through
			return false
		end
		return true
	end
end

function widget:CommandsChanged()
	if not WG['helperBuildResourceSpot'].isMetalMap() then
		local unitCount = #(WG['helperBuildResourceSpot'].GetSelectedUnits())
		if unitCount > 0 then
			local units = WG['helperBuildResourceSpot'].GetSelectedUnits()
			local customCommands = widgetHandler.customCommands
			for i = 1, unitCount do
				if WG['helperBuildResourceSpot'].GetMexBuilder()[units[i]] then
					customCommands[#customCommands + 1] = {
						id = CMD_AREA_MEX,
						type = CMDTYPE.ICON_AREA,
						tooltip = 'Define an area (with metal spots in it) to make metal extractors in',
						name = 'Mex',
						cursor = 'areamex',
						action = 'areamex',
					}
					return
				end
			end
		end
	end
end
