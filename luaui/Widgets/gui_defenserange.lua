include("keysym.h.lua")

local versionNumber = "6.32"

local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name      = "Defense Range",
		desc      = "[v" .. string.format("%s", versionNumber ) .. "] Displays range of defenses (enemy and ally)",
		author    = "very_bad_soldier",
		date      = "October 21, 2007",
		license   = "GNU GPL v2",
		layer     = -100,
		enabled   = true
	}
end

--[[
changelog:
6.3: heightboost support. missing ba floating turrets added (thx to nixa)
6.2: speed-up by cpu culling
6.12: bugfix (BA Ambusher working)
6.11: added missing water units to BA (torpLauncher/FHLT/FRocketTower)
6.1: -XTA-support added (thx to manolo_)
	 -tweak mode and load/save fixed
	 --]]

-- CONFIGURATION
local debug = false --generates debug message
local enabledAsSpec = false

local modConfig = {}
-- BAR
--to support other mods
--table initialized and unitList is needed!
modConfig["BYAR"] = {}
modConfig["BYAR"]["unitList"] = {
	-- ARMADA
	armclaw = { weapons = { 1 } },
	armllt = { weapons = { 1 } },
	armbeamer = { weapons = { 1 } },
	armhlt = { weapons = { 1 } },
	armguard = { weapons = { 1, 1 } },
	armrl = { weapons = { 2 } }, --light aa
	armferret = { weapons = { 2 } },
	armcir = { weapons = { 2 } }, --chainsaw
	armdl = { weapons = { 1 } }, --depthcharge
	armjuno = { weapons = { 1 } },
	armtl = { weapons = { 1 } }, --torp launcher
	armfhlt = { weapons = { 1 } },  --floating hlt
	armfrt = { weapons = { 2 } },  --floating rocket laucher
	armfflak = { weapons = { 2 } },  --floating flak AA
	armatl = { weapons = { 1 } },  --adv torpedo launcher
	armkraken = { weapons = { 1 } },

	armamb = { weapons = { 1,1 } }, --ambusher
	armpb = { weapons = { 1 } }, --pitbull
	armanni = { weapons = { 1 } },
	armflak = { weapons = { 2 } },
	armmercury = { weapons = { 2 } },
	armemp = { weapons = { 1 } },
	armamd = { weapons = { 3 } }, --antinuke

	armbrtha = { weapons = { 1 } },
	armvulc = { weapons = { 1 } },

	-- CORTEX
	cormaw = { weapons = { 1 } },
	corexp = { weapons = { 1 } },
	corllt = { weapons = { 1 } },
	corhllt = { weapons = { 1 } },
	corhlt = { weapons = { 1 } },
	corpun = { weapons = { 1, 1 } },
	corrl = { weapons = { 2 } },
	cormadsam = { weapons = { 2 } },
	corerad = { weapons = { 2 } },
	cordl = { weapons = { 1 } },
	corjuno = { weapons = { 1 } },

	corfhlt = { weapons = { 1 } },  --floating hlt
	cortl = { weapons = { 1 } }, --torp launcher
	coratl = { weapons = { 1 } }, --T2 torp launcher
	corfrt = { weapons = { 2 } }, --floating rocket laucher
	corenaa = { weapons = { 2 } }, --floating flak AA
	corfdoom = { weapons = { 1 } }, --floating devastator

	cortoast = { weapons = { 1 } },
	corvipe = { weapons = { 1 } },
	cordoom = { weapons = { 1 } },
	corflak = { weapons = { 2 } },
	corscreamer = { weapons = { 2 } },
	cortron = { weapons = { 1 } },
	corfmd = { weapons = { 3 } },
	corint = { weapons = { 1 } },
	corbuzz = { weapons = { 1 } },
	
	--LEGION

	leglht = { weapons = { 1 } }, -- t1 heatray tower
	legmg = { weapons = { 1 } }, -- machine gun tower
	legdtr = { weapons = { 1 } }, -- t1 pop-up riot cannon
	legcluster = { weapons = { 1 } },  -- t1 cluster arty
	leghive = { weapons = { 1 } },  -- t1 drone pad

	legrl = { weapons = { 2 } }, -- t1 light aa turret
	legrhapsis = { weapons = { 2 } }, -- t1 salvo aa
	leglupara = { weapons = { 2 } }, -- t1.5 burst flak

	legstarfall = { weapons = { 1 } }, -- LOLCannon
	leglrpc = { weapons = { 1 } }, -- t2 lrpc
	legacluster = { weapons = { 1 } }, -- t2 popup arty
	legbombard = { weapons = { 1 } }, -- t2 pop-up
	legperdition = { weapons = { 1 } }, -- t2 tacnuke

	legflak = { weapons = { 2 } }, -- t2 ravager gatling flak
	leglraa = { weapons = { 2 } }, -- t2 aa railgun
	
	legtl = { weapons = { 1 } }, --torp launcher

	legabm = { weapons = { 3 } },
	legrampart = { weapons = { 3 }},

	-- SCAVENGERS
	scavbeacon_t1_scav = { weapons = { 1 } },
	scavbeacon_t2_scav = { weapons = { 1 } },
	scavbeacon_t3_scav = { weapons = { 1 } },
	scavbeacon_t4_scav = { weapons = { 1 } },

	armannit3 = { weapons = { 1 } },
	--armbotrail = { weapons = { 1 } },
	armminivulc = { weapons = { 1 } },
	legministarfall = { weapons = { 1 } },

	cordoomt3 = { weapons = { 1 } },
	corhllllt = { weapons = { 1 } },
	corminibuzz = { weapons = { 1 } }
}

