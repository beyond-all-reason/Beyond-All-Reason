local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Info",
		desc = "",
		author = "Floris",
		date = "April 2020",
		license = "GNU GPL, v2 or later",
		layer = 1,
		enabled = true
	}
end

local useRenderToTexture = Spring.GetConfigFloat("ui_rendertotexture", 1) == 1		-- much faster than drawing via DisplayLists only
local useRenderToTextureBg = useRenderToTexture

local alwaysShow = false

local width = 0
local height = 0

local zoomMult = 1.5
local defaultCellZoom = 0 * zoomMult
local rightclickCellZoom = 0.065 * zoomMult
local clickCellZoom = 0.065 * zoomMult
local hoverCellZoom = 0.03 * zoomMult
local showBuilderBuildlist = true
local displayMapPosition = false
local activeCmdID

local emptyInfo = false
local showEngineTooltip = false		-- straight up display old engine delivered text

local iconTypes = VFS.Include("gamedata/icontypes.lua")

local fontfile = "fonts/" .. Spring.GetConfigString("bar_font", "Poppins-Regular.otf")
local fontfile2 = "fonts/" .. Spring.GetConfigString("bar_font2", "Exo2-SemiBold.otf")

local vsx, vsy = Spring.GetViewGeometry()

local hoverType, hoverData = '', ''
local sound_button = 'LuaUI/Sounds/buildbar_add.wav'
local sound_button2 = 'LuaUI/Sounds/buildbar_rem.wav'

local ui_scale = tonumber(Spring.GetConfigFloat("ui_scale", 1) or 1)

local backgroundRect = { 0, 0, 0, 0 }
local currentTooltip = ''
local lastUpdateClock = 0
local infoShows = false
local isPregame

local tooltipTitleColor = '\255\205\255\205'
local tooltipTextColor = '\255\255\255\255'
local tooltipLabelTextColor = '\255\200\200\200'
local tooltipDarkTextColor = '\255\133\133\133'
local tooltipValueColor = '\255\255\255\255'
local tooltipValueWhiteColor = '\255\255\255\255'

local selectionHowto = tooltipTextColor .. "Left click" .. tooltipLabelTextColor .. ": Select\n " .. tooltipTextColor .. "   + CTRL" .. tooltipLabelTextColor .. ": Select units of this type on map\n " .. tooltipTextColor .. "   + ALT" .. tooltipLabelTextColor .. ": Select 1 single unit of this unit type\n " .. tooltipTextColor .. "Right click" .. tooltipLabelTextColor .. ": Remove\n " .. tooltipTextColor .. "    + CTRL" .. tooltipLabelTextColor .. ": Remove only 1 unit from that unit type\n " .. tooltipTextColor .. "Middle click" .. tooltipLabelTextColor .. ": Move to center location\n " .. tooltipTextColor .. "    + CTRL" .. tooltipLabelTextColor .. ": Move to center off whole selection"

local anonymousName = '?????'

local dlistGuishader, bgpadding, ViewResizeUpdate, texOffset, displayMode
local loadedFontSize, font, font2, font3, cfgDisplayUnitID, cfgDisplayUnitDefID, rankTextures
local cellRect, cellPadding, cornerSize, cellsize, cellHovered
local gridHeight, selUnitsSorted, selUnitsCounts, selectionCells, customInfoArea, contentPadding
local displayUnitID, displayUnitDefID, doUpdateClock
local contentWidth, dlistInfo, bfcolormap, selUnitTypes

local RectRound, UiElement, UiUnit, elementCorner

local spGetCurrentTooltip = Spring.GetCurrentTooltip
local spGetSelectedUnits = Spring.GetSelectedUnits
local spGetSelectedUnitsCounts = Spring.GetSelectedUnitsCounts
local spGetSelectedUnitsSorted = Spring.GetSelectedUnitsSorted
local spGetSelectedUnitsCount = Spring.GetSelectedUnitsCount
local SelectedUnitsCount = Spring.GetSelectedUnitsCount()
local selectedUnits = Spring.GetSelectedUnits()
local spGetUnitDefID = Spring.GetUnitDefID
local spGetFeatureDefID = Spring.GetFeatureDefID
local spTraceScreenRay = Spring.TraceScreenRay
local spGetMouseState = Spring.GetMouseState
local spGetModKeyState = Spring.GetModKeyState
local spSelectUnitArray = Spring.SelectUnitArray
local spGetTeamUnitsSorted = Spring.GetTeamUnitsSorted
local spSelectUnitMap = Spring.SelectUnitMap
local spGetUnitHealth = Spring.GetUnitHealth
local spGetUnitResources = Spring.GetUnitResources
local spGetUnitExperience = Spring.GetUnitExperience
local spGetUnitWeaponState = Spring.GetUnitWeaponState
local spGetUnitRulesParam = Spring.GetUnitRulesParam
local spColorString = Spring.Utilities.Color.ToString


local math_floor = math.floor
local math_ceil = math.ceil
local math_min = math.min
local math_max = math.max
local math_isInRect = math.isInRect
local string_lines = string.lines

local os_clock = os.clock

local myTeamID = Spring.GetMyTeamID()
local mySpec = Spring.GetSpectatingState()

local GL_QUADS = GL.QUADS
local glTexture = gl.Texture
local glTexRect = gl.TexRect
local glColor = gl.Color
local glBlending = gl.Blending
local GL_SRC_ALPHA = GL.SRC_ALPHA
local GL_ONE_MINUS_SRC_ALPHA = GL.ONE_MINUS_SRC_ALPHA
local GL_ONE = GL.ONE

local hideBuildlist

-- Reverse armor type table
local armorIndex = {}
for ii = 1, #Game.armorTypes do
	armorIndex[Game.armorTypes[ii]] = ii
end

local function round(value, numDecimalPlaces)
	if value then
		return string.format("%0." .. numDecimalPlaces .. "f", math.round(value, numDecimalPlaces))
	else
		return 0
	end
end

local function convertColor(r, g, b)
	return string.char(255, (r * 255), (g * 255), (b * 255))
end

local unitDefInfo = {}
local unitRestricted = {}
local isWaterUnit = {}
local isGeothermalUnit = {}

