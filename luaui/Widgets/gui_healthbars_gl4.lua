function widget:GetInfo()
   return {
      name      = "Health Bars GL4",
      desc      = "Yes this healthbars, just gl4",
      author    = "Beherith",
      date      = "October 2019",
      license   = "GNU GPL, v2 or later for Lua code, (c) Beherith (mysterme@gmail.com) for GLSL",
      layer     = -10,
      enabled   = true
   }
end

-- wellity wellity the time has come, and yes, this is design documentation
-- what can we do with 64 verts per healthbars?
	-- 9 verts bg
	-- 9 verts fg
	-- 20 verts for numbers like an asshole
-- fade bars in and out based on last modified times of values?
-- what info do we need outputted from GS?
-- for fg/bg
-- color? is that it?

-- for numbers:
-- uv coords
-- we also need one extra for text - no bueno for translations tho

-- use billboards,
-- THE TYPES OF UNIT BARS:
	-- timer based, all these need a start and (predicted) end time.
		-- EMP time left
			-- 3 floats, start, end, empdamage
			-- needs update on every fucking unitdamaged callin
			-- handle cases where uni is empd outside of view?


		-- reload
			-- 2 floats, lastshot, nextshot
		-- time left in construction
			-- this is a special hybrid bar added on unitcreated, and removed on unitfinished...
			-- 2 floats, buildpct, eta? (eta could get liveupdated cause unitfinished?)
	-- static percentage based:
		-- health --
		-- emp damage
		-- capture
		-- stockpile build progress
		-- shield

-- stuff that needs to occupy a contiguouis stretch in the user uniforms:

--  Spring.GetUnitHealth ( number unitID )
-- return: nil | number health, number maxHealth, number paralyzeDamage, number captureProgress, number buildProgress

-- local shieldOn, shieldPower = GetUnitShieldState(unitID)
-- numStockpiled, numStockpileQued, stockpileBuild = GetUnitStockpile(unitID)
-- local stunned = GetUnitIsStunned(unitID)
-- local _, reloaded, reloadFrame = GetUnitWeaponState(unitID, ci.primaryWeapon)

-- Features can only have: Health, reclaim and resurrectprogress - in fact they should be completely separate bar ids, and all of them are static percentage based
	-- feature resurrect -- this list must be handled in-widget, maintained and updated accordingly for in-los features.
		-- advanced concepts include priority watch lists of features actively being resurrected (or hooking into allowcommand, but that is garbage!)

	-- feature health
	-- feature reclaim
--  AllowFeatureBuildStep() called when wreck is resurrected

-- Spring.GetFeatureHealth ( number featureID )
--return: nil | number health, number maxHealth, number resurrectProgress
--Spring.GetFeatureResources ( number featureID )
--return: nil | number RemainingMetal, number maxMetal, number RemainingEnergy, number maxEnergy, number reclaimLeft, number reclaimTime



-- the vertex shader:
	-- Job of the VS:
		-- read the data and position
		-- identify if the bar needs to be drawn based on :
			-- visibility of unit
			-- distance of bar
			-- value of the bar
		-- the colormap of the bar needs to be interpolated here from a fixed define string?
		--[[ -- https://community.khronos.org/t/constant-vec3-array-no-go/60184/8
			vec3 MyArray[4]=vec3[4](
				vec3(1.5,34.4,3.2),
				vec3(1.6,34.1,1.2),
				vec3(18.981777,6.258294,-27.141813),
				vec3(1.0,3.0,1.0)
			);
		]]--
	--
	-- VS input:
		-- uint barindex
			-- this is the index of how manyeth bar it is in the list, where 0 is always health. and if an additional bar is needed, then increment accordingly
		-- uint bartype
			-- this is for where to get the colortable and 'icon' from
		-- float unitheight
			-- for correct offsetting
		-- uint uniformSSBOloc
			-- this is what uniform offset to read, 0 will be health?
		-- float2 timers
			-- this is for setting the time from which to calculate the timer based bars, set to 0 for no timer, start and end time maybe to calc diff?
		-- uint unitID
			-- or a featureID for features, those will be a separate list, but use hopefully the same shader.
		--
	-- VS output
		-- unit position
		-- bar position
		-- bar 'scale'
		-- bar basecolor
		-- bar colormap vec3[3]
		-- bar value
		-- bar type
		-- bar alpha
		-- corner size


-- Geometry shader:
	-- should only output anything if the bar actually needs to be drawn
