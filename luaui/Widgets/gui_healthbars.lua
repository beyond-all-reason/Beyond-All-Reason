function widget:GetInfo()
	return {
		name = "Health Bars",
		desc = "Options: /healthbars_style,  /healthbars_percentage",
		author = "Floris (original plain bars by jK)",
		date = "28 march 2015",
		license = "GNU GPL, v2 or later",
		layer = -10,
		enabled = true
	}
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local barScale = 1

local barHeightOffset = 36         -- set value that healthbars for units that can unfold and become larger than its unitdef.height are still visible

local drawDistanceMult = 1

local barHeight = 2.55
local barWidth = 12         --// (barWidth)x2 total width!!!
local barAlpha = 0.86
local barOutlineAlpha = 0.8
local barInnerAlpha = 0.5
local barValueAlpha = 0.9          -- alpha of the colored part

local featureBarHeight = 1.65
local featureBarWidth = 8
local featureBarAlpha = 0.6

local hideHealthbars = false       -- could be toggled if unit shader shows degradation
local showHealthbarOnSelection = true
local showHealthbarOnChange = true
local healthChangeTimer = 3

local drawBarTitles = true          -- (I disabled the healthbar text, cause that one doesnt need an explanation)
local titlesAlpha = 0.3 * barAlpha

local drawBarPercentage = 0                -- wont draw heath percentage text above this percentage
local alwaysDrawBarPercentageForComs = true
local drawFeatureBarPercentage = 0                -- true:  commanders always will show health percentage number
local choppedCornerSize = 0.48
local outlineSize = 0.88
local drawFullHealthBars = false
local unitHpThreshold = 0.99

local drawFeatureHealth = true
local featureTitlesAlpha = featureBarAlpha * titlesAlpha / barAlpha
local featureHpThreshold = 0.85

local featureResurrectVisibility = true      -- draw feature bars for resurrected features on same distance as normal unit bars
local featureReclaimVisibility = true      -- draw feature bars for reclaimed features on same distance as normal unit bars

local minPercentageDistance = 130000     -- always show health percentage text below this distance
local infoDistance = 900000
local maxFeatureInfoDistance = 330000    --max squared distance at which text it drawn for features
local maxFeatureDistance = 700000    --max squared distance at which any info is drawn for features
local maxUnitDistance = 7000000  --max squared distance at which any info is drawn for units

local minReloadTime = 4 --// in seconds

local variableBarSizes = true

local destructableFeature = {}
local drawnFeature = {}
for i = 1, #FeatureDefs do
	destructableFeature[i] = FeatureDefs[i].destructable
	drawnFeature[i] = (FeatureDefs[i].drawTypeString == "model")
end

--// this table is used to shows the hp of perimeter defence, and filter it for default wreckages
local walls = { dragonsteeth = true, dragonsteeth_cor = true, fortification = true, fortification_cor = true, floatingteeth = true, floatingteeth_cor = true }

local stockpileH = 24
local stockpileW = 12

local unitHealthChangeTime = {}
local unitHealthLog = {}

local choppedCorners = true
local showOutline = true
local showInnerBg = true

local isCommander = {}
for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.customParams.iscommander then
		isCommander[unitDefID] = true
	end
end

local selectedUnits = {}
local SelectedUnitsCount = Spring.GetSelectedUnitsCount()

local unba_enabled = (Spring.GetModOptions() and Spring.GetModOptions().unba and Spring.GetModOptions().unba == "enabled")

local chobbyInterface

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

--// colors
local bkBottom = { 0.25, 0.25, 0.25, barAlpha }
local bkTop = { 0.10, 0.10, 0.10, barAlpha }
local bkOutlineBottom = { 0.25, 0.25, 0.25, barOutlineAlpha }
local bkOutlineTop = { 0.10, 0.10, 0.10, barOutlineAlpha }
local bkInnerBottom = { 0.06, 0.06, 0.06, barInnerAlpha }
local bkInnerTop = { 0.33, 0.33, 0.33, barInnerAlpha * 0.5 }
local hpcolormap = { { 1, 0.0, 0.0, barValueAlpha }, { 0.8, 0.60, 0.0, barValueAlpha }, { 0.0, 0.75, 0.0, barValueAlpha } }
local bfcolormap = {}

local fbkBottom = { 0.40, 0.40, 0.40, featureBarAlpha }
local fbkTop = { 0.06, 0.06, 0.06, featureBarAlpha }
local fhpcolormap = { { 0.33, 0.33, 0.33, featureBarAlpha * 1.5 }, { 0.33, 0.33, 0.33, featureBarAlpha * 1.5 }, { 0.33, 0.33, 0.33, featureBarAlpha * 1.5 } }

local barColors = {
	emp = { 0.50, 0.50, 1.00, barValueAlpha },
	emp_p = { 0.40, 0.40, 0.80, barValueAlpha },
	emp_b = { 0.60, 0.60, 0.90, barValueAlpha },
	capture = { 1.00, 0.50, 0.00, barValueAlpha },
	build = { 0.75, 0.75, 0.75, barValueAlpha },
	stock = { 0.50, 0.50, 0.50, barValueAlpha },
	reload = { 0.05, 0.60, 0.60, barValueAlpha },
	shield = { 0.20, 0.60, 0.60, barValueAlpha },
	resurrect = { 1.00, 0.20, 1.00, barValueAlpha },
	reclaim = { 0.75, 0.75, 0.75, barValueAlpha },
	dguncharge = { 1.00, 0.80, 0.00, barValueAlpha },
}

local ignoreUnits = {}
for udefID, def in pairs(UnitDefs) do
	if def.customParams.nohealthbars then
		ignoreUnits[udefID] = true
	end
end
local ignoreFeatures = {}
for fdefID, def in pairs(FeatureDefs) do
	if def.customParams.nohealthbars then
		ignoreFeatures[fdefID] = true
	end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local blink = false
local gameFrame = 0

local empDecline = 1 / 40 --magic

local cx, cy, cz = 0, 0, 0  --// camera pos
local smoothheight = 0

local barShader
local barDList
local barFeatureDList

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

--// speedup (there are a lot more localizations, but they are in limited scope cos we are running out of upvalues)
local glColor = gl.Color
local glMyText = gl.FogCoord
local floor = math.floor
local sub = string.sub
local spGetUnitDefID = Spring.GetUnitDefID
local glDepthTest = gl.DepthTest

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------


-- tiny perf improvement this way:
local unitsUnitDefCache = {}
function GetUnitDefID(unitID)
	if unitsUnitDefCache[unitID] == nil then
		unitsUnitDefCache[unitID] = spGetUnitDefID(unitID)
	end
	return unitsUnitDefCache[unitID]
end
function widget:UnitDestroyed(unitID, unitDefID, unitTeam)
	unitsUnitDefCache[unitID] = nil
end

do
	local deactivated = false
	function showhealthbars(cmd, line, words)
		if ((words[1]) and (words[1] ~= "0")) or (deactivated) then
			widgetHandler:UpdateCallIn('DrawWorld')
			deactivated = false
		else
			widgetHandler:RemoveCallIn('DrawWorld')
			deactivated = true
		end
	end
end --//end do