--implement this if you want dps-depending ring-colors
--colors will be interpolated by dps scores between min and max values. values outside range will be set to nearest value in range -> min or max
modConfig["BYAR"]["armorTags"] = {}
modConfig["BYAR"]["armorTags"]["air"] = "vtol"
modConfig["BYAR"]["armorTags"]["ground"] = "else"
modConfig["BYAR"]["dps"] = {}
modConfig["BYAR"]["dps"]["ground"] = {}
modConfig["BYAR"]["dps"]["air"] = {}
modConfig["BYAR"]["dps"]["ground"]["min"] = 50
modConfig["BYAR"]["dps"]["ground"]["max"] = 500
modConfig["BYAR"]["dps"]["air"]["min"] = 80
modConfig["BYAR"]["dps"]["air"]["max"] = 500
--end of dps-colors


--DEFAULT COLOR CONFIG
--is used when no game-specfic color config is found in current game-definition
local colorConfig = {}
colorConfig["enemy"] = {}
colorConfig["enemy"]["ground"]= {}
colorConfig["enemy"]["ground"]["min"]= {}
colorConfig["enemy"]["ground"]["max"]= {}
colorConfig["enemy"]["air"]= {}
colorConfig["enemy"]["air"]["min"]= {}
colorConfig["enemy"]["air"]["max"]= {}
colorConfig["enemy"]["nuke"]= {}
colorConfig["enemy"]["ground"]["min"] = { 1.0, 0.0, 0.0 }
colorConfig["enemy"]["ground"]["max"] = { 1.0, 1.0, 0.0 }
colorConfig["enemy"]["air"]["min"] = { 0.0, 1.0, 0.0 }
colorConfig["enemy"]["air"]["max"] = { 0.0, 0.0, 1.0 }
colorConfig["enemy"]["nuke"] =  { 1.0, 1.0, 1.0 }

colorConfig["ally"] = colorConfig["enemy"]
--end of DEFAULT COLOR CONFIG

-- cache only what we use
local weapTab = {}	--WeaponDefs
local wdefParams = {'salvoSize', 'reload', 'coverageRange', 'damages', 'range', 'type', 'projectilespeed', 'heightBoostFactor', 'heightMod', 'heightBoostFactor', 'projectilespeed', 'myGravity'}
for weaponDefID, weaponDef in pairs(WeaponDefs) do
	weapTab[weaponDefID] = {}
	for i, param in ipairs(wdefParams) do
		weapTab[weaponDefID][param] = weaponDef[param]
	end
end
wdefParams = nil

local unitRadius = {}
local unitNumWeapons = {}
local canMove = {}
local unitName = {}
local unitWeapons = {}
for unitDefID, unitDef in pairs(UnitDefs) do
	unitRadius[unitDefID] = unitDef.radius
	local weapons = unitDef.weapons
	if #weapons > 0 then
		unitNumWeapons[unitDefID] = #weapons
		for i=1, #weapons do
			if not unitWeapons[unitDefID] then
				unitWeapons[unitDefID] = {}
			end
			unitWeapons[unitDefID][i] = weapons[i].weaponDef
		end
	end
	canMove[unitDefID] = unitDef.canMove
	unitName[unitDefID] = unitDef.name
