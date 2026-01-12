include("keysym.h.lua")

local versionNumber = "1.1"

local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name    = "Attack Range GL4",
		desc    =
		"[v" .. string.format("%s", versionNumber ) .. "] Displays attack ranges of selected units. Alt+, and alt+. (alt comma and alt period) to cycle backward and forward through display config of current unit (saved through games!). Custom keybind to toggle cursor unit range on and off.",
		author  = "Errrrrrr, Beherith",
		date    = "July 20, 2023",
		license = "Lua: GPLv2, GLSL: (c) Beherith (mysterme@gmail.com)",
		layer   = -99,
		enabled = true,
		depends = {'gl4'},
	}
end

-- Localized functions for performance
local mathAbs = math.abs
local mathFloor = math.floor
local mathMax = math.max
local mathPi = math.pi

-- Localized Spring API for performance
local spGetMyTeamID = Spring.GetMyTeamID
local spEcho = Spring.Echo

---------------------------

--[[
Notes 2025.04.21
Could we try to disable all engine range rings - and add them where needed?

- [ ] attack
	- Should already be completely handled by attack range gl4
build
radar
- [ ] Needs a circle within radarpreview
- [ ] Needs a circle when mouseovered?
sonar
seismic
jammer
sonarjammer
shield

decloak (already in widget Cloak/EMP range?)
extract
	- [ ] I dont think this is needed at all any more with mex snap
Kamikaze? (do we use that)
SelfDestruct
InterceptorOn
InterceptorOff


]]--


-------------------------------------
local autoReload = false

---------------------------------------------------------------------------------------------------------------------------
-- Bindable actions:	cursor_range_toggle - Toggles display of the attack range of the unit under the mouse cursor.
-- 						attack_range_inc - Cycle to next attack range display config for current unit type.
-- 						attack_range_dec - Cycle to previous attack range display config for current unit type.
-- The widget's individual unit type's display setup is saved in LuaUI/config/AttackRangeConfig2.lua
---------------------------------------------------------------------------------------------------------------------------
local shift_only = false -- only show ranges when shift is held down
local cursor_unit_range = true -- displays the range of the unit at the mouse cursor (if there is one)
local selectionDisableThreshold = 512	-- turns off when selection is above this number
local selectionDisableThresholdMult = 0.7

---------------------------------------------------------------------------------------------------------------------------
------------------ CONFIGURABLES --------------

local buttonConfig = {
	ally = { ground = true, AA = true, nano = true },
	enemy = { ground = true, AA = true, nano = true }
}

local colorConfig = {
	drawStencil = true,  -- whether to draw the outer, merged rings (quite expensive!)
	cannon_separate_stencil = false, -- set to true to have cannon and ground be on different stencil mask
	drawInnerRings = true, -- whether to draw inner, per attack rings (very cheap)

	externalalpha = 0.75, -- alpha of outer rings
	internalalpha = 0.12, -- alpha of inner rings
	fill_alpha = 0.12, -- this is the solid color in the middle of the stencil
	outer_fade_height_difference = 2500, -- this is the height difference at which the outer ring starts to fade out compared to inner rings
	ground = {
		color = { 1.0, 0.22, 0.05, 0.60 },
		fadeparams = { 4000, 6000, 1.0, 0.0 }, -- FadeStart, FadeEnd, StartAlpha, EndAlpha
		groupselectionfadescale = 0.75,
		externallinethickness = 3.0,
		internallinethickness = 1.8,
		minimapexternallinethickness = 1.0,
		minimapinternallinethickness = 0.5,
	},
	nano = {
		color = { 0.24, 1.0, 0.2, 0.60 },
		fadeparams = { 2000, 4000, 1.0, 0.0 }, -- FadeStart, FadeEnd, StartAlpha, EndAlpha
		groupselectionfadescale = 0.05,
		externallinethickness = 3.0,
		internallinethickness = 2.0,
		minimapexternallinethickness = 1.0,
		minimapinternallinethickness = 0.5,
	},
	AA = {
		color = { 0.8, 0.44, 2.0, 0.40 },
		fadeparams = { 2000, 5000, 1.0, 0.0 }, -- FadeStart, FadeEnd, StartAlpha, EndAlpha
		groupselectionfadescale = 0.75,
		externallinethickness = 3.0,
		internallinethickness = 1.8,
		minimapexternallinethickness = 1.5,
		minimapinternallinethickness = 0.5,
	},
	cannon = {
		color = {1.0, 0.22, 0.05, 0.60},
		fadeparams = { 5000, 8500, 1.0, 0.0  }, -- FadeStart, FadeEnd, StartAlpha, EndAlpha
		groupselectionfadescale = 0.75,
		externallinethickness = 3.0,
		internallinethickness = 1.8,
		minimapexternallinethickness = 1.0,
		minimapinternallinethickness = 0.5,
	},
	lrpc = {
		color = {1.0, 0.22, 0.05, 0.60},
		fadeparams = { 5000, 1000, 1.0, 0.5 }, -- FadeStart, FadeEnd, StartAlpha, EndAlpha
		groupselectionfadescale = 0.75,
		externallinethickness = 2.0,
		internallinethickness = 2.0, -- Not used as LRPC is not stencilled
		minimapexternallinethickness = 2.0,
		minimapinternallinethickness = 0.5,
	},
	-- ground_water = {
	-- 	color       = { 0.2, 0.5, 1.0, 0.60 },  -- RGBA blue
	-- 	fadeparams  = colorConfig.ground.fadeparams,
	-- 	groupselectionfadescale    = colorConfig.ground.groupselectionfadescale,
	-- 	externallinethickness      = colorConfig.ground.externallinethickness,
	-- 	internallinethickness      = colorConfig.ground.internallinethickness,
	-- 	minimapexternallinethickness = colorConfig.ground.minimapexternallinethickness,
	-- 	minimapinternallinethickness = colorConfig.ground.minimapinternallinethickness,
	-- },
}

-- Sub WEAPON types:

-- DGUN
colorConfig.ground_dgun = {
    color                       = colorConfig.ground.color,       -- reuse ground colour
    fadeparams                  = colorConfig.ground.fadeparams,  -- same fade curve
    groupselectionfadescale     = colorConfig.ground.groupselectionfadescale,
    externallinethickness      = colorConfig.ground.externallinethickness,
	internallinethickness      = colorConfig.ground.internallinethickness,
	minimapexternallinethickness = colorConfig.ground.minimapexternallinethickness,
	minimapinternallinethickness = colorConfig.ground.minimapinternallinethickness,
}

