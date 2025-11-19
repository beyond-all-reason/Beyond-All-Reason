include("keysym.h.lua")

local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name      = "Defense Range GL4",
		desc      = "Displays range of defenses (enemy and ally)",
		author    = "Beherith", -- yeah this is now a rewrite from scratch
		date      = "2021.04.26",
		license   = "Lua: GPLv2, GLSL: (c) Beherith (mysterme@gmail.com)",
		layer     = -100,
		enabled   = true,
		depends   = {'gl4'},
	}
end


-- Localized functions for performance
local mathMax = math.max
local tableInsert = table.insert

-- Localized Spring API for performance
local spEcho = Spring.Echo
local spGetUnitTeam = Spring.GetUnitTeam

-- GL4 dev Notes:
-- AA should be purple :D
-- heightboost is going to be a bitch - > use $heightmap and hope that heightboost is kinda linear
-- Vertex Buffer should have: a circle with 256 subdivs
  -- basically a set of vec2's
  -- each elem of this vec2 should also have a normal vector, for ez heightboost
-- whole thing needs an 'override' type thing,
-- needs masking of the instance buffer


-- configurability:
  -- have multiple VBOs' for each unit type?

-- TODO2
--X separate cylsph and cannon types!!!!
--X smaller vertex VBO for regular, larger for cannons
--X separate air and ground types and show based on selection (UNIFORM OR NOT?)
-- better animations!!! -- NOT NEEDED
--x correct colorization
--X correct popElementInstance keys
-- FADE/VIS CONTROL:
	-- 0. Color gets darkened outside los
	-- 1. out of map gets faded to 0
	-- 2. zoomed out anti fades in, all others fade out
	-- 3. mouse will always return it to full vis, with teamcolorized stipples at 1/4th distribution

	--X allow for distance fade config for each class
	--X minalpha, maxalpha, fadestart, fadend
	--X also pass in mouse cursor ground pos as uniform, and fade ground def based on that :)
	--X uniforms: mousemapx, mousemapz, selectiontype (air, ground, mixed, none), globalalpha
--X sphcyl resample with heightmod boosting
--X add height offsets to common turrets!
-- raytracin' cannons?
--X do something with LOS (darken to half?)
--X cordoom multiweapon :)
--X merge mobile antis into this

-- TODO3: 2022.10.10
  -- allow specs to enable? Doesnt make much sense with new stencil based drawing...
  -- X LRPCs
  -- X Fog
  -- X dont check allied defenses for losness
  -- X use luashader uvhm implementation
  -- X fix mobile antis
  -- isallied is totally wrong
  -- dont check for losness in non fullview spec mode!
  -- smartly reinit when selected allyteam changes and there are > 2 allyteams


------------------ CONFIGURABLES --------------

local autoReload = false

local enabledAsSpec = true

local buttonConfig = {
	ally = { ground = false, air = false, nuke = true , cannon = false, lrpc = false},
	enemy = { ground = true, air = true, nuke = true , cannon = true, lrpc = false}
}

local colorConfig = { --An array of R, G, B, Alpha
    drawStencil = true, -- wether to draw the outer, merged rings (quite expensive!)
    distanceScaleStart = 2000, -- Linewidth is 100% up to this camera height
    distanceScaleEnd = 8000, -- Linewidth becomes 50% above this camera height
	drawAllyCategoryBuildQueue = true,
    ground = {
        color = {1.3, 0.18, 0.04, 0.70},
        fadeparams = { 2200, 5500, 1.0, 0.0}, -- FadeStart, FadeEnd, StartAlpha, EndAlpha
        externallinethickness = 5.0, -- can be 2 or 3 if we can distiquish its looks from attackranges
        internallinethickness = 3.0, -- can be 1.8 if we can distiquish its looks from attackranges
		stenciled = true,
		cannonMode = false,
		stencilMask = 1,
		externalalpha = 0.75, -- alpha of outer rings
		internalalpha = 0.10, -- alpha of inner rings
    },
    air = {
        color = {0.8, 0.44, 1.6, 0.70},
        fadeparams = { 3200, 8000, 0.4, 0.0}, -- FadeStart, FadeEnd, StartAlpha, EndAlpha
        externallinethickness = 5.0,
        internallinethickness = 3.0,
		stenciled = true,
		cannonMode = false,
		stencilMask = 2,
		externalalpha = 0.75, -- alpha of outer rings
		internalalpha = 0.10, -- alpha of inner rings
    },
    nuke = {
        color = {1.05, 1.0, 0.2, 0.72},
        fadeparams = {6000, 3000, 0.6, 0.0}, -- FadeStart, FadeEnd, StartAlpha, EndAlpha
        externallinethickness = 5.0,
        internallinethickness = 2.0,
		stenciled = true,
		cannonMode = false,
		stencilMask = 4,
		externalalpha = 0.80, -- alpha of outer rings
		internalalpha = 0.15, -- alpha of inner rings
    },
    cannon = {
        color = {1.3, 0.18, 0.04, 0.70}, --orange 1.2, 0.55, 0.08, 0.74
        fadeparams = {2000, 8000, 0.8, 0.0}, -- FadeStart, FadeEnd, StartAlpha, EndAlpha
        externallinethickness = 5.0,
        internallinethickness = 2.5,
		stenciled = true,
		cannonMode = true,
		stencilMask = 8,
		externalalpha = 0.75, -- alpha of outer rings
		internalalpha = 0.10, -- alpha of inner rings
    },
	lrpc = {
        color = {1.3, 0.18, 0.04, 0.68},
        fadeparams = {9000, 6000, 0.8, 0.0}, -- FadeStart, FadeEnd, StartAlpha, EndAlpha
        externallinethickness = 3.0,
        internallinethickness = 1.5,
		stenciled = false,
		cannonMode = true,
		externalalpha = 0.25, -- alpha of outer rings
    },
}