end

--Button display configuration
--position only relevant if no saved config data found
local buttonConfig = {}
buttonConfig["enabled"] = {
	ally = { ground = false, air = false, nuke = false , radar = false },
	enemy = { ground = true, air = true, nuke = true, radar = false }
}

local rangeCircleList --glList for drawing range circles
local _,oldcamy,_ = Spring.GetCameraPosition() --for tracking if we should change the alpha/linewidth based on camheight

local spGetSpectatingState = Spring.GetSpectatingState
local spec, fullview = spGetSpectatingState()
local myAllyTeam = Spring.GetMyAllyTeamID()

local defences = {}
local currentModConfig = {}

local updateTimes = {}
updateTimes["remove"] = 0
updateTimes["line"] = 0
updateTimes["removeInterval"] = 1 --configurable: seconds for the ::update loop

local state = {}
state["curModID"] = nil
state["myPlayerID"] = nil

local lineConfig = {}
lineConfig["lineWidth"] = 1.5 -- calcs dynamic now
lineConfig["alphaValue"] = 0.0 --> dynamic behavior can be found in the function "widget:Update"
lineConfig["circleDivs"] = 80.0

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
---
local GL_LINE_LOOP          = GL.LINE_LOOP
local glBeginEnd            = gl.BeginEnd
local glColor               = gl.Color
local glDepthTest           = gl.DepthTest
local glLineWidth           = gl.LineWidth
local glTranslate           = gl.Translate
local glVertex              = gl.Vertex
local glCallList		 	= gl.CallList
local glCreateList			= gl.CreateList
local glDeleteList			= gl.DeleteList

local sqrt					= math.sqrt
local abs					= math.abs
local upper                 = string.upper
local floor                 = math.floor
local PI                    = math.pi
local cos                   = math.cos
local sin                   = math.sin

local spEcho                = Spring.Echo
local spGetGameSeconds      = Spring.GetGameSeconds
local spGetMyPlayerID       = Spring.GetMyPlayerID
local spGetPlayerInfo       = Spring.GetPlayerInfo
local spGetPositionLosState = Spring.GetPositionLosState
local spGetUnitDefID        = Spring.GetUnitDefID
local spGetUnitPosition     = Spring.GetUnitPosition
local spGetGroundHeight 	= Spring.GetGroundHeight
local spIsGUIHidden 		= Spring.IsGUIHidden
local spGetLocalTeamID	 	= Spring.GetLocalTeamID
local spIsSphereInView  	= Spring.IsSphereInView

local chobbyInterface