local function refreshUnitInfo()
	for unitDefID, unitDef in pairs(UnitDefs) do
		unitDefInfo[unitDefID] = {}

		if unitDef.iconType and iconTypes[unitDef.iconType] and iconTypes[unitDef.iconType].bitmap then
			unitDefInfo[unitDefID].icontype = iconTypes[unitDef.iconType].bitmap
		end

		if unitDef.name == 'armdl' or unitDef.name == 'cordl' or unitDef.name == 'armlance' or unitDef.name == 'cortitan'
			or (unitDef.minWaterDepth > 0 or unitDef.modCategories['ship'])  then
			if not (unitDef.modCategories['hover'] or (unitDef.modCategories['mobile'] and unitDef.modCategories['canbeuw'])) then
				isWaterUnit[unitDefID] = true
			end
		end

		if unitDef.needGeo then
			isGeothermalUnit[unitDefID] = true
		end

		if unitDef.maxThisUnit == 0 then
			unitRestricted[unitDefID] = true
		end

		if unitDef.isAirUnit then
			unitDefInfo[unitDefID].airUnit = true
		end

		unitDefInfo[unitDefID].translatedHumanName = unitDef.translatedHumanName
		if unitDef.maxWeaponRange > 16 then
			unitDefInfo[unitDefID].maxWeaponRange = unitDef.maxWeaponRange
		end
		if unitDef.speed > 0 then
			unitDefInfo[unitDefID].speed = round(unitDef.speed, 0)
		end
		if unitDef.rSpeed > 0 then
			unitDefInfo[unitDefID].reverseSpeed = round(unitDef.rSpeed, 0)
		end
		if unitDef.stealth then
			unitDefInfo[unitDefID].stealth = true
		end
		if unitDef.cloakCost and unitDef.canCloak then
			unitDefInfo[unitDefID].cloakCost = unitDef.cloakCost
			if unitDef.cloakCostMoving > unitDef.cloakCost then
				unitDefInfo[unitDefID].cloakCostMoving = unitDef.cloakCostMoving
			end
		end
		if unitDef.isTransport then
			unitDefInfo[unitDefID].transport = { unitDef.transportMass, unitDef.transportSize, unitDef.transportCapacity }
		end
		if unitDef.customParams.paralyzemultiplier then
			unitDefInfo[unitDefID].paralyzeMult = tonumber(unitDef.customParams.paralyzemultiplier)
		end
		unitDefInfo[unitDefID].armorType = Game.armorTypes[unitDef.armorType or 0] or '???'

		if unitDef.sightDistance > 0 then
			unitDefInfo[unitDefID].sightDistance = unitDef.sightDistance
		end
		if unitDef.airSightDistance > 0 then
			unitDefInfo[unitDefID].airSightDistance = unitDef.airSightDistance
		end
		if unitDef.radarDistance > 0 then
			unitDefInfo[unitDefID].radarDistance = unitDef.radarDistance
		end
		if unitDef.sonarDistance > 0 then
			unitDefInfo[unitDefID].sonarDistance = unitDef.sonarDistance
		end
		if unitDef.radarDistanceJam > 0 then
			unitDefInfo[unitDefID].radarDistanceJam = unitDef.radarDistanceJam
		end
		if unitDef.sonarDistanceJam > 0 then
			unitDefInfo[unitDefID].sonarDistanceJam = unitDef.sonarDistanceJam
		end
		if unitDef.seismicDistance > 0 then
			unitDefInfo[unitDefID].seismicDistance = unitDef.seismicDistance
		end

		if unitDef.customParams.energyconv_capacity and unitDef.customParams.energyconv_efficiency then
			unitDefInfo[unitDefID].metalmaker = { tonumber(unitDef.customParams.energyconv_capacity), tonumber(unitDef.customParams.energyconv_efficiency) }
		end

		unitDefInfo[unitDefID].description = unitDef.translatedTooltip
		unitDefInfo[unitDefID].energyCost = unitDef.energyCost
		unitDefInfo[unitDefID].metalCost = unitDef.metalCost
		unitDefInfo[unitDefID].energyStorage = unitDef.energyStorage
		unitDefInfo[unitDefID].metalStorage = unitDef.metalStorage

		unitDefInfo[unitDefID].health = unitDef.health
		unitDefInfo[unitDefID].buildTime = unitDef.buildTime
		unitDefInfo[unitDefID].buildPic = unitDef.buildPic and true or false
		if unitDef.canStockpile then
			unitDefInfo[unitDefID].canStockpile = true
		end
		if unitDef.buildSpeed > 0 then
			unitDefInfo[unitDefID].buildSpeed = unitDef.buildSpeed
		end
		if unitDef.buildOptions[1] then
			unitDefInfo[unitDefID].buildOptions = unitDef.buildOptions
		end
		if unitDef.extractsMetal > 0 then
			unitDefInfo[unitDefID].mex = true
		end
		local weapons = unitDef.weapons


		-----------------------------------------------------
		-- Utility functions for calculating weapon values --
		-----------------------------------------------------

		local function calculateLaserDPS(def, damage)
			minIntensity = math.max(def.minIntensity, 0.5)
			local prevMinDps = unitDefInfo[unitDefID].mindps or 0
			local prevMaxDps = unitDefInfo[unitDefID].maxdps or 0
			local mindps = math_floor(minIntensity*(damage * def.salvoSize / def.reload))
			local maxdps = math_floor(damage * def.salvoSize / def.reload)

			unitDefInfo[unitDefID].mindps = mindps + prevMinDps
			unitDefInfo[unitDefID].maxdps = maxdps + prevMaxDps
			return mindps, maxdps
		end


		local function calculateWeaponDPS(def, damage)
			local prevMinDps = unitDefInfo[unitDefID].mindps or 0
			local prevMaxDps = unitDefInfo[unitDefID].maxdps or 0
			local newDps = math_floor(damage * (def.salvoSize * def.projectiles) / def.reload)
			local stockpileDps = math_floor(damage * (def.salvoSize * def.projectiles) / (def.stockpile and def.stockpileTime/30 or def.reload))
			unitDefInfo[unitDefID].mindps = math_min(newDps, stockpileDps) + prevMinDps
			unitDefInfo[unitDefID].maxdps = math_max(newDps, stockpileDps) + prevMaxDps
		end


		local function calculateClusterDPS(def, damage)
			local prevMinDps = unitDefInfo[unitDefID].mindps or 0
			local prevMaxDps = unitDefInfo[unitDefID].maxdps or 0

			local munition = unitDef.name .. '_' .. def.customParams.cluster_def
			local cmNumber = def.customParams.cluster_number
			local cmDamage = WeaponDefNames[munition].damages[0]

			local mainDps = math_floor((def.salvoSize * def.projectiles) / def.reload * (damage))
			local cmunDps = math_floor((def.salvoSize * def.projectiles) / def.reload * (cmNumber * cmDamage))
			unitDefInfo[unitDefID].mindps = prevMinDps + mainDps
			unitDefInfo[unitDefID].maxdps = prevMaxDps + mainDps + cmunDps
		end


		local function setEnergyAndMetalCosts(def)
			if def.energyCost > 0 and (not unitDefInfo[unitDefID].energyPerShot or def.energyCost > unitDefInfo[unitDefID].energyPerShot) then
				unitDefInfo[unitDefID].energyPerShot = def.energyCost
			end
			if def.metalCost > 0 and (not unitDefInfo[unitDefID].metalPerShot or def.metalCost > unitDefInfo[unitDefID].metalPerShot) then
				unitDefInfo[unitDefID].metalPerShot = def.metalCost
			end
		end

		-----------------------------------------------------


		local unitExempt = false
		for i = 1, #weapons do
			if not unitDefInfo[unitDefID].weapons then
				unitDefInfo[unitDefID].weapons = {}
				unitDefInfo[unitDefID].mindps = 0
				unitDefInfo[unitDefID].maxdps = 0
				unitDefInfo[unitDefID].range = 0
				unitDefInfo[unitDefID].reloadTime = 0
				unitDefInfo[unitDefID].mainWeapon = 1
			end

			unitDefInfo[unitDefID].weapons[i] = weapons[i].weaponDef
			local weaponDef = WeaponDefs[weapons[i].weaponDef]
			if weaponDef.interceptor ~= 0 and weaponDef.coverageRange then
				unitDefInfo[unitDefID].maxCoverage = math.max(unitDefInfo[unitDefID].maxCoverage or 1, weaponDef.coverageRange)
			end
			if weaponDef.damages then
				if unitDef.name == 'armfido' then
					unitExempt = true
					if i==2 then                                --Calculating using second weapon only
						local defDmg = weaponDef.damages[0]      		--Damage to default armor category
						calculateWeaponDPS(weaponDef, defDmg)
					end

				elseif unitDef.name == 'armamb' or unitDef.name == 'cortoast' then -- weapons with low/high traj, this list is incomplete
					unitExempt = true
					if i==1 then                                --Calculating using first weapon only
						calculateWeaponDPS(weaponDef, weaponDef.damages[0]) --Damage to default armor category
					end

				elseif
					unitDef.customParams.evocomlvl  or -- use primary weapon for evolving commanders
					unitDef.name == 'armcom'       or -- ignore underwater secondary
					unitDef.name == 'corcom'       or
					unitDef.name == 'legcom'       or
					unitDef.name == 'corkarg'      or -- ignore secondary weapons, kick
					unitDef.name == 'armguard'     or -- ignore high-trajectory modes
					unitDef.name == 'corpun'       or
					unitDef.name == 'legcluster'   or
					unitDef.name == 'armamb'       or
					unitDef.name == 'cortoast'     or
					unitDef.name == 'armvang'
				then
					unitExempt = true
					if i == 1 then  									--Calculating using first weapon only
						setEnergyAndMetalCosts(weaponDef)

						if weaponDef.type == "BeamLaser" then
							calculateLaserDPS(weaponDef, weaponDef.damages[0])
						elseif weaponDef.customParams.cluster then -- Bullets that shoot other, smaller bullets
							calculateClusterDPS(weaponDef, weaponDef.damages[0])
						elseif weapons[i].onlyTargets['vtol'] ~= nil then
							calculateWeaponDPS(weaponDef, weaponDef.damages[armorIndex.vtol]) --Damage to air category
						else
							calculateWeaponDPS(weaponDef, weaponDef.damages[0]) --Damage to default armor category
						end
					end

				elseif unitDef.name == 'corkorg' then          --excluding korstomp from dps calcuation for juggernaut
					unitExempt = true
					if i==1 then
						local defDmg
						defDmg = weaponDef.damages[0]      		--Damage to default armor category
						calculateWeaponDPS(weaponDef, defDmg)
					end

					if i==2 then
						setEnergyAndMetalCosts(weaponDef)
						calculateLaserDPS(weaponDef, weaponDef.damages[0])
					end

					if i==3 then
						calculateWeaponDPS(weaponDef, weaponDef.damages[0]) --Damage to default armor category
					end

				elseif weaponDef.customParams then
					if weaponDef.customParams.cluster then -- Bullets that explode into other, smaller bullets
						unitExempt = true
						calculateClusterDPS(weaponDef, weaponDef.damages[0])
					elseif weaponDef.customParams.speceffect == "split" then -- Bullets that split into other, smaller bullets
						unitExempt = true
						local splitd = WeaponDefNames[weaponDef.customParams.speceffect_def].damages[0]
						local splitn = weaponDef.customParams.number or 1
						calculateWeaponDPS(weaponDef, splitd * splitn)
					elseif weaponDef.customParams.spark_basedamage then -- Lightning
						unitExempt = true
						local forkd = weaponDef.customParams.spark_forkdamage
						local forkn = weaponDef.customParams.spark_maxunits or 1
						calculateWeaponDPS(weaponDef, weaponDef.damages[0] * (1 + forkd * forkn))
						if unitExempt and weaponDef.paralyzer then -- DPS => EMP
							unitDefInfo[unitDefID].minemp = unitDefInfo[unitDefID].mindps
							unitDefInfo[unitDefID].maxemp = unitDefInfo[unitDefID].maxdps
							unitDefInfo[unitDefID].mindps = nil
							unitDefInfo[unitDefID].maxdps = nil
						end
					end
				end

				if unitDefInfo[unitDefID].mainWeapon == i then
					unitDefInfo[unitDefID].range = weaponDef.range
					unitDefInfo[unitDefID].reloadTime = weaponDef.reload
				end
				if weaponDef.type == "BeamLaser" and not unitExempt then	-- BeamLaser dps calc

					local defDmg

					if weapons[1].onlyTargets['vtol'] ~= nil then	--if main weapon isn't dedicated aa, then all weapons calculate using default armor category
						defDmg = weaponDef.damages[armorIndex.vtol]
					else
						defDmg = weaponDef.damages[0]
					end

					setEnergyAndMetalCosts(weaponDef)

					if weaponDef.paralyzer ~= true then


						if weaponDef.customParams then

							if weaponDef.customParams.sweepfire then
								unitDefInfo[unitDefID].maxdps = (weaponDef.damages[0] * weaponDef.customParams.sweepfire) / math.max(weaponDef.minIntensity, 0.5)
								unitDefInfo[unitDefID].mindps = weaponDef.damages[0] * weaponDef.customParams.sweepfire
							else
								calculateLaserDPS(weaponDef, defDmg)
							end
						else
							calculateLaserDPS(weaponDef, defDmg)
						end
					else
						-- calculate laser emp dmg
						minIntensity = math.max(weaponDef.minIntensity, 0.5)
						local prevMinDps = unitDefInfo[unitDefID].minemp or 0
						local prevMaxDps = unitDefInfo[unitDefID].maxemp or 0
						local mindps = math_floor(minIntensity*(weaponDef.damages[0] * weaponDef.salvoSize / weaponDef.reload))
						local maxdps = math_floor(weaponDef.damages[0] * weaponDef.salvoSize / weaponDef.reload)

						unitDefInfo[unitDefID].minemp = mindps + prevMinDps
						unitDefInfo[unitDefID].maxemp = maxdps + prevMaxDps
					end
				elseif weaponDef.paralyzer == true and unitDef.name ~= 'armthor' then -- exclude thor emp missile
					local defDmg = weaponDef.damages[0]      		--Damage to default armor category
					local emp = math_floor(defDmg * weaponDef.salvoSize / weaponDef.reload)
					unitDefInfo[unitDefID].minemp = emp
					unitDefInfo[unitDefID].maxemp = emp
					unitDefInfo[unitDefID].range = weaponDef.range
					unitDefInfo[unitDefID].reloadTime = weaponDef.reload
				end
				if weaponDef.type ~= "BeamLaser" and weaponDef.paralyzer ~= true and not unitExempt then

					local defDmg

					if weapons[1].onlyTargets['vtol'] ~= nil then	--if main weapon isn't dedicated aa, then all weapons calculate using default armor category
						defDmg = weaponDef.damages[armorIndex.vtol]
					else
						defDmg = weaponDef.damages[0]
					end

					if(defDmg > 0) then
						calculateWeaponDPS(weaponDef, defDmg)
						setEnergyAndMetalCosts(weaponDef)
					end
				end
			end
			if weapons[i].onlyTargets['vtol'] ~= nil then
				unitDefInfo[unitDefID].isAaUnit = true
			end

			--shield params
			if weaponDef.shieldRadius and weaponDef.shieldRadius > 0 then
				if #weapons <= 1 then
					unitDefInfo[unitDefID].weapons = {}
					unitDefInfo[unitDefID].mindps = 0
					unitDefInfo[unitDefID].maxdps = 0
					unitDefInfo[unitDefID].range = 0
					unitDefInfo[unitDefID].reloadTime = 0
					unitDefInfo[unitDefID].mainWeapon = 1
					unitDefInfo[unitDefID].shieldOnly = true
				end
				unitDefInfo[unitDefID].shieldRange = weaponDef.shieldRadius
				unitDefInfo[unitDefID].shieldCapacity = weaponDef.shieldPower
				unitDefInfo[unitDefID].shieldRechargeRate = weaponDef.shieldPowerRegen
				unitDefInfo[unitDefID].shieldRechargeCost = weaponDef.shieldPowerRegenEnergy
			end
		end

		if unitDef.customParams.unitgroup and unitDef.customParams.unitgroup == 'explo' and unitDef.deathExplosion and WeaponDefNames[unitDef.deathExplosion] then
			local weapon = WeaponDefs[WeaponDefNames[unitDef.deathExplosion].id]
			if weapon then
				local dmg = weapon.damages[Game.armorTypes["default"]]
				unitDefInfo[unitDefID].mindps = dmg
				unitDefInfo[unitDefID].maxdps = dmg
				unitDefInfo[unitDefID].reloadTime = nil
			end
		end
	end
end

local groups, unitGroup = {}, {}	-- retrieves from buildmenu in initialize
local unitOrder = {}	-- retrieves from buildmenu in initialize

local unitDisabled = {}
local minWaterUnitDepth = -11
local showWaterUnits = false
local _, _, mapMinWater, _ = Spring.GetGroundExtremes()
if mapMinWater <= minWaterUnitDepth then
	showWaterUnits = true
end
-- make them a disabled unit (instead of removing it entirely)
if not showWaterUnits then
	for unitDefID,_ in pairs(isWaterUnit) do
		unitDisabled[unitDefID] = true
	end
end

local showGeothermalUnits = false
local function checkGeothermalFeatures()
	showGeothermalUnits = false
	local geoThermalFeatures = {}
	for defID, def in pairs(FeatureDefs) do
		if def.geoThermal then
			geoThermalFeatures[defID] = true
		end
	end
	local features = Spring.GetAllFeatures()
	for i = 1, #features do
		if geoThermalFeatures[Spring.GetFeatureDefID(features[i])] then
			showGeothermalUnits = true
			break
		end
	end
	-- make them a disabled unit (instead of removing it entirely)
	for unitDefID,_ in pairs(isGeothermalUnit) do
		if not showGeothermalUnits then
			unitDisabled[unitDefID] = true
		else
			if not isWaterUnit[unitDefID] or showWaterUnits then
				unitDisabled[unitDefID] = nil
			end
		end
	end
end

local function checkGuishader(force)
	if WG['guishader'] then
		if force and dlistGuishader then
			dlistGuishader = gl.DeleteList(dlistGuishader)
		end
		if not dlistGuishader then
			dlistGuishader = gl.CreateList(function()
				RectRound(backgroundRect[1], backgroundRect[2], backgroundRect[3], backgroundRect[4], elementCorner, 0, 1, 0, 0)
			end)
			WG['guishader'].InsertDlist(dlistGuishader, 'info')
		end
	elseif dlistGuishader then
		dlistGuishader = gl.DeleteList(dlistGuishader)
	end
end

function widget:PlayerChanged(playerID)
	myTeamID = Spring.GetMyTeamID()
	mySpec = Spring.GetSpectatingState()
end