-- add a “water” variant so we can stay in the ground-stencil pass but colour blue
colorConfig.ground_water = {
    color      = {0.48, 0.67, 1.0, 0.30},      -- nice RGBA blue
    fadeparams = colorConfig.ground.fadeparams, -- reuse the same fade curve
}

--- Camera Height based line shrinkage:

----------------------------------

local unitDefRings = {} --each entry should be  a unitdefIDkey to very specific table:
	-- a list of tables, ideally ranged from 0 where
	-- consider that a unit can have any of multiple types
--[[
	-- unitDefRings[unitDefID] = {

	}
]]--

local mobileAntiUnitDefs = {
	[UnitDefNames.armscab.id ] = true,
	[UnitDefNames.armcarry.id] = true,
	[UnitDefNames.cormabm.id ] = true,
	[UnitDefNames.corcarry.id] = true,
	[UnitDefNames.armantiship.id] = true,
	[UnitDefNames.corantiship.id] = true,
}

local defensePosHash = {} -- key: {poshash=unitID}
-- poshash is 4096 * posx/8 + posz/8

local featureDefIDtoUnitDefID = {} -- this table maps featureDefIDs to unitDefIDs for faster lookups on feature creation


local unitName = {}
local unitWeapons = {}
for udid, ud in pairs(UnitDefs) do
	unitName[udid] = ud.name
	unitWeapons[udid] = ud.weapons
end


local vtoldamagetag = Game.armorTypes['vtol']
local defaultdamagetag = Game.armorTypes['default']
local function initializeUnitDefRing(unitDefID)

	unitDefRings[unitDefID]['rings'] = {}
	local weapons = unitWeapons[unitDefID]
	for weaponNum = 1, #weapons do
		local weaponDef = weapons[weaponNum]
		local weaponDefID = weapons[weaponNum].weaponDef
		local weaponDef = WeaponDefs[weaponDefID]

		local range = weaponDef.range
		local weaponType = unitDefRings[unitDefID]['weapons'][weaponNum]
		--spEcho(weaponType)
		if weaponType ~= nil  then
			if  weaponType == 'nuke' then -- antinuke
				range = weaponDef.coverageRange
				--spEcho("init antinuke", range)
			end
			-- local color = colorConfig[weaponType].color
			-- local fadeparams =  colorConfig[weaponType].fadeparams

			-- pick blue for underwater weapons, otherwise fall back to normal
	        local baseKey = weaponType
	        local cfg    = colorConfig[baseKey]
	        if (baseKey == "ground") and (weaponDef.waterWeapon) then
	            cfg = colorConfig.ground_water
	            --spEcho("[DefenseRange] using water colour for:", weaponDef.name)
	        end
	        local color      = cfg.color
	        local fadeparams = cfg.fadeparams

			local isCylinder = 0
			if (weaponDef.cylinderTargeting)  and (weaponDef.cylinderTargeting > 0.0) then
				isCylinder = 1
			end

			local ringParams = {range, color[1],color[2], color[3], color[4],
				fadeparams[1], fadeparams[2], fadeparams[3], fadeparams[4],
				weaponDef.projectilespeed or 1,
				isCylinder,
				weaponDef.heightBoostFactor or 0,
				weaponDef.heightMod or 0 }
			unitDefRings[unitDefID]['rings'][weaponNum] = ringParams
		end
	end
end