-- if you change code inside this function, then  dont forget to change drawFeatureBarGl() aswell
function drawBarGl()

	local cs = choppedCornerSize
	local heightAddition = outlineSize

	gl.PushMatrix()
	gl.Scale(barScale, barScale, barScale)

	gl.BeginEnd(GL.QUADS, function()


		-- center background piece
		gl.Color(bkOutlineBottom)
		gl.Vertex(barWidth - cs, 0 - heightAddition, 0, 1)
		gl.Vertex(barWidth - cs, 0 - heightAddition, (barWidth * 2) - cs * 2, 1)
		gl.Color(bkOutlineTop)
		gl.Vertex(barWidth - cs, barHeight + heightAddition, (barWidth * 2) - cs * 2, 1)
		gl.Vertex(barWidth - cs, barHeight + heightAddition, 0, 1)

		cs = choppedCornerSize
		-- inner center background piece
		gl.Color(bkInnerBottom[1], bkInnerBottom[2], bkInnerBottom[3], bkInnerBottom[4])
		gl.Vertex(barWidth - cs - cs, 0, 0, 2)
		gl.Vertex(barWidth - cs, 0, (barWidth * 2) - cs * 2, 2)
		gl.Color(bkInnerTop[1], bkInnerTop[2], bkInnerTop[3], bkInnerTop[4])
		gl.Vertex(barWidth - cs, barHeight, (barWidth * 2) - cs * 2, 2)
		gl.Vertex(barWidth - cs - cs, barHeight, 0, 2)

		-- inner background right piece
		local cs2 = cs
		gl.Color(bkInnerBottom[1], bkInnerBottom[2], bkInnerBottom[3], bkInnerBottom[4])
		gl.Vertex(barWidth - cs - cs + cs2, cs2, 0, 2)
		gl.Vertex(barWidth - cs - cs, 0, 0, 2)
		gl.Color(bkInnerTop[1], bkInnerTop[2], bkInnerTop[3], bkInnerTop[4])
		gl.Vertex(barWidth - cs - cs, barHeight, 0, 2)
		gl.Vertex(barWidth - cs - cs + cs2, barHeight - cs2, 0, 2)

		-- background right piece
		local cs2 = outlineSize
		gl.Color(bkOutlineBottom)
		gl.Vertex(barWidth - cs + cs2, cs2 - heightAddition, 0, 1)
		gl.Vertex(barWidth - cs, 0 - heightAddition, 0, 1)
		gl.Color(bkOutlineTop)
		gl.Vertex(barWidth - cs, barHeight + heightAddition, 0, 1)
		gl.Vertex(barWidth - cs + cs2, barHeight + heightAddition - cs2, 0, 1)

		if heightAddition > 0 then
			cs = outlineSize
			-- background left piece
			gl.Color(bkOutlineBottom)
			gl.Vertex(-barWidth - cs, cs - heightAddition, 0, 1)
			gl.Vertex(-barWidth, -heightAddition, 0, 1)
			gl.Color(bkOutlineTop)
			gl.Vertex(-barWidth, barHeight + heightAddition, 0, 1)
			gl.Vertex(-barWidth - cs, barHeight + heightAddition - cs, 0, 1)

			cs = choppedCornerSize
			-- top middle piece
			local usedColor = bkOutlineTop[1] + ((bkOutlineBottom[1] - bkOutlineTop[1]) * (heightAddition / (barHeight + heightAddition + heightAddition)))
			gl.Color(usedColor, usedColor, usedColor, bkOutlineTop[4])
			gl.Vertex(-barWidth, barHeight, 0, 1)
			gl.Vertex(barWidth - cs, barHeight, (barWidth * 2) - cs * 2, 1)
			gl.Color(bkOutlineTop)
			gl.Vertex(barWidth - cs, barHeight + heightAddition, (barWidth * 2) - cs * 2, 1)
			gl.Vertex(-barWidth, barHeight + heightAddition, 0, 1)

			-- bottom middle piece
			usedColor = bkOutlineBottom[1] - ((bkOutlineBottom[1] - bkOutlineTop[1]) * (heightAddition / (barHeight + heightAddition + heightAddition)))
			gl.Color(usedColor, usedColor, usedColor, bkOutlineTop[4])
			gl.Vertex(-barWidth, 0, 0, 1)
			gl.Vertex(barWidth - cs, 0, (barWidth * 2) - cs * 2, 1)
			gl.Color(bkOutlineBottom)
			gl.Vertex(barWidth - cs, -heightAddition, (barWidth * 2) - cs * 2, 1)
			gl.Vertex(-barWidth, -heightAddition, 0, 1)
		end

		-- color (value part) mid piece
		gl.Vertex(-barWidth + cs, 0, 0, 0)
		gl.Vertex(-barWidth, 0, (barWidth * 2) - cs * 2, 0)
		gl.Vertex(-barWidth, barHeight, (barWidth * 2) - cs * 2, 0)
		gl.Vertex(-barWidth + cs, barHeight, 0, 0)

		-- color (value part) left piece
		gl.Vertex(-barWidth, cs, 0, 0)
		gl.Vertex(-barWidth + cs, 0, 0, 0)
		gl.Vertex(-barWidth + cs, barHeight, 0, 0)
		gl.Vertex(-barWidth, barHeight - cs, 0, 0)

		-- color (value part) right piece
		gl.Vertex(-barWidth + cs, cs, (barWidth * 2) - cs * 2, 0)
		gl.Vertex(-barWidth, 0, (barWidth * 2) - cs * 2, 0)
		gl.Vertex(-barWidth, barHeight, (barWidth * 2) - cs * 2, 0)
		gl.Vertex(-barWidth + cs, barHeight - cs, (barWidth * 2) - cs * 2, 0)

	end)
	-- corner fillers
	gl.BeginEnd(GL.TRIANGLES, function()
		cs = choppedCornerSize

		local inputBottomColor = bkOutlineBottom
		local inputTopColor = bkOutlineTop

		-- top right
		local usedColor = inputTopColor[1] + ((inputBottomColor[1] - inputTopColor[1]) * ((heightAddition + cs) / (barHeight + heightAddition + heightAddition)))
		gl.Color(usedColor, usedColor, usedColor, inputTopColor[4])
		gl.Vertex(barWidth - cs, barHeight - cs, (barWidth * 2) - cs * 2, 1)

		usedColor = inputTopColor[1] + ((inputBottomColor[1] - inputTopColor[1]) * (heightAddition / (barHeight + heightAddition + heightAddition)))
		gl.Color(usedColor, usedColor, usedColor, inputTopColor[4])
		gl.Vertex(barWidth - cs, barHeight, (barWidth * 2) - cs * 2, 1)
		gl.Vertex(barWidth - cs - cs, barHeight, (barWidth * 2) - cs * 2, 1)

		-- bottom right
		usedColor = inputBottomColor[1] - ((inputBottomColor[1] - inputTopColor[1]) * ((heightAddition + cs) / (barHeight + heightAddition + heightAddition)))
		gl.Color(usedColor, usedColor, usedColor, inputBottomColor[4])
		gl.Vertex(barWidth - cs, cs, (barWidth * 2) - cs * 2, 1)

		usedColor = inputBottomColor[1] - ((inputBottomColor[1] - inputTopColor[1]) * (heightAddition / (barHeight + heightAddition + heightAddition)))
		gl.Color(usedColor, usedColor, usedColor, inputBottomColor[4])
		gl.Vertex(barWidth - cs, 0, (barWidth * 2) - cs * 2, 1)
		gl.Vertex(barWidth - cs - cs, 0, (barWidth * 2) - cs * 2, 1)

		-- inner background corners
		-- top right
		usedColor = bkInnerTop[1] - ((bkInnerTop[1] - bkInnerBottom[1]) * ((cs) / (barHeight)))
		gl.Color(usedColor, usedColor, usedColor, bkInnerTop[4])
		gl.Vertex(barWidth - cs, barHeight - cs, (barWidth * 2) - cs * 2, 1.0000001)

		gl.Color(bkInnerTop[1], bkInnerTop[2], bkInnerTop[3], bkInnerTop[4])
		gl.Vertex(barWidth - cs, barHeight, (barWidth * 2) - cs * 2, 1.0000001)
		gl.Vertex(barWidth - cs - cs, barHeight, (barWidth * 2) - cs * 2, 1.0000001)

		-- bottom right
		usedColor = bkInnerBottom[1] + ((bkInnerTop[1] - bkInnerBottom[1]) * ((cs) / (barHeight)))
		gl.Color(usedColor, usedColor, usedColor, bkInnerBottom[4])
		gl.Vertex(barWidth - cs, cs, (barWidth * 2) - cs * 2, 1.0000001)

		gl.Color(bkInnerBottom[1], bkInnerBottom[2], bkInnerBottom[3], bkInnerBottom[4])
		gl.Vertex(barWidth - cs, 0, (barWidth * 2) - cs * 2, 1.0000001)
		gl.Vertex(barWidth - cs - cs, 0, (barWidth * 2) - cs * 2, 1.0000001)

		if heightAddition > 0 then
			-- top left
			usedColor = inputTopColor[1] + ((inputBottomColor[1] - inputTopColor[1]) * ((heightAddition + cs) / (barHeight + heightAddition + heightAddition)))
			gl.Color(usedColor, usedColor, usedColor, inputTopColor[4])
			gl.Vertex(-barWidth, barHeight - cs, 0, 1)

			usedColor = inputTopColor[1] + ((inputBottomColor[1] - inputTopColor[1]) * (heightAddition / (barHeight + heightAddition + heightAddition)))
			gl.Color(usedColor, usedColor, usedColor, inputTopColor[4])
			gl.Vertex(-barWidth, barHeight, 0, 1)
			gl.Vertex(-barWidth + cs, barHeight, 0, 1)

			-- bottom left
			usedColor = inputBottomColor[1] - ((inputBottomColor[1] - inputTopColor[1]) * ((heightAddition + cs) / (barHeight + heightAddition + heightAddition)))
			gl.Color(usedColor, usedColor, usedColor, inputBottomColor[4])
			gl.Vertex(-barWidth, cs, 0, 1)

			usedColor = inputBottomColor[1] - ((inputBottomColor[1] - inputTopColor[1]) * (heightAddition / (barHeight + heightAddition + heightAddition)))
			gl.Color(usedColor, usedColor, usedColor, inputBottomColor[4])
			gl.Vertex(-barWidth, 0, 0, 1)
			gl.Vertex(-barWidth + cs, 0, 0, 1)
		end
	end)
	gl.PopMatrix()