-- Job of the geometry shader:
	-- take the VS output params, and create the following bar components:
	-- At furthest detail:
		-- background which is same size as bar
		-- the bar itself
		-- 2*4 vertices
	-- midrange:
		-- a nicer 6 triangle cornered bar background
		-- a cornered bar foreground
		-- 2*8 vertices
	-- closeup:
		-- add the percentage value to the left of the bar
		-- this is 4*4 vertices
	-- full closeness
		-- also write the 'name' of the bar type
	-- GS output per vertex:
		-- position on screen
		-- Z depth (somehow with emission ordering from back to front?
		-- UV coordinates -- this could get nasty quickly
		-- vertex color
		-- solid or textured

-- Fragment shader:
	-- if solid, interpolate vertex color, and straight up draw it
	-- if uv mapped, sample the texture and draw it

-- atlas plans:
	-- 512 x 512 atlas
	-- 16 rows in it
	-- each number from 0 to 9, '.' % and space (the 15th.) 's', ':'
	-- the text?
	-- overlay textures for bars
	-- symbol glyphs

-- TODO
-- 1. enemy paralyzed is not visible?
-- enemy comms and fusions health? hide the ones which should be hidden!
-- check for invalidness on addbars -- dont
-- better maintenance of bartypes and watch lists
-- feature bars fade out faster -- done
-- CLOAKED UNITSES -- done
-- Healthbars color correction -- done
-- Hide buildbars when at full hp - or convert them to build bars? -- done
-- todo some tex filtering issues on healthbar tops and bottoms :/  -- done
-- TODO: some GAIA shit? -- done
-- TODO: enemy comms and fus and decoy fus should not get healthbars! -- done
-- TODO: allies dont get reload bars? Do Specs see them? -- done (it was f'ed up previously)
-- TODO: correct draw order (after highlightunit) -- done
-- TODO: when reiniting feature bars, also check for resurrect/reclaim status -- done, just dont reinit them on playerchanged, no point!
	-- now this is problematic, as the gadget only sends us an event on first reclaim event
	-- we must assume that all features
	-- feature bars dont actually need a reinit, now do they?
-- TODO: make numbers, glyphs optional? -- done, but untested

--/luarules fightertest corak armpw 100 10 2000

local drawWhenGuiHidden = false

local healthbartexture = "LuaUI/Images/healtbars_exo4.tga"

-- a little explanation for 'bartype'
-- 0: default percentage progress bar
-- 1: timer based full textured bar, with time left being read from unitformindex
-- 2: timer based progress bar, with start and end times reading time left from uniformindex, uniformindex + 1 and timeInfo.x
-- 3: default percentage bar with overlayed texture progression
-- 5: The stockpile bar, nasty as hell but whatevs, it

-- TODO: should be a freaking bitmask instead
-- bit 0: use overlay texture false/true
-- bit 1: show glyph icon
-- bit 2: use percentage style display
-- bit 3: use timeleft style display    (2 and 3 mutually exclusive!)
-- bit 4: use integernumber style display (stockpile)
-- bit 5: get progress from nowtime-uniform2 / (uniform3 - uniform2)
-- bit 6: flash bar at 1hz
local bitUseOverlay = 1
local bitShowGlyph = 2
local bitPercentage = 4
local bitTimeLeft = 8
local bitIntegerNumber = 16
local bitGetProgress = 32
local bitFlashBar = 64
local bitColorCorrect = 128

-- unit uniform index map:
-- 0: building
-- 1: NONE ,
-- 2: shield/reloadstart/stockpile
-- 3: reloadend?
-- 4: emp damage /paralyze
-- 5: capture

-- Feature uniform index map:
-- 0: NONE
-- 1: resurrect
-- 2: reclaim

local barTypeMap = { -- WHERE SHOULD WE STORE THE FUCKING COLORS?
	health = {
		mincolor = {1.0, 0.0, 0.0, 1.0},
		maxcolor = {0.0, 1.0, 0.0, 1.0},
		--bartype = 0,
		bartype = bitPercentage + bitColorCorrect,
		hidethreshold = 0.99,
		uniformindex = 32, -- if its >20, then its health/maxhealth
		uvoffset = 0.0625, -- the X offset of the icon for this bar
	},
	shield = {
		mincolor = {0.15, 0.4, 0.4, 1.0},
		maxcolor = {0.3, 0.8, 0.8, 1.0},
		--bartype = 3,
		bartype = bitShowGlyph + bitUseOverlay + bitPercentage,
		hidethreshold = 0.99,
		uniformindex = 2, -- if its >20, then its health/maxhealth
		uvoffset = 0.3125, -- the X offset of the icon for this bar
	},
	capture = {
		mincolor = {0.5, 0.25, 0.0, 1.0},
		maxcolor = {1.0, 0.5, 0.0, 1.0},
		--bartype = 3,
		bartype = bitShowGlyph + bitUseOverlay + bitPercentage,
		hidethreshold = 0.99,
		uniformindex = 5, -- if its >20, then its health/maxhealth
		uvoffset = 0.1875, -- the X offset of the icon for this bar
	},
	stockpile = {
		mincolor = {0.1, 0.1, 0.1, 1.0},
		maxcolor = {0.1, 0.1, 0.1, 1.0},
		--bartype = 5,
		bartype = bitShowGlyph + bitUseOverlay + bitIntegerNumber,
		hidethreshold = 1.99,
		uniformindex = 2, -- if its >20, then its health/maxhealth
		uvoffset = 0.4375, -- the X offset of the icon for this bar
	},
	emp_damage = {
		mincolor = {0.4, 0.4, 0.8, 1.0},
		maxcolor = {0.6, 0.6, 1.0, 1.0},
		--bartype = 3,
		bartype = bitShowGlyph + bitUseOverlay + bitPercentage,
		hidethreshold = 0.99,
		uniformindex = 4, -- if its >20, then its health/maxhealth
		uvoffset = 0.5625, -- the X offset of the icon for this bar
	},
	reload = {
		mincolor = {0.03, 0.4, 0.4, 1.0},
		maxcolor = {0.05, 0.6, 0.6, 1.0},
		--bartype = 2,
		bartype = bitShowGlyph + bitUseOverlay + bitGetProgress,
		hidethreshold = 0.99,
		uniformindex = 2, -- and 3!
		uvoffset = 0.6875, -- the X offset of the icon for this bar
	},
	building = {
		mincolor = {1.0, 1.0, 1.0, 1.0},
		maxcolor = {1.0, 1.0, 1.0, 1.0},
		--bartype = 3,
		bartype = bitShowGlyph + bitUseOverlay + bitPercentage,
		hidethreshold = 0.99,
		uniformindex = 0, -- if its >20, then its health/maxhealth
		uvoffset = 0.9375, -- the X offset of the icon for this bar
	},
	paralyzed = {
		mincolor = {0.6, 0.6, 1.0, 1.0},
		maxcolor = {0.6, 0.6, 1.0, 1.0},
		--bartype = 1,
		bartype = bitShowGlyph + bitUseOverlay + bitFlashBar + bitTimeLeft,
		hidethreshold = 0.99,
		uniformindex = 4, -- if its >20, then its health/maxhealth
		uvoffset = 0.8125, -- the X offset of the icon for this bar
	},
	featurehealth = {
		mincolor = {0.25, 0.25, 0.25, 1.0},
		maxcolor = {0.65, 0.65, 0.65, 1.0},
		--bartype = 0,
		bartype = bitShowGlyph + bitPercentage,
		hidethreshold = 0.99,
		uniformindex = 33, -- if its >20, then its health/maxhealth
		uvoffset = 0.125, -- the X offset of the icon for this bar
	},
	featurereclaim = {
		mincolor = {0.00, 1.00, 0.00, 1.0},
		maxcolor = {0.85, 1.00, 0.85, 1.0},
		--bartype = 0,
		bartype = bitShowGlyph + bitPercentage,
		hidethreshold = 0.99,
		uniformindex = 2, -- if its >20, then its health/maxhealth
		uvoffset = 0.5, -- the X offset of the icon for this bar
	},
	featureresurrect = {
		mincolor = {0.75, 0.15, 0.75, 1.0},
		maxcolor = {1.0, 0.2, 1.0, 1.0},
		--bartype = 0,
		bartype = bitShowGlyph + bitPercentage,
		hidethreshold = 0.99,
		uniformindex = 1, -- if its >20, then its health/maxhealth
		uvoffset = 0.25, -- the X offset of the icon for this bar
	},
}

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local spec, fullview = Spring.GetSpectatingState()
local myTeamID = Spring.GetMyTeamID()
local myAllyTeamID = Spring.GetMyAllyTeamID()
local myPlayerID = Spring.GetMyPlayerID()
local GetUnitWeaponState = Spring.GetUnitWeaponState

local chobbyInterface

local unitDefIgnore = {} -- commanders!
local unitDefhasShield = {} -- value is shield max power
local unitDefCanStockpile = {} -- 0/1?
local unitDefReload = {} -- value is max reload time
local unitDefHeights = {} -- maps unitDefs to height
local unitDefHideDamage = {}
local unitDefPrimaryWeapon = {} -- the index for reloadable weapon on unitdef weapons

local unitBars = {} -- we need this additional table of {[unitID] = {barhealth, barrez, barreclaim}}
local unitEmpWatch = {}
local unitBeingBuiltWatch = {}
local unitCaptureWatch = {}
local unitShieldWatch = {} -- maps unitID to last shield value
local unitEmpDamagedWatch = {}
local unitParalyzedWatch = {}
local unitStockPileWatch = {}
local unitReloadWatch = {}

local featureDefHeights = {} -- maps FeatureDefs to height
local featureBars = {} -- we need this additional table of {[featureid] = {barhealth, barrez, barreclaim}}

--local empDecline = 1 / 40 --magic
local minReloadTime = 4 -- weapons reloading slower than this willget bars

local featureHealthVBO
local featureResurrectVBO
local featureReclaimVBO

local barScale = 1 -- Option 'healthbarsscale'
local variableBarSizes = true -- Option 'healthbarsvariable'

--local resurrectableFeaturesFast = {} -- value is  this is for keeping an eye on resurrectable features, maybe store resurrect progress here?
--local resurrectableFeaturesSlow = {} -- this is for keeping an eye on resurrectable features, maybe store resurrect progress here?
--local reclaimableFeaturesSlow = {} -- for faster updates of features being reclaimed/rezzed
--local reclaimableFeaturesFast = {} -- for faster updates of features being reclaimed/rezzed

--------------------------------------------------------------------------------
-- GL4 Backend stuff:
local healthBarVBO = nil
local healthBarShader = nil

local luaShaderDir = "LuaUI/Widgets/Include/"
local LuaShader = VFS.Include(luaShaderDir.."LuaShader.lua")
VFS.Include(luaShaderDir.."instancevbotable.lua")

-------------------- configurables -----------------------
local additionalheightaboveunit = 24 --16?
local featureHealthDistMult = 7 -- how many times closer features have to be for their bars to show
local featureReclaimDistMult = 2 -- how many times closer features have to be for their bars to show
local featureResurrectDistMult = 1 -- how many times closer features have to be for their bars to show
local glphydistmult = 3.5 -- how much closer than BARFADEEND the bar has to be to start drawing numbers/icons. Numbers closer to 1 will make the glyphs be drawn earlier, high numbers will only shows glyphs when zoomed in hard.
local glyphdistmultfeatures = 1.8 -- how much closer than BARFADEEND the bar has to be to start drawing numbers/icons


local unitDefSizeMultipliers = {} -- table of unitdefID to a size mult (default 1.0) to override sizing of bars per unitdef
local skipGlyphsNumbers = 0.0  -- 0.0 is draw glyph and number,  1.0 means only numbers, 2.0 means only bars,

local debugmode = false

local barHeight = 0.9
local shaderConfig = { -- these are our shader defines
	HEIGHTOFFSET = 3, -- Additional height added to everything
	CLIPTOLERANCE = 1.1, -- At 1.0 it wont draw at units just outside of view (may pop in), 1.1 is a good safe amount
	MAXVERTICES = 64, -- The max number of vertices we can emit, make sure this is consistent with what you are trying to draw (tris 3, quads 4, corneredrect 8, circle 64
	CLIPTOLERANCE = 1.2,
	BARWIDTH = 2.56,
	BARHEIGHT = barHeight,
	BGBOTTOMCOLOR = "vec4(0.25, 0.25, 0.25, 0.8)",
	BGTOPCOLOR = "vec4(0.1, 0.1, 0.1, 0.8)",
	BARSCALE = 4.0,
	PERCENT_VISIBILITY_MAX = 0.99,
	TIMER_VISIBILITY_MIN = 0.0,
	BARSTEP = 10, -- pixels to downshift per new bar
	BOTTOMDARKENFACTOR = 0.5,
	BARFADESTART = 3200,
	BARFADEEND = 3800,
	ATLASSTEP = 0.0625,
	MINALPHA = 0.2,
}
shaderConfig.BARCORNER = 0.06 + (shaderConfig.BARHEIGHT / 9)
shaderConfig.SMALLERCORNER = shaderConfig.BARCORNER * 0.6

if debugmode then
	shaderConfig.DEBUGSHOW = 1 -- comment this to always show all bars
end

local vsSrcPath = "LuaUI/Widgets/Shaders/HealthbarsGL4.vert.glsl"
local gsSrcPath = "LuaUI/Widgets/Shaders/HealthbarsGL4.geom.glsl"
local fsSrcPath = "LuaUI/Widgets/Shaders/HealthbarsGL4.frag.glsl"

local shaderSourceCache = {
		vssrcpath = vsSrcPath,
		fssrcpath = fsSrcPath,
		gssrcpath = gsSrcPath,
		shaderName = "Health Bars Shader GL4",
		uniformInt = {
			healthbartexture = 0;
			},
		uniformFloat = {
			--addRadius = 1,
			iconDistance = 27,
			cameraDistanceMult = 1.0,
			cameraDistanceMultGlyph = 4.0,
			skipGlyphsNumbers = 0.0,
			globalSizeMult = 1.0,
		  },
		shaderConfig = shaderConfig,		  
	}


-- Walk through unitdefs for the stuff we need:
for udefID, unitDef in pairs(UnitDefs) do
	if unitDef.customParams and unitDef.customParams.nohealthbars then
		unitDefIgnore[udefID] = true
	end --ignore debug units

	local shieldDefID = unitDef.shieldWeaponDef
	local shieldPower = ((shieldDefID) and (WeaponDefs[shieldDefID].shieldPower)) or (-1)
	if shieldPower > 1 then unitDefhasShield[udefID] = shieldPower
		--Spring.Echo("HAS SHIELD")
	end

	local weapons = unitDef.weapons
	local reloadTime = unitDef.reloadTime or 0
	local primaryWeapon = 1
	for i = 1, #weapons do
		local WeaponDef = WeaponDefs[weapons[i].weaponDef]
		if WeaponDef and WeaponDef.reload and WeaponDef.reload > reloadTime then
			reloadTime = WeaponDef.reload
			primaryWeapon = i
		end
	end
	unitDefHeights[udefID] = unitDef.height
	unitDefSizeMultipliers[udefID] = math.min(1.45, math.max(0.85, (Spring.GetUnitDefDimensions(udefID).radius / 150) + math.min(0.6, unitDef.power / 4000))) + math.min(0.6, unitDef.health / 22000)
	if unitDef.canStockpile then unitDefCanStockpile[udefID] = unitDef.canStockpile end
	if reloadTime and reloadTime > minReloadTime then
		if debugmode then Spring.Echo("Unit with watched reload time:", unitDef.name, reloadTime, minReloadTime) end

		unitDefReload[udefID] = reloadTime
		unitDefPrimaryWeapon[udefID] = primaryWeapon
	end
	if unitDef.hideDamage == true then
		unitDefHideDamage[udefID] = true
	end
end

for fdefID, featureDef in pairs(FeatureDefs) do
	--Spring.Echo(featureDef.name, featureDef.height)
	featureDefHeights[fdefID] = featureDef.height or 32
end


local function goodbye(reason)
  Spring.Echo("Healthbars GL4 widget exiting with reason: "..reason)
  widgetHandler:RemoveWidget()
end



local function initializeInstanceVBOTable(myName, usesFeatures)
	local newVBOTable
	newVBOTable = makeInstanceVBOTable(
		{
			{id = 0, name = 'height_timers', size = 4},
			{id = 1, name = 'type_index_ssboloc', size = 4, type = GL.UNSIGNED_INT},
			{id = 2, name = 'startcolor', size = 4},
			{id = 3, name = 'endcolor', size = 4},
			{id = 4, name = 'instData', size = 4, type = GL.UNSIGNED_INT},
		},
		256, -- maxelements
		myName, -- name
		4 -- unitIDattribID (instData)
	)
	if newVBOTable == nil then goodbye("Failed to create " .. myName) end

	local newVAO = gl.GetVAO()
	newVAO:AttachVertexBuffer(newVBOTable.instanceVBO)
	newVBOTable.VAO = newVAO
	if usesFeatures then newVBOTable.featureIDs = true end
	return newVBOTable
end


local function initGL4()
	healthBarShader =  LuaShader.CheckShaderUpdates(shaderSourceCache)

	if not healthBarShader then goodbye("Failed to compile health bars GL4 ") end

	healthBarVBO = initializeInstanceVBOTable("healthBarVBO", false)

	featureHealthVBO = initializeInstanceVBOTable("featureHealthVBO", true) -- we need separate ones for all feature health bars, as they seem to be
	featureResurrectVBO = initializeInstanceVBOTable("featureResurrectVBO", true)
	featureReclaimVBO = initializeInstanceVBOTable("featureReclaimVBO", true)

	if debugmode then
		healthBarVBO.debug = true
	end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

--'if DBGTRACE then Spring.Echo("%s:%d %s) | ", "caller:"..tostring(debug.getinfo(2).name) %s) end\n'
local healthBarTableCache = {}
for i = 1, 20 do healthBarTableCache[i] = 0.0 end


local function addBarForUnit(unitID, unitDefID, barname, reason)
	--Spring.Debug.TraceFullEcho()
	if debugmode then Spring.Debug.TraceEcho(unitBars[unitID]) end
	--Spring.Echo("Caller1:", tostring()".name), "caller2:", tostring(debug.getinfo(3).name))
	unitDefID = unitDefID or Spring.GetUnitDefID(unitID)

	-- Why? Because adding additional bars can be triggered from outside of unit tracker api
	-- like EMP, where we assume that unit is already visible, however
	-- debug units are not present in unittracker api!
	if (unitDefID == nil) or unitDefIgnore[unitDefID] then return nil end

	local gf = Spring.GetGameFrame()
	local bt = barTypeMap[barname]
	--if cnt == 1 then bt = barTypeMap.building end
	--if cnt == 2 then bt = barTypeMap.reload end
	local instanceID = unitID .. '_' .. barname
	--Spring.Echo(instanceID, barname, unitBars[unitID])
	if healthBarVBO.instanceIDtoIndex[instanceID] then
		if debugmode then Spring.Echo("Trying to add duplicate bar", unitID, instanceID, barname, reason, unitBars[unitID]) end
		return
	end -- we already have this bar !

	if unitDefID == nil or Spring.ValidUnitID(unitID) == false or Spring.GetUnitIsDead(unitID) == true then -- dead or invalid
		if debugmode then
			Spring.Debug.TraceEcho("Tried to add a bar to dead/invalid/nounitdef unit", unitID, unitdefID, barname)
		end
		return nil
	end

	if unitBars[unitID] == nil then
		if debugmode then
			Spring.Echo("A unit has no bars yet", UnitDefs[unitDefID].name, Spring.GetUnitPosition(unitID))
			Spring.Debug.TraceFullEcho()
			Spring.SendCommands({"pause 1"})
			Spring.Echo("No bars unit, last seen at", unitID)
			Spring.MarkerAddPoint(Spring.GetUnitPosition(unitID) )
		end
		unitBars[unitID] = 1
	end


	--local barpos = unitBars[unitID]
	--if bartype == 'emp_damage' or bartype == 'paralyze' then
	--	barpos = 33
	--else
	unitBars[unitID] = unitBars[unitID] + 1
	--end -- to keep these on top

	local effectiveScale = ((variableBarSizes and unitDefSizeMultipliers[unitDefID]) or 1.0) * barScale

	healthBarTableCache[1] = unitDefHeights[unitDefID] + additionalheightaboveunit * effectiveScale  -- height
	healthBarTableCache[2] = effectiveScale
	healthBarTableCache[3] = 0.0 -- unused
	healthBarTableCache[4] = bt.uvoffset -- glyph uv offset

	healthBarTableCache[5] = bt.bartype -- bartype int
	healthBarTableCache[6] = unitBars[unitID] - 1   -- bar index (how manyeth per unit)
	healthBarTableCache[7] = bt.uniformindex -- ssbo location offset (> 20 for health)

	healthBarTableCache[9] = bt.mincolor[1]
	healthBarTableCache[10] = bt.mincolor[2]
	healthBarTableCache[11] = bt.mincolor[3]
	healthBarTableCache[12] = bt.mincolor[4]

	healthBarTableCache[13] = bt.maxcolor[1]
	healthBarTableCache[14] = bt.maxcolor[2]
	healthBarTableCache[15] = bt.maxcolor[3]
	healthBarTableCache[16] = bt.maxcolor[4]

	return pushElementInstance(
		healthBarVBO, -- push into this Instance VBO Table
		healthBarTableCache,
		instanceID, -- this is the key inside the VBO Table, should be unique per unit
		true, -- update existing element
		nil, -- noupload, dont use unless you know what you want to batch push/pop
		unitID) -- last one should be featureID!
		-- we are returning here, to sign successful adds
end


local uniformcache = {0.0}

local function updateReloadBar(unitID, unitDefID, reason)
	if not unitDefPrimaryWeapon[unitDefID] then
		return
	end

	local reloadFrame = GetUnitWeaponState(unitID, unitDefPrimaryWeapon[unitDefID], 'reloadFrame')
	local reloadTime = GetUnitWeaponState(unitID, unitDefPrimaryWeapon[unitDefID], 'reloadTime')
	local gf = Spring.GetGameFrame()

	if (reloadFrame == nil or reloadFrame > gf) and unitReloadWatch[unitID] == nil then
		addBarForUnit(unitID, unitDefID, "reload", reason)
	end

	if (reloadFrame and reloadTime and gl.SetUnitBufferUniforms) then
		uniformcache[1] = reloadFrame - 30 * reloadTime
		gl.SetUnitBufferUniforms(unitID, uniformcache, 2)
		uniformcache[1] = reloadFrame
		gl.SetUnitBufferUniforms(unitID, uniformcache, 3)
	end
end

local function removeBarFromUnit(unitID, barname, reason) -- this will bite me in the ass later, im sure, yes it did, we need to just update them :P
	local instanceKey = unitID .. "_" .. barname
	if healthBarVBO.instanceIDtoIndex[instanceKey] then
		if debugmode then Spring.Debug.TraceEcho(reason) end
		--if barname == 'emp_damage' or barname == 'paralyze' then
			-- dont decrease counter for these
		--else
			unitBars[unitID] = unitBars[unitID] - 1
		--end
		popElementInstance(healthBarVBO, instanceKey)
	end
end


local function addBarsForUnit(unitID, unitDefID, unitTeam, unitAllyTeam, reason) -- TODO, actually, we need to check for all of these for stuff entering LOS

	if unitDefID == nil or Spring.ValidUnitID(unitID) == false or Spring.GetUnitIsDead(unitID) == true then
		if debugmode then Spring.Echo("Tried to add a bar to a dead or invalid unit", unitID, "at", Spring.GetUnitPosition(unitID), reason) end
		return
	end

	unitBars[unitID] = unitBars[unitID] or 0

	-- This is optionally passed, and it only important in one edge case:
	-- If a unit is captured and thus immediately become outside of LOS, then the getunitallyteam is still the old ally team according to getUnitAllyTEam, and not the new allyteam.
	unitAllyTeam = unitAllyTeam or Spring.GetUnitAllyTeam(unitID)
	local health, maxHealth, paralyzeDamage, capture, build = Spring.GetUnitHealth(unitID)
	if (fullview or (unitAllyTeam == myAllyTeamID) or (unitDefHideDamage[unitDefID] == nil)) and (unitDefIgnore[unitDefID] == nil ) then
		if debugmode and health == nil then
			Spring.Echo("Trying to add a healthbar to nil health unit", unitID, unitDefID)
			local ux, uy, uz = Spring.GetUnitPosition(unitID)
			Spring.MarkerAddPoint(ux, uy, uz, "health")
		end
		addBarForUnit(unitID, unitDefID, "health", reason)
	end
	if unitDefhasShield[unitDefID] then
		--Spring.Echo("hasshield")
		addBarForUnit(unitID, unitDefID, "shield", reason)
		unitShieldWatch[unitID] = -1.0
	end

	updateReloadBar(unitID, unitDefID, reason)

	if health ~= nil then
		if build < 1 then
			addBarForUnit(unitID, unitDefID, "building", reason)
			unitBeingBuiltWatch[unitID] = build
			uniformcache[1] = build
			gl.SetUnitBufferUniforms(unitID, uniformcache, 0)
		else
			uniformcache[1] = -1.0 -- mean that the unit has been built, we init it to -1 always
			gl.SetUnitBufferUniforms(unitID, uniformcache, 0)
		end
		--Spring.Echo(unitID, unitDefID, unitDefCanStockpile[unitDefID])
		if debugmode then
			if unitDefCanStockpile[unitDefID] then
				Spring.Echo("unitDefCanStockpile", unitAllyTeam, myAllyTeamID, fullview)
			end

		end

		if unitDefCanStockpile[unitDefID] and ((unitAllyTeam == myAllyTeamID) or fullview) then
			unitStockPileWatch[unitID] = 0.0
			addBarForUnit(unitID, unitDefID, "stockpile", reason)
		end
		if  capture > 0 then
			addBarForUnit(unitID, unitDefID, "capture", reason)
			uniformcache[1] = capture
			gl.SetUnitBufferUniforms(unitID, uniformcache, 5)
			unitCaptureWatch[unitID] = capture
		end

		if paralyzeDamage > 0 then
			--TODO

			if Spring.GetUnitIsStunned(unitID) then
				if unitParalyzedWatch[unitID] == nil then  -- already paralyzed
					unitParalyzedWatch[unitID] = 0.0
					-- if unit was already empd, remove that bar
					if unitEmpDamagedWatch[unitID] then
						unitEmpDamagedWatch[unitID] = nil
						removeBarFromUnit(unitID, 'emp_damage', 'unitEmpDamagedWatch')
					end
					addBarForUnit(unitID, unitDefID, "paralyzed", reason)
				end
			else
				if unitEmpDamagedWatch[unitID] == nil then
					unitEmpDamagedWatch[unitID] = 0.0
					addBarForUnit(unitID, unitDefID, "emp_damage", reason)
				end
			end
		end
	end
end

local function removeBarsFromUnit(unitID, reason)
	for barname,v in pairs(barTypeMap) do
		removeBarFromUnit(unitID, barname, reason)
	end
	unitShieldWatch[unitID] = nil
	unitCaptureWatch[unitID] = nil
	unitEmpDamagedWatch[unitID] = nil
	unitParalyzedWatch[unitID] = nil
	unitBeingBuiltWatch[unitID] = nil
	unitStockPileWatch[unitID] = nil
	unitReloadWatch[unitID] = nil
	unitBars[unitID] = nil
end


local function addBarToFeature(featureID,  barname)
	if debugmode then Spring.Debug.TraceEcho() end
	local featureDefID = Spring.GetFeatureDefID(featureID)

	local bt = barTypeMap[barname]

	local targetVBO = featureHealthVBO
	if barname == 'featurereclaim' then targetVBO = featureReclaimVBO end
	if barname == 'featureresurrect' then targetVBO = featureResurrectVBO end

	--Spring.Echo("addBarToFeature", featureID,  barname, featureDefHeights[featureDefID])
	if targetVBO.instanceIDtoIndex[featureID] then return end -- already exists, bail
	if featureBars[featureID] == nil then
		--Spring.Echo("this feature did not exist yet?", FeatureDefs[Spring.GetFeatureDefID(featureID)].name, Spring.GetFeaturePosition(featureID))
		featureBars[featureID] = 0
	end
	featureBars[featureID] = featureBars[featureID] + 1

	--Spring.Debug.TableEcho(bt)
	pushElementInstance(
		targetVBO, -- push into this Instance VBO Table
			{featureDefHeights[featureDefID] + additionalheightaboveunit,  -- height
			1.0 * barScale, -- size mult
			0, -- timer end
			bt.uvoffset, -- unused float

			bt.bartype, -- bartype int
			featureBars[featureID] - 1, -- bar index (how manyeth per unit)
			bt.uniformindex, -- ssbo location offset (> 20 for health)
			0, -- unused int

			bt.mincolor[1], bt.mincolor[2], bt.mincolor[3], bt.mincolor[4],
			bt.maxcolor[1], bt.maxcolor[2], bt.maxcolor[3], bt.maxcolor[4],
			0, 0, 0, 0}, -- these are just padding zeros for instData, that will get filled in
		featureID, -- this is the key inside the VBO Table, should be unique per unit
		true, -- update existing element
		nil, -- noupload, dont use unless you know what you want to batch push/pop
		featureID) -- last one should be featureID!
end


local function removeBarFromFeature(featureID, targetVBO)
	--Spring.Echo("removeBarFromFeature", featureID, targetVBO.myName)
	if targetVBO.instanceIDtoIndex[featureID] then
		popElementInstance(targetVBO, featureID)
	end
	if featureBars[featureID] then
		featureBars[featureID] = featureBars[featureID] - 1 -- TODO ERROR
	end
end

local function removeBarsFromFeature(featureID)
	removeBarFromFeature(featureID, featureHealthVBO)
	removeBarFromFeature(featureID, featureReclaimVBO)
	removeBarFromFeature(featureID, featureResurrectVBO)
end


local function init()
	clearInstanceTable(healthBarVBO)
	unitEmpWatch = {}
	unitBeingBuiltWatch = {}
	unitCaptureWatch = {}
	unitShieldWatch = {} -- maps unitID to last shield value
	unitEmpDamagedWatch = {}
	unitParalyzedWatch = {}
	unitStockPileWatch = {}
	unitReloadWatch = {}
	unitBars = {}
	for i, unitID in ipairs(Spring.GetAllUnits()) do -- gets radar blips too!
		-- probably shouldnt be adding non-visible units

		if fullview then
			addBarsForUnit(unitID, Spring.GetUnitDefID(unitID), Spring.GetUnitTeam(unitID), nil, 'initfullview')
		else
			local losstate = Spring.GetUnitLosState(unitID, myAllyTeamID)
			if losstate.los then
				addBarsForUnit(unitID, Spring.GetUnitDefID(unitID), Spring.GetUnitTeam(unitID), nil, 'initlos')
				--Spring.Echo(unitID, "IS in los")
			else
				--Spring.Echo(unitID, "is not in los for ", myAllyTeamID)
			end
		end
	end

end

local function initfeaturebars()
	clearInstanceTable(featureHealthVBO)
	clearInstanceTable(featureResurrectVBO)
	clearInstanceTable(featureReclaimVBO)
	local gameFrame = Spring.GetGameFrame()
	for i, featureID in ipairs(Spring.GetAllFeatures()) do
		local featureDefID = Spring.GetFeatureDefID(featureID)
		--local resurrectname = Spring.GetFeatureResurrect(featureID)
		--if resurrectname then
		--	resurrectableFeatures[featureID] = true
			-- if it has resurrect progress, then just straight up just store a bar here for it?
			-- or shall we only instantiate bars when needed? probably number 2 is smarter...
		--end -- maybe store resurrect progress here?

		if featureDefID then -- dont add features that we cant get the ID of
			-- add a health bar for it (dont add one for pre-existing stuff)
			widget:FeatureCreated(featureID)
		else

		end
	end
end

--12:32 PM] Beherith: widget:PlayerChanged generalizations
--[12:33 PM] Beherith: So, I would like to ask if we have a general guideline or if @Floris  knows anything about what circumstances should trigger UI GFX widget reinitialization
--[12:36 PM] Beherith: Here, I assume we can live with a few assumptions:
--1. UI GFX widgets are LOS dependent things, that either
--    A. Should look the same for all players on an ALLYteam
--    B. Could look different for each member of an ALLYTeam
--2. Always render different things for different ALLYteams
--This presents and interesting state for most widgets  especially for SPECFULLVIEW
--Obviously, the biggest reason for needing to abstract this is to avoid boilerplate mistakes for most new GL4 widgets, which are --stateful, unlike most previous widgets (most of which collected things they wanted to draw every frame)
--[12:39 PM] Beherith: So I assume widget:PlayerChanged gets called on any legal player change, and should keep track of the following:
--1. spectating state
--2. specfullview state
--3. myAllyTeamID
--4. myTeamID
--[12:40 PM] Beherith: There are 3 real states someone can be in:
--1. player
--2. spectator no fullview
--3. spectator with fullview

--(excluding godmode /globallos et al)
--[12:40 PM] Beherith: Transitions between any of the above 3 should trigger a full reinit
--[12:41 PM] Beherith: But some internal transitions, for stuff that is draw differently for allies might require additional checks, for spectators who have fullview off?


local function FeatureReclaimStartedHealthbars (featureID, step) -- step is negative for reclaim, positive for resurrect
	--Spring.Echo("FeatureReclaimStartedHealthbars", featureID)

    --gl.SetFeatureBufferUniforms(featureID, 0.5, 2) -- update GL
	if step > 0 then addBarToFeature(featureID, 'featureresurrect')
	else addBarToFeature(featureID, 'featurereclaim') end
end

local function UnitCaptureStartedHealthbars(unitID, step) -- step is negative for reclaim, positive for resurrect
	if debugmode then Spring.Echo("UnitCaptureStartedHealthbars", unitID) end
    --gl.SetFeatureBufferUniforms(featureID, 0.5, 2) -- update GL
	local capture = select(4, Spring.GetUnitHealth(unitID))
	unitCaptureWatch[unitID] = capture
	addBarForUnit(unitID, Spring.GetUnitDefID(unitID), 'capture', 'UnitCaptureStartedHealthbars')

end

--function widget:UnitDamaged(unitID, unitDefID, unitTeam, damage, paralyzer)
local function UnitParalyzeDamageHealthbars(unitID, unitDefID, damage)
	--Spring.Echo()
	if Spring.GetUnitIsStunned(unitID) then -- DO NOTE THAT: return: nil | bool stunned_or_inbuild, bool stunned, bool inbuild
		if unitParalyzedWatch[unitID] == nil then  -- already paralyzed
			unitParalyzedWatch[unitID] = 0.0
			-- if unit was already empd, remove that bar
			if unitEmpDamagedWatch[unitID] then
				unitEmpDamagedWatch[unitID] = nil
				removeBarFromUnit(unitID, 'emp_damage', 'unitEmpDamagedWatch')
			end
			addBarForUnit(unitID, unitDefID, "paralyzed", 'unitParalyzedWatch')
		end
	else
		if unitEmpDamagedWatch[unitID] == nil then
			unitEmpDamagedWatch[unitID] = 0.0
			addBarForUnit(unitID, unitDefID, "emp_damage", 'unitEmpDamagedWatch')
		end
	end
end

local function ProjectileCreatedReloadHB(projectileID, unitID, weaponID, unitDefID)
	local unitDefID = Spring.GetUnitDefID(unitID)

	updateReloadBar(unitID, unitDefID, 'ProjectileCreatedReloadHB')
end

function widget:Initialize()
	WG['healthbars'] = {}
	WG['healthbars'].getScale = function()
		return barScale
	end
	WG['healthbars'].setScale = function(value)
		barScale = value
		init()
		initfeaturebars()
	end
	WG['healthbars'].getVariableSizes = function()
		return variableBarSizes
	end
	WG['healthbars'].setVariableSizes = function(value)
		variableBarSizes = value
		init()
		initfeaturebars()
	end
	WG['healthbars'].getDrawWhenGuiHidden = function()
		return drawWhenGuiHidden
	end
	WG['healthbars'].setDrawWhenGuiHidden = function(value)
		drawWhenGuiHidden = value
	end

	initGL4()

	-- TODO: dont even bother drawing health bars for features that were present on frame 0 - no point in doing so
	-- This is stuff like trees and map features, and scenario features
	init()
	initfeaturebars()
	widgetHandler:RegisterGlobal("FeatureReclaimStartedHealthbars", FeatureReclaimStartedHealthbars )
	widgetHandler:RegisterGlobal("UnitCaptureStartedHealthbars", UnitCaptureStartedHealthbars )
	widgetHandler:RegisterGlobal("UnitParalyzeDamageHealthbars", UnitParalyzeDamageHealthbars )
	widgetHandler:RegisterGlobal("ProjectileCreatedReloadHB", ProjectileCreatedReloadHB )
end

function widget:Shutdown()
	widgetHandler:DeregisterGlobal("FeatureReclaimStartedHealthbars" )
	widgetHandler:DeregisterGlobal("UnitCaptureStartedHealthbars" )
	widgetHandler:DeregisterGlobal("UnitParalyzeDamageHealthbars" )
	widgetHandler:DeregisterGlobal("ProjectileCreatedReloadHB" )
	Spring.Echo("Healthbars GL4 unloaded hooks")
end

function widget:RecvLuaMsg(msg, playerID)
	if msg:sub(1,18) == 'LobbyOverlayActive' then
		chobbyInterface = (msg:sub(1,19) == 'LobbyOverlayActive1')
	end
end

--[[
function widget:UnitCreated(unitID, unitDefID, teamID)
	addBarsForUnit(unitID, unitDefID, teamID, nil, 'UnitCreated')
end

function widget:UnitDestroyed(unitID, unitDefID, teamID)
	if debugmode then Spring.Echo("HBGL4:UnitDestroyed",unitID, unitDefID, teamID) end
	removeBarsFromUnit(unitID,'UnitDestroyed')
end

function widget:UnitFinished(unitID, unitDefID, teamID) -- reset bars on construction complete?
	widget:UnitDestroyed(unitID, unitDefID, teamID)
	widget:UnitCreated(unitID, unitDefID, teamID)
end

function widget:UnitEnteredLos(unitID, unitTeam, allyTeam, unitDefID) -- this is still called when in spectator mode :D
	if not fullview then addBarsForUnit(unitID, Spring.GetUnitDefID(unitID), unitTeam, nil, 'UnitEnteredLos') end
end

function widget:UnitLeftLos(unitID, unitTeam, allyTeam, unitDefID)
	if spec and fullview then return end -- Interesting bug: if we change to spec with /spectator 1, then we receive unitLeftLos callins afterwards :P
	removeBarsFromUnit(unitID, 'UnitLeftLos')
end


function widget:UnitTaken(unitID, unitDefID, oldTeamID, newTeamID)
	local newAllyTeamID = select( 6, Spring.GetTeamInfo(newTeamID))

	if debugmode then
		Spring.Echo("widget:UnitTaken",unitID, unitDefID, oldTeamID, newTeamID, Spring.GetUnitAllyTeam(unitID),newAllyTeamID)
	end

	removeBarsFromUnit(unitID,'UnitTaken') -- because taken units dont actually call unitleftlos :D
	if newAllyTeamID == myAllyTeamID then  -- but taken units, that we see being taken trigger unitenteredlos  on the same frame
		addBarsForUnit(unitID, unitDefID, newTeamID, newAllyTeamID, 'UnitTaken')
	end
end

function widget:UnitGiven(unitID, unitDefID, newTeamID)
	--Spring.Echo("widget:UnitGiven",unitID, unitDefID, newTeamID)
	removeBarsFromUnit(unitID, 'UnitGiven')
	addBarsForUnit(unitID, unitDefID, newTeamID, nil,  'UnitTaken')
end
]]--


function widget:VisibleUnitAdded(unitID, unitDefID, unitTeam)
	addBarsForUnit(unitID, unitDefID, unitTeam, nil, 'VisibleUnitAdded')
end

function widget:VisibleUnitRemoved(unitID)
	removeBarsFromUnit(unitID, 'VisibleUnitRemoved')
end

function widget:VisibleUnitsChanged(extVisibleUnits, extNumVisibleUnits)
	unitBars = {}
	unitShieldWatch = {}
	unitCaptureWatch = {}
	unitEmpDamagedWatch = {}
	unitParalyzedWatch = {}
	unitBeingBuiltWatch = {}
	unitStockPileWatch = {}
	unitReloadWatch = {}
	spec, fullview = Spring.GetSpectatingState()
	myTeamID = Spring.GetMyTeamID()
	myAllyTeamID = Spring.GetMyAllyTeamID()
	myPlayerID = Spring.GetMyPlayerID()


	clearInstanceTable(healthBarVBO) -- clear all instances
	for unitID, unitDefID in pairs(extVisibleUnits) do
		addBarsForUnit(unitID, unitDefID, Spring.GetUnitTeam(unitID), nil, "VisibleUnitsChanged") -- TODO: add them with noUpload = true
	end
	--uploadAllElements(healthBarVBO) -- upload them all
end

function widget:PlayerChanged(playerID)

	local currentspec, currentfullview = Spring.GetSpectatingState()
	local currentTeamID = Spring.GetMyTeamID()
	local currentAllyTeamID = Spring.GetMyAllyTeamID()
	local currentPlayerID = Spring.GetMyPlayerID()
	local reinit = false

	if debugmode then Spring.Echo("HBGL4 widget:PlayerChanged",'spec', currentspec, 'fullview', currentfullview, 'teamID', currentTeamID, 'allyTeamID', currentAllyTeamID, "playerID", currentPlayerID) end

	-- cases where we need to trigger:
	if (currentspec ~= spec) or -- we transition from spec to player, yes this is needed
		(currentfullview ~= fullview) or -- we turn on or off fullview
		((currentAllyTeamID ~= myAllyTeamID) and not currentfullview)  -- our ALLYteam changes, and we are not in fullview
		--((currentTeamID ~= myTeamID) and not currentfullview)

		then
		-- do the actual reinit stuff, but first change my own
		reinit = true
		if debugmode then Spring.Echo("HBGL4 triggered a playerchanged reinit") end

	end
	-- save the state:
	spec = currentspec
	fullview = currentfullview
	myAllyTeamID = currentAllyTeamID
	myTeamID = currentTeamID
	myPlayerID = currentPlayerID
	--if reinit then init() end
end


function widget:GameFrame(n)

	if debugmode then
		locateInvalidUnits(healthBarVBO)
		locateInvalidUnits(featureHealthVBO)
	end
	-- Units:
	-- check shields
	if n % 3 == 0 then
		for unitID, oldshieldPower in pairs(unitShieldWatch) do
			local shieldOn, shieldPower = Spring.GetUnitShieldState(unitID)
			if shieldOn == false then shieldPower = 0.0 end
			if oldshieldPower ~= shieldPower then
				if shieldPower == nil then
					removeBarFromUnit(unitID, "shield", "unitShieldWatch")
				else
					uniformcache[1] = shieldPower / (unitDefhasShield[Spring.GetUnitDefID(unitID)])
					gl.SetUnitBufferUniforms(unitID, uniformcache, 2)
				end
				unitShieldWatch[unitID] = shieldPower
			end
		end
	end

	-- todo paralyzed and EMP doesnt work for enemy units :(
	-- check EMP'd units
	if (n + 1) % 3 == 0 then
		for unitID, oldempvalue in pairs(unitEmpDamagedWatch) do
			local health, maxHealth, newparalyzeDamage, capture, build = Spring.GetUnitHealth(unitID)
			if newparalyzeDamage and oldempvalue ~= newparalyzeDamage then
				if newparalyzeDamage == 0 then
					unitEmpDamagedWatch[unitID] = nil
					removeBarFromUnit(unitID, "emp_damage",'unitEmpDamagedWatch')
				else
					uniformcache[1] = newparalyzeDamage/ maxHealth
					unitEmpDamagedWatch[unitID] = newparalyzeDamage
					gl.SetUnitBufferUniforms(unitID, uniformcache, 4)
				end
			end
		end
	end

	-- check Paralyzed units
	if (n+2) % 3  == 0 then
		for unitID, paralyzetime in pairs(unitParalyzedWatch) do
			if Spring.GetUnitIsStunned(unitID) then
				local health, maxHealth, paralyzeDamage, capture, build = Spring.GetUnitHealth(unitID)
				--uniformcache[1] = math.floor((paralyzeDamage - maxHealth)) / (maxHealth * empDecline))
				if paralyzeDamage then
				
					-- this returns something like 1.20 which somehow turns into seconds somewhere unsearchable, currently wrong display
					-- this needs conditional fixing within an if Spring.GetModOptions().emprework
					uniformcache[1] = paralyzeDamage / maxHealth
					--Spring.Echo("Paralyze damages", paralyzeDamage, maxHealth)
					--Spring.Echo("Paralyze damage cur", (paralyzeDamage / maxHealth))

					gl.SetUnitBufferUniforms(unitID, uniformcache, 4)
				end
			else
				unitParalyzedWatch[unitID] = nil
				removeBarFromUnit(unitID, "paralyzed", 'unitEmpDamagedWatch')
				addBarForUnit(unitID, unitDefID, "emp_damage",'unitEmpDamagedWatch')
				unitEmpDamagedWatch[unitID] = 1.0
			end
		end
	end

	-- check build progress
	if (n % 1 == 0) then
		for unitID, buildprogress in pairs(unitBeingBuiltWatch) do
			local health, maxHealth, paralyzeDamage, capture, build = Spring.GetUnitHealth(unitID)
			if build and build ~= buildprogress then
				uniformcache[1] = build
				--Spring.Echo("Health", health/maxHealth, build, math.abs(build - health/maxHealth))
				--if math.abs(build - health/maxHealth) < 0.005 then uniformcache[1] = 1.0 end
				gl.SetUnitBufferUniforms(unitID,uniformcache, 0)
				unitBeingBuiltWatch[unitID] = buildProgress
				if build == 1 then
					removeBarFromUnit(unitID, "building", 'unitBeingBuiltWatch')
					unitBeingBuiltWatch[unitID] = nil
				else
					unitBeingBuiltWatch[unitID] = 1.0
				end
			end

		end

	end

	-- check capture progress?
	if (n % 1) == 0 then
		for unitID, captureprogress in pairs(unitCaptureWatch) do
			local capture = select(4, Spring.GetUnitHealth(unitID))
			if capture and capture ~= captureprogress then
				uniformcache[1] = capture
				gl.SetUnitBufferUniforms(unitID, uniformcache, 5)
				unitCaptureWatch[unitID] = capture
			end
			if capture == 0 or capture == nil then
				removeBarFromUnit(unitID, 'capture', 'unitCaptureWatch')
				unitCaptureWatch[unitID] = nil
			end
		end
	end

	-- check stockpile progress
	if (n % 5) == 2 then
		for unitID, stockpilebuild in pairs(unitStockPileWatch) do
			local numStockpiled, numStockpileQued, stockpileBuild = Spring.GetUnitStockpile(unitID)
			if stockpileBuild and stockpileBuild ~= stockpilebuild then
				-- we somehow need to forward 3 vars, all 3 of the above. packed into a float, this is nasty
				--Spring.Echo("Stockpiling", numStockpiled, numStockpileQued, stockpileBuild)
				if numStockpiled == nil then Spring.Debug.TraceFullEcho(nil,nil,nil, 'nostockpile', unitID, Spring.GetUnitPosition(unitID)) end

				uniformcache[1] =  numStockpiled + stockpileBuild -- less hacky
				--uniformcache[1] =  128*numStockpileQued + numStockpiled + stockpileBuild -- the worlds nastiest hack
				unitStockPileWatch[unitID] = stockpileBuild
				gl.SetUnitBufferUniforms(unitID, uniformcache, 2)
			end
		end
	end
end

local rezreclaim = {0.0, 1.0}
function widget:FeatureCreated(featureID)
	local featureDefID = Spring.GetFeatureDefID(featureID)
	local gameFrame = Spring.GetGameFrame()
	-- some map-supplied features dont have a model, in these cases modelpath == ""
	if FeatureDefs[featureDefID].name ~= 'geovent' and FeatureDefs[featureDefID].modelpath ~= ''  then
		--Spring.Echo(FeatureDefs[featureDefID].name)
		--featureBars[featureID] = 0 -- this is already done in AddBarToFeature

		local health,maxhealth,rezProgress = Spring.GetFeatureHealth(featureID)

		if gameFrame > 0 then
			addBarToFeature(featureID, 'featurehealth')
		else
			if health ~= maxhealth then addBarToFeature(featureID, 'featurehealth') end
		end


		if rezProgress > 0 then
			addBarToFeature(featureID, 'featureresurrect')
		end

		local _, _, _, _, reclaimLeft = Spring.GetFeatureResources(featureID)

		if reclaimLeft < 1.0 then
			addBarToFeature(featureID, 'featurereclaim')
		end

		if rezProgress > 0  or reclaimLeft < 1 then
			-- We have to update the feature uniform buffers in this case, as features can be created with less than max health on the map with FP_featureplacer
			rezreclaim[1] = rezProgress -- resurrect progress
			rezreclaim[2] = reclaimLeft -- reclaim percent
			gl.SetFeatureBufferUniforms(featureID, rezreclaim, 1) -- update GL, at offset of 1
		end

	end
end

function widget:FeatureDestroyed(featureID)
	if debugmode then Spring.Echo("FeatureDestroyed",featureID, featureBars[featureID]) end
	removeBarsFromFeature(featureID)
	featureBars[featureID] = nil
end

function widget:DrawWorld()
	--Spring.Echo(Engine.versionFull )
	if chobbyInterface then return end
	if not drawWhenGuiHidden and Spring.IsGUIHidden() then return end

    local now = os.clock()
	if Spring.GetGameFrame() % 90 == 0 then
		--Spring.Echo("healthBarVBO",healthBarVBO.usedElements, "featureHealthVBO",featureHealthVBO.usedElements)
	end
	if healthBarVBO.usedElements > 0 or featureHealthVBO.usedElements > 0 then -- which quite strictly, is impossible anyway
		local disticon = Spring.GetConfigInt("UnitIconDistance", 200) * 27.5 -- iconLength = unitIconDist * unitIconDist * 750.0f;
		gl.DepthTest(true)
		gl.DepthMask(true)
		gl.Texture(0,healthbartexture)
		healthBarShader:Activate()
		healthBarShader:SetUniform("iconDistance",disticon)
		if not debugmode then healthBarShader:SetUniform("cameraDistanceMult",1.0)  end
		healthBarShader:SetUniform("cameraDistanceMultGlyph", glphydistmult)
		healthBarShader:SetUniform("skipGlyphsNumbers",skipGlyphsNumbers)  --0.0 is everything,  1.0 means only numbers, 2.0 means only bars,
		if healthBarVBO.usedElements > 0 then
			healthBarVBO.VAO:DrawArrays(GL.POINTS,healthBarVBO.usedElements)
		end
		-- below its the feature bars being drawn:
			healthBarShader:SetUniform("cameraDistanceMultGlyph", glyphdistmultfeatures)
			if featureHealthVBO.usedElements > 0 then
				if not debugmode then healthBarShader:SetUniform("cameraDistanceMult",featureHealthDistMult)  end
				featureHealthVBO.VAO:DrawArrays(GL.POINTS,featureHealthVBO.usedElements)
			end
			if featureResurrectVBO.usedElements > 0 then
				if not debugmode then healthBarShader:SetUniform("cameraDistanceMult",featureResurrectDistMult)  end
				featureResurrectVBO.VAO:DrawArrays(GL.POINTS,featureResurrectVBO.usedElements)
			end
			if featureReclaimVBO.usedElements > 0 then
				if not debugmode then healthBarShader:SetUniform("cameraDistanceMult",featureReclaimDistMult)  end
				featureReclaimVBO.VAO:DrawArrays(GL.POINTS,featureReclaimVBO.usedElements)
			end

		healthBarShader:Deactivate()
		gl.Texture(false)
		gl.DepthTest(false)
    gl.DepthMask(false) --"BK OpenGL state resets", reset to default state
	end
end

function widget:TextCommand(command)
	if string.find(command, "debughealthbars", nil, true) == 1 then
		debugmode = not debugmode
		Spring.Echo("Debug mode for HealthBars GL4 set to", debugmode)
		healthBarVBO.debug = debugmode
	end
end

function widget:GetConfigData(data)
	return {
		barScale = barScale,
		barHeight = barHeight,
		variableBarSizes = variableBarSizes,
		drawWhenGuiHidden = drawWhenGuiHidden
	}
end

function widget:SetConfigData(data)
	barScale = data.barScale or barScale
	if data.variableBarSizes ~= nil then
		variableBarSizes = data.variableBarSizes
	end
	if data.drawWhenGuiHidden ~= nil then
		drawWhenGuiHidden = data.drawWhenGuiHidden
	end
	if data.barHeight ~= nil then
		barHeight = data.barHeight
		shaderSourceCache.shaderConfig.BARHEIGHT = barHeight
		shaderSourceCache.shaderConfig.BARCORNER = 0.06 + (shaderConfig.BARHEIGHT / 9)
		shaderSourceCache.shaderConfig.SMALLERCORNER = shaderConfig.BARCORNER * 0.6
	end
end