local function initUnitList()
	local unitDefRingsNames = {
		-- ARMADA
		['armclaw'] = { weapons = { 'ground' } },
		['armllt'] = { weapons = { 'ground' } },
		['armbeamer'] = { weapons = { 'ground' } },
		['armhlt'] = { weapons = { 'ground' } },
		['armguard'] = { weapons = { 'cannon'} },
		['armrl'] = { weapons = { 'air' } }, --light aa
		['armferret'] = { weapons = { 'air' } },
		['armcir'] = { weapons = { 'air' } }, --chainsaw
		['armdl'] = { weapons = { 'ground' } }, --depthcharge
		['armjuno'] = { weapons = { 'ground' } },
		['armtl'] = { weapons = { 'ground' } }, --torp launcher
		['armfhlt'] = { weapons = { 'ground' } },  --floating hlt
		['armnavaldefturret'] = { weapons = { 'ground' } },  --cauterizer
		['armanavaldefturret'] = { weapons = { 'ground' } },  --liquifier
		['armfrt'] = { weapons = { 'air' } },  --floating rocket laucher
		['armfflak'] = { weapons = { 'air' } },  --floating flak AA
		['armatl'] = { weapons = { 'ground' } }, --adv torpedo launcher
		['armkraken'] = { weapons = { 'cannon' } }, --adv torpedo launcher

		['armamb'] = { weapons = { 'cannon' } }, --ambusher 'cannon'
		['armpb'] = { weapons = { 'ground' } }, --pitbull 'cannon'
		['armanni'] = { weapons = { 'ground' } },
		['armflak'] = { weapons = { 'air' } },
		['armmercury'] = { weapons = { 'air' } },
		['armemp'] = { weapons = { 'ground' } },
		['armamd'] = { weapons = { 'nuke' } }, --antinuke

		['armbrtha'] = { weapons = { 'lrpc' } },
		['armvulc'] = { weapons = { 'lrpc' } },

		-- CORTEX
		['cormaw'] = { weapons = { 'ground' } },
		['corexp'] = { weapons = { 'ground'} },
		['cormexp'] = { weapons = { 'ground','ground' } },
		['corllt'] = { weapons = { 'ground' } },
		['corhllt'] = { weapons = { 'ground' } },
		['corhlt'] = { weapons = { 'ground' } },
		['corpun'] = { weapons = { 'cannon'} },
		['corrl'] = { weapons = { 'air' } },
		['cormadsam'] = { weapons = { 'air' } },
		['corerad'] = { weapons = { 'air' } },
		['cordl'] = { weapons = { 'ground' } },
		['corjuno'] = { weapons = { 'ground' } },

		['corfhlt'] = { weapons = { 'ground' } },  --floating hlt
		['cornavaldefturret'] = { weapons = { 'ground' } },  --cyclops
		['coranavaldefturret'] = { weapons = { 'ground' } },  --orthrus
		['cortl'] = { weapons = { 'ground' } }, --torp launcher
		['coratl'] = { weapons = { 'ground' } }, --T2 torp launcher
		['corfrt'] = { weapons = { 'air' } }, --floating rocket laucher
		['corenaa'] = { weapons = { 'air' } }, --floating flak AA
		['corfdoom'] = { weapons = { [1] = 'cannon' } },

		['cortoast'] = { weapons = { 'cannon' } },
		['corvipe'] = { weapons = { 'ground' } },
		['cordoom'] = { weapons = { 'ground', 'ground', 'ground'} },
		['corflak'] = { weapons = { 'air' } },
		['corscreamer'] = { weapons = { 'air' } },
		['cortron'] = { weapons = { 'cannon' } },
		['corfmd'] = { weapons = { 'nuke' } },
		['corint'] = { weapons = { 'lrpc' } },
		['corbuzz'] = { weapons = { 'lrpc' } },

		['armscab'] = { weapons = { 'nuke' } },
		['armcarry'] = { weapons = { 'nuke' } },
		['cormabm'] = { weapons = { 'nuke' } },
		['corcarry'] = { weapons = { 'nuke' } },
		['armantiship'] = { weapons = { 'nuke' } },
		['corantiship'] = { weapons = { 'nuke' } },

		-- LEGION
		['legabm'] = { weapons = { 'nuke' } }, --antinuke
		['legrampart'] = { weapons = { 'nuke', 'ground' } }, --rampart
		['leglht'] = { weapons = { 'ground' } }, --llt
		['legcluster'] = { weapons = { 'cannon' } }, --short range arty T1
		['legacluster'] = { weapons = { 'cannon' } }, --T2 arty
		['legdtr'] = { weapons = { 'ground' } }, --dragons jaw
		['leghive'] = { weapons = { 'ground' } }, --Drone-defense
		['legmg'] = { weapons = { 'ground' } }, --ground-AA MG defense
		['legfmg'] = { weapons = { 'ground' } },  --cyclops
		['legnavaldefturret'] = { weapons = { 'ground' } },  --cyclops
		['leganavaldefturret'] = { weapons = { 'ground' } },  --Ionia
		['legbombard'] = { weapons = { 'ground' } }, --Grenadier defense
		['legbastion'] = { weapons = { 'ground' } }, --T2 Heatray Tower
		['legrl'] = { weapons = { 'air' } }, --T1 AA
		['leglupara'] = { weapons = { 'air' } }, --T1.5 AA
		['legrhapsis'] = { weapons = { 'air' } }, --T1.5 AA
		['legflak'] = { weapons = { 'air' } }, --T2 AA FLAK
		['leglraa'] = { weapons = { 'air' } }, --T2 LR-AA
		['legperdition'] = { weapons = { 'cannon' } }, --T2 LR-AA
		['legapopupdef'] = { weapons = { 'ground' } }, --popup riot/minigun turret

		['legstarfall'] = { weapons = { 'lrpc' } },
		['leglrpc'] = { weapons = { 'lrpc' } },

		-- SCAVENGERS
		['scavbeacon_t1_scav'] = { weapons = { 'ground' } },
		['scavbeacon_t2_scav'] = { weapons = { 'ground' } },
		['scavbeacon_t3_scav'] = { weapons = { 'ground' } },
		['scavbeacon_t4_scav'] = { weapons = { 'ground' } },

		['armannit3'] = { weapons = { 'ground' } },
		['armminivulc'] = { weapons = { 'ground' } },

		['cordoomt3'] = { weapons = { 'ground' } },
		['corhllllt'] = { weapons = { 'ground' } },
		['corminibuzz'] = { weapons = { 'ground' } }
	}
	-- convert unitname -> unitDefID
	unitDefRings = {}
	for unitName, ranges in pairs(unitDefRingsNames) do
		if UnitDefNames[unitName] then
			unitDefRings[UnitDefNames[unitName].id] = ranges
		end
	end
	unitDefRingsNames = nil

	for unitDefID, _ in pairs(unitDefRings) do
		initializeUnitDefRing(unitDefID)
	end
	-- Initialize Colors too
	local scavlist = {}
	for k,_ in pairs(unitDefRings) do
		scavlist[k] = true
	end
	-- add scavs
	for k,_ in pairs(scavlist) do
		--spEcho(k, unitName[k])
		if UnitDefNames[unitName[k] .. '_scav'] then
			unitDefRings[UnitDefNames[unitName[k] .. '_scav'].id] = unitDefRings[k]
		end
	end

	local scavlist = {}
	for k,_ in pairs(mobileAntiUnitDefs) do
		scavlist[k] = true
	end
	for k,v in pairs(scavlist) do
		if UnitDefNames[unitName[k] .. '_scav'] then
			mobileAntiUnitDefs[UnitDefNames[unitName[k] .. '_scav'].id] = mobileAntiUnitDefs[k]
		end
	end

	-- Initialize featureDefIDtoUnitDefID
	local wreckheaps = {"_dead","_heap"}
	for unitDefID,_ in pairs(unitDefRings) do
		local unitDefName = unitName[unitDefID]
		for i, suffix in pairs(wreckheaps) do
			if FeatureDefNames[unitDefName..suffix] then
				featureDefIDtoUnitDefID[FeatureDefNames[unitDefName..suffix].id] = unitDefID
				--spEcho(FeatureDefNames[unitDefName..suffix].id, unitDefID)
			end
		end
	end