end


-- is a copy of drawBarGl(), some vars changed (only at top: barHeight, barWidth, bkBottom, bkTop)
function drawFeatureBarGl()
	local barHeight = featureBarHeight
	local barWidth = featureBarWidth
	local bkBottom = fbkBottom
	local bkTop = fbkTop

	local cs = choppedCornerSize
	local heightAddition = outlineSize

	gl.BeginEnd(GL.QUADS, function()


		-- center background piece
		gl.Color(bkOutlineBottom)
		gl.Vertex(barWidth - cs, 0 - heightAddition, 0, 1)
		gl.Vertex(barWidth - cs, 0 - heightAddition, (barWidth * 2) - cs * 2, 1)
		gl.Color(bkOutlineTop)
		gl.Vertex(barWidth - cs, barHeight + heightAddition, (barWidth * 2) - cs * 2, 1)
		gl.Vertex(barWidth - cs, barHeight + heightAddition, 0, 1)

		cs = choppedCornerSize
		-- inner center background piece
		gl.Color(bkInnerBottom[1], bkInnerBottom[2], bkInnerBottom[3], bkInnerBottom[4])
		gl.Vertex(barWidth - cs - cs, 0, 0, 2)
		gl.Vertex(barWidth - cs, 0, (barWidth * 2) - cs * 2, 2)
		gl.Color(bkInnerTop[1], bkInnerTop[2], bkInnerTop[3], bkInnerTop[4])
		gl.Vertex(barWidth - cs, barHeight, (barWidth * 2) - cs * 2, 2)
		gl.Vertex(barWidth - cs - cs, barHeight, 0, 2)

		-- inner background right piece
		local cs2 = cs
		gl.Color(bkInnerBottom[1], bkInnerBottom[2], bkInnerBottom[3], bkInnerBottom[4])
		gl.Vertex(barWidth - cs - cs + cs2, cs2, 0, 2)
		gl.Vertex(barWidth - cs - cs, 0, 0, 2)
		gl.Color(bkInnerTop[1], bkInnerTop[2], bkInnerTop[3], bkInnerTop[4])
		gl.Vertex(barWidth - cs - cs, barHeight, 0, 2)
		gl.Vertex(barWidth - cs - cs + cs2, barHeight - cs2, 0, 2)

		-- background right piece
		local cs2 = outlineSize
		gl.Color(bkOutlineBottom)
		gl.Vertex(barWidth - cs + cs2, cs2 - heightAddition, 0, 1)
		gl.Vertex(barWidth - cs, 0 - heightAddition, 0, 1)
		gl.Color(bkOutlineTop)
		gl.Vertex(barWidth - cs, barHeight + heightAddition, 0, 1)
		gl.Vertex(barWidth - cs + cs2, barHeight + heightAddition - cs2, 0, 1)

		if heightAddition > 0 then
			cs = outlineSize
			-- background left piece
			gl.Color(bkOutlineBottom)
			gl.Vertex(-barWidth - cs, cs - heightAddition, 0, 1)
			gl.Vertex(-barWidth, -heightAddition, 0, 1)
			gl.Color(bkOutlineTop)
			gl.Vertex(-barWidth, barHeight + heightAddition, 0, 1)
			gl.Vertex(-barWidth - cs, barHeight + heightAddition - cs, 0, 1)

			cs = choppedCornerSize
			-- top middle piece
			local usedColor = bkOutlineTop[1] + ((bkOutlineBottom[1] - bkOutlineTop[1]) * (heightAddition / (barHeight + heightAddition + heightAddition)))
			gl.Color(usedColor, usedColor, usedColor, bkOutlineTop[4])
			gl.Vertex(-barWidth, barHeight, 0, 1)
			gl.Vertex(barWidth - cs, barHeight, (barWidth * 2) - cs * 2, 1)
			gl.Color(bkOutlineTop)
			gl.Vertex(barWidth - cs, barHeight + heightAddition, (barWidth * 2) - cs * 2, 1)
			gl.Vertex(-barWidth, barHeight + heightAddition, 0, 1)

			-- bottom middle piece
			usedColor = bkOutlineBottom[1] - ((bkOutlineBottom[1] - bkOutlineTop[1]) * (heightAddition / (barHeight + heightAddition + heightAddition)))
			gl.Color(usedColor, usedColor, usedColor, bkOutlineTop[4])
			gl.Vertex(-barWidth, 0, 0, 1)
			gl.Vertex(barWidth - cs, 0, (barWidth * 2) - cs * 2, 1)
			gl.Color(bkOutlineBottom)
			gl.Vertex(barWidth - cs, -heightAddition, (barWidth * 2) - cs * 2, 1)
			gl.Vertex(-barWidth, -heightAddition, 0, 1)
		end

		-- color (value part) mid piece
		gl.Vertex(-barWidth + cs, 0, 0, 0)
		gl.Vertex(-barWidth, 0, (barWidth * 2) - cs * 2, 0)
		gl.Vertex(-barWidth, barHeight, (barWidth * 2) - cs * 2, 0)
		gl.Vertex(-barWidth + cs, barHeight, 0, 0)

		-- color (value part) left piece
		gl.Vertex(-barWidth, cs, 0, 0)
		gl.Vertex(-barWidth + cs, 0, 0, 0)
		gl.Vertex(-barWidth + cs, barHeight, 0, 0)
		gl.Vertex(-barWidth, barHeight - cs, 0, 0)

		-- color (value part) right piece
		gl.Vertex(-barWidth + cs, cs, (barWidth * 2) - cs * 2, 0)
		gl.Vertex(-barWidth, 0, (barWidth * 2) - cs * 2, 0)
		gl.Vertex(-barWidth, barHeight, (barWidth * 2) - cs * 2, 0)
		gl.Vertex(-barWidth + cs, barHeight - cs, (barWidth * 2) - cs * 2, 0)

	end)
	-- corner fillers
	gl.BeginEnd(GL.TRIANGLES, function()
		cs = choppedCornerSize

		local inputBottomColor = bkOutlineBottom
		local inputTopColor = bkOutlineTop

		-- top right
		local usedColor = inputTopColor[1] + ((inputBottomColor[1] - inputTopColor[1]) * ((heightAddition + cs) / (barHeight + heightAddition + heightAddition)))
		gl.Color(usedColor, usedColor, usedColor, inputTopColor[4])
		gl.Vertex(barWidth - cs, barHeight - cs, (barWidth * 2) - cs * 2, 1)

		usedColor = inputTopColor[1] + ((inputBottomColor[1] - inputTopColor[1]) * (heightAddition / (barHeight + heightAddition + heightAddition)))
		gl.Color(usedColor, usedColor, usedColor, inputTopColor[4])
		gl.Vertex(barWidth - cs, barHeight, (barWidth * 2) - cs * 2, 1)
		gl.Vertex(barWidth - cs - cs, barHeight, (barWidth * 2) - cs * 2, 1)

		-- bottom right
		usedColor = inputBottomColor[1] - ((inputBottomColor[1] - inputTopColor[1]) * ((heightAddition + cs) / (barHeight + heightAddition + heightAddition)))
		gl.Color(usedColor, usedColor, usedColor, inputBottomColor[4])
		gl.Vertex(barWidth - cs, cs, (barWidth * 2) - cs * 2, 1)

		usedColor = inputBottomColor[1] - ((inputBottomColor[1] - inputTopColor[1]) * (heightAddition / (barHeight + heightAddition + heightAddition)))
		gl.Color(usedColor, usedColor, usedColor, inputBottomColor[4])
		gl.Vertex(barWidth - cs, 0, (barWidth * 2) - cs * 2, 1)
		gl.Vertex(barWidth - cs - cs, 0, (barWidth * 2) - cs * 2, 1)

		-- inner background corners
		-- top right
		usedColor = bkInnerTop[1] - ((bkInnerTop[1] - bkInnerBottom[1]) * ((cs) / (barHeight)))
		gl.Color(usedColor, usedColor, usedColor, bkInnerTop[4])
		gl.Vertex(barWidth - cs, barHeight - cs, (barWidth * 2) - cs * 2, 1.0000001)

		gl.Color(bkInnerTop[1], bkInnerTop[2], bkInnerTop[3], bkInnerTop[4])
		gl.Vertex(barWidth - cs, barHeight, (barWidth * 2) - cs * 2, 1.0000001)
		gl.Vertex(barWidth - cs - cs, barHeight, (barWidth * 2) - cs * 2, 1.0000001)

		-- bottom right
		usedColor = bkInnerBottom[1] + ((bkInnerTop[1] - bkInnerBottom[1]) * ((cs) / (barHeight)))
		gl.Color(usedColor, usedColor, usedColor, bkInnerBottom[4])
		gl.Vertex(barWidth - cs, cs, (barWidth * 2) - cs * 2, 1.0000001)

		gl.Color(bkInnerBottom[1], bkInnerBottom[2], bkInnerBottom[3], bkInnerBottom[4])
		gl.Vertex(barWidth - cs, 0, (barWidth * 2) - cs * 2, 1.0000001)
		gl.Vertex(barWidth - cs - cs, 0, (barWidth * 2) - cs * 2, 1.0000001)

		if heightAddition > 0 then
			-- top left
			usedColor = inputTopColor[1] + ((inputBottomColor[1] - inputTopColor[1]) * ((heightAddition + cs) / (barHeight + heightAddition + heightAddition)))
			gl.Color(usedColor, usedColor, usedColor, inputTopColor[4])
			gl.Vertex(-barWidth, barHeight - cs, 0, 1)

			usedColor = inputTopColor[1] + ((inputBottomColor[1] - inputTopColor[1]) * (heightAddition / (barHeight + heightAddition + heightAddition)))
			gl.Color(usedColor, usedColor, usedColor, inputTopColor[4])
			gl.Vertex(-barWidth, barHeight, 0, 1)
			gl.Vertex(-barWidth + cs, barHeight, 0, 1)

			-- bottom left
			usedColor = inputBottomColor[1] - ((inputBottomColor[1] - inputTopColor[1]) * ((heightAddition + cs) / (barHeight + heightAddition + heightAddition)))
			gl.Color(usedColor, usedColor, usedColor, inputBottomColor[4])
			gl.Vertex(-barWidth, cs, 0, 1)

			usedColor = inputBottomColor[1] - ((inputBottomColor[1] - inputTopColor[1]) * (heightAddition / (barHeight + heightAddition + heightAddition)))
			gl.Color(usedColor, usedColor, usedColor, inputBottomColor[4])
			gl.Vertex(-barWidth, 0, 0, 1)
			gl.Vertex(-barWidth + cs, 0, 0, 1)
		end
	end)