-- WATER WEAPONS
colorConfig.ground_water = {
  color                      = {0.32, 0.48, 1.0, 0.30},
  fadeparams                 = colorConfig.ground.fadeparams,
  groupselectionfadescale    = colorConfig.ground.groupselectionfadescale,
  externallinethickness      = colorConfig.ground.externallinethickness,
  internallinethickness      = colorConfig.ground.internallinethickness,
  minimapexternallinethickness = colorConfig.ground.minimapexternallinethickness,
  minimapinternallinethickness = colorConfig.ground.minimapinternallinethickness,
}

-- EMP (paralyzer) weapons
colorConfig.ground_emp = {
  color                       = { 0.72, 0.72, 1.0, 0.60 },    -- EMP light blue
  fadeparams                  = colorConfig.ground.fadeparams,
  groupselectionfadescale     = colorConfig.ground.groupselectionfadescale,
  externallinethickness       = colorConfig.ground.externallinethickness,
  internallinethickness       = colorConfig.ground.internallinethickness,
  minimapexternallinethickness= colorConfig.ground.minimapexternallinethickness,
  minimapinternallinethickness= colorConfig.ground.minimapinternallinethickness,
}

----------------------------------
local show_selected_weapon_ranges = true
local weaponTypeMap = { 'ground', 'nano', 'AA', 'cannon', 'lrpc' }

local unitDefRings = {} --each entry should be a unitdefIDkey to a table:

local vtoldamagetag = Game.armorTypes['vtol']
local defaultdamagetag = Game.armorTypes['default']

-- globals
local minimapUtils = VFS.Include("luaui/Include/minimap_utils.lua")
local getCurrentMiniMapRotationOption = minimapUtils.getCurrentMiniMapRotationOption
local ROTATION = minimapUtils.ROTATION
local selUnitCount = 0
local selBuilderCount = 0 -- we need builder count separately
local shifted = false
local isBuilding = false
local builders = {} -- { unitID = unitDef, ...}

local unitToggles = {}
local unitTogglesChunked = {}