end

--Button display configuration
--position only relevant if no saved config data found

local spGetSpectatingState = Spring.GetSpectatingState
local spec, fullview = spGetSpectatingState()
local myAllyTeam = Spring.GetMyAllyTeamID()
local numallyteams = 2

local defenses = {} -- table of unitID keys to info tables:
	--unitID = {posx = 0, posy = 0, posz = 0, teamID = 0,
	--	vaokeys = {key1 = targetvao1, ... }
	--}
local enemydefenses = {} -- a minor optimization to prevent iterating over our own on removal search

local mobileAntiUnits = {}


--------------------------------------------------------------------------------

local glDepthTest           = gl.DepthTest
local glLineWidth           = gl.LineWidth
local glTexture             = gl.Texture
local glClear				= gl.Clear
local glColorMask			= gl.ColorMask
local glStencilTest			= gl.StencilTest
local glStencilMask			= gl.StencilMask
local glStencilFunc			= gl.StencilFunc
local glStencilOp			= gl.StencilOp

local GL_KEEP = 0x1E00 --GL.KEEP
local GL_REPLACE = GL.REPLACE --GL.KEEP

local spGetPositionLosState = Spring.GetPositionLosState
local spGetUnitDefID        = Spring.GetUnitDefID
local spGetUnitPosition     = Spring.GetUnitPosition

local chobbyInterface

function widget:TextCommand(command)
	local mycommand=false --buttonConfig["enemy"][tag]

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
		if rangetype == 'ground' then
			buttonConfig[ally]['ground']=enabled
			buttonConfig[ally]['cannon']=enabled
		else
			buttonConfig[ally][rangetype]=enabled
		end
		spEcho("Range visibility of "..ally.." "..rangetype.." defenses set to",enabled)
		return true
	end

	return false
end

------ GL4 THINGS  -----
---

-- nukes and cannons:
local largeCircleVBO = nil
local largeCircleSegments = 1024

-- others:
local smallCircleVBO = nil
local smallCircleSegments = 128

local weaponTypeToString = {"ground","air","nuke","cannon"}
local allyenemypairs = {"ally","enemy"}
local defenseRangeClasses = {}
for allyenemy, ringclasses in pairs(buttonConfig) do
	for ringclass, enabled in pairs(ringclasses) do
			tableInsert(defenseRangeClasses, allyenemy .. ringclass)
	end
end
--local defenseRangeClasses = {'enemyair','enemyground','enemynuke','allyair','allyground','allynuke', 'enemycannon', 'allycannon'}
local defenseRangeVAOs = {}

local circleInstanceVBOLayout = {
		  {id = 1, name = 'posscale', size = 4}, -- abs pos for static units, offset for dynamic units, scale is actual range, Y is turretheight
		  {id = 2, name = 'color1', size = 4}, --  vec4 the color of this new
		  {id = 3, name = 'visibility', size = 4}, --- vec4 FadeStart, FadeEnd, StartAlpha, EndAlpha
		  {id = 4, name = 'projectileParams', size = 4}, --- projectileSpeed, iscylinder, heightBoostFactor , heightMod
		  {id = 5, name = 'additionalParams', size = 4 }, --- groupselectionfadescale, weaponType, ISDGUN, MAXANGLEDIF
		  {id = 6, name = 'instData',         size = 4, type = GL.UNSIGNED_INT }, -- Currently unused within defense ranges, as they are forced-static
		}

local LuaShader = gl.LuaShader
local InstanceVBOTable = gl.InstanceVBOTable

local pushElementInstance    = InstanceVBOTable.pushElementInstance
local popElementInstance     = InstanceVBOTable.popElementInstance
local getElementInstanceData = InstanceVBOTable.getElementInstanceData

local defenseRangeShader = nil

local shaderSourceCache = {
	shaderName = 'Defense Range GL4',
	vssrcpath = "LuaUI/Shaders/weapon_range_rings_unified_gl4.vert.glsl",
	fssrcpath = "LuaUI/Shaders/weapon_range_rings_unified_gl4.frag.glsl",
	shaderConfig = {
		MYGRAVITY = Game.gravity + 0.1,
		DEBUG = autoReload and 1 or 0,
		MOUSEOVERALPHAMULTIPLIER = 5.0,
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
		staticUnits = 1.0,
	},
}


local function goodbye(reason)
  spEcho("DefenseRange GL4 widget exiting with reason: "..reason)
  widgetHandler:RemoveWidget()
end

local function makeShaders()
	defenseRangeShader = LuaShader.CheckShaderUpdates(shaderSourceCache, 0)
	if not defenseRangeShader then
		goodbye("Failed to compile defenseRangeShader GL4 ")
		return false
	end
	return true
end

local function initGL4()
	smallCircleVBO = InstanceVBOTable.makeCircleVBO(smallCircleSegments)
	largeCircleVBO = InstanceVBOTable.makeCircleVBO(largeCircleSegments)
	for i,defRangeClass in ipairs(defenseRangeClasses) do
		defenseRangeVAOs[defRangeClass] = InstanceVBOTable.makeInstanceVBOTable(circleInstanceVBOLayout,16,defRangeClass .. "_defenserange_gl4")
		if defRangeClass:find("nuke", nil, true) or defRangeClass:find("lrpc", nil, true) then --defRangeClass:find("cannon", nil, true) or
			defenseRangeVAOs[defRangeClass].vertexVBO = largeCircleVBO
			defenseRangeVAOs[defRangeClass].numVertices = largeCircleSegments
		else
			defenseRangeVAOs[defRangeClass].vertexVBO = smallCircleVBO
			defenseRangeVAOs[defRangeClass].numVertices = smallCircleSegments
		end
		local newVAO = InstanceVBOTable.makeVAOandAttach(defenseRangeVAOs[defRangeClass].vertexVBO,defenseRangeVAOs[defRangeClass].instanceVBO)
		defenseRangeVAOs[defRangeClass].VAO = newVAO
	end
	return makeShaders()