end

function init()

	--// wow, using a buffered list can give 1-2 frames in extreme(!) situations :p
	for hp = 0, 100 do
		bfcolormap[hp] = { GetColor(hpcolormap, hp * 0.01) }
	end

	--// create bar shader
	if gl.CreateShader then

		if barShader then
			gl.DeleteShader(barShader)
		end
		barShader = gl.CreateShader({

			vertex = [[
				#version 150 compatibility
				#define barColor gl_MultiTexCoord1
				#define progress gl_MultiTexCoord2.x
				#define offset   gl_MultiTexCoord2.y

				void main()
				{
				   // switch between font rendering and bar rendering
				   if (gl_FogCoord>0.5f) {
					 gl_TexCoord[0]= gl_TextureMatrix[0]*gl_MultiTexCoord0;
					 gl_FrontColor = gl_Color;
					 gl_Position   = ftransform();
					 //return;			-- commenting out this line fixes glitchy healthbars on intel gfx
				   }
				   vec4 vertex = gl_Vertex;
				   if (vertex.w==1) {
					 gl_FrontColor = gl_Color;
					 if (vertex.z>0.0) {
					   vertex.x -= (1.0-progress)*gl_Vertex.z;
					   vertex.z  = 0.0;
					 }

				   }else if (vertex.w==-2 ) {
					 gl_FrontColor = vec4(barColor.rgb,barColor.a);

					 if (gl_Vertex.z>1.0) {
					   vertex.x += progress*gl_Vertex.z;
					   vertex.z  = 0.0;
					 }
					 vertex.w  = 1;

				   }else if (vertex.w==-3 ) {
					 gl_FrontColor = vec4(barColor.rgb,barColor.a);

					 if (vertex.z>1.0) {
					   vertex.x += progress*gl_Vertex.z;
					   vertex.z  = 0.0;
					 }
					 vertex.w  = 1;

				   }else if (vertex.w==-4 ) {
					 gl_FrontColor = vec4(barColor.rgb,0);

					 if (gl_Vertex.z>1.0) {
					   vertex.x += progress*gl_Vertex.z;
					   vertex.z  = 0.0;
					 }
					 vertex.w  = 1;

				   }else if (vertex.w>1 ) {
					 if (progress >= 0.92) {		// smooth out because else the bar wil overlap and look ugly at the end point
					   gl_FrontColor = vec4(gl_Color[0]+(barColor.r/4),gl_Color[1]+(barColor.g/4),gl_Color[2]+(barColor.b/4),((0.08-(progress-0.92))*12.5)*gl_Color[3]);
					 }else{
					   gl_FrontColor = vec4(gl_Color[0]+(barColor.r/4),gl_Color[1]+(barColor.g/4),gl_Color[2]+(barColor.b/4),gl_Color[3]);
					 }

					 if (vertex.z>0.0) {
					   vertex.x -= (1.0-progress)*gl_Vertex.z;
					   vertex.z  = 0.0;
					 }
					 vertex.w  = 1.0;

				   }else{
					 if (vertex.y>0.0) {
					   gl_FrontColor = vec4(barColor.rgb*1.8,barColor.a);
					 }else{
					   gl_FrontColor = vec4(barColor.rgb*0.85,barColor.a);
					 }
					 if (vertex.z>1.0) {
					   vertex.x += progress*gl_Vertex.z;
					   vertex.z  = 0.0;
					 }
					 vertex.w  = 1.0;
				   }
				   vertex.y  += offset;
				   gl_Position  = gl_ModelViewProjectionMatrix*vertex;
				 }
			]],
			uniform = {

			},
		})

		if barShader then
			if barDList then
				gl.DeleteList(barDList)
				gl.DeleteList(barFeatureDList)
			end
			barDList = gl.CreateList(drawBarGl)
			barFeatureDList = gl.CreateList(drawFeatureBarGl)
		end
	end