local unitName = {}
local unitWeapons = {}
local unitMaxWeaponRange = {}
local unitBuildDistance = {}
local unitBuilder = {}
local unitOnOffable = {}
local unitOnOffName = {}
for udid, ud in pairs(UnitDefs) do
	unitBuilder[udid] = ud.isBuilder and (ud.canAssist or ud.canReclaim) and not (ud.isFactory and #ud.buildOptions > 0)
	if unitBuilder[udid] then
		unitBuildDistance[udid] = ud.buildDistance
	end
	unitName[udid] = ud.name
	unitWeapons[udid] = ud.weapons
	unitMaxWeaponRange[udid] = ud.maxWeaponRange
	unitOnOffable[udid] = ud.onOffable
	if ud.customParams.onoffname then
		unitOnOffName[udid] = ud.customParams.onoffname
	end
end

local chunk, err = loadfile("LuaUI/config/AttackRangeConfig2.lua")
if chunk then
	local tmp = {}
	setfenv(chunk, tmp)
	unitTogglesChunked = chunk()
end

--helpers
local function convertToBitmap(statusTable)
	if type(statusTable) ~= "table" then
		return 0
	end
	local bitmap = 0
	for i, status in ipairs(statusTable) do
		if status then
			bitmap = bitmap + 2 ^ (i - 1)
		end
	end
	return bitmap
end

local function convertToStatusTable(bitmap, numWeapons)
	local statusTable = {}
	for i = 1, numWeapons do
		local status = bitmap % 2 == 1
		table.insert(statusTable, status)
		bitmap = (bitmap - (bitmap % 2)) / 2
	end
	return statusTable
end

local function getNextWeaponCombination(currentCombination, direction)
	local numWeapons = #currentCombination
	local bitmap = convertToBitmap(currentCombination)

	if direction == 1 then
		bitmap = (bitmap + 1) % (2 ^ numWeapons)
	elseif direction == -1 then
		bitmap = (bitmap - 1) % (2 ^ numWeapons)
	end

	return convertToStatusTable(bitmap, numWeapons)
end

local function initializeUnitDefRing(unitDefID)
	local weapons = unitWeapons[unitDefID]
	unitDefRings[unitDefID]['rings'] = {}
	local weaponCount = #weapons or 0
	for weaponNum = 1, #weapons do
		local weaponDefID = weapons[weaponNum].weaponDef
		local weaponDef = WeaponDefs[weaponDefID]

		-- ── your debug & color‐pick here ──
    -- spEcho(string.format(
    --   "[AttackRange] %s.waterweapon = %s",
    --   weaponDef.name, tostring(weaponDef.waterweapon)
    -- ))

		local range = weaponDef.range
		local dps = 0
		local weaponType = unitDefRings[unitDefID]['weapons'][weaponNum]

		if weaponType ~= nil and weaponType > 0 then
			local damage = 0
			if weaponType == 3 then --AA
				damage = weaponDef.damages[vtoldamagetag]
			else
				damage = weaponDef.damages[defaultdamagetag]
			end
			dps = damage * (weaponDef.salvoSize or 1) / (weaponDef.reload or 1)
			-- local color = colorConfig[weaponTypeMap[weaponType]].color
			-- local fadeparams = colorConfig[weaponTypeMap[weaponType]].fadeparams

			-- after you have `weaponDef` and `weaponType`…
		local baseKey = weaponTypeMap[ weaponType ]      -- e.g. "ground", "AA", etc.
		local cfgKey  = baseKey

		-- 1) paralyzer/EMP weapons
		if weaponDef.paralyzer then
			cfgKey = baseKey .. "_emp"
			--spEcho("[AttackRange] using EMP colour for:", weaponDef.name)
  		-- 2) DGun override
		elseif weaponDef.type == "DGun" then
			cfgKey = baseKey .. "_dgun"
			--spEcho("[AttackRange] using DGun style for:", weaponDef.name)
		-- 2) then water override
		elseif weaponDef.waterWeapon
			or (weaponDef.customParams and weaponDef.customParams.waterweapon == "true")
		then
			cfgKey = baseKey .. "_water"
			--spEcho("[AttackRange] using water style for:", weaponDef.name)
		end

    -- safety fallback if you typo the key
    if not colorConfig[cfgKey] then
        cfgKey = baseKey
    end

    local color      = colorConfig[cfgKey].color
    local fadeparams = colorConfig[cfgKey].fadeparams

			local isCylinder = 0
			if (weaponDef.cylinderTargeting)  and (weaponDef.cylinderTargeting > 0.0) then
				isCylinder = 1
			end
			local isDgun = (weaponDef.type == "DGun") and 1 or 0

			local wName = weaponDef.name
			if (weaponDef.type == "AircraftBomb") or (wName:find("bogus")) or weaponDef.customParams.bogus or weaponDef.customParams.norangering then
				range = 0
			end
			--spEcho("weaponNum: ".. weaponNum ..", name: " .. tableToString(weaponDef.name))
			local groupselectionfadescale = colorConfig[weaponTypeMap[weaponType]].groupselectionfadescale

			--local udwp = UnitDefs[unitDefID].weapons
			-- weapons[weaponNum].maxAngleDif is :
			-- 0 for 180
			-- -1 for 360
			-- 0.707 for 90

			-- Because I cant be assed to calculate the full 3d cone-ground intersection slice within the vertex shader:
			-- We are only going to display angles for weapons that actually point forward, e.g. mainDirXYZ of 0 0 1
			-- we need to output two numbers here, and pack it into one float
			-- The integer part will be the offset around the circle, from forward dir, in degrees, +-180
			-- the fractional part will be the max left-right attack angle around the ground plane.
			-- maindir = "0 0 1" is forward
			-- exactly zero means no angle limits!
			-- maindir "0 1 0" is designed for shooting at feet prevention!

			local maxangledif = 0

			-- customParams (note the case), is a table of strings always
			if (weapons[weaponNum].maxAngleDif > -1) and
				(not (weaponDef.customParams and weaponDef.customParams.noattackrangearc)) then
				--spEcho(weaponDef.customParams)--, weapons[weaponNum].customParams.noattackarc)
				local offsetdegrees = 0
				local difffract = 0

				local weaponParams = weapons[weaponNum]
				local mdx = weaponParams.mainDirX
				local mdy = weaponParams.mainDirY
				local mdz = weaponParams.mainDirZ
				local angledif = math.acos(weapons[weaponNum].maxAngleDif) / mathPi

				-- Normalize maindir
				local length = math.diag(mdx,mdy,mdz)
				mdx = mdx/length
				mdy = mdy/length
				mdz = mdz/length

				offsetdegrees = math.atan2(mdx,mdz) * 180 / mathPi
				difffract = angledif --(1.0 - angledif ) * (0.5) -- So 0.001 is tiny aim angle, 0.9999 is full aim angle

				maxangledif = mathFloor(offsetdegrees)

				if mathAbs(mdy) > 0.01 and mathAbs(mdy) < 0.99 then -- its off the Y plane
					local modifier = math.sqrt ( 1.0 - mdy*mdy)
					difffract  = difffract * modifier
					maxangledif = maxangledif + difffract
				elseif  mathAbs(mdy) < 0.99 then
					maxangledif = maxangledif  + difffract
				else

				end



				--spEcho(string.format("%s has params offsetdegrees = %.2f MAD = %.3f (%.1f deg), diffract = %.3f md(xyz) = (%.3f,%.3f,%.3f)", weaponDef.name, offsetdegrees, weapons[weaponNum].maxAngleDif, angledif*180,  difffract, mdx,mdy,mdz))


				--spEcho("weapons[weaponNum].maxAngleDif",weapons[weaponNum].maxAngleDif, maxangledif)
				--for k,v in pairs(weapons[weaponNum]) do spEcho(k,v)end
			end

			--if weapons[weaponNum].maxAngleDif then	spEcho(weapons[weaponNum].maxAngleDif,'for',weaponDef.name, 'saved as',maxangledif ) end

			local ringParams = { range, color[1], color[2], color[3], color[4], --5
				fadeparams[1], fadeparams[2], fadeparams[3], fadeparams[4], --9
				weaponDef.projectilespeed or 1, --10
				isCylinder,-- and 1 or 0, (11)
				weaponDef.heightBoostFactor or 0, --12
				weaponDef.heightMod or 0, --13
				groupselectionfadescale, --14
				weaponType, --15
				isDgun, --16
				maxangledif  --17
			}
			unitDefRings[unitDefID]['rings'][weaponNum] = ringParams
		end
	end

	-- for builders, we need to add a special nano ring def
	if unitBuilder[unitDefID] then
		local range = unitBuildDistance[unitDefID]
		local color = colorConfig['nano'].color
		local fadeparams = colorConfig['nano'].fadeparams
		local groupselectionfadescale = colorConfig['nano'].groupselectionfadescale

		local ringParams = { range, color[1], color[2], color[3], color[4],
			fadeparams[1], fadeparams[2], fadeparams[3], fadeparams[4],
			1,
			false,
			0,
			0,
			groupselectionfadescale,
			2,
			0
		}
		unitDefRings[unitDefID]['rings'][weaponCount + 1] = ringParams -- weaponCount + 1 is nano
	end
end

local function initUnitList()
	unitDefRings = {}

	for unitDefID, _ in pairs(unitDefRings) do
		initializeUnitDefRing(unitDefID)
	end
end

--Button display configuration
--position only relevant if no saved config data found

local myAllyTeam            = Spring.GetMyAllyTeamID()
local myTeamID              = spGetMyTeamID()

--------------------------------------------------------------------------------

local glDepthTest           = gl.DepthTest
local glLineWidth           = gl.LineWidth
local glTexture             = gl.Texture
local glClear               = gl.Clear
local glColorMask           = gl.ColorMask
local glStencilTest         = gl.StencilTest
local glStencilMask         = gl.StencilMask
local glStencilFunc         = gl.StencilFunc
local glStencilOp           = gl.StencilOp
local GL_STENCIL_BUFFER_BIT = GL.STENCIL_BUFFER_BIT
local GL_TRIANGLE_FAN       = GL.TRIANGLE_FAN
local GL_LEQUAL             = GL.LEQUAL
local GL_LINE_LOOP          = GL.LINE_LOOP
local GL_NOTEQUAL           = GL.NOTEQUAL

local GL_KEEP               = 0x1E00 --GL.KEEP
local GL_REPLACE            = GL.REPLACE --GL.KEEP