local mapBaseHeight
local h = {}
for i=1,3 do
	for i=1,3 do
		h[#h+1]=Spring.GetGroundHeight(Game.mapSizeX*i/4,Game.mapSizeZ*i/4)
	end
end
mapBaseHeight = 0
for _,s in ipairs(h) do
	mapBaseHeight = mapBaseHeight + s
end
mapBaseHeight = mapBaseHeight / #h
local gy = math.max(0,mapBaseHeight)

local darkOpacity = 0

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------


function widget:TextCommand(command)
	--Spring.Echo("DEFRANGE", command, mycommand)
	local mycommand=false --buttonConfig["enabled"]["enemy"][tag]

	if string.find(command, "defrange", nil, true) then
		mycommand = true
		local ally = 'ally'
		local rangetype = 'ground'
		local enabled = false
		if string.find(command, "enemy", nil, true) then
			ally = 'enemy'
		end
		if string.find(command, "air", nil, true) then
			rangetype = 'air'
		elseif string.find(command, "nuke", nil, true) then
			rangetype = 'nuke'
		end
		if string.find(command, "+", nil, true) then
			enabled = true
		end
		buttonConfig["enabled"][ally][rangetype]=enabled
		Spring.Echo("Range visibility of "..ally.." "..rangetype.." defenses set to",enabled)
		return true
	end

	return false
end

function widget:Shutdown()
	if rangeCircleList then
		gl.DeleteList(rangeCircleList)
	end
end

function init()
	local units = Spring.GetAllUnits()
	for i=1, #units do
		local unitID = units[i]
		UnitDetected(unitID, Spring.GetUnitAllyTeam(unitID) == myAllyTeam)
	end
end

function widget:Initialize()
	state["myPlayerID"] = spGetLocalTeamID()

	DetectMod()

	init()

	WG['defrange'] = {}
	WG['defrange'].getAllyAir = function()
		return buttonConfig["enabled"].ally.air
	end
	WG['defrange'].setAllyAir = function(value)
		buttonConfig["enabled"].ally.air = value
	end
	WG['defrange'].getAllyGround = function()
		return buttonConfig["enabled"].ally.ground
	end
	WG['defrange'].setAllyGround = function(value)
		buttonConfig["enabled"].ally.ground = value
	end
	WG['defrange'].getAllyNuke = function()
		return buttonConfig["enabled"].ally.nuke
	end
	WG['defrange'].setAllyNuke = function(value)
		buttonConfig["enabled"].ally.nuke = value
	end
	WG['defrange'].getEnemyAir = function()
		return buttonConfig["enabled"].enemy.air
	end
	WG['defrange'].setEnemyAir = function(value)
		buttonConfig["enabled"].enemy.air = value
	end
	WG['defrange'].getEnemyGround = function()
		return buttonConfig["enabled"].enemy.ground
	end
	WG['defrange'].setEnemyGround = function(value)
		buttonConfig["enabled"].enemy.ground = value
	end
	WG['defrange'].getEnemyNuke = function()
		return buttonConfig["enabled"].enemy.nuke
	end
	WG['defrange'].setEnemyNuke = function(value)
		buttonConfig["enabled"].enemy.nuke = value
	end
end

function widget:UnitTaken(unitID, unitDefID, unitTeam, newTeam)
	UnitDetected( unitID, true )
end

function widget:UnitGiven(unitID, unitDefID, unitTeam, oldTeam)
	UnitDetected( unitID, true )
end

function widget:UnitCreated( unitID,  unitDefID,  unitTeam)
	UnitDetected( unitID, true )
end

function widget:UnitEnteredLos(unitID, allyTeam)
	UnitDetected( unitID, false, allyTeam )
end

function UnitDetected( unitID, allyTeam, teamId )
	local tag
	local tabValue = defences[unitID]
	if tabValue ~= nil and tabValue[1] ~= allyTeam then
		--unit already known
		return
	end
	local unitDefID = spGetUnitDefID(unitID)

	local x, y, z = spGetUnitPosition(unitID)

	local range = 0
	local type = 0
	local dps
	local weaponDef

	if unitRadius[unitDefID] and unitRadius[unitDefID] < 100 then
		if not unitNumWeapons[unitDefID] then
			--not interesting, has no weapons and no radar coverage, lame
			return
		end

		if canMove[unitDefID] then
			--not interesting, it moves
			return
		end
	end

	printDebug( unitName[unitDefID] )
	local foundWeapons = {}
	if unitNumWeapons[unitDefID] then
		for i=1, unitNumWeapons[unitDefID] do

			--Used for showing scavenger unit ranges
			local uName = unitName[unitDefID]
			if string.find(uName, "_scav") then
				uName = string.gsub(unitName[unitDefID], "_scav", "")
				uName = uName or unitName[unitDefID]
			end

			if currentModConfig["unitList"][uName] == nil or currentModConfig["unitList"][uName]["weapons"][i] == nil then
				printDebug("Weapon skipped! Name: "..  unitName[unitDefID] .. " weaponidx: " .. i )
			else
				--get definition from weapon table
				weaponDef = weapTab[ unitWeapons[unitDefID][i] ]

				range = weaponDef.range --get normal weapon range
				--printDebug("Weapon #" .. i .. " Range: " .. range .. " Type: " .. weaponDef.type )

				type = currentModConfig["unitList"][uName]["weapons"][i]

				local dam = weaponDef.damages
				local dps, damage, color1, color2

				--check if dps-depending colors should be used
				if currentModConfig["armorTags"] ~= nil then
					printDebug("DPS colors!")
					if type == 1 or type == 4 then	 -- show combo units with ground-dps-colors
						tag = currentModConfig["armorTags"] ["ground"]
					elseif type == 2 then
						tag = currentModConfig["armorTags"] ["air"]
					elseif type == 3 then -- antinuke
						range = weaponDef.coverageRange
						dps = nil
						tag = nil
					end

					if tag ~= nil then
						dps = 0
						--printDebug("Salvo: " .. weaponDef.salvoSize 	)
						damage = dam[Game.armorTypes[tag]]
						if damage then
							dps = damage * weaponDef.salvoSize / weaponDef.reload
						end
						--printDebug("DPS: " .. dps 	)
					end

					color1, color2 = GetColorsByTypeAndDps( dps, type, ( allyTeam == false ) )
				else
					printDebug("Default colors!")
					local team = "ally"
					if allyTeam then
						team = "enemy"
					end

					if type == 1 or type == 4 then	 -- show combo units with ground-dps-colors
						color1 = colorConfig[team]["ground"]["min"]
						color2 = colorConfig[team]["air"]["min"]
					elseif type == 2 then
						color1 = colorConfig[team]["air"]["min"]
					elseif type == 3 then -- antinuke
						color1 = colorConfig[team]["nuke"]
					end
				end

				--add weapon to list
				local rangeLines = CalcBallisticCircle(x,y,z,range, weaponDef )
				local rangeLinesEx = CalcBallisticCircle(x,y,z,range + 3, weaponDef ) --calc a little bigger circle to display for combo-weapons (air and ground) to display both circles together (without overlapping)
				foundWeapons[i] = { type = type, range = range, rangeLines = rangeLines, rangeLinesEx = rangeLinesEx, color1 = color1, color2 = color2 }
				printDebug("Detected Weapon - Type: " .. type .. " Range: " .. range )
			end
		end
	end
	printDebug("Adding UnitID " .. unitID .. " WeaponCount: " .. #foundWeapons ) --.. "W1: " .. foundWeapons[1]["type"])
	defences[unitID] = { allyState = ( allyTeam == false ), pos = {x, y, z}, unitId = unitID }
	defences[unitID]["weapons"] = foundWeapons

	UpdateCircleList()
end

function GetColorsByTypeAndDps( dps, type, isEnemy )
	--BEWARE: dps can be nil here! when antinuke for example
 -- get alternative color for weapons ground AND air
	local color1 = nil
	local color2 = nil
	if ( type == 4 ) then -- show combo units with "ground"-colors
		if ( isEnemy ) then
			color2 = GetColorByDps( dps, true, "air" )
		else
			color2 = GetColorByDps( dps, false, "air")
		end
	end

  --get standard colors
	if type == 1 or type == 4 then
	  if isEnemy then
			color1 = GetColorByDps( dps, true, "ground" )
		else
			color1 = GetColorByDps( dps, false, "ground")
		end
	elseif type == 2 then
		if isEnemy then
			color1 = GetColorByDps( dps, true, "air" )
		else
			color1 = GetColorByDps( dps, false, "air")
		end
	elseif type == 3 then
		if isEnemy then
			color1 = colorConfig["enemy"]["nuke"]
		else
			color1 = colorConfig["ally"]["nuke"]
		end
	end

	return color1, color2
end

--linear interpolates between min and max color
function GetColorByDps( dps, isEnemy, typeStr )
	local color = { 0.0, 0.0, 0.0 }
	local team = "ally"
	if isEnemy then team = "enemy" end

	printDebug("GetColor typeStr : " .. typeStr  .. "Team: " .. team )
	--printDebug( colorConfig[team][typeStr]["min"] )
	local ldps = currentModConfig["dps"][typeStr]["min"]
	if dps > ldps then ldps = dps end
	if currentModConfig["dps"][typeStr]["max"] < ldps then
		ldps = currentModConfig["dps"][typeStr]["max"]
	end

	ldps = ldps - currentModConfig["dps"][typeStr]["min"]
	local factor = ldps / ( currentModConfig["dps"][typeStr]["max"] - currentModConfig["dps"][typeStr]["min"] )
--	printDebug( "Dps: " .. dps .. " Factor: " .. factor .. " ldps: " .. ldps )
	for i=1,3 do
		color[i] =  ( ( ( 1.0 -  factor ) * colorConfig[team][typeStr]["min"][i] ) + ( factor * colorConfig[team][typeStr]["max"][i] ) )
	--	printDebug( "#" .. i .. ":" .. "min: " .. colorConfig[team][typeStr]["min"]["color"][i] .. " max: " .. colorConfig[team][typeStr]["max"]["color"][i] .. " calc: " .. color[i] )
	end
	return color
end


function ResetGl()
	glColor( { 1.0, 1.0, 1.0, 1.0 } )
	glLineWidth( 1.0 )
end


function CheckSpecState()
	local playerID = spGetMyPlayerID()
	if select(3,spGetPlayerInfo(playerID,false)) == true then
		widgetHandler:RemoveWidget()
		return false
	end

	return true
end

function widget:PlayerChanged()
	if myAllyTeam ~= Spring.GetMyAllyTeamID() or fullview ~= select(2, spGetSpectatingState()) then
		myAllyTeam = Spring.GetMyAllyTeamID()
		spec, fullview = spGetSpectatingState()
		init()
	end
end

function widget:Update()
	if fullview and not enabledAsSpec then
		return
	end

	local cy = select(2,Spring.GetCameraPosition())
	darkOpacity = 0.5 - (cy-gy-3000) * (1/10000)
	if darkOpacity < 0.1 then darkOpacity = 0.1 end

	local timef = spGetGameSeconds()
	local time = floor(timef)

	if (timef - updateTimes["line"]) > 0.2 and timef ~= updateTimes["line"] then
		updateTimes["line"] = timef

		--adjust line width and alpha by camera height (old code, kept for refence)
        --[[
		_, camy, _ = spGetCameraPosition()
		if ( camy < 700 ) and ( oldcamy >= 700 ) then
			oldcamy = camy
			lineConfig["lineWidth"] = 2.33
			lineConfig["alphaValue"] = 0.25
			UpdateCircleList()
		elseif ( camy < 1800 ) and ( oldcamy >= 1800 ) then
			oldcamy = camy
			lineConfig["lineWidth"] = 1.8
			lineConfig["alphaValue"] = 0.3
			UpdateCircleList()
		elseif ( camy > 1800 ) and ( oldcamy <= 1800 ) then
			oldcamy = camy
			lineConfig["lineWidth"] = 1.33
			lineConfig["alphaValue"] = 0.35
			UpdateCircleList()
		end
        ]]

        lineConfig["lineWidth"] = 1.33
        lineConfig["alphaValue"] = darkOpacity
        UpdateCircleList()

	end


	-- update timers once every <updateInt> seconds
	if time % updateTimes["removeInterval"] == 0 and time ~= updateTimes["remove"] then
		updateTimes["remove"] = time
		--do update stuff:

		--if not spec then
		--	return false
		--end

		--remove dead units
		for k, def in pairs(defences) do
			local x, y, z = def["pos"][1], def["pos"][2], def["pos"][3]
			local a, b, c = spGetPositionLosState(x, y, z)
			local losState = b
			if losState then
				if not spGetUnitDefID(def["unitId"]) then
					printDebug("Unit killed.")
					defences[k] = nil
					UpdateCircleList()
				end
			end
		end
	end
end

function DetectMod()
	state["curModID"] = upper(Game.gameShortName or "")

	if modConfig[state["curModID"]] == nil then
		spEcho("<DefenseRange> Unsupported Game, shutting down...")
		widgetHandler:RemoveWidget()
		return
	end

	currentModConfig = modConfig[state["curModID"]]

	--load mod specific color config if existent
	if currentModConfig["color"] ~= nil then
		colorConfig = currentModConfig["color"]
		printDebug("Game-specfic color configuration loaded")
	end

	printDebug( "<DefenseRange> ModName: " .. Game.modName .. " Detected Mod: " .. state["curModID"] )
end


function GetRange2DWeapon( range, yDiff)
	local root1 = range * range - yDiff * yDiff
	if root1 < 0 then
		return 0
	else
		return sqrt(root1)
	end
end

function GetRange2DCannon( range, yDiff, projectileSpeed, rangeFactor, myGravity, heightBoostFactor )
	local factor = 0.7071067
	local smoothHeight = 100.0
	local speed2d = projectileSpeed*factor
	local speed2dSq = speed2d*speed2d
	local curGravity = Game.gravity
	local gravity = - ( curGravity / 900 ) -- -0.13333333
	if myGravity ~= nil and myGravity ~= 0 then
		gravity = myGravity   -- i have never seen a stationary weapon using myGravity tag, so its untested :D
	end

	--printDebug("rangeFactor: " .. rangeFactor)
	--printDebug("ProjSpeed: " .. projectileSpeed)
	if heightBoostFactor < 0.0 then
		heightBoostFactor = (2.0 - rangeFactor) / sqrt(rangeFactor)
	end

	if yDiff < -smoothHeight then
		yDiff = yDiff * heightBoostFactor
	elseif yDiff < 0.0 then
		yDiff = yDiff * ( 1.0 + ( heightBoostFactor - 1.0 ) * ( -yDiff)/smoothHeight )
	end

	local root1 = speed2dSq + 2 * gravity * yDiff
	if root1 < 0.0 then
		printDebug("Cann return 0")
		return 0.0
	else
		printDebug("Cann return: " .. rangeFactor * ( speed2dSq + speed2d * sqrt( root1 ) ) / (-gravity) )
		return rangeFactor * ( speed2dSq + speed2d * sqrt( root1 ) ) / (-gravity)
	end
end

--hopefully accurate reimplementation of the spring engine's ballistic circle code
function CalcBallisticCircle( x, y, z, range, weaponDef )
	local rangeLineStrip = {}
	local rangeLineStripCount = 0
	local slope = 0.0

	local rangeFunc = GetRange2DWeapon
	local rangeFactor = 1.0 --used by range2dCannon
	if weaponDef.type == "Cannon" then
		rangeFunc = GetRange2DCannon
		rangeFactor = range / GetRange2DCannon( range, 0.0, weaponDef.projectilespeed, rangeFactor, nil, weaponDef.heightBoostFactor )
		if rangeFactor > 1.0 or rangeFactor <= 0.0 then
			rangeFactor = 1.0
		end
	end


	local yGround = spGetGroundHeight( x,z)
	for i = 1, lineConfig["circleDivs"] do
		local radians = 2.0 * PI * i / lineConfig["circleDivs"]
		local rad = range

		local sinR = sin( radians )
		local cosR = cos( radians )

		local posx = x + sinR * rad
		local posz = z + cosR * rad
		local posy = spGetGroundHeight( posx, posz )

		local heightDiff = ( posy - yGround ) / 2.0							-- maybe y has to be getGroundHeight(x,z) cause y is unit center and not aligned to ground

		rad = rad - heightDiff * slope
		local adjRadius = rangeFunc( range, heightDiff * weaponDef.heightMod, weaponDef.projectilespeed, rangeFactor, nil, weaponDef.heightBoostFactor )
		local adjustment = rad / 2.0
		local yDiff = 0.0

		for j = 0, 49 do
			if abs( adjRadius - rad ) + yDiff <= 0.01 * rad then
				break
			end

			if adjRadius > rad then
				rad = rad + adjustment
			else
				rad = rad - adjustment
				adjustment = adjustment / 2.0
			end

			posx = x + ( sinR * rad )
			posz = z + ( cosR * rad )
			local newY = spGetGroundHeight( posx, posz )

			yDiff = abs( posy - newY )
			posy = newY
			--posy = max( posy, 0.0 )  --hack
			if posy < 0 then posy = 0 end

			heightDiff = ( posy - yGround ) 																--maybe y has to be Ground(x,z)
			adjRadius = rangeFunc( range, heightDiff * weaponDef.heightMod, weaponDef.projectilespeed, rangeFactor, weaponDef.myGravity, weaponDef.heightBoostFactor )
		end


		posx = x + ( sinR * adjRadius )
		posz = z + ( cosR * adjRadius )
		posy = spGetGroundHeight( posx, posz ) + 5.0
		--posy = max( posy, 0.0 )   --hack
		if posy < 0 then posy = 0 end
		rangeLineStripCount = rangeLineStripCount + 1
		rangeLineStrip[rangeLineStripCount] = { posx, posy, posz }
	end

	return rangeLineStrip
end

function CheckDrawTodo( def, weaponIdx )
	if def.weapons[weaponIdx]["type"] == 1 or def.weapons[weaponIdx]["type"] == 4 then
		if def["allyState"] == true and buttonConfig["enabled"]["enemy"]["ground"] then
			return true
		elseif def["allyState"] == false and buttonConfig["enabled"]["ally"]["ground"] then
			return true
		else
			return false
		end
	end

	if def.weapons[weaponIdx]["type"] == 2 or def.weapons[weaponIdx]["type"] == 4 then
		if def["allyState"] == true and buttonConfig["enabled"]["enemy"]["air"] then
			return true
		elseif def["allyState"] == false and buttonConfig["enabled"]["ally"]["air"] then
			return true
		else
			return false
		end
	end

	if def.weapons[weaponIdx]["type"] == 3 then
		if def["allyState"] == true and buttonConfig["enabled"]["enemy"]["nuke"] then
			return true
		elseif def["allyState"] == false and buttonConfig["enabled"]["ally"]["nuke"] then
			return true
		end
	end

	return false
end



local function BuildVertexList(verts)
	for i, vert in pairs(verts) do
		--printDebug(verts)
		glVertex(vert)
	end
end

function DrawRanges()
	glDepthTest(true)
	glTranslate(0,6,0)	-- else it gets rendered below map sometimes
	local color
	local range
	for test, def in pairs(defences) do
		--Spring.Echo('defrange drawrranges test',test, #def["weapons"])
		for i, weapon in pairs(def["weapons"]) do
			local execDraw = false
			--f false then --3.9 % cpu, 45 fps
			--	if spIsSphereInView( def["pos"][1], def["pos"][2], def["pos"][3], weapon["range"] ) then
			--		execDraw = CheckDrawTodo( def, i )
			--	end
			--lse--faster: 3.0% cpu, 46fps

				if CheckDrawTodo( def, i ) then
					execDraw =spIsSphereInView( def["pos"][1], def["pos"][2], def["pos"][3], weapon["range"] )
				end
			--end
			if execDraw then
				color = weapon["color1"]
				range = weapon["range"]
				if weapon["type"] == 4 then
					if ( ( def["allyState"] == true and buttonConfig["enabled"]["enemy"]["air"] ) or ( def["allyState"] == false and buttonConfig["enabled"]["ally"]["air"] ) )
						and
						( ( def["allyState"] == true and buttonConfig["enabled"]["enemy"]["ground"] == false ) or ( def["allyState"] == false and buttonConfig["enabled"]["ally"]["ground"] == false ) )
					then
						-- check if unit is combo unit, get secondary color if so
						--if air only is selected
						color = weapon["color2"]
					end
				end

				glColor( color[1], color[2], color[3], lineConfig["alphaValue"])
				glLineWidth(lineConfig["lineWidth"])
				glBeginEnd(GL_LINE_LOOP, BuildVertexList, weapon["rangeLines"] )

				--printDebug( "Drawing defence: range: " .. range .. " Color: " .. color[1] .. "/" .. color[2] .. "/" .. color[3] .. " a:" .. lineConfig["alphaValue"] )

				if weapon["type"] == 4
					and
					( ( def["allyState"] == true and buttonConfig["enabled"]["enemy"]["air"] ) or ( def["allyState"] == false and buttonConfig["enabled"]["ally"]["air"] ) )
					and
					( ( def["allyState"] == true and buttonConfig["enabled"]["enemy"]["ground"] ) or ( def["allyState"] == false and buttonConfig["enabled"]["ally"]["ground"] ) )
				then
					--air and ground: draw 2nd circle
					glColor( weapon["color2"][1], weapon["color2"][2], weapon["color2"][3], lineConfig["alphaValue"])
					glBeginEnd(GL_LINE_LOOP, BuildVertexList, weapon["rangeLinesEx"] )
				end
			end
		end
	end

	glTranslate(0,-6,0)
	glDepthTest(false)
end


function UpdateCircleList()
	--delete old list
	if rangeCircleList then
		glDeleteList(rangeCircleList)
	end

	rangeCircleList = glCreateList(function()
		--create new list
		DrawRanges()
		ResetGl()
	end)
end

function widget:RecvLuaMsg(msg, playerID)
	if msg:sub(1,18) == 'LobbyOverlayActive' then
		chobbyInterface = (msg:sub(1,19) == 'LobbyOverlayActive1')
	end
end

function widget:DrawWorld()
	if fullview and not enabledAsSpec then
		return
	end
	if chobbyInterface then return end
	if not spIsGUIHidden() and (not WG['topbar'] or not WG['topbar'].showingQuit()) then
		if rangeCircleList then
			glCallList(rangeCircleList)
		else
			UpdateCircleList()
		end
	end
end


function printDebug(value)
	if debug then
		if type(value) == "boolean" then
			if value == true then spEcho( "true" )
				else spEcho("false") end
		elseif type(value) == "table" then
			spEcho("Dumping table:")
			for key,val in pairs(value) do
				spEcho(key,val)
			end
		else
			spEcho(value)
		end
	end
end



--SAVE / LOAD CONFIG FILE
function widget:GetConfigData()
	local data = {}
	data["enabled"] = buttonConfig["enabled"]
	return data
end

function widget:SetConfigData(data)
	if data ~= nil then
		if data["enabled"] ~= nil then
			buttonConfig["enabled"] = data["enabled"]
			printDebug("enabled config found...")
		end
	end
end