end

function widget:Initialize()
	--// catch f9
	Spring.SendCommands({ "showhealthbars 0" })
	Spring.SendCommands({ "showrezbars 0" })
	widgetHandler:AddAction("showhealthbars", showhealthbars)
	Spring.SendCommands({ "unbind f9 showhealthbars" })
	Spring.SendCommands({ "bind f9 luaui showhealthbars" })

	WG['healthbars'] = {}
	WG['healthbars'].getScale = function()
		return barScale
	end
	WG['healthbars'].setScale = function(value)
		barScale = value
		init()
	end
	WG['healthbars'].getHideHealth = function()
		return hideHealthbars
	end
	WG['healthbars'].setHideHealth = function(value)
		hideHealthbars = value
	end
	WG['healthbars'].getDrawDistance = function()
		return drawDistanceMult
	end
	WG['healthbars'].setDrawDistance = function(value)
		drawDistanceMult = value
	end

	WG['healthbars'].getVariableSizes = function()
		return variableBarSizes
	end
	WG['healthbars'].setVariableSizes = function(value)
		variableBarSizes = value
	end

	init()
end

function widget:Shutdown()
	--// catch f9
	widgetHandler:RemoveAction("showhealthbars", showhealthbars)
	Spring.SendCommands({ "unbind f9 luaui" })
	Spring.SendCommands({ "bind f9 showhealthbars" })
	--Spring.SendCommands({"showhealthbars 1"}) -- don't re-enable, nobody ever uses engines built in healthbars
	--Spring.SendCommands({"showrezbars 1"})

	if barShader then
		gl.DeleteShader(barShader)
	end
	if barDList then
		gl.DeleteList(barDList)
		gl.DeleteList(barFeatureDList)
	end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function GetColor(colormap, slider)
	local coln = #colormap
	if (slider >= 1) then
		local col = colormap[coln]
		return col[1], col[2], col[3], col[4]
	end
	if (slider < 0) then
		slider = 0
	elseif (slider > 1) then
		slider = 1
	end
	local posn = 1 + (coln - 1) * slider
	local iposn = floor(posn)
	local aa = posn - iposn
	local ia = 1 - aa

	local col1, col2 = colormap[iposn], colormap[iposn + 1]

	return col1[1] * ia + col2[1] * aa, col1[2] * ia + col2[2] * aa,
	col1[3] * ia + col2[3] * aa, col1[4] * ia + col2[4] * aa
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local DrawUnitBar
local DrawFeatureBar
local DrawStockpile

do
	--//speedup
	local GL_QUADS = GL.QUADS
	local glVertex = gl.Vertex
	local glBeginEnd = gl.BeginEnd
	local glMultiTexCoord = gl.MultiTexCoord
	local glTexRect = gl.TexRect
	local glTexture = gl.Texture
	local glCallList = gl.CallList
	local glText = gl.Text

	local function DrawGradient(left, top, right, bottom, topclr, bottomclr)

		glColor(bottomclr)
		glVertex(left, bottom)
		glVertex(right, bottom)
		glColor(topclr)
		glVertex(right, top)
		glVertex(left, top)
	end

	local brightClr = {}
	function DrawUnitBar(offsetY, percent, color)
		if barShader then
			glMultiTexCoord(1, color)
			glMultiTexCoord(2, percent, offsetY)
			glCallList(barDList)
			return
		end

		brightClr[1] = color[1] * 1.5
		brightClr[2] = color[2] * 1.5
		brightClr[3] = color[3] * 1.5
		brightClr[4] = color[4]
		local progress_pos = -barWidth + barWidth * 2 * percent - 1
		local bar_Height = barHeight + offsetY
		if percent < 1 then
			glBeginEnd(GL_QUADS, DrawGradient, progress_pos, bar_Height, barWidth, offsetY, bkTop, bkBottom)
		end
		glBeginEnd(GL_QUADS, DrawGradient, -barWidth, bar_Height, progress_pos, offsetY, brightClr, color)
	end

	function DrawFeatureBar(offsetY, percent, color)
		if barShader then
			glMultiTexCoord(1, color)
			glMultiTexCoord(2, percent, offsetY)
			glCallList(barFeatureDList)
			return
		end

		brightClr[1] = color[1] * 1.5
		brightClr[2] = color[2] * 1.5
		brightClr[3] = color[3] * 1.5
		brightClr[4] = color[4]
		local progress_pos = -featureBarWidth + featureBarWidth * 2 * percent
		glBeginEnd(GL_QUADS, DrawGradient, progress_pos, featureBarHeight + offsetY, featureBarWidth, offsetY, fbkTop, fbkBottom)
		glBeginEnd(GL_QUADS, DrawGradient, -featureBarWidth, featureBarHeight + offsetY, progress_pos, offsetY, brightClr, color)
	end

	function DrawStockpile(numStockpiled, numStockpileQued)
		--// DRAW STOCKPILED MISSLES
		glColor(1, 1, 1, 1)
		glTexture("LuaUI/Images/nuke.png")
		local xoffset = barWidth + 16
		for i = 1, ((numStockpiled > 3) and 3) or numStockpiled do
			glTexRect(xoffset, -(11 * barHeight - 2) - stockpileH, xoffset - stockpileW, -(11 * barHeight - 2))
			xoffset = xoffset - 8
		end
		glTexture(false)

		glText(numStockpiled .. '/' .. numStockpileQued, barWidth + 1.7, -(11 * barHeight - 2) - 16, 6.5, "cno")
	end

end --//end do


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local AddBar
local DrawBars
local barsN = 0