local spGetUnitDefID        = Spring.GetUnitDefID
local spGetUnitPosition     = Spring.GetUnitPosition
local spGetUnitWeaponVectors=Spring.GetUnitWeaponVectors
local spGetUnitAllyTeam     = Spring.GetUnitAllyTeam
local spGetMouseState       = Spring.GetMouseState
local spTraceScreenRay      = Spring.TraceScreenRay
local GetModKeyState        = Spring.GetModKeyState
local GetActiveCommand      = Spring.GetActiveCommand
local GetSelectedUnits      = Spring.GetSelectedUnits
local chobbyInterface

local CMD_ATTACK 		  = CMD.ATTACK
local CMD_FIGHT 		  = CMD.FIGHT
local CMD_AREA_ATTACK 	  = CMD.AREA_ATTACK
local CMD_MANUALFIRE	  = CMD.MANUALFIRE

function widget:TextCommand(command)
	local mycommand = false --buttonConfig["enemy"][tag]

	if string.find(command, "defrange", nil, true) then
		mycommand = true
		local ally = 'ally'
		local rangetype = 'ground'
		local enabled = false
		if string.find(command, "enemy", nil, true) then
			ally = 'enemy'
		end
		if string.find(command, "nano", nil, true) then
			rangetype = 'nano'
		elseif string.find(command, "AA", nil, true) then
			rangetype = 'AA'
		end
		if string.find(command, "+", nil, true) then
			enabled = true
		end
		buttonConfig[ally][rangetype] = enabled
		spEcho("Range visibility of " .. ally .. " " .. rangetype .. " attacks set to", enabled)
		return true
	end

	return false
end

------ GL4 THINGS  -----
-- AA and cannons:
local largeCircleVBO = nil
local largeCircleSegments = 1024

-- others:
local smallCircleVBO = nil
local smallCircleSegments = 128

local weaponTypeToString = { "ground", "nano", "AA", "cannon", 'lrpc' }
local allyenemypairs = { "ally", "enemy" }
local attackRangeClasses = { 'enemyground', 'enemyAA', 'enemynano', 'allyground', 'allyAA', 'enemycannon', 'allycannon',
	'allynano', 'allylrpc', 'enemylrpc' }
local attackRangeVAOs = {}

local circleInstanceVBOLayout = {
	{ id = 1, name = 'posscale',         size = 4 }, -- abs pos for static units, offset for dynamic units, scale is actual range, Y is turretheight
	{ id = 2, name = 'color1',           size = 4 }, --  vec4 the color of this new
	{ id = 3, name = 'visibility',       size = 4 }, --- vec4 FadeStart, FadeEnd, StartAlpha, EndAlpha
	{ id = 4, name = 'projectileParams', size = 4 }, --- projectileSpeed, iscylinder, heightBoostFactor , heightMod
	{ id = 5, name = 'additionalParams', size = 4 }, --- groupselectionfadescale, weaponType, ISDGUN, MAXANGLEDIF
	{ id = 6, name = 'instData',         size = 4, type = GL.UNSIGNED_INT },
}

local LuaShader = gl.LuaShader
local InstanceVBOTable = gl.InstanceVBOTable
local popElementInstance = InstanceVBOTable.popElementInstance
local pushElementInstance = InstanceVBOTable.pushElementInstance

local attackRangeShader = nil

local shaderSourceCache = {
	shaderName = 'Attack Range GL4',
	vssrcpath = "LuaUI/Shaders/weapon_range_rings_unified_gl4.vert.glsl",
	fssrcpath = "LuaUI/Shaders/weapon_range_rings_unified_gl4.frag.glsl",
	shaderConfig = {
		MYGRAVITY = Game.gravity + 0.1,
		STATICUNITS = 0,
		DEBUG = autoReload and 1 or 0,
		MOUSEOVERALPHAMULTIPLIER = 1.0,
	},
	uniformInt = {
		heightmapTex = 0,
		losTex = 1,
		mapNormalTex = 2,
	},
	uniformFloat = {
		lineAlphaUniform = 1,
		cannonmode = 0,
		fadeDistOffset = 0,
		drawMode = 0,
		selBuilderCount = 1.0,
		selUnitCount = 1.0,
		inMiniMap = 0.0,
	},
}

local function goodbye(reason)
	spEcho("AttackRange GL4 widget exiting with reason: " .. reason)
	widgetHandler:RemoveWidget()
end


local cacheTable = {}
for i = 1, 24 do cacheTable[i] = 0 end


-- code for selected units start here
local selectedUnits = {}
local selUnits = {}
local updateSelection = false
local selections = {} -- contains params for added vaos
local mouseUnit
local mouseovers = {} -- mirroring selections, but for mouseovers

local unitsOnOff = {} -- unit weapon toggle states, tracked from CommandNotify (also building on off status)
local myTeam = spGetMyTeamID()

