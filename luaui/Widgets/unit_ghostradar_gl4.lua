function widget:GetInfo()
	return {
		name      = "Ghost Radar GL4",
		desc      = "Allows ghosted unit shape below radar blips",
		author    = "very_bad_soldier, Floris (GL4)",
		date      = "July 21, 2008",
		license   = "GNU GPL v2",
		layer     = 0,
		enabled   = true
	}
end

local shapeOpacity = 0.5
local addHeight = 8	-- compensate for unit wobbling underground

local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitPosition = Spring.GetUnitPosition
local spIsUnitInView = Spring.IsUnitInView

local unitshapes = {}
local dots = {}
local spec,specFullView = Spring.GetSpectatingState()
local gaiaTeamID = Spring.GetGaiaTeamID()

local includedUnitDefIDs = {}
for unitDefID,unitDef in ipairs(UnitDefs) do
	if unitDef.isBuilding == false and unitDef.isFactory == false then
		if unitDef.model and unitDef.model.textures and unitDef.model.textures.tex1:lower() == "arm_color.dds" then
			includedUnitDefIDs[unitDefID] = true
		elseif unitDef.model and unitDef.model.textures and unitDef.model.textures.tex1:lower() == "cor_color.dds" then
			includedUnitDefIDs[unitDefID] = true
		end
	end
end

local function removeUnitShape(unitID)
	if unitshapes[unitID] then
		WG.StopDrawUnitShapeGL4(unitshapes[unitID])
		unitshapes[unitID] = nil
	end
end

local function addUnitShape(unitID, unitDefID, px, py, pz, rotationY, teamID)
	if unitshapes[unitID] then
		removeUnitShape(unitID)
	end
	unitshapes[unitID] = WG.DrawUnitShapeGL4(unitDefID, px, py+addHeight, pz, rotationY, shapeOpacity, teamID, nil, nil)
	return unitshapes[unitID]
end

function widget:PlayerChanged()
	spec,specFullView = Spring.GetSpectatingState()
	if specFullView then
		for unitID, _ in pairs(unitshapes) do
			removeUnitShape(unitID)
		end
	end
end

function widget:UnitEnteredRadar(unitID, unitTeam)
	if dots[unitID] then
		dots[unitID].radar = true
	end
end

function widget:UnitLeftRadar(unitID, unitTeam)
	if dots[unitID] then
		dots[unitID].radar = false
		--if not dots[unitID].los then -- not in LOS - forget unit type
		--	dots[unitID].unitDefID = nil
		--end
		removeUnitShape(unitID)
	end
end

function widget:UnitEnteredLos(unitID, unitTeam)
	local unitDefID = spGetUnitDefID(unitID)
	if unitDefID and includedUnitDefIDs[unitDefID] and unitTeam ~= gaiaTeamID then		-- update unitID info, ID could have been reused already!
		dots[unitID] = {
			unitDefID = spGetUnitDefID(unitID),
			teamID = unitTeam,
			radar = true,
			los = true,
		}
	else
		dots[unitID] = nil
	end
	removeUnitShape(unitID)
end

function widget:UnitLeftLos(unitID, unitTeam)
	if dots[unitID] then
		dots[unitID].los = false
		if not dots[unitID].radar then -- not on radar - forget unit type
			--dots[unitID].unitDefID = nil
			removeUnitShape(unitID)
		else
			local x, y, z = spGetUnitPosition(unitID)
			addUnitShape(unitID, dots[unitID].unitDefID, x, y, z, 0, unitTeam)
		end
	end
end

function widget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
	if dots[unitID] then
		dots[unitID] = nil	-- kill the dot info if this unitID gets reused
	end
end

function widget:UnitDestroyed(unitID, unitDefID, teamID, attackerID, attackerDefID, attackerTeamID)
	if dots[unitID] then
		dots[unitID] = nil
		removeUnitShape(unitID)
	end
end

function widget:Initialize()
	if not WG.DrawUnitShapeGL4 then
		widgetHandler:RemoveWidget()
	end
	for unitID, _ in pairs(dots) do
		if not dots[unitID].los and dots[unitID].radar then
			local x, y, z = spGetUnitPosition(unitID)
			if x then
				addUnitShape(unitID, dots[unitID].unitDefID, x, y, z, 0, dots[unitID].teamID)
			end
		end
	end
end

function widget:Shutdown()
	if WG.StopDrawUnitShapeGL4 then
		for unitID, _ in pairs(unitshapes) do
			removeUnitShape(unitID)
		end
	end
end

function widget:Update(dt)
	if not WG.DrawUnitShapeGL4 then
		widgetHandler:RemoveWidget()
	end
	if spec then
		_,specFullView,_ = Spring.GetSpectatingState()
	end
	if not specFullView then
		for unitID, shape in pairs(unitshapes) do
			local x, y, z = spGetUnitPosition(unitID)
			if not x then
				dots[unitID] = nil
				removeUnitShape(unitID)	-- needs to be done cause we dont know if unit has died
			elseif spIsUnitInView(unitID) then
				addUnitShape(unitID, dots[unitID].unitDefID, x, y, z, 0, dots[unitID].teamID)	-- update because unit position does change
			end
		end
	else
		for unitID, _ in pairs(unitshapes) do
			removeUnitShape(unitID)
		end
	end
end

function widget:GetConfigData()
	return {
		dots = dots,
	}
end

function widget:SetConfigData(data)
	if Spring.GetGameFrame() > 0 and data.dots ~= nil then
		dots = data.dots
	end
end