do
	--//speedup
	local glColor = gl.Color
	local glText = gl.Text
	local glPushMatrix = gl.PushMatrix
	local glPopMatrix = gl.PopMatrix
	local glScale = gl.Scale
	local glTranslate = gl.Translate

	local maxBars = 20
	local bars = {}
	local barHeightL = barHeight + 1.5 + outlineSize

	local barStart = -(barWidth + 1.5) - outlineSize
	local fBarHeightL = featureBarHeight + 1.5 + outlineSize
	local fBarStart = -(featureBarWidth + 1.5) - outlineSize

	for i = 1, maxBars do
		bars[i] = {}
	end

	function AddBar(title, progress, color_index, text, color)
		barsN = barsN + 1
		local barInfo = bars[barsN]
		barInfo.title = title
		barInfo.progress = progress
		barInfo.color = color or barColors[color_index]
		barInfo.text = text
	end

	function DrawBars(fullText, scale)
		glPushMatrix()
		glScale(barScale * scale, barScale * scale, barScale * scale)
		if barsN > 1 then
			glTranslate(0, (barsN - 1) * barHeightL, 0)
		end
		local yoffset = 0
		for i = 1, barsN do
			local barInfo = bars[i]
			DrawUnitBar(yoffset, barInfo.progress, barInfo.color)
			if fullText then
				if barShader then
					glMyText(1)
				end
				glColor(1, 1, 1, barAlpha)
				glText(barInfo.text, barStart, -outlineSize, 4, "r")
				if drawBarTitles and barInfo.title ~= Spring.I18N('ui.statusBars.health') then
					glColor(1, 1, 1, titlesAlpha)
					glText(barInfo.title, 0, 0, 2.35, "cd")
				end
				if barShader then
					glMyText(0)
				end
			end
			yoffset = yoffset - barHeightL
		end
		glPopMatrix()
		barsN = 0 --//reset!
	end

	function DrawBarsFeature(fullText, scale)
		glPushMatrix()
		glScale(barScale * scale, barScale * scale, barScale * scale)
		local yoffset = 0
		for i = 1, barsN do
			local barInfo = bars[i]
			DrawFeatureBar(yoffset, barInfo.progress, barInfo.color)
			if fullText then
				if barShader then
					glMyText(1)
				end
				if drawBarPercentage > 0 then
					glColor(1, 1, 1, featureBarAlpha)
					glText(barInfo.text, fBarStart, yoffset - outlineSize, 4, "r")
				end
				if drawBarTitles and barInfo.title ~= Spring.I18N('ui.statusBars.health') then
					glColor(1, 1, 1, featureTitlesAlpha)
					glText(barInfo.title, 0, yoffset - outlineSize, 2.35, "cd")
				end
				if barShader then
					glMyText(0)
				end
			end
			yoffset = yoffset - fBarHeightL
		end
		glPopMatrix()

		barsN = 0 --//reset!
	end

end --//end do


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local DrawUnitInfos

local spGetUnitHealth = Spring.GetUnitHealth

do
	--//speedup
	local glTranslate = gl.Translate
	local glPushMatrix = gl.PushMatrix
	local glPopMatrix = gl.PopMatrix
	local glBillboard = gl.Billboard
	local GetUnitIsStunned = Spring.GetUnitIsStunned
	local GetUnitHealth = Spring.GetUnitHealth
	local GetUnitWeaponState = Spring.GetUnitWeaponState
	local GetUnitShieldState = Spring.GetUnitShieldState
	local GetUnitStockpile = Spring.GetUnitStockpile
	local GetUnitRulesParam = Spring.GetUnitRulesParam
	local GetUnitViewPosition = Spring.GetUnitViewPosition

	local fullText
	local ux, uy, uz
	local dx, dy, dz, dist
	local health, maxHealth, paralyzeDamage, capture, build
	local hp, hp100, emp
	local reload, reloaded, reloadFrame
	local numStockpiled, numStockpileQued

	local ci
	local unitdefInfo = {}
	for unitDefID, unitDef in pairs(UnitDefs) do

		--// find real primary weapon and its reloadtime
		unitDef.reloadTime = 0
		unitDef.primaryWeapon = 0
		unitDef.shieldPower = 0
		for i = 1, #unitDef.weapons do
			local WeaponDefID = unitDef.weapons[i].weaponDef
			local WeaponDef = WeaponDefs[WeaponDefID]
			if WeaponDef.reload > unitDef.reloadTime then
				unitDef.reloadTime = WeaponDef.reload
				unitDef.primaryWeapon = i
			end
		end
		local shieldDefID = unitDef.shieldWeaponDef
		unitDef.shieldPower = ((shieldDefID) and (WeaponDefs[shieldDefID].shieldPower)) or (-1)

		unitdefInfo[unitDefID] = {
			height = unitDef.height + barHeightOffset,
			maxShield = unitDef.shieldPower,
			canStockpile = unitDef.canStockpile,
			reloadTime = unitDef.reloadTime,
			primaryWeapon = unitDef.primaryWeapon,
			scale = math.min(1.45, math.max(0.85, (Spring.GetUnitDefDimensions(unitDefID).radius / 150) + math.min(0.6, unitDef.power / 4000))) + math.min(0.6, unitDef.health / 22000),
		}
	end

	function DrawUnitInfos(unitID, unitDefID, hideHealth, ux, uy, uz, dist)

		local fullText = (dist < infoDistance * drawDistanceMult)

		ci = unitdefInfo[unitDefID]

		-- fade out when zooming out
		local scale = 1 - ((dist - (maxUnitDistance * drawDistanceMult * 0.25)) / (maxUnitDistance * drawDistanceMult - (maxUnitDistance * drawDistanceMult * 0.25)))
		if scale > 1 then
			scale = 1
		end
		if variableBarSizes then
			scale = scale * ci.scale
		end


		--// GET UNIT INFORMATION
		health, maxHealth, paralyzeDamage, capture, build = GetUnitHealth(unitID)
		if hideHealth then
			health = maxHealth
		end

		--if (not health)    then health=-1   elseif(health<1)    then health=1    end
		if not maxHealth or maxHealth < 1 then
			maxHealth = 1
		end
		if not build then
			build = 1
		end

		emp = (paralyzeDamage or 0) / maxHealth
		hp = (health or 0) / maxHealth

		--// BARS //-----------------------------------------------------------------------------
		--// Shield
		if ci.maxShield > 0 then
			if isCommander[unitDefID] and unba_enabled then
				for i = 23, 29 do
					if GetUnitShieldState(unitID, i) then
						local shieldOn, shieldPower = GetUnitShieldState(unitID, i)
						if shieldOn ~= 0 and build == 1 and shieldPower < ci.maxShield then
							ci.maxShield = WeaponDefs[UnitDefs[unitDefID].weapons[i].weaponDef].shieldPower
							shieldPower = shieldPower / ci.maxShield
							AddBar(Spring.I18N('ui.statusBars.shield'), shieldPower, "shield", (fullText and floor(shieldPower * 100) .. '%') or '')
						end
					end
				end
			else
				local shieldOn, shieldPower = GetUnitShieldState(unitID)
				if shieldOn and build == 1 and shieldPower < ci.maxShield then
					shieldPower = shieldPower / ci.maxShield
					AddBar(Spring.I18N('ui.statusBars.shield'), shieldPower, "shield", (fullText and floor(shieldPower * 100) .. '%') or '')
				end
			end
		end

		--// HEALTH
		if health and (drawFullHealthBars or hp < unitHpThreshold) and (build == 1 or build - hp >= 0.01) then
			hp100 = hp * 100
			hp100 = hp100 - hp100 % 1 --//same as floor(hp*100), but 10% faster
			if hp100 < 0 then
				hp100 = 0
			elseif hp100 > 100 then
				hp100 = 100
			end
			if drawFullHealthBars or hp100 < 100 and not (hp < 0) then
				local infotext = ''
				if fullText and (hp100 and hp100 <= drawBarPercentage and hp100 > 0) or dist < minPercentageDistance * drawDistanceMult then
					infotext = hp100 .. '%'
				end
				if alwaysDrawBarPercentageForComs then
					if isCommander[GetUnitDefID(unitID)] then
						infotext = hp100 .. '%'
					end
				end
				AddBar(Spring.I18N('ui.statusBars.health'), hp, nil, infotext or '', bfcolormap[hp100])
			end
		end

		--// BUILD
		if build < 1 then
			local infotext = ''
			if fullText and (drawBarPercentage > 0 or dist < minPercentageDistance * drawDistanceMult) then
				infotext = floor(build * 100) .. '%'
			end
			AddBar(Spring.I18N('ui.statusBars.building'), build, "build", infotext or '')
		end

		--// STOCKPILE
		if ci.canStockpile then
			local stockpileBuild
			numStockpiled, numStockpileQued, stockpileBuild = GetUnitStockpile(unitID)
			if numStockpiled then
				stockpileBuild = stockpileBuild or 0
				if stockpileBuild > 0 then
					AddBar(Spring.I18N('ui.statusBars.stockpile'), stockpileBuild, "stock", (fullText and floor(stockpileBuild * 100) .. '%') or '')
				end
			end
		else
			numStockpiled = false
		end

		--// PARALYZE
		if emp > 0.01 and hp > 0.01 and emp < 1e8 then
			local stunned = GetUnitIsStunned(unitID)
			local infotext = ''
			if stunned then
				if fullText then
					infotext = floor((paralyzeDamage - maxHealth) / (maxHealth * empDecline)) .. 's'
				end
				emp = 1
			else
				if emp > 1 then
					emp = 1
				end
				if fullText and drawBarPercentage > 0 then
					infotext = floor(emp * 100) .. '%'
				end
			end
			local empcolor_index = (stunned and ((blink and "emp_b") or "emp_p")) or ("emp")
			AddBar(Spring.I18N('ui.statusBars.paralyze'), emp, empcolor_index, infotext)
		end

		--// CAPTURE
		if (capture or -1) > 0 then
			local infotext = ''
			if fullText and drawBarPercentage > 0 then
				infotext = floor(capture * 100) .. '%'
			end
			AddBar(Spring.I18N('ui.statusBars.capture'), capture, "capture", infotext or '')
		end

		--// RELOAD
		if ci.reloadTime >= minReloadTime then
			_, reloaded, reloadFrame = GetUnitWeaponState(unitID, ci.primaryWeapon)
			if reloaded == false then
				reload = 1 - ((reloadFrame - gameFrame) / 30) / ci.reloadTime
				if reload < 0 then
					reload = 0
				end

				local infotext = ''
				if fullText and drawBarPercentage > 0 then
					infotext = reload .. '%'
				end
				AddBar(Spring.I18N('ui.statusBars.reload'), reload, "reload", infotext or '')
			end
		end

		if barsN > 0 or numStockpiled then
			glPushMatrix()
			glTranslate(ux, uy + ci.height, uz)
			glBillboard()

			--// DRAW BARS
			DrawBars(fullText, scale)

			--// STOCKPILE ICON
			if numStockpiled then
				if barShader then
					glMyText(1)
					DrawStockpile(numStockpiled, numStockpileQued)
					glMyText(0)
				else
					DrawStockpile(numStockpiled, numStockpileQued)
				end
			end

			glPopMatrix()
		end
	end