end

function widget:Initialize()
	initUnitList()

	if initGL4() == false then
		return
	end

	WG['defrange'] = {}
	for _,ae in ipairs({'ally','enemy'}) do
		local Ae = string.upper(string.sub(ae, 1, 1)) .. string.sub(ae, 2)
		for _,wt in ipairs({'ground','air','nuke'}) do
			local Wt = string.upper(string.sub(wt, 1, 1)) .. string.sub(wt, 2)
			WG['defrange']['get'..Ae..Wt] = function() return buttonConfig[ae][wt] end
			WG['defrange']['set'..Ae..Wt] = function(value)
				if wt == 'ground' then
					buttonConfig[ae]['ground'] = value
					buttonConfig[ae]['lrpc'] = value
				else
					buttonConfig[ae][wt] = value
				end
				spEcho(string.format("Defense Range GL4 Setting %s%s to %s",Ae,Wt, value and 'on' or 'off'))
				if WG['unittrackerapi'] and WG['unittrackerapi'].visibleUnits then
					widget:VisibleUnitsChanged(WG['unittrackerapi'].visibleUnits, nil)
				end
			end
		end
	end
	myAllyTeam = Spring.GetMyAllyTeamID()
	local allyteamlist = Spring.GetAllyTeamList( )
	--spEcho("# of allyteams = ", #allyteamlist)
	numallyteams = #allyteamlist

	if WG['unittrackerapi'] and WG['unittrackerapi'].visibleUnits then
		widget:VisibleUnitsChanged(WG['unittrackerapi'].visibleUnits, nil)
	end
end

local floor = math.floor
local function hashPos(x,z)
	return floor(x/8)*4096 + floor(z/8)
end

local cacheTable = {}
for i=1,24 do cacheTable[i] = 0 end

local function UnitDetected(unitID, unitDefID, unitTeam, noUpload)
	if unitDefRings[unitDefID] == nil then return end -- no rings for this

	if defenses[unitID] ~= nil then return end -- already has rings

	-- otherwise we must add it!

	--local weapons = unitWeapons[unitDefID]
	local alliedUnit = (Spring.GetUnitAllyTeam(unitID) == myAllyTeam)
	local x, y, z, mpx, mpy, mpz, apx, apy, apz = spGetUnitPosition(unitID, true, true)

	--for weaponNum = 1, #weapons do
	local addedrings = 0
	for i, weaponType in pairs(unitDefRings[unitDefID]['weapons']) do
		local allystring = alliedUnit and "ally" or "enemy"
		-- We want to continue to maintain ally lists, because these ally lists will be
		if buttonConfig[allystring][weaponType] or (colorConfig.drawAllyCategoryBuildQueue and (allystring == "ally")) then

			--local weaponType = unitDefRings[unitDefID]['weapons'][weaponNum]

			local weaponID = i
			local ringParams = unitDefRings[unitDefID]['rings'][i]
			local x, y, z, mpx, mpy, mpz, apx, apy, apz = spGetUnitPosition(unitID, true, true)
			local wpx, wpy, wpz, wdx, wdy, wdz = Spring.GetUnitWeaponVectors(unitID, weaponID)
			--spEcho("Defranges: unitID", unitID,x,y,z,"weaponID", weaponID, "y", y, "mpy",  mpy,"wpy", wpy)

			-- Now this is a truly terrible hack, we cache each unitDefID's max weapon turret height at position 18 in the table
			-- so it only goes up with popups
			local turretHeight = mathMax(ringParams[18] or 0, (wpy or mpy ) - y)
			ringParams[18] = turretHeight


			cacheTable[1] = mpx
			cacheTable[2] = turretHeight
			cacheTable[3] = mpz
			local vaokey = allystring .. weaponType

			for j = 1,13 do
				cacheTable[j+3] = ringParams[j]
			end

			local instanceID = 1000000 * i + unitID
			pushElementInstance(defenseRangeVAOs[vaokey], cacheTable, instanceID, true,  noUpload)
			addedrings = addedrings + 1
			if defenses[unitID] == nil then
				--lazy creation
				defenses[unitID] = { posx = mpx, posy = mpy, posz = mpz, vaokeys = {}, allied = alliedUnit, unitDefID = unitDefID}
			end
			defenses[unitID].vaokeys[instanceID] = vaokey
		end
	end
	if addedrings == 0 then
		return
	end

	if mobileAntiUnitDefs[unitDefID] then
		mobileAntiUnits[unitID] = true
	end

	if alliedUnit then -- if allied rings are on, then add them!
	else
		enemydefenses[unitID] = true
		defensePosHash[hashPos(x,z)] = unitID
	end

end

function widget:VisibleUnitAdded(unitID, unitDefID, unitTeam)
	UnitDetected(unitID, unitDefID, unitTeam)
end

function widget:VisibleUnitsChanged(extVisibleUnits, extNumVisibleUnits)
	-- the set of visible units changed. Now is a good time to reevalueate our life choices
	-- This happens when we move from team to team, or when we move from spec to other
	-- my
	spec, fullview = Spring.GetSpectatingState()
	if (not enabledAsSpec) and spec then
		spEcho("Defense Range GL4 disabled in spectating state")
		widget:RemoveWidget()
		return
	end
	defenses = {}
	enemydefenses = {}
	defensePosHash = {}
	mobileAntiUnits = {}
	for vaokey, instanceTable in pairs(defenseRangeVAOs) do
		InstanceVBOTable.clearInstanceTable(instanceTable) -- clear all instances
	end
	for unitID, unitDefID in pairs(extVisibleUnits) do
		UnitDetected(unitID, unitDefID, spGetUnitTeam(unitID), true) -- add them with noUpload = true
	end
	for vaokey, instanceTable in pairs(defenseRangeVAOs) do
		InstanceVBOTable.uploadAllElements(instanceTable) -- clear all instances
	end
end

local function checkEnemyUnitConfirmedDead(unitID, defense)
	local x, y, z = defense["posx"], defense["posy"], defense["posz"]
	local _, losState, _ = spGetPositionLosState(x, y, z)
	--spEcho("checkEnemyUnitConfirmedDead",unitID, losState, spGetUnitDefID(unitID), Spring.GetUnitIsDead(unitID))
	if losState then -- visible
		if Spring.GetUnitIsDead(unitID) ~= false then -- If its cloaked and jammed, we cant see it i think
			return true
		end
	end
	return false
end

local function removeUnit(unitID,defense)
	mobileAntiUnits[unitID] = nil
	enemydefenses[unitID] = nil
	defensePosHash[hashPos(defense.posx,defense.posz)] = nil
	for instanceKey,vaoKey in pairs(defense.vaokeys) do
		--spEcho(vaoKey,instanceKey)
		if defenseRangeVAOs[vaoKey].instanceIDtoIndex[instanceKey] then
			popElementInstance(defenseRangeVAOs[vaoKey],instanceKey)
		end
	end
	defenses[unitID] = nil
end

function widget:VisibleUnitRemoved(unitID) -- remove the corresponding ground plate if it exists
	if defenses[unitID] == nil then return end -- nothing to do

	local defense = defenses[unitID]
	--local teamID = spGetUnitTeam(unitID)
	local removeme = false

	if mobileAntiUnits[unitID] then
		removeme = true
	else
		if defense.allied then
			removeme = true
		else
			removeme = checkEnemyUnitConfirmedDead(unitID, defense)
			-- if we cant get unitDefID, then its probably an enemy unit
			-- we also dont know the reason for removal, but we can check wether its pos is in los:
		end
	end
	if removeme then
		removeUnit(unitID, defense)
	end
end


function widget:FeatureCreated(featureID, allyTeam)
	-- check if the feature we created could be related to a defense that we currently have active?
	-- ugh this will require a unitdefid based hash and some other nasty tricks
	-- check if the feature was created outside of LOS
	local featureDefID = Spring.GetFeatureDefID(featureID)
	if featureDefID and featureDefIDtoUnitDefID[featureDefID] then
		local fx, fy, fz = Spring.GetFeaturePosition(featureID)
		local poshash = floor(fx/8)*4096 + floor(fz/8)
		local unitID = defensePosHash[poshash]
		if unitID then
			if defenses[unitID] and defenses[unitID].allied == false and
				featureDefIDtoUnitDefID[featureDefID] == defenses[unitID].unitDefID then
				--spEcho("feature created at a likely dead defense pos!")
				removeUnit(unitID,defenses[unitID])
			end
		end
	end
end

function widget:PlayerChanged(playerID)
	--[[
	spEcho("playerchanged", playerID)
	local GetLocalPlayerID  = Spring.GetLocalPlayerID( )
	--spEcho("GetLocalPlayerID", GetLocalPlayerID)
	local GetMyTeamID = Spring.GetMyTeamID ( )
	--spEcho("GetMyTeamID", GetMyTeamID)
	]]--
	local nowspec, nowfullview = spGetSpectatingState()
	local nowmyAllyTeam = Spring.GetMyAllyTeamID()
	-- When we start, check if there are >2 allyteams
	local reinit = false
	-- check spec transition
	if spec ~= nowspec then
		--keep allyteam, but reinit
		reinit = true
		-- When widget starts, allied check is fine, its correct w.r.t to myteamid
	end
	spec = nowspec

	if numallyteams > 3 then -- one for gaia
		if nowmyAllyTeam ~= myAllyTeam then
			reinit = true
		end
	else
		-- if there are only 2 ally teams, no need to reinit
	end

	if reinit then
		myAllyTeam = nowmyAllyTeam -- only update if we reinit
		--spEcho("DefenseRange GL4 allyteam change detected, reinitializing")
		if WG['unittrackerapi'] and WG['unittrackerapi'].visibleUnits then
			widget:VisibleUnitsChanged(WG['unittrackerapi'].visibleUnits, nil)
		end
	else
		--spEcho("No change needed", numallyteams, myAllyTeam)
	end
end

local gameFrame = 0
local lastUpdatedGameFrame = 0
local antiupdaterate = 1
local removalRate = 6
local lastRemoval = 0
local removestep = 0

function widget:GameFrame(gf)
	gameFrame = gf
end

local buildUnitDefID = nil
local buildDrawOverride = { ground = false, air = false, nuke = false , cannon = false, lrpc = false}

function widget:Update(dt)
	--spec, fullview = spGetSpectatingState()
	--if spec then
	--	return
	--end

-- detect if our “myAllyTeam” has changed (e.g. a spec following a different player)
   local currentAllyTeam = Spring.GetMyAllyTeamID()
   if currentAllyTeam ~= myAllyTeam then
     myAllyTeam = currentAllyTeam
     -- clear out all the old rings
     defenses, enemydefenses, defensePosHash, mobileAntiUnits = {}, {}, {}, {}
     for _, ivt in pairs(defenseRangeVAOs) do
       InstanceVBOTable.clearInstanceTable(ivt)
     end
     -- rebuild from whatever visibleUnits API you have
     local extVisibleUnits = (WG.unittrackerapi and WG.unittrackerapi.visibleUnits)
                           or (function()
                                local t = {}
                                for _, uid in ipairs(Spring.GetAllUnits()) do
                                  t[uid] = spGetUnitDefID(uid)
                                end
                                return t
                              end)()
     widget:VisibleUnitsChanged(extVisibleUnits, nil)
   end

	if gameFrame >= lastUpdatedGameFrame + antiupdaterate then
		lastUpdatedGameFrame = gameFrame

		--update the goddamned stupid mobile anti vbo ffs
		for unitID, mobileantiinfo in pairs(mobileAntiUnits) do
			local px, py, pz = spGetUnitPosition(unitID)
			if px then
				local defense = defenses[unitID]
				defense.posx = px
				defense.posy = py
				defense.posz = pz
				for instanceKey,vaoKey in pairs(defense.vaokeys) do
					local cacheTable = getElementInstanceData(defenseRangeVAOs[vaoKey], instanceKey, cacheTable) -- this is horrible perf wise
					--spEcho("Anti at",unitID, px, pz,mobileantiinfo[1],mobileantiinfo[2],vbodata[1],vbodata[2])
					cacheTable[1] = px
					cacheTable[2] = py
					cacheTable[3] = pz
					pushElementInstance(defenseRangeVAOs[vaoKey],cacheTable,instanceKey, true) -- last true is updateExisting
				end
			end
		end

	end

	if gameFrame >= lastRemoval + removalRate then
		lastRemoval = gameFrame
		removestep = (removestep + 1) % removalRate
		--remove dead units
		local scanned = 0
		for unitID, _ in pairs(enemydefenses) do
			if unitID % removalRate == removestep then
				local defense = defenses[unitID]
				scanned = scanned + 1
				if defense.allied == false then
					local x, y, z = defense["posx"], defense["posy"], defense["posz"]
					local _, losState, _ = spGetPositionLosState(x, y, z)
					--spEcho("removal",unitID, losState)
					if losState then
						if not spGetUnitDefID(unitID) then
							removeUnit(unitID, defense)
						end
					end
				end
			end
		end
		--spEcho("removestep", removestep , scanned)
	end
	-- DRAW THE ATTACK RING FOR THE ACTIVELY BUILDING UNIT
	local cmdID = select(2, Spring.GetActiveCommand())
	-- remove from queue every frame cause mouse will probably move anyway
	-- we kinda also need to remove if the allyenemy state changed
	if (buildUnitDefID ~= nil)  then
		local rings = unitDefRings[buildUnitDefID]
		if rings then
			-- find out which VBO to remove from:
			local allystring = 'ally'
			for i, weaponType in ipairs(rings['weapons']) do
				buildDrawOverride[weaponType] = false
				for j,allyenemy in ipairs(allyenemypairs) do -- remove from all
					local vaokey = allyenemy .. weaponType
					local instanceID = 2000000 + 100000* i +  buildUnitDefID
					if defenseRangeVAOs[vaokey].instanceIDtoIndex[instanceID] then
						popElementInstance(defenseRangeVAOs[vaokey], instanceID)
					end
				end
			end
		end
		buildUnitDefID = nil
	end

	if (cmdID ~= nil and (cmdID < 0)) then
		buildUnitDefID = -1* cmdID
		if unitDefRings[buildUnitDefID] then
			local rings = unitDefRings[buildUnitDefID]
			-- only add to ally, independent of buttonconfig (ugh)
			-- todo, this wont show the respective attack range ring if the button for it is off.
			-- Ergo we should rather gate addition on buttonConfig in visibleUnitCreated
			-- instead of during the draw pass

			local mx, my, lp, mp, rp, offscreen = Spring.GetMouseState()
			local _, coords = Spring.TraceScreenRay(mx, my, true)
			--spEcho(cmdID, "Attempting to draw rings at")
			--spEcho(mx, my, coords[1], coords[2], coords[3])

			if coords and coords[1] and coords[2] and coords[3] then
				local bpx, bpy, bpz = Spring.Pos2BuildPos(buildUnitDefID, coords[1], coords[2], coords[3])
				local allystring = 'ally'
				for i, weaponType in pairs(unitDefRings[buildUnitDefID]['weapons']) do
                   local allystring = "ally"
                   buildDrawOverride[weaponType] = true
                   -- allow rings if either normal ally-rings are on, OR build-queue preview is explicitly enabled
                   if buttonConfig[allystring][weaponType]
                      or colorConfig.drawAllyCategoryBuildQueue
                   then
                       local ringParams = unitDefRings[buildUnitDefID]['rings'][i]
                       if ringParams then
                           cacheTable[1] = bpx
                           cacheTable[2] = ringParams[18]
                           cacheTable[3] = bpz
                           for j = 1,13 do
                               cacheTable[j+3] = ringParams[j]
                           end
                           local vaokey    = allystring .. weaponType
                           local instanceID = 2000000 + 100000 * i + buildUnitDefID
                           pushElementInstance(defenseRangeVAOs[vaokey], cacheTable, instanceID, true)
                       end
                   end
               end
			end
		end

	end -- not build command

end

function widget:RecvLuaMsg(msg, playerID)
	if msg:sub(1,18) == 'LobbyOverlayActive' then
		chobbyInterface = (msg:sub(1,19) == 'LobbyOverlayActive1')
	end
end
local drawcounts = {}

local cameraHeightFactor = 0

local function GetCameraHeightFactor() -- returns a smoothstepped value between 0 and 1 for height based rescaling of line width.
	local camX, camY, camZ = Spring.GetCameraPosition()
	local camheight = camY - mathMax(Spring.GetGroundHeight(camX, camZ), 0)
	-- Smoothstep to half line width as camera goes over 2k height to 4k height
	--genType t;  /* Or genDType t; */
    --t = clamp((x - edge0) / (edge1 - edge0), 0.0, 1.0);
    --return t * t * (3.0 - 2.0 * t);

	camheight = math.clamp((camheight - colorConfig.distanceScaleStart) / (colorConfig.distanceScaleEnd - colorConfig.distanceScaleStart), 0, 1)
	--return camheight * camheight * (3 - 2 *camheight)
	return 1
end

local groundnukeair = {"ground","air","nuke"}
local cannonlrpc = {"cannon","lrpc"}
local allrings = {"ground","air","nuke", "cannon","lrpc"}
local stenciledrings = {}
local nonstenciledrings = {}
for i, weaponType in ipairs(allrings) do
	if colorConfig[weaponType].stenciled then
		tableInsert(stenciledrings, weaponType)
	else
		tableInsert(nonstenciledrings, weaponType)
	end
end


local function DRAWRINGS(primitiveType, linethickness, classes, alpha)
	local stencilMask
	for i,allyState in ipairs(allyenemypairs) do
		for j, wt in ipairs(classes) do
			local defRangeClass = allyState..wt
			local iT = defenseRangeVAOs[defRangeClass]

			 -- if we might have queued buildings here, and we already discarded addition of unwanted rings based on buttonConfig in visibleUnitCreated

			if iT.usedElements > 0 and (buttonConfig[allyState][wt] or buildDrawOverride[wt]) then
				defenseRangeShader:SetUniform("cannonmode",colorConfig[wt].cannonMode and 1 or 0)
				defenseRangeShader:SetUniform("lineAlphaUniform",colorConfig[wt][alpha])
				if linethickness then
					glLineWidth(colorConfig[wt][linethickness] * cameraHeightFactor)
				end
				if colorConfig[wt].stencilMask then
					stencilMask = colorConfig[wt].stencilMask * ( (i==1) and 1 or 16)
					glStencilMask(stencilMask)  -- only allow these bits to get written
					glStencilFunc(GL.NOTEQUAL, stencilMask, stencilMask) -- what to do with the stencil
				end
				iT.VAO:DrawArrays(primitiveType,iT.numVertices,0,iT.usedElements,0) -- +1!!!
			end
		end
	end
end

function widget:DrawWorld()
	--if fullview and not enabledAsSpec then
	--	return
	--end

	if autoReload then
		defenseRangeShader = LuaShader.CheckShaderUpdates(shaderSourceCache) or defenseRangeShader
	end


	if chobbyInterface then return end
	if not Spring.IsGUIHidden() and (not WG['topbar'] or not WG['topbar'].showingQuit()) then
		cameraHeightFactor = GetCameraHeightFactor() * 0.5 + 0.5
		glTexture(0, "$heightmap")
		glTexture(1, "$info")
		defenseRangeShader:Activate()
		defenseRangeShader:SetUniform("staticUnits", 1.0)
		-- Stencil Setup
		-- 	-- https://learnopengl.com/Advanced-OpenGL/Stencil-testing
		if colorConfig.drawStencil then
			glClear(GL.STENCIL_BUFFER_BIT) -- clear prev stencil
			glDepthTest(false) -- always draw
			glColorMask(false, false, false, false) -- disable color drawing

			glStencilTest(true) -- enable stencil test
			glStencilMask(255) -- all 8 bits
			glStencilOp(GL_KEEP, GL_KEEP, GL_REPLACE) -- Set The Stencil Buffer To 1 Where Draw Any Polygon

			DRAWRINGS(GL.TRIANGLE_FAN, nil, stenciledrings) -- FILL THE CIRCLES
			--glLineWidth(mathMax(0.1,4 + math.sin(gameFrame * 0.04) * 10))
			glColorMask(true, true, true, true)	-- re-enable color drawing
			glStencilMask(0)

			glDepthTest(GL.LEQUAL) -- test for depth on these outside cases
			DRAWRINGS(GL.LINE_LOOP, 'externallinethickness', stenciledrings, "externalalpha") -- DRAW THE OUTER RINGS
			glStencilTest(false)
			glStencilMask(255)   -- Set all bits of stencil buffer to writeable
			glStencilOp(GL_KEEP, GL_KEEP, GL_KEEP) -- Reset default stencil operation (which is the do nothing operation)
			glClear(GL.STENCIL_BUFFER_BIT) -- Clear the stencil buffer for whichever widget wants it next (this is probably redundant)
			-- All the above are needed :O

		end


		DRAWRINGS(GL.LINE_LOOP, 'internallinethickness', stenciledrings, "internalalpha") -- DRAW THE INNER RINGS
		DRAWRINGS(GL.LINE_LOOP, 'externallinethickness', nonstenciledrings, "externalalpha") -- DRAW THE INNER RINGS


		defenseRangeShader:Deactivate()

		glTexture(0, false)
		glTexture(1, false)
		glDepthTest(false)
		if false and Spring.GetDrawFrame() % 60 == 0 then
			local s = 'drawcounts: '
			for k,v in pairs(drawcounts) do s = s .. " " .. tostring(k) .. ":" .. tostring(v) end
			spEcho(s)
		end
	end
end
if autoReload then
    function widget:DrawScreen()
        if defenseRangeShader.DrawPrintf then defenseRangeShader.DrawPrintf() end
    end
end


--- SHIT THAT NEEDS TO BE IN CONFIG:

-- ALLY/ENEMY
-- AIR/NUKE/GROUND
-- OPACITY
-- ENABLE IN SPEC MODE
-- LINEWIDTH
-- internalrings
-- nostencil mode


--SAVE / LOAD CONFIG FILE
function widget:GetConfigData()
	local data = {}
	data["enabled"] = buttonConfig
	return data
end

function widget:SetConfigData(data)
	if data ~= nil then
		if data["enabled"] ~= nil then
			local newconfig = data["enabled"]
			local configstr = ""
			for allyenemy, weapontypes in pairs(newconfig) do
				for wt, enabledstate in pairs(weapontypes) do
					buttonConfig[allyenemy][wt] = enabledstate
					configstr = configstr .. tostring(allyenemy) .. tostring(wt) .. ":" .. tostring(enabledstate) .. ", "
				end
			end
			if autoReload then
				--spEcho("defenserange gl4:", configstr)
			end
			--printDebug("enabled config found...")
		end
	end
end