function widget:ViewResize()
	ViewResizeUpdate = true

	vsx, vsy = Spring.GetViewGeometry()

	width = 0.2125
	height = 0.14 * ui_scale
	width = width / (vsx / vsy) * 1.78        -- make smaller for ultrawide screens
	width = width * ui_scale
	-- make pixel aligned
	height = math_floor(height * vsy) / vsy
	width = math_floor(width * vsx) / vsx

	bgpadding = WG.FlowUI.elementPadding
	elementCorner = WG.FlowUI.elementCorner

	RectRound = WG.FlowUI.Draw.RectRound
	UiElement = WG.FlowUI.Draw.Element
	UiUnit = WG.FlowUI.Draw.Unit

	backgroundRect = { 0, 0, width * vsx, height * vsy }

	doUpdate = true
	if dlistInfo then
		dlistInfo = gl.DeleteList(dlistInfo)
	end
	if infoBgTex then
		gl.DeleteTextureFBO(infoBgTex)
		infoBgTex = nil
	end
	if infoTex then
		gl.DeleteTextureFBO(infoTex)
		infoTex = nil
	end

	checkGuishader(true)

	local outlineMult = math.clamp(1/(vsy/1400), 1, 1.6)
	font, loadedFontSize = WG['fonts'].getFont(nil, 1.25, 0.22 * outlineMult, 1.7+(outlineMult*0.25))
	font2 = WG['fonts'].getFont(fontfile2, 1.25, 0.22 * outlineMult, 1.7+(outlineMult*0.25))
	font3 = WG['fonts'].getFont(fontfile2, 1.25, 0.22 * outlineMult, 1.7+(outlineMult*0.25))
end

function GetColor(colormap, slider)
	local coln = #colormap
	if slider >= 1 then
		local col = colormap[coln]
		return col[1], col[2], col[3], col[4]
	end
	if slider < 0 then
		slider = 0
	elseif slider > 1 then
		slider = 1
	end
	local posn = 1 + (coln - 1) * slider
	local iposn = math_floor(posn)
	local aa = posn - iposn
	local ia = 1 - aa

	local col1, col2 = colormap[iposn], colormap[iposn + 1]

	return col1[1] * ia + col2[1] * aa, col1[2] * ia + col2[2] * aa,
	col1[3] * ia + col2[3] * aa, col1[4] * ia + col2[4] * aa
end

function widget:GameFrame()
	isPregame = false
	if checkGeothermalFeatures then
		checkGeothermalFeatures()
		checkGeothermalFeatures = nil
		widgetHandler:RemoveCallIn("GameFrame")
	end
end

function widget:Initialize()
	isPregame = Spring.GetGameFrame() < 1

	refreshUnitInfo()

	checkGeothermalFeatures()

	widget:ViewResize()

	WG['info'] = {}
	WG['info'].getShowBuilderBuildlist = function()
		return showBuilderBuildlist
	end
	WG['info'].setShowBuilderBuildlist = function(value)
		showBuilderBuildlist = value
	end
	WG['info'].getDisplayMapPosition = function()
		return displayMapPosition
	end
	WG['info'].setDisplayMapPosition = function(value)
		displayMapPosition = value
	end
	WG['info'].getAlwaysShow = function()
		return alwaysShow
	end
	WG['info'].setAlwaysShow = function(value)
		alwaysShow = value
	end
	WG['info'].displayUnitID = function(unitID)
		cfgDisplayUnitID = unitID
	end
	WG['info'].clearDisplayUnitID = function()
		cfgDisplayUnitID = nil
	end
	WG['info'].displayUnitDefID = function(unitDefID)
		cfgDisplayUnitDefID = unitDefID
	end
	WG['info'].clearDisplayUnitDefID = function()
		cfgDisplayUnitDefID = nil
	end
	WG['info'].getPosition = function()
		return width, height
	end
	WG['info'].getIsShowing = function()
		return infoShows
	end
	if WG['buildmenu'] then
		if WG['buildmenu'].getGroups then
			groups, unitGroup = WG['buildmenu'].getGroups()
		end
		if WG['buildmenu'].getOrder then
			unitOrder = WG['buildmenu'].getOrder()

			-- order buildoptions
			for uDefID, def in pairs(unitDefInfo) do
				if def.buildOptions then
					local temp = {}
					for i, udid in pairs(def.buildOptions) do
						temp[udid] = i
					end
					local newBuildOptions = {}
					local newBuildOptionsCount = 0
					for k, orderUDefID in pairs(unitOrder) do
						if temp[orderUDefID] then
							newBuildOptionsCount = newBuildOptionsCount + 1
							newBuildOptions[newBuildOptionsCount] = orderUDefID
						end
					end
					unitDefInfo[uDefID].buildOptions = newBuildOptions
				end
			end
		end
	end

	Spring.SetDrawSelectionInfo(false)    -- disables springs default display of selected units count
	Spring.SendCommands("tooltip 0")

	if WG['rankicons'] then
		rankTextures = WG['rankicons'].getRankTextures()
	end

	bfcolormap = {}
	local hpcolormap = { { 1, 0.0, 0.0, 1 }, { 0.8, 0.60, 0.0, 1 }, { 0.0, 0.75, 0.0, 1 } }
	for hp = 0, 100 do
		bfcolormap[hp] = { GetColor(hpcolormap, hp * 0.01) }
	end
end

function widget:Shutdown()
	Spring.SetDrawSelectionInfo(true) --disables springs default display of selected units count
	Spring.SendCommands("tooltip 1")
	if dlistInfo then
		dlistInfo = gl.DeleteList(dlistInfo)
	end
	if infoBgTex then
		gl.DeleteTextureFBO(infoBgTex)
	end
	if infoTex then
		gl.DeleteTextureFBO(infoTex)
	end
	if WG['guishader'] and dlistGuishader then
		WG['guishader'].DeleteDlist('info')
		dlistGuishader = nil
	end
end

local sec2 = 0
local sec = 0
local lastCameraPanMode = false
function widget:Update(dt)
	infoShows = false
	local x, y, b, b2, b3, mouseOffScreen, cameraPanMode = spGetMouseState()
	if lastCameraPanMode ~= cameraPanMode then
		lastCameraPanMode = cameraPanMode
		checkChanges()
		doUpdate = true
	end
	if not alwaysShow and ((cameraPanMode and not doUpdate) or mouseOffScreen) and not isPregame then
		if SelectedUnitsCount == 0 then
			if dlistGuishader then
				WG['guishader'].DeleteDlist('info')
				dlistGuishader = nil
			end
		end
		return
	end

	sec2 = sec2 + dt
	if sec2 > 0.5 then
		sec2 = 0

		if not rankTextures and WG['rankicons'] then
			rankTextures = WG['rankicons'].getRankTextures()
		end

		local _, _, mapMinWater, _ = Spring.GetGroundExtremes()
		if mapMinWater <= minWaterUnitDepth then
			if not showWaterUnits then
				showWaterUnits = true

				for unitDefID,_ in pairs(isWaterUnit) do
					if not isGeothermalUnit[unitDefID] or showGeothermalUnits then	-- make sure geothermal units keep being disabled if that should be the case
						unitDisabled[unitDefID] = nil
					end
				end
			end
		end
	end

	sec = sec + dt
	if sec > 0.035 then
		sec = 0
		checkChanges()
		if alwaysShow or not emptyInfo then
			checkGuishader()
		end
	end


	if ViewResizeUpdate then
		ViewResizeUpdate = nil
	end

	if doUpdate or (doUpdateClock and os_clock() >= doUpdateClock) or (os_clock() >= doUpdateClock2) then
		doUpdateClock = nil
		doUpdateClock2 = os_clock() + 0.9
		if useRenderToTexture then
			updateTex = true
		else
			if dlistInfo then
				dlistInfo = gl.DeleteList(dlistInfo)
			end
		end
		doUpdate = nil
		lastUpdateClock = os_clock()
	end

	if displayUnitID and not Spring.ValidUnitID(displayUnitID) then
		displayMode = 'text'
		displayUnitID = nil
		displayUnitDefID = nil
	end

	if (not alwaysShow and (cameraPanMode or mouseOffScreen) and SelectedUnitsCount == 0 and not isPregame) then
		return
	end

	if alwaysShow or not emptyInfo or (isPregame and not mySpec) then
		infoShows = true
	end
end

local function DrawRectRoundCircle(x, y, z, radius, cs, centerOffset, color1, color2)
	if not color2 then
		color2 = color1
	end
	--centerOffset = 0
	local coords = {
		{ x - radius + cs, z + radius, y }, -- top left
		{ x + radius - cs, z + radius, y }, -- top right
		{ x + radius, z + radius - cs, y }, -- right top
		{ x + radius, z - radius + cs, y }, -- right bottom
		{ x + radius - cs, z - radius, y }, -- bottom right
		{ x - radius + cs, z - radius, y }, -- bottom left
		{ x - radius, z - radius + cs, y }, -- left bottom
		{ x - radius, z + radius - cs, y }, -- left top
	}
	local cs2 = cs * (centerOffset / radius)
	local coords2 = {
		{ x - centerOffset + cs2, z + centerOffset, y }, -- top left
		{ x + centerOffset - cs2, z + centerOffset, y }, -- top right
		{ x + centerOffset, z + centerOffset - cs2, y }, -- right top
		{ x + centerOffset, z - centerOffset + cs2, y }, -- right bottom
		{ x + centerOffset - cs2, z - centerOffset, y }, -- bottom right
		{ x - centerOffset + cs2, z - centerOffset, y }, -- bottom left
		{ x - centerOffset, z - centerOffset + cs2, y }, -- left bottom
		{ x - centerOffset, z + centerOffset - cs2, y }, -- left top
	}
	for i = 1, 8 do
		local i2 = (i >= 8 and 1 or i + 1)
		gl.Color(color2)
		gl.Vertex(coords[i][1], coords[i][2], coords[i][3])
		gl.Vertex(coords[i2][1], coords[i2][2], coords[i2][3])
		gl.Color(color1)
		gl.Vertex(coords2[i2][1], coords2[i2][2], coords2[i2][3])
		gl.Vertex(coords2[i][1], coords2[i][2], coords2[i][3])
	end
end
local function RectRoundCircle(x, y, z, radius, cs, centerOffset, color1, color2)
	gl.BeginEnd(GL_QUADS, DrawRectRoundCircle, x, y, z, radius, cs, centerOffset, color1, color2)
end

local function drawSelectionCell(cellID, uDefID, usedZoom, highlightColor)
	if not usedZoom then
		usedZoom = defaultCellZoom
	end

	glColor(1,1,1,1)
	UiUnit(
		cellRect[cellID][1] + cellPadding, cellRect[cellID][2] + cellPadding, cellRect[cellID][3], cellRect[cellID][4],
		cornerSize,
		1,1,1,1,
		usedZoom,
		nil, nil,
		"#" .. uDefID,
		nil,
		groups[unitGroup[uDefID]]
	)

	-- unit count
	local fontSize = math_min(gridHeight * 0.17, cellsize * 0.6) * (1 - ((1 + string.len(selUnitsCounts[uDefID])) * 0.066))
	if selUnitsCounts[uDefID] > 1 then
		--font3:Begin()
		font3:Print('\255\233\233\233'..selUnitsCounts[uDefID], cellRect[cellID][3] - cellPadding - (fontSize * 0.09), cellRect[cellID][2] + (fontSize * 0.3), fontSize, "ro")
		--font3:End()
	end

	-- kill count
	local kills = 0
	for i, unitID in ipairs(selUnitsSorted[uDefID]) do
		local unitKills = spGetUnitRulesParam(unitID, "kills")
		if unitKills then
			kills = kills + unitKills
		end
	end
	if kills > 0 then
		local size = math_floor((cellRect[cellID][3] - (cellRect[cellID][1] + (cellPadding*0.5)))*0.33)
		glColor(0.88,0.88,0.88,useRenderToTexture and 0.87 or 0.66)
		glTexture(":l:LuaUI/Images/skull.dds")
		glTexRect(cellRect[cellID][3] - size+(cellPadding*0.5), cellRect[cellID][4]-size-(cellPadding*0.5), cellRect[cellID][3]+(cellPadding*0.5), cellRect[cellID][4]-(cellPadding*0.5))
		glTexture(false)
		--font3:Begin()
		font3:Print('\255\233\233\233'..kills, cellRect[cellID][3] - (size * 0.5)+(cellPadding*0.5), cellRect[cellID][4] -(cellPadding*0.5)- (size * 0.5) - (fontSize * 0.19), fontSize * 0.66, "oc")
		--font3:End()
	end
end