end --// end do

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local DrawFeatureInfos

do
	--//speedup
	local glTranslate = gl.Translate
	local glPushMatrix = gl.PushMatrix
	local glPopMatrix = gl.PopMatrix
	local glBillboard = gl.Billboard
	local GetFeatureResources = Spring.GetFeatureResources
	local GetFeatureHealth = Spring.GetFeatureHealth

	local featureDefID
	local health, maxHealth, resurrect, reclaimLeft
	local hp

	local ci
	local featuredefInfo = {}

	function DrawFeatureInfos(featureID, featureDefID, fx, fy, fz, dist)

		health, maxHealth, resurrect = GetFeatureHealth(featureID)
		if health == nil or health < 1 then
			return
		end
		_, _, _, _, reclaimLeft = GetFeatureResources(featureID)
		if not resurrect then
			resurrect = 0
		end
		if not reclaimLeft then
			reclaimLeft = 1
		end

		hp = (health or 0) / (maxHealth or 1)

		--// filter all walls and none resurrecting features
		if resurrect == 0 and reclaimLeft == 1 and hp > featureHpThreshold then
			return
		end

		-- fade out when zooming out
		local scale = 1 - ((dist - (maxFeatureDistance * drawDistanceMult * 0.25)) / (maxFeatureDistance * drawDistanceMult - (maxFeatureDistance * drawDistanceMult * 0.25)))
		if scale > 1 then
			scale = 1
		end

		local fullText = (dist < maxFeatureInfoDistance * drawDistanceMult)

		--// BARS //-----------------------------------------------------------------------------
		--// HEALTH
		if hp < featureHpThreshold and drawFeatureHealth then
			local color = { GetColor(fhpcolormap, hp) }
			AddBar(Spring.I18N('ui.statusBars.health'), hp, nil, (floor(hp * 100) <= drawFeatureBarPercentage and floor(hp * 100) .. '%') or '', color)
		end

		--// RESURRECT
		if resurrect > 0 then
			AddBar(Spring.I18N('ui.statusBars.resurrect'), resurrect, "resurrect", (fullText and floor(resurrect * 100) .. '%') or '')
		end

		--// RECLAIMING
		if reclaimLeft > 0 and reclaimLeft < 1 then
			AddBar(Spring.I18N('ui.statusBars.reclaim'), reclaimLeft, "reclaim", (fullText and floor(reclaimLeft * 100) .. '%') or '')
		end

		if barsN > 0 then

			if not featuredefInfo[featureDefID] then
				local featureDef = FeatureDefs[featureDefID or -1] or { height = 0, name = '' }
				featuredefInfo[featureDefID] = {
					height = featureDef.height + barHeightOffset,
					wall = walls[featureDef.name],
				}
			end
			ci = featuredefInfo[featureDefID]

			glPushMatrix()
			glTranslate(fx, fy + ci.height, fz)
			glBillboard()

			--// DRAW BARS
			DrawBarsFeature(fullText, scale)

			glPopMatrix()
		end
	end

end --// end do

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local visibleFeatures = {}
local visibleUnits = {}