-- mirrors functionality of UnitDetected
local function AddSelectedUnit(unitID, mouseover)
	--if not show_selected_weapon_ranges then return end
	local collections = selections
	if mouseover then
		collections = mouseovers
	end

	local unitDefID = spGetUnitDefID(unitID)
	if not unitDefID then return end
	if collections[unitID] ~= nil then return end

	--- if unittype is toggled off we don't proceed at all
	local currentUnitName = unitName[unitDefID]
	local alliedUnit = (spGetUnitAllyTeam(unitID) == myAllyTeam)
	local allystring = alliedUnit and "ally" or "enemy"

	local weapons = unitWeapons[unitDefID]
	if (not weapons or #weapons == 0) and not unitBuilder[unitDefID] then return end -- no weapons and not builder, nothing to add
	-- we want to add to unitDefRings here if it doesn't exist
	if not unitDefRings[unitDefID] then
		-- read weapons and add them to weapons table, then add to entry
		local entry = { weapons = {} }
		for weaponNum = 1, #weapons do
			local weaponDefID = weapons[weaponNum].weaponDef
			local weaponDef = WeaponDefs[weaponDefID]
			local weapon = weapons[weaponNum]

			if true then --range > 0 then -- trying something different
				if weapon.onlyTargets and weapon.onlyTargets.vtol then
					entry.weapons[weaponNum] = 3 -- weaponTypeMap[3] is "AA"
				elseif weaponDef.type == "Cannon" then
					-- if weaponDef.range < 700 then
					-- 	entry.weapons[weaponNum] = 1 -- weaponTypeMap[1] is "ground"
					if weaponDef.range > 2600 then
						entry.weapons[weaponNum] = 5 -- weaponTypeMap[5] is "lrpc"
					else
						entry.weapons[weaponNum] = 4 -- weaponTypeMap[4] is "cannon"
					end
				elseif weaponDef.type == "Melee" then
					entry.weapons[weaponNum] = 1 -- weaponTypeMap[1] is "ground"
				else
					if weaponDef.range < 700 then
						entry.weapons[weaponNum] = 1 -- weaponTypeMap[1] is "ground
					elseif weaponDef.range > 2600 then
						entry.weapons[weaponNum] = 5 -- weaponTypeMap[5] is "lrpc"
					else
						entry.weapons[weaponNum] = 1 -- weaponTypeMap[1] is "ground"
					end
				end
			end
		end
		-- builder can have no weapon but still need to be added
		if unitBuilder[unitDefID] then
			local wt = entry.weapons
			wt[#wt + 1] = 2 -- 2 is nano
		end

		unitDefRings[unitDefID] = entry -- we insert the entry so we can reuse existing code
		-- we need to initialize the other params
		initializeUnitDefRing(unitDefID)
	end


	local x, y, z, mpx, mpy, mpz, apx, apy, apz = spGetUnitPosition(unitID, true, true)

	--for weaponNum = 1, #weapons do
	local addedRings = 0
	local weaponTypes = unitDefRings[unitDefID]['weapons']
	for j, weaponType in pairs(weaponTypes) do
		local drawIt = true
		-- we need to check if the unit has on/off weapon states, and only add the one active
		local weaponOnOff
		-- on off can be set on a building, we need to check that
		if unitOnOffable[unitDefID] and not unitOnOffName[unitDefID] then -- if it's a building with actual on/off, we display range if it's on
			weaponOnOff = unitsOnOff[unitID] or 1
			drawIt = (weaponOnOff == 1)
		elseif unitOnOffable[unitDefID] and unitOnOffName[unitDefID] then -- this is a unit or building with 2 weapons
			weaponOnOff = unitsOnOff[unitID] or 0
			drawIt = ((weaponOnOff + 1) == j) or
			#weaponTypes == 1 -- remember weaponOnOff is 0 or 1, weapon number starts from 1
		end

		-- we add checks here for the display toggle status from config
		if unitToggles[currentUnitName] then -- only if there's a config, else default is to draw it
			local wToggleStatuses = unitToggles[currentUnitName][allystring]
			if type(wToggleStatuses) == 'table' then
				drawIt = wToggleStatuses[j] and drawIt
			else
				-- fixing the unitToggles table since something was corrupted
				local entry = {}
				for i=1, #weaponTypes do
					entry[i] = true
				end
				unitToggles[currentUnitName][allystring] = entry
			end
		end

		local ringParams = unitDefRings[unitDefID]['rings'][j]
		if drawIt and ringParams[1] > 0 then

			local weaponID = j
			-- TODO:
			-- Weapons aim from their WPY positions, but that can change for e.g. popups!
			-- This is quite important to pass in as posscale.y!
			-- Need to cache weaponID of the respective weapon for this to work
			-- also assumes that weapons are centered onto drawpos
			local wpx, wpy, wpz, wdx, wdy, wdz = spGetUnitWeaponVectors(unitID, weaponID)
			--spEcho("unitID", unitID,"weaponID", weaponID, "y", y, "mpy",  mpy,"wpy", wpy)

			-- Now this is a truly terrible hack, we cache each unitDefID's max weapon turret height at position 18 in the table
			-- so it only goes up with popups
			local turretHeight = mathMax(ringParams[18] or 0, (wpy or mpy ) - y)
			ringParams[18] = turretHeight


			cacheTable[1] = mpx
			cacheTable[2] = turretHeight
			cacheTable[3] = mpz
			local vaokey = allystring .. weaponTypeToString[weaponType]

			for i = 1, 17 do
				cacheTable[i + 3] = ringParams[i]
			end

			if false then
				local s = ' '
				for i = 1, 20 do
					s = s .. "; " .. tostring(cacheTable[i])
				end
				if true then
					spEcho("Adding rings for", unitID, x, z)
					spEcho("added", vaokey, s)
				end
			end
			local instanceID = 10000000 * (mouseover and 1 or 0) + 1000000 * weaponType + unitID +
				100000 *
				j -- weapon index needs to be included here for uniqueness
			pushElementInstance(attackRangeVAOs[vaokey], cacheTable, instanceID, true, false, unitID)
			addedRings = addedRings + 1
			if collections[unitID] == nil then
				--lazy creation
				collections[unitID] = {
					posx = mpx,
					posy = mpy,
					posz = mpz,
					vaokeys = {},
					allied = alliedUnit,
					unitDefID = unitDefID
				}
			end
			collections[unitID].vaokeys[instanceID] = vaokey
		end
	end
	-- we cheat here and update builder count
	if unitBuilder[unitDefID] and addedRings > 0 then
		selBuilderCount = selBuilderCount + 1
	end
end

local function RemoveSelectedUnit(unitID, mouseover)
	--if not show_selected_weapon_ranges then return end
	local collections = selections
	if mouseover then collections = mouseovers end

	local removedRings = 0
	if collections[unitID] then
		local collection = collections[unitID]
		if not collection then return end
		for instanceKey, vaoKey in pairs(collection.vaokeys) do
			--spEcho(vaoKey,instanceKey)
			popElementInstance(attackRangeVAOs[vaoKey], instanceKey)
			removedRings = removedRings + 1
		end
		-- before we get rid of the definition we cheat again
		if unitBuilder[collections[unitID].unitDefID] then
			selBuilderCount = selBuilderCount - 1
		end
		collections[unitID] = nil
	end
end

function widget:SelectionChanged(sel)
	updateSelection = true
end

local function InitializeBuilders()
	builders = {}
	for _, unitID in ipairs(Spring.GetTeamUnits(spGetMyTeamID())) do
		if unitBuilder[spGetUnitDefID(unitID)] then
			builders[unitID] = true
		end
	end
end

local function makeShaders()
	attackRangeShader = LuaShader.CheckShaderUpdates(shaderSourceCache, 0) or attackRangeShader
	if not attackRangeShader then
		goodbye("Failed to compile attackRangeShader GL4 ")
		return false
	end
	return true
end

local function initGL4()
	smallCircleVBO = InstanceVBOTable.makeCircleVBO(smallCircleSegments)
	largeCircleVBO = InstanceVBOTable.makeCircleVBO(largeCircleSegments)
	for i, atkRangeClass in ipairs(attackRangeClasses) do
		attackRangeVAOs
		[atkRangeClass] = InstanceVBOTable.makeInstanceVBOTable(circleInstanceVBOLayout, 20, atkRangeClass.. "_attackrange_gl4", 6) -- 6 is unitIDattribID (instData)
		if atkRangeClass:find("lrpc", nil, true) or atkRangeClass:find("AA", nil, true) then
			attackRangeVAOs
			[atkRangeClass].vertexVBO = largeCircleVBO
			attackRangeVAOs
			[atkRangeClass].numVertices = largeCircleSegments
		else
			attackRangeVAOs
			[atkRangeClass].vertexVBO = smallCircleVBO
			attackRangeVAOs
			[atkRangeClass].numVertices = smallCircleSegments
		end
		local newVAO = InstanceVBOTable.makeVAOandAttach(attackRangeVAOs
			[atkRangeClass].vertexVBO, attackRangeVAOs
			[atkRangeClass].instanceVBO)
		attackRangeVAOs
		[atkRangeClass].VAO = newVAO
	end
	return makeShaders()
end

-- refresh all display according to toggle status
local function RefreshEverything()
	-- what about just reinitialize?
	attackRangeVAOs = {}
	selections = {}
	selUnitCount = 0
	selectedUnits = {}
	selUnits = {}
	mouseovers = {}

	widget:Initialize()
end

local function toggleShowSelectedRanges(on)
	if show_selected_weapon_ranges == on then return end
	show_selected_weapon_ranges = on
end

local function toggleCursorRange(_, _, args)
	cursor_unit_range = not cursor_unit_range
	spEcho("Cursor unit range set to: " .. (cursor_unit_range and "ON" or "OFF"))
end

-- direction should be 1 or -1 (next or previous bitmap value)
local function cycleUnitDisplay(direction)
	if (selUnitCount > 1) or (selUnitCount == 0) then
		spEcho("Please select only one unit to change display setting!")
		return
	end
	local unitID = selectedUnits[1]
	if not unitID then return end

	local alliedUnit = (spGetUnitAllyTeam(unitID) == myAllyTeam)
	local allystring = alliedUnit and "ally" or "enemy"
	local unitDefID = spGetUnitDefID(unitID)
	if unitMaxWeaponRange[unitDefID] == 0 and not unitBuilder[unitDefID] then
		spEcho("Unit has no weapon range!")
		return
	end
	local name = unitName[unitDefID]
	local wToggleStatuses = {}
	local newToggleStatuses = {}
	unitToggles[name] = unitToggles[name] or {}
	if not unitToggles[name][allystring] then -- default toggle is on, we set it to off (0)
		for i = 1, #unitDefRings[unitDefID].weapons do
			wToggleStatuses[i] = true -- every ring defined weapon is on by default
		end
		newToggleStatuses = getNextWeaponCombination(wToggleStatuses, direction)
		unitToggles[name][allystring] = newToggleStatuses
	else -- there's already something stored here so we toggle this value
		wToggleStatuses = unitToggles[name][allystring]
		newToggleStatuses = getNextWeaponCombination(wToggleStatuses, direction)
		unitToggles[name][allystring] = newToggleStatuses
	end
	local bitmap = convertToBitmap(newToggleStatuses)
	local maxConfigBitmap = 2 ^ #newToggleStatuses - 1
	-- some crude info display for now
	spEcho("Changed range display of " .. name ..
		" to config " .. tostring(bitmap) ..
		": " .. table.toString(unitToggles[name][allystring]))

	-- write toggle changes to file
	table.save(unitToggles, "LuaUI/config/AttackRangeConfig2.lua", "--Attack Range Display Configuration (v2)")
	-- play a sound cue based on status bitmap state: max means all on, 0 means all off
	local soundEffect = 'Sounds/commands/cmd-defaultweapon.wav'
	local soundEffectOn = 'Sounds/commands/cmd-on.wav'
	local soundEffectOff = 'Sounds/commands/cmd-off.wav'
	local volume = 0.3
	if bitmap == maxConfigBitmap then
		soundEffect = soundEffectOn
		volume = 1.0
	elseif bitmap == 0 then
		soundEffect = soundEffectOff
		volume = 0.6
	end
	Spring.PlaySoundFile(soundEffect, volume, 'ui')

	RefreshEverything()
end

local function cycleUnitDisplayHandler(_, _, _, data)
	local data = data or {}
	local direction = data["direction"]
	cycleUnitDisplay(direction)
end

function widget:PlayerChanged(playerID)
    myAllyTeamID = Spring.GetLocalAllyTeamID()
    myTeamID = Spring.GetLocalTeamID()

	InitializeBuilders()
end

function widget:Initialize()
	initUnitList()

	if initGL4() == false then
		widgetHandler:RemoveWidget(self)
		return
	end

	unitTogglesChunked = unitTogglesChunked or {}
	for i, v in pairs(unitTogglesChunked) do
		unitToggles[i] = v
	end

	widgetHandler:AddAction("cursor_range_toggle", toggleCursorRange, nil, "p")
	widgetHandler:AddAction("attack_range_inc", cycleUnitDisplayHandler, {direction = 1}, "p")
	widgetHandler:AddAction("attack_range_dec", cycleUnitDisplayHandler, {direction = -1}, "p")

	myAllyTeam = Spring.GetMyAllyTeamID()
	myTeamID = spGetMyTeamID()

	updateSelection = true
	local _, _, _, shift = GetModKeyState()
	if shift_only and not shift then
		toggleShowSelectedRanges(false)
	end
	InitializeBuilders()

	WG.attackrange = {}
	WG.attackrange.getShiftOnly = function()
		return shift_only
	end
	WG.attackrange.setShiftOnly = function(value)
		shift_only = value
		widget:Initialize()
	end
	WG.attackrange.getCursorUnitRange = function()
		return cursor_unit_range
	end
	WG.attackrange.setCursorUnitRange = function(value)
		cursor_unit_range = value
		widget:Initialize()
	end
	WG.attackrange.getNumRangesMult = function()
		return selectionDisableThresholdMult
	end
	WG.attackrange.setNumRangesMult = function(value)
		selectionDisableThresholdMult = value
	end
end

function widget:Shutdown()
	widgetHandler:RemoveAction("cursor_range_toggle", "p")
	widgetHandler:RemoveAction("attack_range_inc", "p")
	widgetHandler:RemoveAction("attack_range_dec", "p")
end

local gameFrame = 0

function widget:GameFrame(gf)
	gameFrame = gf
end

local function RefreshSelectedUnits()
	local newSelUnits = {}
	for i, unitID in ipairs(selectedUnits) do
		newSelUnits[unitID] = true
		if not selUnits[unitID] and selUnitCount < mathFloor(selectionDisableThreshold * selectionDisableThresholdMult) then
			AddSelectedUnit(unitID)
		end
	end
	for unitID, _ in pairs(selUnits) do
		if not newSelUnits[unitID] then
			RemoveSelectedUnit(unitID)
		end
	end
	selUnits = newSelUnits
end

local function UpdateSelectedUnits()
	selectedUnits = GetSelectedUnits()
	selUnitCount = #selectedUnits
	updateSelection = false

	RefreshSelectedUnits()
end

-- whether to draw the build range of all builders - only happens when isBuilding
local function DrawBuilders()
	if isBuilding then
		for unitID, _ in pairs(builders) do
			if not selUnits[unitID] then
				AddSelectedUnit(unitID)
			end
		end
	else -- not building, we remove all builders that aren't selected
		for unitID, _ in pairs(builders) do
			if not selUnits[unitID] then
				RemoveSelectedUnit(unitID)
			end
		end
	end
end

function widget:KeyPress(key, mods, isRepeat)
	if key == 304 then
		shifted = true
	end
end

function widget:KeyRelease(key, mods, isRepeat)
	if key == 304 then
		shifted = false
	end
end

function widget:Update(dt)
	if updateSelection and gameFrame % 3 == 0 then
		UpdateSelectedUnits()
	end

	if show_selected_weapon_ranges and cursor_unit_range and gameFrame % 3 == 1 then
		local mx, my, _, mmb, _, mouseOffScreen, cameraPanMode = spGetMouseState()
		if mouseOffScreen or mmb or cameraPanMode then return end

		local desc, args = spTraceScreenRay(mx, my, false)
		local mUnitID
		if desc and desc == "unit" then
			mUnitID = args
		else
			mUnitID = nil
			RemoveSelectedUnit(mouseUnit, true)
			mouseUnit = nil
		end
		if mUnitID and (mUnitID ~= mouseUnit) then
			RemoveSelectedUnit(mouseUnit, true)
			if not selections[mUnitID] then
				AddSelectedUnit(mUnitID, true)
			end
			mouseUnit = mUnitID
		end
	end

	if gameFrame % 3 == 2 then
		local cmdIndex, cmdID, cmdType, cmdName = GetActiveCommand()
		if shift_only then
			if shifted then
				toggleShowSelectedRanges(true)
			else
				if cmdID == 20 then toggleShowSelectedRanges(true) end
				if not cmdID or cmdID ~= 20 then toggleShowSelectedRanges(false) end
			end
		end
		local isBuildingNow = (cmdID ~= nil) and (cmdID < 0) -- we're building, need to draw builder ranges
		if isBuilding ~= isBuildingNow then
			isBuilding = isBuildingNow
			DrawBuilders()
		end
	end
end

function widget:UnitCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOpts, cmdTag)
	if unitTeam == myTeam and cmdID == 85 then -- my unit, "OnOff" command
		unitsOnOff[unitID] = cmdParams[1]
		RemoveSelectedUnit(unitID)          -- need to refresh this unit's ring
		AddSelectedUnit(unitID)
	end
end

function widget:RecvLuaMsg(msg, playerID)
	if msg:sub(1, 18) == 'LobbyOverlayActive' then
		chobbyInterface = (msg:sub(1, 19) == 'LobbyOverlayActive1')
	end
end

local drawcounts = {}

local cameraHeightFactor = 0

local function GetCameraHeightFactor()
	return 1
end

local groundnukeair = { "ground", "nano", "AA" }
local cannonlrpc = { "cannon", "lrpc" }
local function DRAWRINGS(primitiveType, linethickness)
	if not show_selected_weapon_ranges and not isBuilding then return end
	local stencilMask
	attackRangeShader:SetUniform("cannonmode", 0)
	for i, allyState in ipairs(allyenemypairs) do
		for j, wt in ipairs(groundnukeair) do
			local atkRangeClass = allyState .. wt
			local iT = attackRangeVAOs[atkRangeClass]
			stencilMask = 2 ^ (4 * (i - 1) + (j - 1)) -- from 1 to 128
			drawcounts[stencilMask] = iT.usedElements
			if iT.usedElements > 0 then --and buttonConfig[allyState][wt] then
				if linethickness then
					glLineWidth(colorConfig[wt][linethickness] * cameraHeightFactor)
				end
				glStencilMask(stencilMask) -- only allow these bits to get written
				-- Bitwise AND the stencil buffer with stencilMask when GL_NOTEQUAL:
				glStencilFunc(GL_NOTEQUAL, stencilMask, stencilMask) -- what to do with the stencil
				iT.VAO:DrawArrays(primitiveType, iT.numVertices, 0, iT.usedElements, 0) -- +1!!!
			end
		end
	end

	attackRangeShader:SetUniform("cannonmode", 1)
	for i, allyState in ipairs(allyenemypairs) do
		for j, wt in ipairs(cannonlrpc) do
			if linethickness or wt == 'cannon' then
				local atkRangeClass = allyState .. wt
				local iT = attackRangeVAOs[atkRangeClass]
				local stencilOffset = colorConfig.cannon_separate_stencil and 3 or 0
				stencilMask = 2 ^ (4 * (i - 1) + stencilOffset) -- if 0 then it's on the same as "ground"
				drawcounts[stencilMask] = iT.usedElements
				if iT.usedElements > 0 then
					if linethickness then
						glLineWidth(colorConfig[wt][linethickness] * cameraHeightFactor)
					end
					glStencilMask(stencilMask)
					glStencilFunc(GL_NOTEQUAL, stencilMask, stencilMask)
					iT.VAO:DrawArrays(primitiveType, iT.numVertices, 0, iT.usedElements, 0) -- +1!!!
				end
			end
		end
	end
end

function widget:DrawWorld(inMiniMap)

	if autoReload then
		attackRangeShader = LuaShader.CheckShaderUpdates(shaderSourceCache) or attackRangeShader
	end

	if chobbyInterface or not (selUnitCount > 0 or mouseUnit) then return end
	if not Spring.IsGUIHidden() and (not WG['topbar'] or not WG['topbar'].showingQuit()) then
		cameraHeightFactor = GetCameraHeightFactor() * 0.5 + 0.5
		glTexture(0, "$heightmap")
		glTexture(1, "$info")
		-- glTexture(2, '$normals')
		-- Stencil Setup
		-- https://learnopengl.com/Advanced-OpenGL/Stencil-testing
		if colorConfig.drawStencil then
			glClear(GL_STENCIL_BUFFER_BIT)   -- clear previous stencil
			glDepthTest(false)               -- always draw, ignore depth test

			-- Draw the filled circles onto the stencil buffer
			glStencilTest(true)              -- enable stencil test
			glStencilMask(255)               -- set all 8 bits to writeable

			-- 1. Stencil test fails: GL_KEEP existing stencil value
			-- 2. Z test fails: GL_KEEP existing stencil value
			-- 3. Both tests pass: GL_REPLACE stencil value with desired number
			glStencilOp(GL_KEEP, GL_KEEP, GL_REPLACE) -- Set The Stencil Buffer To [mask] Where Draw Any Polygon

			attackRangeShader:Activate()
			attackRangeShader:SetUniform("selUnitCount", selUnitCount)
			attackRangeShader:SetUniform("selBuilderCount", selBuilderCount)
			attackRangeShader:SetUniform("drawMode", 0.0)
			attackRangeShader:SetUniform("inMiniMap", inMiniMap and 1.0 or 0.0)
			attackRangeShader:SetUniformInt("rotationMiniMap", getCurrentMiniMapRotationOption() or ROTATION.DEG_0)
			attackRangeShader:SetUniform("drawAlpha", colorConfig.fill_alpha)
			attackRangeShader:SetUniform("fadeDistOffset", colorConfig.outer_fade_height_difference)

			DRAWRINGS(GL_TRIANGLE_FAN) -- FILL THE CIRCLES

			-- Draw the outside rings by testing the stencil buffer
			glLineWidth(mathMax(0.1, 4 + math.sin(gameFrame * 0.04) * 10))
			glColorMask(true, true, true, true) -- re-enable color drawing
			glStencilMask(0)
			glDepthTest(GL_LEQUAL) -- test for depth on these outside cases

			attackRangeShader:SetUniform("lineAlphaUniform", colorConfig.externalalpha)
			attackRangeShader:SetUniform("drawMode", 1.0)
			attackRangeShader:SetUniform("drawAlpha", 1.0)

			DRAWRINGS(GL_LINE_LOOP, inMiniMap and 'minimapexternallinethickness' or 'externallinethickness') -- DRAW THE OUTER RINGS

			-- This is the correct way to exit out of the stencil mode, to not break drawing of area commands:
			glStencilTest(false) -- Disable the stencil test
			glStencilMask(255)   -- Set all bits of stencil buffer to writeable
			glStencilOp(GL_KEEP, GL_KEEP, GL_KEEP) -- Reset default stencil operation (which is the do nothing operation)
			glClear(GL_STENCIL_BUFFER_BIT) -- Clear the stencil buffer for whichever widget wants it next (this is probably redundant)
			-- All the above are needed :O
		end

		-- After all the stenciled drawings, we have disabled the stencil test, so we can draw the inner rings
		if colorConfig.drawInnerRings then
			attackRangeShader:SetUniform("lineAlphaUniform", colorConfig.internalalpha)
			attackRangeShader:SetUniform("drawMode", 2.0)
			attackRangeShader:SetUniform("fadeDistOffset", 0)
			DRAWRINGS(GL_LINE_LOOP, inMiniMap and 'minimapinternallinethickness' or 'internallinethickness') -- DRAW THE INNER RINGS
		end

		attackRangeShader:Deactivate()

		glTexture(0, false)
		glTexture(1, false)
		glDepthTest(false)
	end
end

function widget:DrawInMiniMap()
	-- TODO:
	-- do a sanity check and dont draw here if there are too many units selected...
	widget:DrawWorld(true)
end

function widget:VisibleUnitAdded(unitID, unitDefID, unitTeam)
	if unitTeam == myTeamID and unitBuilder[unitDefID] then
		builders[unitID] = true
	end
end

function widget:VisibleUnitRemoved(unitID, unitDefID, unitTeam)
	unitDefID = unitDefID or spGetUnitDefID(unitID)
	unitTeam = unitTeam or Spring.GetUnitTeam(unitID)
	RemoveSelectedUnit(unitID, false)
	builders[unitID] = nil
end




if autoReload then
    function widget:DrawScreen()
        if attackRangeShader.DrawPrintf then attackRangeShader.DrawPrintf(0, 64) end
    end
end


--SAVE / LOAD CONFIG FILE
-----------------------------------------------------------------------------------------
-- Useful config options to have for players in options menu are:
-- 1. "shift_only" - only show ranges when shift is held
-- 2. "cursor_unit_range" - show range of unit under cursor
-- 3. "colorConfig" - table of color options BUT ONLY THE FOLLOWING FIELDS:
--		"fill_alpha", "externalalpha", "internalalpha", "outer_fade_height_difference"
--		"ground.externallinethickness", "ground.internallinethickness"
--		"AA.externallinethickness", "AA.internallinethickness"
--		"cannon.externallinethickness", "cannon.internallinethickness"
--		"nano.externallinethickness", "nano.internallinethickness"
-- Other values inside colorConfig are potentially useful but not nearly as important
--
-- The rest of the config data should be left to advanced users to tweak in widget's own config files (which will be generated upon use)
-- The config file is saved and load at LuaUI/config/AttackRangeConfig2.lua
-----------------------------------------------------------------------------------------
function widget:GetConfigData()
	return {
		shift_only = shift_only,
		cursor_unit_range = cursor_unit_range,
		selectionDisableThresholdMult = selectionDisableThresholdMult,
	}
end

function widget:SetConfigData(data)
	if data.shift_only ~= nil then
		shift_only = data.shift_only
	end
	if data.cursor_unit_range ~= nil then
		cursor_unit_range = data.cursor_unit_range
	end
	if data.selectionDisableThresholdMult ~= nil then
		selectionDisableThresholdMult = data.selectionDisableThresholdMult
	end
end