local function drawSelection()
	selUnitsCounts = spGetSelectedUnitsCounts()
	selUnitsSorted = spGetSelectedUnitsSorted()
	selUnitTypes = 0
	selectionCells = {}

	for k, uDefID in pairs(unitOrder) do
		if selUnitsSorted[uDefID] then
			if type(selUnitsSorted[uDefID]) == 'table' then
				selUnitTypes = selUnitTypes + 1
				selectionCells[selUnitTypes] = uDefID
			end
		end
	end

	-- draw selection totals
	local numLines
	--local stats = getSelectionTotals(selectionCells)
	local fontSize = (height * vsy * 0.115) * (0.95 - ((1 - ui_scale) * 0.5))
	local height = 0
	local heightStep = (fontSize * 1.36)
	font2:Begin()
	font2:Print(tooltipTextColor .. #selectedUnits .. tooltipLabelTextColor .. "  "..Spring.I18N('ui.info.unitsselected'), backgroundRect[1] + contentPadding, backgroundRect[4] - contentPadding - (fontSize * 1.2) - height, (fontSize * 1.23), "o")
	font2:End()
	font:Begin()
	height = height + (fontSize * 0.85)

	-- loop all unitdefs/cells (but not individual unitID's)
	local totalMetalValue = 0
	local totalEnergyValue = 0
	for _, unitDefID in pairs(selectionCells) do
		-- metal cost
		if unitDefInfo[unitDefID].metalCost then
			totalMetalValue = totalMetalValue + (unitDefInfo[unitDefID].metalCost * selUnitsCounts[unitDefID])
		end
		-- energy cost
		if unitDefInfo[unitDefID].energyCost then
			totalEnergyValue = totalEnergyValue + (unitDefInfo[unitDefID].energyCost * selUnitsCounts[unitDefID])
		end
	end

	-- loop all unitID's
	local totalMaxHealthValue = 0
	local totalMetalMake, totalMetalUse, totalEnergyMake, totalEnergyUse = 0, 0, 0, 0
	local totalKills = 0
	for _, unitID in pairs(cellHovered and selUnitsSorted[selectionCells[cellHovered]] or selectedUnits) do
		local metalMake, metalUse, energyMake, energyUse = spGetUnitResources(unitID)
		if metalMake then
			totalMetalMake = totalMetalMake + metalMake
			totalMetalUse = totalMetalUse + metalUse
			totalEnergyMake = totalEnergyMake + energyMake
			totalEnergyUse = totalEnergyUse + energyUse
		end
		local kills = spGetUnitRulesParam(unitID, "kills")
		if kills then
			totalKills = totalKills + kills
		end
	end

	local valuePlusColor = '\255\180\255\180'
	local valueMinColor = '\255\255\180\180'
	if totalMetalUse > 0 or totalMetalMake > 0 then
		height = height + heightStep
		font:Print( tooltipLabelTextColor .. Spring.I18N('ui.info.m').."   " .. (totalMetalMake > 0 and valuePlusColor .. '+' .. (totalMetalMake < 10 and round(totalMetalMake, 1) or round(totalMetalMake, 0)) .. '  ' or '') .. (totalMetalUse > 0 and valueMinColor .. '-' .. (totalMetalUse < 10 and round(totalMetalUse, 1) or round(totalMetalUse, 0)) or ''), backgroundRect[1] + contentPadding, backgroundRect[4] - (bgpadding*2.4) - (fontSize * 0.8) - height, fontSize, "o")
	end
	if totalEnergyUse > 0 or totalEnergyMake > 0 then
		height = height + heightStep
		font:Print( tooltipLabelTextColor .. Spring.I18N('ui.info.e').."   " .. (totalEnergyMake > 0 and valuePlusColor .. '+' .. (totalEnergyMake < 10 and round(totalEnergyMake, 1) or round(totalEnergyMake, 0)) .. '  ' or '') .. (totalEnergyUse > 0 and valueMinColor .. '-' .. (totalEnergyUse < 10 and round(totalEnergyUse, 1) or round(totalEnergyUse, 0)) or ''), backgroundRect[1] + contentPadding, backgroundRect[4] - (bgpadding*2.4) - (fontSize * 0.8) - height, fontSize, "o")
	end

	-- metal cost
	height = height + heightStep
	font:Print( tooltipLabelTextColor .. Spring.I18N('ui.info.costm').."   " .. tooltipValueWhiteColor .. totalMetalValue, backgroundRect[1] + contentPadding, backgroundRect[4] - (bgpadding*2.4) - (fontSize * 0.8) - height, fontSize, "o")

	-- energy cost
	height = height + heightStep
	font:Print( tooltipLabelTextColor .. Spring.I18N('ui.info.coste').."\255\255\255\128   " .. totalEnergyValue, backgroundRect[1] + contentPadding, backgroundRect[4] - (bgpadding*2.4) - (fontSize * 0.8) - height, fontSize, "o")

	-- kills
	if totalKills > 0 then
		height = height + heightStep
		font:Print( tooltipLabelTextColor .. Spring.I18N('ui.info.kills').."   " .. tooltipValueColor .. totalKills, backgroundRect[1] + contentPadding, backgroundRect[4] - (bgpadding*2.4) - (fontSize * 0.8) - height, fontSize, "o")
	end
	font:End()

	-- selected units grid area
	local gridWidth = math_floor((backgroundRect[3] - backgroundRect[1] - bgpadding) * 0.6)  -- leaving some room for the totals
	gridHeight = math_floor((backgroundRect[4] - backgroundRect[2]) - bgpadding)
	customInfoArea = { backgroundRect[3] - gridWidth, backgroundRect[2], backgroundRect[3] - bgpadding, backgroundRect[2] + gridHeight }

	-- draw selected unit icons
	local rows = 2
	local maxRows = 15  -- just to be sure
	local colls = math_ceil(selUnitTypes / rows)
	cellsize = math_floor(math_min(gridWidth / colls, gridHeight / rows))
	while cellsize < gridHeight / (rows + 1) do
		rows = rows + 1
		colls = math_ceil(selUnitTypes / rows)
		cellsize = math_min(gridWidth / colls, gridHeight / rows)
		if rows > maxRows then
			break
		end
	end

	-- adjust grid size to add some padding at the top and right side
	cellsize = math_floor((cellsize * (1 - (0.04 / rows))) + 0.5)  -- leave some space at the top
	cellPadding = math_max(1, math_floor(cellsize * 0.03))
	customInfoArea[3] = customInfoArea[3] - cellPadding -- leave space at the right side

	-- draw grid (bottom right to top left)
	cellRect = {}
	texOffset = (0.03 * rows) * zoomMult
	cornerSize = math_max(1, cellPadding * 0.9)
	if texOffset > 0.25 then
		texOffset = 0.25
	end
	local cellID = selUnitTypes
	for row = 1, rows do
		for coll = 1, colls do
			if selectionCells[cellID] then
				--local uDefID = selectionCells[cellID]
				cellRect[cellID] = { math_ceil(customInfoArea[3] - cellPadding - (coll * cellsize)), math_ceil(customInfoArea[2] + cellPadding + ((row - 1) * cellsize)), math_ceil(customInfoArea[3] - cellPadding - ((coll - 1) * cellsize)), math_ceil(customInfoArea[2] + cellPadding + ((row) * cellsize)) }
				drawSelectionCell(cellID, selectionCells[cellID], texOffset)
			end
			cellID = cellID - 1
			if cellID <= 0 then
				break
			end
		end
		if cellID <= 0 then
			break
		end
	end
	glTexture(false)
	glColor(1, 1, 1, 1)
end

local function GetAIName(teamID)
	local _, _, _, name, _, options = Spring.GetAIInfo(teamID)
	local niceName = Spring.GetGameRulesParam('ainame_' .. teamID)
	if niceName then
		name = niceName
		--if Spring.Utilities.ShowDevUI() and options.profile then
		--	name = name .. " [" .. options.profile .. "]"
		--end
	end
	return Spring.I18N('ui.playersList.aiName', { name = name })
end

local function drawUnitInfo()
	local fontSize = (height * vsy * 0.123) * (0.94 - ((1 - math.max(1.05, ui_scale)) * 0.4))

	local iconSize = math.floor(fontSize * 4.4)
	local iconPadding = math.floor(fontSize * 0.22)

	if unitDefInfo[displayUnitDefID].buildPic then
		local iconX = backgroundRect[1] + iconPadding
		local iconY =  backgroundRect[4] - iconPadding - bgpadding
		-- unit icon
		glColor(1,1,1,1)
		UiUnit(
			iconX, iconY - iconSize, iconX + iconSize, iconY,
			nil,
			1, 1, 1, 1,
			0.03,
			nil, nil,
			"#" .. displayUnitDefID,
			(unitDefInfo[displayUnitDefID].icontype and ':l:' .. unitDefInfo[displayUnitDefID].icontype or nil),
			groups[unitGroup[displayUnitDefID]],
			{unitDefInfo[displayUnitDefID].metalCost, unitDefInfo[displayUnitDefID].energyCost}
		)
		-- price
		local function AddSpaces(price)
			if price >= 1000 then
				return string.format("%s %03d", AddSpaces(math_floor(price / 1000)), price % 1000)
			end
			return price
		end
		local halfSize = iconSize * 0.5
		local padding = (halfSize + halfSize) * 0.045
		local size = (halfSize + halfSize) * 0.18
		local metalPriceText = "\255\245\245\245" .. AddSpaces(unitDefInfo[displayUnitDefID].metalCost)
		local energyPriceText = "\n\255\255\255\000" .. AddSpaces(unitDefInfo[displayUnitDefID].energyCost)
		local energyPriceTextHeight = font3:GetTextHeight(energyPriceText) * size

		font3:Begin()
		font3:Print(metalPriceText, iconX + iconSize - padding, iconY - halfSize - halfSize + padding + (size * 1.07) + energyPriceTextHeight, size, "ro")
		font3:Print(energyPriceText, iconX + iconSize - padding, iconY - halfSize - halfSize + padding + (size * 1.07), size, "ro")
		font3:End()
	end
	iconSize = iconSize + iconPadding

	local mindps, maxdps, minemp, maxemp, range, metalExtraction, stockpile, maxRange, exp, metalMake, metalUse, energyMake, energyUse
	local text, unitDescriptionLines = font:WrapText(unitDefInfo[displayUnitDefID].description, (contentWidth - iconSize) * (loadedFontSize / fontSize))

	if displayUnitID then
		exp = spGetUnitExperience(displayUnitID)
		if exp and exp > 0.009 and WG['rankicons'] and rankTextures then
			if displayUnitID then
				local rank = WG['rankicons'].getRank(displayUnitDefID, exp)
				if rankTextures[rank] then
					local rankIconSize = math_floor((height * vsy * 0.24) + 0.5)
					local rankIconMarginX = math_floor((height * vsy * 0.015) + 0.5)
					local rankIconMarginY = math_floor((height * vsy * 0.18) + 0.5)
					glColor(1, 1, 1, 0.88)
					glTexture(':lr' .. (rankIconSize * 2) .. ',' .. (rankIconSize * 2) .. ':' .. rankTextures[rank])
					glTexRect(backgroundRect[3] - rankIconMarginX - rankIconSize, backgroundRect[4] - rankIconMarginY - rankIconSize, backgroundRect[3] - rankIconMarginX, backgroundRect[4] - rankIconMarginY)
					glTexture(false)
					glColor(1, 1, 1, 1)
				end
			end
		end
		local kills = spGetUnitRulesParam(displayUnitID, "kills")
		if kills then
			local rankIconSize = math_floor((height * vsy * 0.16))
			local rankIconMarginY = math_floor((height * vsy * 0.07) + 0.5)
			local rankIconMarginX = math_floor((height * vsy * 0.053) + 0.5)
			glColor(0.7,0.7,0.7,useRenderToTexture and 0.81 or 0.55)
			glTexture(":l:LuaUI/Images/skull.dds")
			glTexRect(backgroundRect[3] - rankIconMarginX - rankIconSize, backgroundRect[4] - rankIconMarginY - rankIconSize, backgroundRect[3] - rankIconMarginX, backgroundRect[4] - rankIconMarginY)
			glTexture(false)
			font2:Begin()
			font2:Print('\255\215\215\215'..kills, backgroundRect[3] - rankIconMarginX - (rankIconSize * 0.5), backgroundRect[4] - (rankIconMarginY * 2.05) - (fontSize * 0.31), fontSize * 0.87, "oc")
			font2:End()
		end
	end

	local unitNameColor = tooltipTitleColor
	if SelectedUnitsCount > 0 then
		if displayMode ~= 'unitdef' or (WG['buildmenu'] and (activeCmdID and activeCmdID < 0 and (not WG['buildmenu'].hoverID or (-activeCmdID == WG['buildmenu'].hoverID)))) then
			unitNameColor = '\255\125\255\125'
		end
	end
	local descriptionColor = '\255\240\240\240'
	local metalColor = '\255\245\245\245'
	local energyColor = '\255\255\255\000'
	local healthColor = '\255\100\255\100'

	local labelColor = useRenderToTexture and '\255\212\212\212' or '\255\205\205\205'
	local valueColor = '\255\255\255\255'
	local valuePlusColor = '\255\180\255\180'
	local valueMinColor = '\255\255\180\180'

	-- custom unit info background
	local width = contentWidth * 0.82
	local height = (backgroundRect[4] - backgroundRect[2]) * (unitDescriptionLines > 1 and 0.495 or 0.6)

	-- unit tooltip
	font:Begin()
	font:Print(descriptionColor .. text, backgroundRect[3] - width + bgpadding, backgroundRect[4] - contentPadding - (fontSize * 2.17), fontSize * 0.94, "o")
	font:End()

	-- unit name
	local nameFontSize = fontSize * 1.12
	local humanName = unitDefInfo[displayUnitDefID].translatedHumanName
	humanName = string.gsub(humanName, 'Scavenger', 'Scav')
	if font:GetTextWidth(humanName) * nameFontSize > width*1.05 then
		while font:GetTextWidth(humanName) * nameFontSize > width do
			humanName = string.sub(humanName, 1, string.len(humanName)-1)
		end
		humanName = humanName..'...'
	end
	font2:Begin()
	font2:Print(unitNameColor .. humanName, backgroundRect[3] - width + bgpadding, backgroundRect[4] - contentPadding - (nameFontSize * 0.76), nameFontSize, "o")
	--font2:End()

	-- custom unit info area
	customInfoArea = { math_floor(backgroundRect[3] - width - bgpadding), math_floor(backgroundRect[2]), math_floor(backgroundRect[3] - bgpadding), math_floor(backgroundRect[2] + height) }

	if displayMode ~= 'unitdef' or not showBuilderBuildlist or not unitDefInfo[displayUnitDefID].buildOptions or (not (WG['buildmenu'] and WG['buildmenu'].hoverID)) then
		RectRound(customInfoArea[1], customInfoArea[2], customInfoArea[3], customInfoArea[4], elementCorner*0.66, 1, 0, 0, 0, { 0.8, 0.8, 0.8, useRenderToTexture and 0.48 or 0.1 }, { 0.8, 0.8, 0.8, useRenderToTexture and 0.55 or 0.15 })
	end

	local contentPaddingLeft = contentPadding * 0.6
	local texSize = fontSize * 0.6

	local leftSideHeight = (backgroundRect[4] - backgroundRect[2]) * 0.47
	local posY1 = math_floor(backgroundRect[2] + leftSideHeight) - contentPadding - ((math_floor(backgroundRect[2] + leftSideHeight) - math_floor(backgroundRect[2])) * 0.1)
	local posY2 = math_floor(backgroundRect[2] + leftSideHeight) - contentPadding - ((math_floor(backgroundRect[2] + leftSideHeight) - math_floor(backgroundRect[2])) * 0.38)
	local posY3 = math_floor(backgroundRect[2] + leftSideHeight) - contentPadding - ((math_floor(backgroundRect[2] + leftSideHeight) - math_floor(backgroundRect[2])) * 0.67)

	local valueY1, valueY2, valueY3 = '', '', ''
	local health, maxHealth, _, _, buildProgress
	if displayUnitID then
		local metalMake, metalUse, energyMake, energyUse = spGetUnitResources(displayUnitID)
		if metalMake then
			valueY1 = (metalMake > 0 and valuePlusColor .. '+' .. (metalMake < 10 and round(metalMake, 1) or round(metalMake, 0)) .. ' ' or '') .. (metalUse > 0 and valueMinColor .. '-' .. (metalUse < 10 and round(metalUse, 1) or round(metalUse, 0)) or '')
			valueY2 = (energyMake > 0 and valuePlusColor .. '+' .. (energyMake < 10 and round(energyMake, 1) or round(energyMake, 0)) .. ' ' or '') .. (energyUse > 0 and valueMinColor .. '-' .. (energyUse < 10 and round(energyUse, 1) or round(energyUse, 0)) or '')
			valueY3 = ''
		end

		-- display health value/bar
		health, maxHealth = spGetUnitHealth(displayUnitID)
		if health then
			local color = bfcolormap[math.clamp(math_floor((health / maxHealth) * 100), 0, 100)]
			valueY3 = convertColor(color[1], color[2], color[3]) .. math_floor(health)
		end

		-- display unit owner name
		local teamID = Spring.GetUnitTeam(displayUnitID)
		if mySpec or (myTeamID ~= teamID) then
			local _, playerID, _, isAiTeam = Spring.GetTeamInfo(teamID, false)
			local name = Spring.GetPlayerInfo(playerID, false)
			if isAiTeam then
				name = GetAIName(teamID)
			end
			if not mySpec and Spring.GetModOptions().teamcolors_anonymous_mode ~= 'disabled' then
				name = anonymousName
			end
			if name then
				local fontSizeOwner = fontSize * 0.87
				--if not mySpec and Spring.GetModOptions().teamcolors_anonymous_mode ~= 'disabled' then
				--	name = ColourString(Spring.GetConfigInt("anonymousColorR", 255)/255, Spring.GetConfigInt("anonymousColorG", 0)/255, Spring.GetConfigInt("anonymousColorB", 0)/255) .. name
				--else
				name = spColorString(Spring.GetTeamColor(teamID)) .. name
				--end
				font2:Print(name, backgroundRect[3] - bgpadding - bgpadding, backgroundRect[2] + (fontSizeOwner * 0.44), fontSizeOwner, "or")
			end
		end
	else
		valueY1 = metalColor .. unitDefInfo[displayUnitDefID].metalCost
		valueY2 = energyColor .. unitDefInfo[displayUnitDefID].energyCost
		valueY3 = healthColor .. unitDefInfo[displayUnitDefID].health
	end

	glColor(1, 1, 1, 1)
	local texDetailSize = math_floor(texSize * 4)
	if valueY1 ~= '' then
		glTexture(":lr" .. texDetailSize .. "," .. texDetailSize .. ":LuaUI/Images/metal.png")
		glTexRect(backgroundRect[1] + contentPaddingLeft - (texSize * 0.6), posY1 - texSize, backgroundRect[1] + contentPaddingLeft + (texSize * 1.4), posY1 + texSize)
	end
	if valueY2 ~= '' then
		glTexture(":lr" .. texDetailSize .. "," .. texDetailSize .. ":LuaUI/Images/energy.png")
		glTexRect(backgroundRect[1] + contentPaddingLeft - (texSize * 0.6), posY2 - texSize, backgroundRect[1] + contentPaddingLeft + (texSize * 1.4), posY2 + texSize)
	end
	if valueY3 ~= '' then
		glTexture(":lr" .. texDetailSize .. "," .. texDetailSize .. ":LuaUI/Images/info_health.png")
		glTexRect(backgroundRect[1] + contentPaddingLeft - (texSize * 0.6), posY3 - texSize, backgroundRect[1] + contentPaddingLeft + (texSize * 1.4), posY3 + texSize)
	end
	glTexture(false)

	-- metal
	local fontSize2 = fontSize * 0.87
	local contentPaddingLeft = contentPaddingLeft + texSize + (contentPadding * 0.5)
	font2:Print(valueY1, backgroundRect[1] + contentPaddingLeft, posY1 - (fontSize2 * 0.31), fontSize2, "o")
	-- energy
	font2:Print(valueY2, backgroundRect[1] + contentPaddingLeft, posY2 - (fontSize2 * 0.31), fontSize2, "o")
	-- health
	font2:Print(valueY3, backgroundRect[1] + contentPaddingLeft, posY3 - (fontSize2 * 0.31), fontSize2, "o")
	font2:End()

	cellRect = nil

	-- draw unit buildoption icons
	if displayMode == 'unitdef' and showBuilderBuildlist and unitDefInfo[displayUnitDefID].buildOptions and not hideBuildlist then
		gridHeight = math_ceil(height * 0.975)
		local rows = 2
		local colls = math_ceil(#unitDefInfo[displayUnitDefID].buildOptions / rows)
		cellsize = math_floor((math_min(width / colls, gridHeight / rows)) + 0.5)
		if cellsize < gridHeight / 3 then
			rows = 3
			colls = math_ceil(#unitDefInfo[displayUnitDefID].buildOptions / rows)
			cellsize = math_floor((math_min(width / colls, gridHeight / rows)) + 0.5)
		end

		-- draw grid (bottom right to top left)
		local cellID = #unitDefInfo[displayUnitDefID].buildOptions
		cellPadding = math_floor((cellsize * 0.022) + 0.5)
		cellRect = {}
		for row = 1, rows do
			for coll = 1, colls do
				if unitDefInfo[displayUnitDefID].buildOptions[cellID] then
					local uDefID = unitDefInfo[displayUnitDefID].buildOptions[cellID]
					cellRect[cellID] = { math_floor(customInfoArea[3] - cellPadding - (coll * cellsize)), math_floor(customInfoArea[2] + cellPadding + ((row - 1) * cellsize)), math_floor(customInfoArea[3] - cellPadding - ((coll - 1) * cellsize)), math_floor(customInfoArea[2] + cellPadding + ((row) * cellsize)) }
					local disabled = (unitRestricted[uDefID] or unitDisabled[uDefID])
					if disabled then
						glColor(0.4, 0.4, 0.4, 1)
					else
						glColor(1,1,1,1)
					end
					UiUnit(
						cellRect[cellID][1] + cellPadding, cellRect[cellID][2] + cellPadding, cellRect[cellID][3], cellRect[cellID][4],
						cellPadding * 1.3,
						1, 1, 1, 1,
						0.1,
						nil, disabled and 0 or nil,
						"#"..uDefID,
						(unitDefInfo[uDefID].icontype and ':l:' .. unitDefInfo[uDefID].icontype or nil),
						groups[unitGroup[uDefID]],
						{unitDefInfo[uDefID].metalCost, unitDefInfo[uDefID].energyCost}
					)
				end
				cellID = cellID - 1
				if cellID <= 0 then
					break
				end
			end
			if cellID <= 0 then
				break
			end
		end
		glTexture(false)
		glColor(1, 1, 1, 1)


		-- draw transported unit list
	elseif displayMode == 'unit' and unitDefInfo[displayUnitDefID].transport and (Spring.GetUnitIsTransporting(displayUnitID) and #Spring.GetUnitIsTransporting(displayUnitID) or 0) > 0 then
		local units = Spring.GetUnitIsTransporting(displayUnitID)
		if #units > 0 then
			gridHeight = math_ceil(height * 0.975)
			local rows = 2
			local colls = math_ceil(#units / rows)
			cellsize = math_floor((math_min(width / colls, gridHeight / rows)) + 0.5)
			if cellsize < gridHeight / 3 then
				rows = 3
				colls = math_ceil(#units / rows)
				cellsize = math_floor((math_min(width / colls, gridHeight / rows)) + 0.5)
			end

			-- draw grid (bottom right to top left)
			local cellID = #units
			cellPadding = math_floor((cellsize * 0.022) + 0.5)
			cornerSize = math_max(1, cellPadding * 0.9)
			cellRect = {}
			for row = 1, rows do
				for coll = 1, colls do
					if units[cellID] then
						local uDefID = spGetUnitDefID(units[cellID])
						cellRect[cellID] = { math_floor(customInfoArea[3] - cellPadding - (coll * cellsize)), math_floor(customInfoArea[2] + cellPadding + ((row - 1) * cellsize)), math_floor(customInfoArea[3] - cellPadding - ((coll - 1) * cellsize)), math_floor(customInfoArea[2] + cellPadding + ((row) * cellsize)) }
						UiUnit(
							cellRect[cellID][1] + cellPadding, cellRect[cellID][2] + cellPadding, cellRect[cellID][3], cellRect[cellID][4],
							cellPadding * 1.3,
							1, 1, 1, 1,
							0.1,
							nil, nil,
							"#"..uDefID,
							(unitDefInfo[uDefID].icontype and ':l:' .. unitDefInfo[uDefID].icontype or nil),
							groups[unitGroup[uDefID]],
							{unitDefInfo[uDefID].metalCost, unitDefInfo[uDefID].energyCost}
						)
					end
					cellID = cellID - 1
					if cellID <= 0 then
						break
					end
				end
				if cellID <= 0 then
					break
				end
			end
			glTexture(false)
			glColor(1, 1, 1, 1)
		end
	else
		-- unit/unitdef info (without buildoptions)


		contentPadding = contentPadding * 0.95
		local contentPaddingLeft = customInfoArea[1] + contentPadding

		local text = ''
		local separator = ''
		local infoFontsize = fontSize * 0.89
		-- to determine what to show in what order
		local function addTextInfo(label, value)
			text = text .. labelColor .. separator .. string.upper(label:sub(1, 1)) .. label:sub(2)  .. valueColor .. (value and (label ~= '' and ' ' or '')..value or '')
			separator = ',   '
		end


		-- unit specific info
		if unitDefInfo[displayUnitDefID].mindps then
			mindps = unitDefInfo[displayUnitDefID].mindps
		end
		if unitDefInfo[displayUnitDefID].maxdps then
			maxdps = unitDefInfo[displayUnitDefID].maxdps
		end
		if unitDefInfo[displayUnitDefID].minemp then
			minemp = unitDefInfo[displayUnitDefID].minemp
		end
		if unitDefInfo[displayUnitDefID].maxemp then
			maxemp = unitDefInfo[displayUnitDefID].maxemp
		end
		if unitDefInfo[displayUnitDefID].range then
			range = unitDefInfo[displayUnitDefID].range
		end

		-- get unit specific data
		if displayMode == 'unit' then
			-- get lots of unit info from functions: https://springrts.com/wiki/Lua_SyncedRead
			if unitDefInfo[displayUnitDefID].mainWeapon ~= nil then
				maxRange = Spring.GetUnitWeaponState(displayUnitID, unitDefInfo[displayUnitDefID].mainWeapon, "range")
			else
				maxRange = range
			end
			if not exp then
				exp = spGetUnitExperience(displayUnitID)
			end

		else
			-- get unitdef specific data
			if unitDefInfo[displayUnitDefID].maxWeaponRange then
				maxRange = range
			end
		end

		if unitDefInfo[displayUnitDefID].weapons then
			local reloadTimeSpeedup = 1.0
			local currentReloadTime = unitDefInfo[displayUnitDefID].reloadTime
			if exp and exp > 0.009 then
				addTextInfo(Spring.I18N('ui.info.xp'), round(exp, 2))
				addTextInfo(Spring.I18N('ui.info.maxhealth'), '+' .. round((maxHealth / unitDefInfo[displayUnitDefID].health - 1) * 100, 0) .. '%')
				currentReloadTime = spGetUnitWeaponState(displayUnitID, unitDefInfo[displayUnitDefID].mainWeapon, 'reloadTimeXP')
				if unitDefInfo[displayUnitDefID].reloadTime then
					reloadTimeSpeedup = currentReloadTime / unitDefInfo[displayUnitDefID].reloadTime
					local reloadTimeSpeedupPercentage = tonumber(round((1 - reloadTimeSpeedup) * 100, 0))
					if reloadTimeSpeedupPercentage > 0 then
						addTextInfo(Spring.I18N('ui.info.reload'), '-' .. reloadTimeSpeedupPercentage .. '%')
					end
				end
			end

			-- basic dps display
			if mindps and mindps > 0 and mindps == maxdps then
				local dps = round(mindps/ reloadTimeSpeedup, 0)
				addTextInfo(Spring.I18N('ui.info.dps'), dps)

			-- dps range
			elseif mindps and mindps > 0 and mindps ~= maxdps then
				local min = round(mindps/ reloadTimeSpeedup, 0)
				local max = round(maxdps/ reloadTimeSpeedup, 0)
				addTextInfo("DPS", min.."-"..max)
			end

			-- emp dps display
			if minemp and minemp > 0 and minemp == maxemp then

				local emp = round(minemp/ reloadTimeSpeedup, 0)
				addTextInfo("DPS(EMP)", emp)

			-- more emp dps
			elseif minemp and minemp and minemp ~= maxemp then
				local min = round(minemp/ reloadTimeSpeedup, 0)
				local max = round(maxemp/ reloadTimeSpeedup, 0)
				addTextInfo("DPS(EMP)", min.."-"..max)
			end

			if unitDefInfo[displayUnitDefID].maxCoverage then
				addTextInfo(Spring.I18N('ui.info.coverrange'), unitDefInfo[displayUnitDefID].maxCoverage)
			elseif maxRange and not unitDefInfo[displayUnitDefID].shieldOnly then
				addTextInfo(Spring.I18N('ui.info.weaponrange'), math_floor(maxRange))
			end
			if currentReloadTime and currentReloadTime > 0 then
				addTextInfo(Spring.I18N('ui.info.reloadtime'), round(currentReloadTime, 2))
			end

			if unitDefInfo[displayUnitDefID].energyPerShot then
				addTextInfo(Spring.I18N('ui.info.energyshot'), unitDefInfo[displayUnitDefID].energyPerShot)
			end
			if unitDefInfo[displayUnitDefID].metalPerShot then
				addTextInfo(Spring.I18N('ui.info.metalshot'), unitDefInfo[displayUnitDefID].metalPerShot)
			end
		end
		-- shield display
		if unitDefInfo[displayUnitDefID].shieldCapacity then
			addTextInfo(Spring.I18N('ui.info.shieldcapacity'), unitDefInfo[displayUnitDefID].shieldCapacity)
			addTextInfo(Spring.I18N('ui.info.shieldrange'), unitDefInfo[displayUnitDefID].shieldRange)
			addTextInfo(Spring.I18N('ui.info.shieldrechargerate'), unitDefInfo[displayUnitDefID].shieldRechargeRate)
			addTextInfo(Spring.I18N('ui.info.shieldrechargecost'), unitDefInfo[displayUnitDefID].shieldRechargeCost)
		end

		if unitDefInfo[displayUnitDefID].stealth then
			addTextInfo(Spring.I18N('ui.info.stealthy'), nil)
		end

		if unitDefInfo[displayUnitDefID].cloakCost then
			if unitDefInfo[displayUnitDefID].cloakCostMoving then
				addTextInfo(Spring.I18N('ui.info.cloakcost'), unitDefInfo[displayUnitDefID].cloakCost .. "/" .. unitDefInfo[displayUnitDefID].cloakCostMoving)
			else
				addTextInfo(Spring.I18N('ui.info.cloakcost'), unitDefInfo[displayUnitDefID].cloakCost)
			end
		end

		if unitDefInfo[displayUnitDefID].speed then
			addTextInfo(Spring.I18N('ui.info.speed'), unitDefInfo[displayUnitDefID].speed)
		end
		if unitDefInfo[displayUnitDefID].reverseSpeed then
			addTextInfo(Spring.I18N('ui.info.reversespeed'), unitDefInfo[displayUnitDefID].reverseSpeed)
		end

		if unitDefInfo[displayUnitDefID].buildSpeed then
			addTextInfo(Spring.I18N('ui.info.buildpower'), unitDefInfo[displayUnitDefID].buildSpeed)
		end

		--if unitDefInfo[displayUnitDefID].armorType and unitDefInfo[displayUnitDefID].armorType ~= 'standard' then
		--	addTextInfo('armor', unitDefInfo[displayUnitDefID].armorType)
		--end

		if unitDefInfo[displayUnitDefID].sightDistance then
			addTextInfo(Spring.I18N('ui.info.los'), round(unitDefInfo[displayUnitDefID].sightDistance, 0))
		end
		if unitDefInfo[displayUnitDefID].airSightDistance and (unitDefInfo[displayUnitDefID].airUnit or unitDefInfo[displayUnitDefID].isAaUnit) then

			addTextInfo(Spring.I18N('ui.info.airlos'), round(unitDefInfo[displayUnitDefID].airSightDistance, 0))
		end
		if unitDefInfo[displayUnitDefID].radarDistance then
			addTextInfo(Spring.I18N('ui.info.radar'), round(unitDefInfo[displayUnitDefID].radarDistance, 0))
		end
		if unitDefInfo[displayUnitDefID].sonarDistance then
			addTextInfo(Spring.I18N('ui.info.sonar'), round(unitDefInfo[displayUnitDefID].sonarDistance, 0))
		end
		if unitDefInfo[displayUnitDefID].radarDistanceJam then
			addTextInfo(Spring.I18N('ui.info.jamrange'), round(unitDefInfo[displayUnitDefID].radarDistanceJam, 0))
		end
		if unitDefInfo[displayUnitDefID].sonarDistanceJam then
			addTextInfo(Spring.I18N('ui.info.sonarjamrange'), round(unitDefInfo[displayUnitDefID].sonarDistanceJam, 0))
		end
		if unitDefInfo[displayUnitDefID].seismicDistance then
			addTextInfo(Spring.I18N('ui.info.seismic'), unitDefInfo[displayUnitDefID].seismicDistance)
		end
		--addTextInfo('mass', round(Spring.GetUnitMass(displayUnitID),0))
		--addTextInfo('radius', round(Spring.GetUnitRadius(displayUnitID),0))
		--addTextInfo('height', round(Spring.GetUnitHeight(displayUnitID),0))

		if unitDefInfo[displayUnitDefID].metalmaker then
			addTextInfo(Spring.I18N('ui.info.eneededforconversion'), unitDefInfo[displayUnitDefID].metalmaker[1])
			addTextInfo(Spring.I18N('ui.info.convertedm'), round(unitDefInfo[displayUnitDefID].metalmaker[1] / (1 / unitDefInfo[displayUnitDefID].metalmaker[2]), 1))
		end
		if unitDefInfo[displayUnitDefID].energyStorage > 0 then
			addTextInfo(Spring.I18N('ui.info.estorage'), unitDefInfo[displayUnitDefID].energyStorage)
		end
		if unitDefInfo[displayUnitDefID].metalStorage > 0 then
			addTextInfo(Spring.I18N('ui.info.mstorage'), unitDefInfo[displayUnitDefID].metalStorage)
		end

		if unitDefInfo[displayUnitDefID].transport then

			if unitDefInfo[displayUnitDefID].transport[1] < 5001 then
				addTextInfo(Spring.I18N('ui.info.transport_light', { highlightColor = valueColor }), nil)
			end
			if unitDefInfo[displayUnitDefID].transport[1] > 5000 then
				addTextInfo(Spring.I18N('ui.info.transport_heavy', { highlightColor = valueColor }), nil)
			end
			addTextInfo(Spring.I18N('ui.info.transportcapacity'), unitDefInfo[displayUnitDefID].transport[3])
		end

		local text, _ = font:WrapText(text, ((backgroundRect[3] - bgpadding - bgpadding - bgpadding) - (backgroundRect[1] + contentPaddingLeft)) * (loadedFontSize / infoFontsize))

		-- prune number of lines
		local lines = string_lines(text)
		text = ''
		for i, line in pairs(lines) do
			text = text .. line
			-- only 4 fully fit, but showing 5, so the top part of text shows and indicates there is more to see somehow
			if i == 5 then
				break
			end
			text = text .. '\n'
		end
		lines = nil

		-- display unit(def) info text
		font:Begin()
		font:SetTextColor(1, 1, 1, 1)
		font:SetOutlineColor(0.1, 0.1, 0.1, 1)
		font:Print(text, customInfoArea[3] - width + (width*0.025), customInfoArea[4] - contentPadding - (infoFontsize * 0.55), infoFontsize, "o")
		font:End()

	end
end

local function drawEngineTooltip()
	local mouseX, mouseY, lmb, mmb, rmb, mouseOffScreen, cameraPanMode = spGetMouseState()
	if not cameraPanMode and not mouseOffScreen then
		local fontSize = (height * vsy * 0.11) * (0.95 - ((1 - ui_scale) * 0.5))
		if showEngineTooltip then
			-- display default plaintext engine tooltip
			local text, numLines = font:WrapText(currentTooltip, contentWidth * (loadedFontSize / fontSize))
			font:Begin()
			font:SetTextColor(1, 1, 1, 1)
			font:SetOutlineColor(0.1, 0.1, 0.1, 1)
			font:Print(text, backgroundRect[1] + contentPadding, backgroundRect[4] - contentPadding - (fontSize * 0.8), fontSize, "o")
			font:End()
		else
			local heightStep = (fontSize * 1.4)
			hoverType, hoverData = spTraceScreenRay(mouseX, mouseY)
			if hoverType == 'ground' then
				local desc, coords = spTraceScreenRay(mouseX, mouseY, true)
				local groundType1, groundType2, metal, hardness, tankSpeed, botSpeed, hoverSpeed, shipSpeed, receiveTracks = Spring.GetGroundInfo(coords[1], coords[3])
				local text = ''
				local height = 0
				font:Begin()
				font:SetTextColor(1, 1, 1, 1)
				font:SetOutlineColor(0.1, 0.1, 0.1, 1)
				if displayMapPosition then
					font:Print(tooltipValueColor..math.floor(hoverData[1])..',', backgroundRect[1] + contentPadding, backgroundRect[4] - contentPadding - (fontSize * 0.8) - height, fontSize, "o")
					font:Print(math.floor(hoverData[3]), backgroundRect[1] + contentPadding + (fontSize * 3.2), backgroundRect[4] - contentPadding - (fontSize * 0.8) - height, fontSize, "o")
					font:Print(tooltipLabelTextColor..Spring.I18N('ui.info.elevation')..'  '..tooltipValueColor..math.floor(Spring.GetGroundHeight(coords[1], coords[3])), backgroundRect[1] + contentPadding + (fontSize * 6.6), backgroundRect[4] - contentPadding - (fontSize * 0.8) - height, fontSize, "o")
					height = height + heightStep
				end
				if tankSpeed ~= 1 or botSpeed ~= 1 or hoverSpeed ~= 1 or (shipSpeed ~= 1 and coords[2] <= 0) then
					text = ''
					if tankSpeed ~= 1 then
						text = text..(text~='' and '   ' or '')..tooltipLabelTextColor..Spring.I18N('ui.info.tank')..' '..tooltipValueColor..math.floor(tankSpeed*100).."%"
					end
					if botSpeed ~= 1 then
						text = text..(text~='' and '   ' or '')..tooltipLabelTextColor..Spring.I18N('ui.info.bot')..' '..tooltipValueColor..math.floor(botSpeed*100).."%"
					end
					if hoverSpeed ~= 1 then
						text = text..(text~='' and '   ' or '')..tooltipLabelTextColor..Spring.I18N('ui.info.hover')..' '..tooltipValueColor..math.floor(hoverSpeed*100).."%"
					end
					if shipSpeed ~= 1 and coords[2] <= 0 then
						text = text..(text~='' and '   ' or '')..tooltipLabelTextColor..Spring.I18N('ui.info.ship')..' '..tooltipValueColor..math.floor(shipSpeed*100).."%"
					end
					if groundType2 and groundType2 ~= '' then
						font2:Begin()
						font2:Print(tooltipLabelTextColor..groundType2, backgroundRect[1] + contentPadding, backgroundRect[4] - contentPadding - (fontSize * 1) - height, (fontSize * 1.2), "o")
						font2:End()
						height = height + (fontSize * 0.25)
						height = height + heightStep
					end
					font:Print(tooltipDarkTextColor..Spring.I18N('ui.info.speedmultipliers')..'   '..text, backgroundRect[1] + contentPadding, backgroundRect[4] - contentPadding - (fontSize * 0.8) - height, fontSize, "o")
				elseif not displayMapPosition then
					emptyInfo = true
				end
				--if metal > 0 then
				--	height = height + heightStep
				--	font:Print(tooltipLabelTextColor..Spring.I18N('ui.info.metal')..' '..tooltipValueColor..math.floor(metal), backgroundRect[1] + contentPadding, backgroundRect[4] - contentPadding - (fontSize * 0.8) - height, fontSize, "o")
				--end
				--if hardness ~= 1 then
				--	height = height + heightStep
				--	font:Print(tooltipLabelTextColor..Spring.I18N('ui.info.hardness')..' '..tooltipValueColor..math.floor(hardness), backgroundRect[1] + contentPadding, backgroundRect[4] - contentPadding - (fontSize * 0.8) - height, fontSize, "o")
				--end
				font:End()
			elseif hoverType == 'feature' then
				local featureDefID = Spring.GetFeatureDefID(hoverData)
				local text = FeatureDefs[featureDefID].tooltip
				local height = 0
				if text == '' then
					text = FeatureDefs[featureDefID].translatedDescription
				end
				if text and text ~= '' then
					font2:Begin()
					font2:Print(tooltipTitleColor..text, backgroundRect[1] + contentPadding, backgroundRect[4] - contentPadding - (fontSize * 1.2) - height, (fontSize * 1.4), "o")
					font2:End()
					height = height + (fontSize * 0.5)
				end
				font:Begin()
				font:SetTextColor(1, 1, 1, 1)
				font:SetOutlineColor(0.1, 0.1, 0.1, 1)
				text = ''
				local metal, _, energy, _ = Spring.GetFeatureResources(hoverData)
				if energy > 0 then
					height = height + heightStep
					text = tooltipLabelTextColor..Spring.I18N('ui.info.energy').."  \255\255\255\000"..math.floor(energy)
					font:Print(text, backgroundRect[1] + contentPadding, backgroundRect[4] - contentPadding - (fontSize * 0.8) - height, fontSize, "o")
				end
				if metal > 0 then
					height = height + heightStep
					text = tooltipLabelTextColor..Spring.I18N('ui.info.metal').."  "..tooltipValueColor..math.floor(metal)
					font:Print(text, backgroundRect[1] + contentPadding, backgroundRect[4] - contentPadding - (fontSize * 0.8) - height, fontSize, "o")
				end
				font:End()
			else
				emptyInfo = true
			end
		end
	else
		if cameraPanMode and #selectedUnits > 0 then
			checkChanges()
		else
			emptyInfo = true
		end
	end
end

local function drawInfoBackground()
	UiElement(backgroundRect[1], backgroundRect[2], backgroundRect[3], backgroundRect[4], 0, 1, 0, 0, nil, nil, nil, nil, nil, nil, nil, nil, useRenderToTextureBg)
end

local function drawInfo()
	emptyInfo = false

	contentPadding = (height * vsy * 0.075) * (0.95 - ((1 - ui_scale) * 0.5))
	contentWidth = backgroundRect[3] - backgroundRect[1] - contentPadding - contentPadding

	if displayMode == 'selection' then
		drawSelection()
	elseif displayMode ~= 'text' and displayUnitDefID then
		drawUnitInfo()
	else
		drawEngineTooltip()
	end
end

local function LeftMouseButton(unitDefID, unitTable)
	local alt, ctrl, meta, shift = spGetModKeyState()
	local acted = false
	if not ctrl then
		-- select units of icon type
		if alt or meta then
			acted = true
			spSelectUnitArray({ unitTable[1] })  -- only 1
		else
			acted = true
			spSelectUnitArray(unitTable)
		end
	else
		-- select all units of the icon type
		local sorted = spGetTeamUnitsSorted(myTeamID)
		local units = sorted[unitDefID]
		if units then
			acted = true
			spSelectUnitArray(units, shift)
		end
	end
	selectedUnits = spGetSelectedUnits()
	SelectedUnitsCount = spGetSelectedUnitsCount()
	if acted then
		Spring.PlaySoundFile(sound_button, 0.5, 'ui')
	end
end

local function MiddleMouseButton(unitDefID, unitTable)
	local alt, ctrl, meta, shift = spGetModKeyState()
	if ctrl then
		-- center the view on the entire selection
		Spring.SendCommands({ "viewselection" })
	else
		-- center the view on this type on unit
		spSelectUnitArray(unitTable)
		Spring.SendCommands({ "viewselection" })
		spSelectUnitArray(selectedUnits)
	end
	selectedUnits = spGetSelectedUnits()
	SelectedUnitsCount = spGetSelectedUnitsCount()
	Spring.PlaySoundFile(sound_button, 0.5, 'ui')
end

local function RightMouseButton(unitDefID, unitTable)
	local alt, ctrl, meta, shift = spGetModKeyState()

	-- remove selected units of icon type
	local map = {}
	for i = 1, #selectedUnits do
		map[selectedUnits[i]] = true
	end
	for _, uid in ipairs(unitTable) do
		map[uid] = nil
		if ctrl then
			break -- only remove 1 unit
		end
	end
	spSelectUnitMap(map)
	selectedUnits = spGetSelectedUnits()
	SelectedUnitsCount = spGetSelectedUnitsCount()
	Spring.PlaySoundFile(sound_button2, 0.5, 'ui')
end

function widget:MousePress(x, y, button)
	if Spring.IsGUIHidden() then
		return
	end
	if infoShows and math_isInRect(x, y, backgroundRect[1], backgroundRect[2], backgroundRect[3], backgroundRect[4]) then
		return true
	end
end

-- makes sure it gets unloaded at a free spot
local mapSizeX, mapSizeZ = Game.mapSizeX, Game.mapSizeZ
local function unloadTransport(transportID, unitID, x, z, shift, depth)
	if not depth then
		depth = 1
	end
	local radius = 20 * depth
	local orgX, orgZ = x, z
	local y = Spring.GetGroundHeight(x, z)
	local unitSphereRadius = 60	-- too low value will result in unload conflicts
	local areaUnits = Spring.GetUnitsInSphere(x, y, z, unitSphereRadius)
	if #areaUnits == 0 then	-- unblocked spot!
		Spring.GiveOrderToUnit(transportID, CMD.UNLOAD_UNIT, { x, y, z, unitID }, {shift and "shift"})
	else
		-- unload is blocked by unit at ground just lets find free alternative spot in a radius around it
		local samples = 8
		local sideAngle = (math.pi * 2) / samples
		local foundUnloadSpot = false
		for i = 1, samples + 1 do
			x = x + (radius * math.cos(i * sideAngle))
			z = z + (radius * math.sin(i * sideAngle))
			if x > 0 and z > 0 and x < mapSizeX and z < mapSizeZ then
				y = Spring.GetGroundHeight(x, z)
				areaUnits = Spring.GetUnitsInSphere(x, y, z, unitSphereRadius)
				if #areaUnits == 0 then	-- unblocked spot!
					local areaFeatures = Spring.GetFeaturesInSphere(x, y, z, unitSphereRadius)
					if #areaFeatures == 0 then
						Spring.GiveOrderToUnit(transportID, CMD.UNLOAD_UNIT, { x, y, z, unitID }, {shift and "shift"})
						foundUnloadSpot = true
						break
					end
				end
			end
		end
		-- try again with increased radius
		if not foundUnloadSpot and depth < 15 then	-- limit depth for safety
			unloadTransport(transportID, unitID, orgX, orgZ, shift, depth+1)
		end
	end
end


function widget:MouseRelease(x, y, button)
	if Spring.IsGUIHidden() then
		return
	end

	if displayMode and customInfoArea and math_isInRect(x, y, customInfoArea[1], customInfoArea[2], customInfoArea[3], customInfoArea[4]) then

		-- selection
		if displayMode == 'selection' and selectionCells and selectionCells[1] and cellRect then
			for cellID, unitDefID in pairs(selectionCells) do
				if cellRect[cellID] and math_isInRect(x, y, cellRect[cellID][1], cellRect[cellID][2], cellRect[cellID][3], cellRect[cellID][4]) then
					local unitTable = nil
					local index = 0
					for udid, uTable in pairs(selUnitsSorted) do
						if udid == unitDefID then
							unitTable = uTable
							break
						end
						index = index + 1
					end
					if unitTable == nil then
						return -1
					end

					if button == 1 then
						LeftMouseButton(unitDefID, unitTable)
					elseif button == 2 then
						MiddleMouseButton(unitDefID, unitTable)
					elseif button == 3 then
						RightMouseButton(unitDefID, unitTable)
					end
					return -1
				end
			end
		end

		-- transported unit list
		if displayMode == 'unit' and button == 1 then
			local units = Spring.GetUnitIsTransporting(displayUnitID)
			if units and #units > 0 then
				for cellID, unitID in pairs(units) do
					if cellRect[cellID] and math_isInRect(x, y, cellRect[cellID][1], cellRect[cellID][2], cellRect[cellID][3], cellRect[cellID][4]) then
						local x,y,z = Spring.GetUnitPosition(displayUnitID)
						local alt, ctrl, meta, shift = spGetModKeyState()
						if shift then
							local cmdQueue = Spring.GetUnitCommands(displayUnitID, 35) or {}
							if cmdQueue[1] then
								if cmdQueue[#cmdQueue] and cmdQueue[#cmdQueue].id == CMD.MOVE and cmdQueue[#cmdQueue].params[3] then
									x, z = cmdQueue[#cmdQueue].params[1], cmdQueue[#cmdQueue].params[3]
									-- remove the last move command (to replace it with the unload cmd after)
									Spring.GiveOrderToUnit(displayUnitID, CMD.STOP, {}, 0)
									for c = 1, #cmdQueue do
										if c < #cmdQueue then
											Spring.GiveOrderToUnit(displayUnitID, cmdQueue[c].id, cmdQueue[c].params, { "shift" })
										end
									end
								end
							end
						end
						unloadTransport(displayUnitID, unitID, math_floor(x), math_floor(z), shift)
						return -1
					end
				end
			end
		end
	end
	return -1
end


function widget:DrawScreen()
	local x, y, b, b2, b3, mouseOffScreen, cameraPanMode = spGetMouseState()

	if (not alwaysShow and (cameraPanMode or mouseOffScreen) and SelectedUnitsCount == 0 and not isPregame) then
		if dlistGuishader then
			WG['guishader'].DeleteDlist('info')
			dlistGuishader = nil
		end
		return
	end

	if useRenderToTextureBg then
		if not infoBgTex then
			infoBgTex = gl.CreateTexture(math_floor(width*vsx), math_floor(height*vsy), {
				target = GL.TEXTURE_2D,
				format = GL.RGBA,
				fbo = true,
			})
			gl.RenderToTexture(infoBgTex, function()
				gl.Clear(GL.COLOR_BUFFER_BIT, 0, 0, 0, 0)
				gl.PushMatrix()
				gl.Translate(-1, -1, 0)
				gl.Scale(2 / (width*vsx), 2 / (height*vsy),	0)
				drawInfoBackground()
				gl.PopMatrix()
			end)
		end
	end
	if useRenderToTexture then
		if not infoTex then
			infoTex = gl.CreateTexture(math_floor(width*vsx)*(vsy<1400 and 2 or 1), math_floor(height*vsy)*(vsy<1400 and 2 or 1), {
				target = GL.TEXTURE_2D,
				format = GL.RGBA,
				fbo = true,
			})
		end
		if infoTex and updateTex then
			updateTex = nil
			gl.RenderToTexture(infoTex, function()
				gl.Clear(GL.COLOR_BUFFER_BIT, 0, 0, 0, 0)
				gl.PushMatrix()
				gl.Translate(-1, -1, 0)
				gl.Scale(2 / (width*vsx), 2 / (height*vsy),	0)
				drawInfo()
				gl.PopMatrix()
			end)
		end
	else
		if not dlistInfo then
			dlistInfo = gl.CreateList(function()
				if not useRenderToTexture then
					if not useRenderToTextureBg then
						drawInfoBackground()
					end
					drawInfo()
				end
			end)
		end
	end

	if alwaysShow or not emptyInfo or (isPregame and (not mySpec or displayMapPosition)) then
		if useRenderToTextureBg and infoBgTex then
			-- background element
			gl.Color(1,1,1,Spring.GetConfigFloat("ui_opacity", 0.7)*1.1)
			gl.Texture(infoBgTex)
			gl.TexRect(backgroundRect[1], backgroundRect[2], backgroundRect[3], backgroundRect[4], false, true)
		end
		if useRenderToTexture and infoTex then
			-- content
			gl.Color(1,1,1,1)
			gl.Texture(infoTex)
			gl.TexRect(backgroundRect[1], backgroundRect[2], backgroundRect[3], backgroundRect[4], false, true)
			gl.Texture(false)
		end
		if dlistInfo then
			gl.CallList(dlistInfo)
		end
	elseif dlistGuishader then
		WG['guishader'].DeleteDlist('info')
		dlistGuishader = nil
	end

	-- widget hovered
	if infoShows and math_isInRect(x, y, backgroundRect[1], backgroundRect[2], backgroundRect[3], backgroundRect[4]) then

		Spring.SetMouseCursor('cursornormal')

		-- selection grid
		if displayMode == 'selection' and selectionCells and selectionCells[1] and cellRect then

			for cellID, unitDefID in pairs(selectionCells) do
				if cellRect[cellID] and math_isInRect(x, y, cellRect[cellID][1], cellRect[cellID][2], cellRect[cellID][3], cellRect[cellID][4]) then

					local cellZoom = hoverCellZoom
					local color = { 1, 1, 1 }
					if b then
						cellZoom = clickCellZoom
						color = { 0.36, 0.8, 0.3 }
					elseif b2 then
						cellZoom = clickCellZoom
						color = { 1, 0.66, 0.1 }
					elseif b3 then
						cellZoom = rightclickCellZoom
						color = { 1, 0.1, 0.1 }
					end
					cellZoom = cellZoom + math_min(0.33 * cellZoom * ((gridHeight / cellsize) - 2), 0.15) -- add extra zoom when small icons
					drawSelectionCell(cellID, selectionCells[cellID], texOffset + cellZoom, { color[1], color[2], color[3], 0.1 })
					-- highlight
					glBlending(GL_SRC_ALPHA, GL_ONE)
					if b or b2 or b3 then
						RectRound(cellRect[cellID][1] + cellPadding, cellRect[cellID][2] + cellPadding, cellRect[cellID][3], cellRect[cellID][4], cellPadding * 0.9, 1, 1, 1, 1, { color[1], color[2], color[3], (b or b2 or b3) and 0.4 or 0.2 }, { color[1], color[2], color[3], (b or b2 or b3) and 0.07 or 0.04 })
					else
						RectRound(cellRect[cellID][1] + cellPadding, cellRect[cellID][2] + cellPadding, cellRect[cellID][3], cellRect[cellID][4], cellPadding * 0.9, 1, 1, 1, 1, { 1,1,1, 0.08}, { 1,1,1, 0.08})
					end
					-- light border
					local halfSize = (((cellRect[cellID][3] - cellPadding)) - (cellRect[cellID][1])) * 0.5
					glBlending(GL_SRC_ALPHA, GL_ONE)
					RectRoundCircle(
						cellRect[cellID][1] + cellPadding + halfSize,
						0,
						cellRect[cellID][2] + cellPadding + halfSize,
						halfSize, cornerSize, halfSize - math_max(1, cellPadding), { 1,1,1, 0.07}, { 1,1,1, 0.07}
					)
					glBlending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)

					--cellHovered = cellID
					break
				end
			end

			if WG['tooltip'] then
				local statsIndent = '  '
				local stats = ''
				--local cells = cellHovered and { [cellHovered] = selectionCells[cellHovered] } or selectionCells
				-- description
				if cellHovered then
					local text, numLines = font:WrapText(unitDefInfo[selectionCells[cellHovered]].description, (backgroundRect[3] - backgroundRect[1]) * (loadedFontSize / 16))
					stats = stats .. statsIndent .. tooltipTextColor .. text .. '\n\n'
				end
				local text
				local textTitle
				stats = ''--getSelectionTotals(cells)
				if cellHovered then
					textTitle = unitDefInfo[selectionCells[cellHovered]].translatedHumanName .. tooltipLabelTextColor .. (selUnitsCounts[selectionCells[cellHovered]] > 1 and ' x ' .. tooltipTextColor .. selUnitsCounts[selectionCells[cellHovered]] or '')
				else
					--textTitle = Spring.I18N('ui.info.selectedunits')..": " .. tooltipTextColor .. #selectedUnits
					text = selectionHowto
				end

				WG['tooltip'].ShowTooltip('info', text, nil, nil, textTitle)
			end
		end

		-- transport load list
		if displayMode == 'unit' and unitDefInfo[displayUnitDefID].transport and cellRect then
			local units = Spring.GetUnitIsTransporting(displayUnitID)
			if #units > 0 then
				for cellID, unitID in pairs(units) do

					if cellRect[cellID] and math_isInRect(x, y, cellRect[cellID][1], cellRect[cellID][2], cellRect[cellID][3], cellRect[cellID][4]) then

						local cellZoom = hoverCellZoom
						local color = { 1, 1, 1 }
						if b then
							cellZoom = clickCellZoom
							color = { 1, 0.85, 0.1 }
						end
						cellZoom = cellZoom + math_min(0.33 * cellZoom * ((gridHeight / cellsize) - 2), 0.15) -- add extra zoom when small icons

						-- highlight
						glBlending(GL_SRC_ALPHA, GL_ONE)
						if b then
							RectRound(cellRect[cellID][1] + cellPadding, cellRect[cellID][2] + cellPadding, cellRect[cellID][3], cellRect[cellID][4], cellPadding * 0.9, 1, 1, 1, 1, { color[1], color[2], color[3], 0.3 }, { color[1], color[2], color[3], 0.3 })
						else
							RectRound(cellRect[cellID][1] + cellPadding, cellRect[cellID][2] + cellPadding, cellRect[cellID][3], cellRect[cellID][4], cellPadding * 0.9, 1, 1, 1, 1, { 1,1,1, 0.08}, { 1,1,1, 0.08})
						end
						-- light border
						local halfSize = (((cellRect[cellID][3] - cellPadding)) - (cellRect[cellID][1])) * 0.5
						glBlending(GL_SRC_ALPHA, GL_ONE)
						RectRoundCircle(
							cellRect[cellID][1] + cellPadding + halfSize,
							0,
							cellRect[cellID][2] + cellPadding + halfSize,
							halfSize, cornerSize, halfSize - math_max(1, cellPadding), { 1,1,1, 0.07}, { 1,1,1, 0.07}
						)
						glBlending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)

						--cellHovered = cellID
						break
					end
				end
			end
		elseif displayMode == 'unit' then
			if WG['unitstats'] and WG['unitstats'].showUnit then
				WG['unitstats'].showUnit(displayUnitID)
			end
		end
	end
end

function checkChanges()
	hideBuildlist = nil	-- only set for pregame startunit
	local x, y, b, _, _, _, cameraPanMode = spGetMouseState()
	hoverType, hoverData = spTraceScreenRay(x, y)

	local prevDisplayMode = displayMode
	local prevDisplayUnitDefID = displayUnitDefID
	local prevDisplayUnitID = displayUnitID

	-- determine what mode to display
	displayMode = 'text'
	displayUnitID = nil
	displayUnitDefID = nil

	if isPregame and not mySpec then
 		activeCmdID = WG["pregame-build"] and WG["pregame-build"].getPreGameDefID()
		activeCmdID = activeCmdID and -activeCmdID
	else
		activeCmdID = select(2, Spring.GetActiveCommand())
	end

	-- buildmenu unitdef
	if WG['buildmenu'] and WG['buildmenu'].hoverID then
		displayMode = 'unitdef'
		displayUnitDefID = WG['buildmenu'].hoverID
	elseif cfgDisplayUnitDefID then
		displayMode = 'unitdef'
		displayUnitDefID = cfgDisplayUnitDefID
	elseif activeCmdID and activeCmdID < 0 then
		displayMode = 'unitdef'
		displayUnitDefID = -activeCmdID
	elseif cfgDisplayUnitID and Spring.ValidUnitID(cfgDisplayUnitID) then
		displayMode = 'unit'
		displayUnitID = cfgDisplayUnitID
		displayUnitDefID = spGetUnitDefID(displayUnitID)
		if lastUpdateClock + 0.4 < os_clock() then
			-- unit stats could have changed meanwhile
			doUpdate = true
		end

		-- hovered unit
	elseif not cameraPanMode and not b and not math_isInRect(x, y, backgroundRect[1], backgroundRect[2], backgroundRect[3], backgroundRect[4]) and hoverType and hoverType == 'unit' then
		displayMode = 'unit'
		displayUnitID = hoverData
		displayUnitDefID = spGetUnitDefID(displayUnitID)
		if not displayUnitDefID and SelectedUnitsCount >= 1 then
			if SelectedUnitsCount == 1 then
				displayUnitID = selectedUnits[1]
				displayUnitDefID = spGetUnitDefID(selectedUnits[1])
			else
				displayMode = 'selection'
			end
		end
		if lastUpdateClock + 0.4 < os_clock() then
			-- unit stats could have changed meanwhile
			doUpdate = true
		end

		-- hovered feature
	elseif not cameraPanMode and not math_isInRect(x, y, backgroundRect[1], backgroundRect[2], backgroundRect[3], backgroundRect[4]) and hoverType and hoverType == 'feature' then
		displayMode = 'feature'
		local featureID = hoverData
		local featureDefID = spGetFeatureDefID(featureID)
		local featureDef = FeatureDefs[featureDefID]
		local newTooltip = featureDef.translatedDescription or ''

		if featureDef.reclaimable then
			local metal, _, energy, _ = Spring.GetFeatureResources(featureID)
			metal = math.floor(metal)
			energy = math.floor(energy)
			local reclaimText = Spring.I18N('ui.reclaimInfo.metal', { metal = metal }) .. "\255\255\255\128" .. " " .. Spring.I18N('ui.reclaimInfo.energy', { energy = energy })
			newTooltip = newTooltip .. "\n\n" .. reclaimText
		end

		if newTooltip ~= currentTooltip then
			currentTooltip = newTooltip
			doUpdate = true
		end

		-- selected unit
	elseif SelectedUnitsCount == 1 then
		displayMode = 'unit'
		displayUnitID = selectedUnits[1]
		displayUnitDefID = spGetUnitDefID(selectedUnits[1])
		if lastUpdateClock + 0.4 < os_clock() then
			-- unit stats could have changed meanwhile
			doUpdate = true
		end

		-- selection
	elseif SelectedUnitsCount > 1 then
		displayMode = 'selection'

		-- tooltip text
	else
		local newTooltip = spGetCurrentTooltip()
		if newTooltip ~= currentTooltip then
			currentTooltip = newTooltip
			doUpdate = true
		end
	end

	-- display changed
	if prevDisplayMode ~= displayMode or prevDisplayUnitDefID ~= displayUnitDefID or prevDisplayUnitID ~= displayUnitID then
		doUpdate = true
	end

	if displayMode == 'text' and isPregame then
		if not mySpec then
			displayMode = 'unitdef'
			displayUnitDefID = Spring.GetTeamRulesParam(myTeamID, 'startUnit')
			hideBuildlist = true
		else
			emptyInfo = true
		end
	end
end

function widget:SelectionChanged(sel)
	local newSelectedUnitsCount = spGetSelectedUnitsCount()
	if SelectedUnitsCount ~= 0 and newSelectedUnitsCount == 0 then
		doUpdate = true
		SelectedUnitsCount = 0
		selectedUnits = {}
	end
	if newSelectedUnitsCount > 0 then
		SelectedUnitsCount = newSelectedUnitsCount
		selectedUnits = sel
		if not doUpdateClock then
			doUpdateClock = os_clock() + 0.05  -- delay to save some performance
		end
	end
	if not alwaysShow and select(7, spGetMouseState()) then	-- cameraPanMode
		checkChanges()
	end
end

function widget:LanguageChanged()
	refreshUnitInfo()
	widget:ViewResize()
end


function widget:GetConfigData(data)
	return {
		showBuilderBuildlist = showBuilderBuildlist,
		displayMapPosition = displayMapPosition,
		alwaysShow = alwaysShow,
	}
end

function widget:SetConfigData(data)
	if data.showBuilderBuildlist ~= nil then
		showBuilderBuildlist = data.showBuilderBuildlist
	end
	if data.displayMapPosition ~= nil then
		displayMapPosition = data.displayMapPosition
	end
	if data.alwaysShow ~= nil then
		alwaysShow = data.alwaysShow
	end
end