do
	local GetCameraPosition = Spring.GetCameraPosition
	local GetSmoothMeshHeight = Spring.GetSmoothMeshHeight
	local IsGUIHidden = Spring.IsGUIHidden
	local glDepthMask = gl.DepthMask
	local GetFeatureHealth = Spring.GetFeatureHealth
	local GetFeatureResources = Spring.GetFeatureResources
	local GetUnitViewPosition = Spring.GetUnitViewPosition

	function widget:RecvLuaMsg(msg, playerID)
		if msg:sub(1, 18) == 'LobbyOverlayActive' then
			chobbyInterface = (msg:sub(1, 19) == 'LobbyOverlayActive1')
		end
	end

	function widget:DrawWorld()
		if chobbyInterface then
			return
		end

		if Spring.IsGUIHidden() then
			return
		end

		if #visibleUnits + #visibleFeatures == 0 then
			return
		end

		cx, cy, cz = GetCameraPosition()

		--if the camera is too far up, higher than maxDistance on smoothmesh, dont even call any visibility checks or nothing
		local smoothheight = GetSmoothMeshHeight(cx, cz) --clamps x and z
		if (cy - smoothheight) ^ 2 < maxUnitDistance * drawDistanceMult then

			glDepthTest(true)    -- enabling this will make healthbars opague to other healthbars
			glDepthMask(true)

			if barShader then
				gl.UseShader(barShader)
				glMyText(0)
			end
			local now = os.clock()
			--// draw bars of units
			local unitID, unitDefID
			for i = 1, #visibleUnits do
				unitID = visibleUnits[i]
				unitDefID = GetUnitDefID(unitID)
				if unitDefID then
					local hideHealth = hideHealthbars
					if hideHealthbars and showHealthbarOnSelection and SelectedUnitsCount > 0 and selectedUnits[unitID] ~= nil then
						hideHealth = false
					end
					if hideHealthbars and showHealthbarOnChange and unitHealthChangeTime[unitID] then
						if unitHealthChangeTime[unitID] + healthChangeTimer > now then
							hideHealth = false
						else
							unitHealthChangeTime[unitID] = nil
						end
					end
					if hideHealth and alwaysDrawBarPercentageForComs and isCommander[unitDefID] then
						hideHealth = false
					end

					local ux, uy, uz = GetUnitViewPosition(unitID)
					if ux ~= nil and not ignoreUnits[unitDefID] then
						local dx, dy, dz = ux - cx, uy - cy, uz - cz
						local dist = dx * dx + dy * dy + dz * dz
						if dist < maxUnitDistance * drawDistanceMult then
							DrawUnitInfos(unitID, unitDefID, hideHealth, ux, uy, uz, dist)
						end
					end
				end
			end

			--// draw bars for features
			local drawFeatureInfo = false
			if (cy - smoothheight) ^ 2 < maxFeatureDistance * drawDistanceMult then
				drawFeatureInfo = true
			end
			local wx, wy, wz, dx, dy, dz, dist, featureInfo, resurrect, reclaimLeft

			if drawFeatureInfo or (featureResurrectVisibility or featureReclaimVisibility) then
				for i = 1, #visibleFeatures do
					featureInfo = visibleFeatures[i]
					if not ignoreFeatures[featureInfo[5]] then
						if featureResurrectVisibility then
							resurrect = select(3, GetFeatureHealth(featureInfo[4]))
						end
						if featureReclaimVisibility then
							reclaimLeft = select(5, GetFeatureResources(featureInfo[4]))
						end
						if drawFeatureInfo or (featureResurrectVisibility and resurrect and resurrect > 0) or (featureReclaimVisibility and reclaimLeft and reclaimLeft < 1) then
							wx, wy, wz = featureInfo[1], featureInfo[2], featureInfo[3]
							dx, dy, dz = wx - cx, wy - cy, wz - cz
							dist = dx * dx + dy * dy + dz * dz
							if dist < maxFeatureDistance * drawDistanceMult
							--or (((featureResurrectVisibility and resurrect and resurrect > 0)
							--or (featureReclaimVisibility and reclaimLeft and reclaimLeft < 1)) and dist <= maxUnitDistance * drawDistanceMult)
							then
								DrawFeatureInfos(featureInfo[4], featureInfo[5], wx, wy, wz, dist)
							end
						end
					end
				end
			end

			if barShader then
				gl.UseShader(0)
			end
			glDepthMask(false)
		end

		glColor(1, 1, 1, 1)
		--glDepthTest(false)
	end
end --//end do

do
	local GetGameFrame = Spring.GetGameFrame
	local GetVisibleUnits = Spring.GetVisibleUnits
	local GetVisibleFeatures = Spring.GetVisibleFeatures
	local GetFeatureDefID = Spring.GetFeatureDefID
	local GetFeaturePosition = Spring.GetFeaturePosition
	local GetFeatureResources = Spring.GetFeatureResources
	local select = select

	local sec = 0
	local sec1 = 0
	local sec2 = 0
	local sec3 = 0

	function widget:Update(dt)
		gameFrame = GetGameFrame()

		sec = sec + dt
		blink = (sec % 1) < 0.5

		sec1 = sec1 + dt
		if sec1 > 1 / 4 and (cy - smoothheight) ^ 2 < maxUnitDistance * drawDistanceMult then
			sec1 = 0
			visibleUnits = GetVisibleUnits(-1, nil, false)    -- expensive
		end

		sec3 = sec3 + dt
		if showHealthbarOnChange and sec3 > 0.6 then
			sec3 = 0
			local unitID, health, maxHealth
			local now = os.clock()
			for i = 1, #visibleUnits do
				unitID = visibleUnits[i]
				health, maxHealth = spGetUnitHealth(unitID)
				if not unitHealthLog[unitID] or unitHealthLog[unitID] ~= health then
					if unitHealthLog[unitID] and health then
						if health < unitHealthLog[unitID] or (health > unitHealthLog[unitID] and (health - unitHealthLog[unitID]) / maxHealth > 0.006) then
							-- put it threshold against autorepair
							unitHealthChangeTime[unitID] = now
						end
					end
					unitHealthLog[unitID] = health
				end
			end
		end

		sec2 = sec2 + dt
		if sec2 > 1 / 2 and (cy - smoothheight) ^ 2 < maxFeatureDistance * drawDistanceMult then
			sec2 = 0
			visibleFeatures = GetVisibleFeatures(-1, nil, false, false)
			local cnt = #visibleFeatures
			local featureID, featureDefID

			for i = cnt, 1, -1 do
				featureID = visibleFeatures[i]
				featureDefID = GetFeatureDefID(featureID) or -1
				--// filter trees and none destructable features
				if destructableFeature[featureDefID] and (drawnFeature[featureDefID] or select(5, GetFeatureResources(featureID)) < 1) then
					local fx, fy, fz = GetFeaturePosition(featureID)
					visibleFeatures[i] = { fx, fy, fz, featureID, featureDefID }
				else
					visibleFeatures[i] = visibleFeatures[cnt]
					visibleFeatures[cnt] = nil
					cnt = cnt - 1
				end
			end
		end

	end

end --//end do

function widget:UnitDestroyed(unitID, unitDefID, unitTeam)
	unitHealthChangeTime[unitID] = nil
	unitHealthLog[unitID] = nil
end

function widget:UnitDamaged(unitID, unitDefID, unitTeam, damage, paralyzer)
	if showHealthbarOnChange and not paralyzer then
		unitHealthChangeTime[unitID] = os.clock()
		unitHealthLog[unitID] = select(1, spGetUnitHealth(unitID))
	end
end

function widget:SelectionChanged(sel)
	if showHealthbarOnSelection then
		selectedUnits = {}
		for k, v in pairs(sel) do
			selectedUnits[v] = true
		end
		SelectedUnitsCount = Spring.GetSelectedUnitsCount()
	end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:GetConfigData(data)
	return {
		barScale = barScale,
		drawBarPercentage = drawBarPercentage,
		alwaysDrawBarPercentageForComs = alwaysDrawBarPercentageForComs,
		hideHealthbars = hideHealthbars,
		drawDistanceMult = drawDistanceMult,
		variableBarSizes = variableBarSizes
	}
end

function widget:SetConfigData(data)
	barScale = data.barScale or barScale
	drawBarPercentage = data.drawBarPercentage or drawBarPercentage
	alwaysDrawBarPercentageForComs = data.alwaysDrawBarPercentageForComs or alwaysDrawBarPercentageForComs
	if data.hideHealthbars ~= nil then
		hideHealthbars = data.hideHealthbars
	end
	if data.drawDistanceMult ~= nil then
		drawDistanceMult = data.drawDistanceMult
	end
	if data.variableBarSizes ~= nil then
		variableBarSizes = data.variableBarSizes
	end
end
