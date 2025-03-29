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
		enabled   = false,
		depends   = {'gl4'},
	}
end

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

local enabledAsSpec = true

local buttonConfig = {
	ally = { ground = true, air = true, nuke = true },
	enemy = { ground = true, air = true, nuke = true }
}

local colorConfig = { --An array of R, G, B, Alpha
    drawStencil = true, -- wether to draw the outer, merged rings (quite expensive!)
    drawInnerRings = true, -- wether to draw inner, per defense rings (very cheap)
    externalalpha = 0.70, -- alpha of outer rings
    internalalpha = 0.0, -- alpha of inner rings
    distanceScaleStart = 2000, -- Linewidth is 100% up to this camera height
    distanceScaleEnd = 4000, -- Linewidth becomes 50% above this camera height
    ground = {
        color = {1.0, 0.2, 0.0, 1.0},
        fadeparams = { 2000, 5000, 1.0, 0.0}, -- FadeStart, FadeEnd, StartAlpha, EndAlpha
        externallinethickness = 4.0,
        internallinethickness = 2.0,
    },
    air = {
        color = {0.90, 0.45, 1.2, 1.0},
        fadeparams = { 2000, 5000, 0.4, 0.0}, -- FadeStart, FadeEnd, StartAlpha, EndAlpha
        externallinethickness = 4.0,
        internallinethickness = 2.0,
    },
    nuke = {
        color = {0.7, 0.8, 1.0, 1.0},
        fadeparams = {5000, 4000, 0.6, 0.0}, -- FadeStart, FadeEnd, StartAlpha, EndAlpha
        externallinethickness = 4.0,
        internallinethickness = 2.0,
    },
    cannon = {
        color = {1.0, 0.6, 0.0, 1.0},
        fadeparams = {3000, 6000, 0.8, 0.0}, -- FadeStart, FadeEnd, StartAlpha, EndAlpha
        externallinethickness = 4.0,
        internallinethickness = 2.0,
    },
}


--- Camera Height based line shrinkage:


----------------------------------

local buttonconfigmap ={'ground','air','nuke','ground'}
local DEBUG = false --generates debug message
local weaponTypeMap = {'ground','air','nuke','cannon'}

local unitDefRings = {} --each entry should be  a unitdefIDkey to very specific table:
	-- a list of tables, ideally ranged from 0 where

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
		local dps = 0
		local weaponType = unitDefRings[unitDefID]['weapons'][weaponNum]
		--Spring.Echo(weaponType)
		if weaponType ~= nil and weaponType > 0 then
			local damage = 0
			if weaponType == 2 then --AA
				damage = weaponDef.damages[vtoldamagetag]
			elseif weaponType == 3 then -- antinuke
				damage = 0
				range = weaponDef.coverageRange
				--Spring.Echo("init antinuke", range)
			else
				damage = weaponDef.damages[defaultdamagetag]
			end
			dps = damage * (weaponDef.salvoSize or 1) / (weaponDef.reload or 1)
			local color = colorConfig[weaponTypeMap[weaponType]].color
			local fadeparams =  colorConfig[weaponTypeMap[weaponType]].fadeparams

			local isCylinder = 1
			if weaponType == 1 or weaponType == 4 then -- all non-cannon ground weapons are spheres, aa and antinuke are cyls
				isCylinder = 0
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
		['armclaw'] = { weapons = { 1 } },
		['armllt'] = { weapons = { 1 } },
		['armbeamer'] = { weapons = { 1 } },
		['armhlt'] = { weapons = { 1 } },
		['armguard'] = { weapons = { 4} },
		['armrl'] = { weapons = { 2 } }, --light aa
		['armferret'] = { weapons = { 2 } },
		['armcir'] = { weapons = { 2 } }, --chainsaw
		['armdl'] = { weapons = { 1 } }, --depthcharge
		['armjuno'] = { weapons = { 1 } },
		['armtl'] = { weapons = { 1 } }, --torp launcher
		['armfhlt'] = { weapons = { 1 } },  --floating hlt
		['armfrt'] = { weapons = { 2 } },  --floating rocket laucher
		['armfflak'] = { weapons = { 2 } },  --floating flak AA
		['armatl'] = { weapons = { 1 } },  --adv torpedo launcher

		['armamb'] = { weapons = { 4 } }, --ambusher
		['armpb'] = { weapons = { 4 } }, --pitbull
		['armanni'] = { weapons = { 1 } },
		['armflak'] = { weapons = { 2 } },
		['armmercury'] = { weapons = { 2 } },
		['armemp'] = { weapons = { 1 } },
		['armamd'] = { weapons = { 3 } }, --antinuke

		['armbrtha'] = { weapons = { 4 } },
		['armvulc'] = { weapons = { 4 } },

		-- CORTEX
		['cormaw'] = { weapons = { 1 } },
		['corexp'] = { weapons = { 1} },
		['cormexp'] = { weapons = { 1,1 } },
		['corllt'] = { weapons = { 1 } },
		['corhllt'] = { weapons = { 1 } },
		['corhlt'] = { weapons = { 1 } },
		['corpun'] = { weapons = { 4} },
		['corrl'] = { weapons = { 2 } },
		['cormadsam'] = { weapons = { 2 } },
		['corerad'] = { weapons = { 2 } },
		['cordl'] = { weapons = { 1 } },
		['corjuno'] = { weapons = { 1 } },

		['corfhlt'] = { weapons = { 1 } },  --floating hlt
		['cortl'] = { weapons = { 1 } }, --torp launcher
		['coratl'] = { weapons = { 1 } }, --T2 torp launcher
		['corfrt'] = { weapons = { 2 } }, --floating rocket laucher
		['corenaa'] = { weapons = { 2 } }, --floating flak AA

		['cortoast'] = { weapons = { 4 } },
		['corvipe'] = { weapons = { 1 } },
		['cordoom'] = { weapons = { 1, 1, 1} },
		['corflak'] = { weapons = { 2 } },
		['corscreamer'] = { weapons = { 2 } },
		['cortron'] = { weapons = { 1 } },
		['corfmd'] = { weapons = { 3 } },
		['corint'] = { weapons = { 4 } },
		['corbuzz'] = { weapons = { 4 } },

		['armscab'] = { weapons = { 3 } },
		['armcarry'] = { weapons = { 3 } },
		['cormabm'] = { weapons = { 3 } },
		['corcarry'] = { weapons = { 3 } },
		['armantiship'] = { weapons = { 3 } },
		['corantiship'] = { weapons = { 3 } },

		-- LEGION
		['legabm'] = { weapons = { 3 } }, --antinuke
		['legrampart'] = { weapons = { 3 } }, --rampart

		-- SCAVENGERS
		['scavbeacon_t1_scav'] = { weapons = { 1 } },
		['scavbeacon_t2_scav'] = { weapons = { 1 } },
		['scavbeacon_t3_scav'] = { weapons = { 1 } },
		['scavbeacon_t4_scav'] = { weapons = { 1 } },

		['armannit3'] = { weapons = { 1 } },
		['armminivulc'] = { weapons = { 1 } },

		['cordoomt3'] = { weapons = { 1 } },
		['corhllllt'] = { weapons = { 1 } },
		['corminibuzz'] = { weapons = { 1 } }
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
		--Spring.Echo(k, unitName[k])
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
				--Spring.Echo(FeatureDefNames[unitDefName..suffix].id, unitDefID)
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
		buttonConfig[ally][rangetype]=enabled
		Spring.Echo("Range visibility of "..ally.." "..rangetype.." defenses set to",enabled)
		return true
	end

	return false
end

------ GL4 THINGS  -----
-- nukes and cannons:
local largeCircleVBO = nil
local largeCircleSegments = 512

-- others:
local smallCircleVBO = nil
local smallCircleSegments = 128

local weaponTypeToString = {"ground","air","nuke","cannon"}
local allyenemypairs = {"ally","enemy"}
local defenseRangeClasses = {'enemyair','enemyground','enemynuke','allyair','allyground','allynuke', 'enemycannon', 'allycannon'}
local defenseRangeVAOs = {}

local circleInstanceVBOLayout = {
		  {id = 1, name = 'posscale', size = 4}, -- a vec4 for pos + scale
		  {id = 2, name = 'color1', size = 4}, --  vec4 the color of this new
		  {id = 3, name = 'visibility', size = 4}, --- vec4 heightdrawstart, heightdrawend, fadefactorin, fadefactorout
		  {id = 4, name = 'projectileParams', size = 4}, --- heightboost gradient
		}

local luaShaderDir = "LuaUI/Include/"
local LuaShader = VFS.Include(luaShaderDir.."LuaShader.lua")
VFS.Include(luaShaderDir.."instancevbotable.lua")
local defenseRangeShader = nil


local function goodbye(reason)
  Spring.Echo("DefenseRange GL4 widget exiting with reason: "..reason)
  widgetHandler:RemoveWidget()
end

local function makeCircleVBO(circleSegments)
	circleSegments  = circleSegments -1 -- for po2 buffers
	local circleVBO = gl.GetVBO(GL.ARRAY_BUFFER,true)
	if circleVBO == nil then goodbye("Failed to create circleVBO") end

	local VBOLayout = {
	 {id = 0, name = "position", size = 4},
	}

	local VBOData = {}

	for i = 0, circleSegments  do -- this is +1
		VBOData[#VBOData+1] = math.sin(math.pi*2* i / circleSegments) -- X
		VBOData[#VBOData+1] = math.cos(math.pi*2* i / circleSegments) -- Y
		VBOData[#VBOData+1] = i / circleSegments -- circumference [0-1]
		VBOData[#VBOData+1] = 0
	end

	circleVBO:Define(
		circleSegments + 1,
		VBOLayout
	)
	circleVBO:Upload(VBOData)
	return circleVBO
end

local vsSrc = [[
#version 420
#line 10000

//__DEFINES__

layout (location = 0) in vec4 circlepointposition;
layout (location = 1) in vec4 posscale;
layout (location = 2) in vec4 color1;
layout (location = 3) in vec4 visibility; // FadeStart, FadeEnd, StartAlpha, EndAlpha
layout (location = 4) in vec4 projectileParams; // projectileSpeed, iscylinder!!!! , heightBoostFactor , heightMod

uniform float lineAlphaUniform = 1.0;
uniform float cannonmode = 0.0;

uniform sampler2D heightmapTex;
uniform sampler2D losTex; // hmm maybe?

out DataVS {
	flat vec4 blendedcolor;
};

//__ENGINEUNIFORMBUFFERDEFS__

#line 11000

float heightAtWorldPos(vec2 w){
	vec2 uvhm =  heightmapUVatWorldPos(w);
	return textureLod(heightmapTex, uvhm, 0.0).x;
}

float GetRangeFactor(float projectileSpeed) { // returns >0 if weapon can shoot here, <0 if it cannot, 0 if just right
	// on first run, with yDiff = 0, what do we get?
	float speed2d = projectileSpeed * 0.707106;
	float gravity =  120.0 	* (0.001111111);
	return ((speed2d * speed2d) * 2.0 ) / (gravity);
}

float GetRange2DCannon(float yDiff,float projectileSpeed,float rangeFactor,float heightBoostFactor) { // returns >0 if weapon can shoot here, <0 if it cannot, 0 if just right
	// on first run, with yDiff = 0, what do we get?

	//float factor = 0.707106;
	float smoothHeight = 100.0;
	float speed2d = projectileSpeed*0.707106;
	float speed2dSq = speed2d * speed2d;
	float gravity = -1.0*  (120.0 /900);

	if (heightBoostFactor < 0){
		heightBoostFactor = (2.0 - rangeFactor) / sqrt(rangeFactor);
	}

	if (yDiff < -100.0){
		yDiff = yDiff * heightBoostFactor;
	}else {
		if (yDiff < 0.0) {
			yDiff = yDiff * (1.0 + (heightBoostFactor - 1.0 ) * (-1.0 * yDiff) * 0.01);
		}
	}

	float root1 = speed2dSq + 2 * gravity *yDiff;
	if (root1 < 0.0 ){
		return 0.0;
	}else{
		return rangeFactor * ( speed2dSq + speed2d * sqrt( root1 ) ) / (-1.0 * gravity);
	}
}

//float heightMod  default: 0.2 (0.8 for #Cannon, 1.0 for #BeamLaser and #LightningCannon)
//Changes the spherical weapon range into an ellipsoid. Values above 1.0 mean the weapon cannot target as high as it can far, values below 1.0 mean it can target higher than it can far. For example 0.5 would allow the weapon to target twice as high as far.

//float heightBoostFactor default: -1.0
//Controls the boost given to range by high terrain. Values > 1.0 result in increased range, 0.0 means the cannon has fixed range regardless of height difference to target. Any value < 0.0 (i.e. the default value) result in an automatically calculated value based on range and theoretical maximum range.

#define RANGE posscale.w
#define PROJECTILESPEED projectileParams.x
#define ISCYLINDER projectileParams.y
#define HEIGHTBOOSTFACTOR projectileParams.z
#define HEIGHTMOD projectileParams.w
#define YGROUND posscale.y

#define OUTOFBOUNDSALPHA alphaControl.y
#define FADEALPHA alphaControl.z
#define MOUSEALPHA alphaControl.w


void main() {
	// translate to world pos:
	vec4 circleWorldPos = vec4(1.0);
	circleWorldPos.xz = circlepointposition.xy * RANGE +  posscale.xz;

	vec4 alphaControl = vec4(1.0);

	// get heightmap
	circleWorldPos.y = heightAtWorldPos(circleWorldPos.xz);


	if (cannonmode > 0.5){

		// BAR only has 3 distinct ballistic projectiles, heightBoostFactor is only a handful from -1 to 2.8 and 6 and 8
		// gravity we can assume to be linear

		float heightDiff = (circleWorldPos.y - YGROUND) * 0.5;

		float rangeFactor = RANGE /  GetRangeFactor(PROJECTILESPEED); //correct
		if (rangeFactor > 1.0 ) rangeFactor = 1.0;
		if (rangeFactor <= 0.0 ) rangeFactor = 1.0;
		float radius = RANGE;// - heightDiff;
		float adjRadius = GetRange2DCannon(heightDiff * HEIGHTMOD, PROJECTILESPEED, rangeFactor, HEIGHTBOOSTFACTOR);
		float adjustment = radius * 0.5;
		float yDiff = 0;
		float adds = 0;
		//for (int i = 0; i < mod(timeInfo.x/8,16); i ++){ //i am a debugging god
		for (int i = 0; i < 16; i ++){
				if (adjRadius > radius){
					radius = radius + adjustment;
					adds = adds + 1;
				}else{
					radius = radius - adjustment;
					adds = adds - 1;
				}
				adjustment = adjustment * 0.5;
				circleWorldPos.xz = circlepointposition.xy * radius + posscale.xz;
				float newY = heightAtWorldPos(circleWorldPos.xz );
				yDiff = abs(circleWorldPos.y - newY);
				circleWorldPos.y = max(0, newY);
				heightDiff = circleWorldPos.y - posscale.y;
				adjRadius = GetRange2DCannon(heightDiff * HEIGHTMOD, PROJECTILESPEED, rangeFactor, HEIGHTBOOSTFACTOR);
		}
	}else{
		if (ISCYLINDER < 0.5){ // isCylinder
			//simple implementation, 4 samples per point
			//for (int i = 0; i<mod(timeInfo.x/4,30); i++){
			for (int i = 0; i<8; i++){
				// draw vector from centerpoint to new height point and normalize it to range length
				vec3 tonew = circleWorldPos.xyz - posscale.xyz;
				tonew.y *= HEIGHTMOD;
				tonew = normalize(tonew) * RANGE;
				circleWorldPos.xz = posscale.xz + tonew.xz;
				circleWorldPos.y = heightAtWorldPos(circleWorldPos.xz);
			}
		}
	}

	circleWorldPos.y += 6; // lift it from the ground

	// -- MAP OUT OF BOUNDS
	vec2 mymin = min(circleWorldPos.xz,mapSize.xy - circleWorldPos.xz);
	float inboundsness = min(mymin.x, mymin.y);
	OUTOFBOUNDSALPHA = 1.0 - clamp(inboundsness*(-0.02),0.0,1.0);


	//--- DISTANCE FADE ---
	vec4 camPos = cameraViewInv[3];
	float distToCam = length(posscale.xyz - camPos.xyz); //dist from cam
	// FadeStart, FadeEnd, StartAlpha, EndAlpha
	float fadeDist = visibility.y - visibility.x;
	FADEALPHA  = clamp((visibility.y - distToCam)/(fadeDist),0,1);//,visibility.z,visibility.w);

	//--- Optimize by anything faded out getting transformed back to origin with 0 range?
	//seems pretty ok!
	if (FADEALPHA < 0.001) {
		circleWorldPos.xyz = posscale.xyz;
	}

	if (cannonmode > 0.5){
	// cannons should fade distance based on their range
		float cvmin = max(visibility.x, 2* RANGE);
		float cvmax = max(visibility.y, 4* RANGE);
		//FADEALPHA = clamp((cvmin - distToCam)/(cvmax - cvmin + 1.0),visibility.z,visibility.w);
	}

	blendedcolor = color1;

	// -- DARKEN OUT OF LOS
	vec4 losTexSample = texture(losTex, vec2(circleWorldPos.x / mapSize.z, circleWorldPos.z / mapSize.w)); // lostex is PO2
	float inlos = dot(losTexSample.rgb,vec3(0.33));
	inlos = clamp(inlos*5 -1.4	, 0.5,1.0); // fuck if i know why, but change this if LOSCOLORS are changed!
	blendedcolor.rgb *= inlos;

	// --- YES FOG
	float fogDist = length((cameraView * vec4(circleWorldPos.xyz,1.0)).xyz);
	float fogFactor = clamp((fogParams.y - fogDist) * fogParams.w, 0, 1);
	blendedcolor.rgb = mix(fogColor.rgb, vec3(blendedcolor), fogFactor);


	// -- IN-SHADER MOUSE-POS BASED HIGHLIGHTING
	float disttomousefromunit = 1.0 - smoothstep(48, 64, length(posscale.xz - mouseWorldPos.xz));
	// this will be positive if in mouse, negative else
	float highightme = clamp( (disttomousefromunit ) + 0.0, 0.0, 1.0);
	MOUSEALPHA = highightme;

	// ------------ dump the stuff for FS --------------------
	//worldPos = circleWorldPos;
	//worldPos.a = RANGE;
	alphaControl.x = circlepointposition.z; // save circle progress here
	gl_Position = cameraViewProj * vec4(circleWorldPos.xyz, 1.0);


	//lets blend the alpha here, and save work in FS:
	float outalpha = OUTOFBOUNDSALPHA * (MOUSEALPHA + FADEALPHA *  lineAlphaUniform);
	blendedcolor.a *= outalpha ;
	//blendedcolor.rgb = vec3(fract(distToCam/100));
}
]]

local fsSrc =  [[
#version 330

#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require

//_DEFINES__

#line 20000


//_ENGINEUNIFORMBUFFERDEFS__

in DataVS {
	flat vec4 blendedcolor;
};

out vec4 fragColor;

void main() {
	fragColor = blendedcolor; // now pared down to only this, all work is done in vertex shader now
}
]]


local function makeShaders()
	local engineUniformBufferDefs = LuaShader.GetEngineUniformBufferDefs()
	vsSrc = vsSrc:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineUniformBufferDefs)
	fsSrc = fsSrc:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineUniformBufferDefs)
	defenseRangeShader =  LuaShader(
	{
		vertex = vsSrc:gsub("//__DEFINES__", "#define MYGRAVITY "..tostring(Game.gravity+0.1)),
		fragment = fsSrc,
		--geometry = gsSrc, no geom shader for now
		uniformInt = {
			heightmapTex = 0,
			losTex = 1,
		},
		uniformFloat = {
			lineAlphaUniform = 1,
			cannonmode = 0,
		},
	},
	"defenseRangeShader GL4"
	)
	shaderCompiled = defenseRangeShader:Initialize()
	if not shaderCompiled then
		goodbye("Failed to compile defenseRangeShader GL4 ")
		return false
	end
	return true
end

local function initGL4()
	smallCircleVBO = makeCircleVBO(smallCircleSegments)
	largeCircleVBO = makeCircleVBO(largeCircleSegments)
	for i,defRangeClass in ipairs(defenseRangeClasses) do
		defenseRangeVAOs[defRangeClass] = makeInstanceVBOTable(circleInstanceVBOLayout,16,defRangeClass .. "_defenserange_gl4")
		if defRangeClass:find("cannon", nil, true) or defRangeClass:find("nuke", nil, true) then
			defenseRangeVAOs[defRangeClass].vertexVBO = largeCircleVBO
			defenseRangeVAOs[defRangeClass].numVertices = largeCircleSegments
		else
			defenseRangeVAOs[defRangeClass].vertexVBO = smallCircleVBO
			defenseRangeVAOs[defRangeClass].numVertices = smallCircleSegments
		end
		local newVAO = makeVAOandAttach(defenseRangeVAOs[defRangeClass].vertexVBO,defenseRangeVAOs[defRangeClass].instanceVBO)
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
				buttonConfig[ae][wt] = value
				Spring.Echo(string.format("Defense Range GL4 Setting %s%s to %s",Ae,Wt, value and 'on' or 'off'))
				if WG['unittrackerapi'] and WG['unittrackerapi'].visibleUnits then
					widget:VisibleUnitsChanged(WG['unittrackerapi'].visibleUnits, nil)
				end
			end
		end
	end
	myAllyTeam = Spring.GetMyAllyTeamID()
	local allyteamlist = Spring.GetAllyTeamList( )
	--Spring.Echo("# of allyteams = ", #allyteamlist)
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
for i=1,16 do cacheTable[i] = 0 end

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
		if buttonConfig[allystring][buttonconfigmap[weaponType]] then
			--local weaponType = unitDefRings[unitDefID]['weapons'][weaponNum]
			cacheTable[1] = mpx
			cacheTable[2] = mpy
			cacheTable[3] = mpz
			local vaokey = allystring .. weaponTypeToString[weaponType]

			local ringParams = unitDefRings[unitDefID]['rings'][i]
			for i = 1,13 do
				cacheTable[i+3] = ringParams[i]
			end
			if true then
				local s = ' '
				for i = 1,16 do
					s = s .. "; " ..tostring(cacheTable[i])
				end
				--Spring.Echo("Adding rings for", unitID, x,z)
				--Spring.Echo("added",vaokey,s)
			end
			local instanceID = 1000000 * weaponType + unitID
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
		Spring.Echo("Defense Range GL4 disabled in spectating state")
		widget:RemoveWidget()
		return
	end
	defenses = {}
	enemydefenses = {}
	defensePosHash = {}
	mobileAntiUnits = {}
	for vaokey, instanceTable in pairs(defenseRangeVAOs) do
		clearInstanceTable(instanceTable) -- clear all instances
	end
	for unitID, unitDefID in pairs(extVisibleUnits) do
		UnitDetected(unitID, unitDefID, Spring.GetUnitTeam(unitID), true) -- add them with noUpload = true
	end
	for vaokey, instanceTable in pairs(defenseRangeVAOs) do
		uploadAllElements(instanceTable) -- clear all instances
	end
end

local function checkEnemyUnitConfirmedDead(unitID, defense)
	local x, y, z = defense["posx"], defense["posy"], defense["posz"]
	local _, losState, _ = spGetPositionLosState(x, y, z)
	--Spring.Echo("checkEnemyUnitConfirmedDead",unitID, losState, spGetUnitDefID(unitID), Spring.GetUnitIsDead(unitID))
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
		--Spring.Echo(vaoKey,instanceKey)
		if defenseRangeVAOs[vaoKey].instanceIDtoIndex[instanceKey] then
			popElementInstance(defenseRangeVAOs[vaoKey],instanceKey)
		end
	end
	defenses[unitID] = nil
end

function widget:VisibleUnitRemoved(unitID) -- remove the corresponding ground plate if it exists
	if defenses[unitID] == nil then return end -- nothing to do

	local defense = defenses[unitID]
	--local teamID = Spring.GetUnitTeam(unitID)
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
				--Spring.Echo("feature created at a likely dead defense pos!")
				removeUnit(unitID,defenses[unitID])
			end
		end
	end
end

function widget:PlayerChanged(playerID)
	--[[
	Spring.Echo("playerchanged", playerID)
	local GetLocalPlayerID  = Spring.GetLocalPlayerID( )
	--Spring.Echo("GetLocalPlayerID", GetLocalPlayerID)
	local GetMyTeamID = Spring.GetMyTeamID ( )
	--Spring.Echo("GetMyTeamID", GetMyTeamID)
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
		--Spring.Echo("DefenseRange GL4 allyteam change detected, reinitializing")
		if WG['unittrackerapi'] and WG['unittrackerapi'].visibleUnits then
			widget:VisibleUnitsChanged(WG['unittrackerapi'].visibleUnits, nil)
		end
	else
		--Spring.Echo("No change needed", numallyteams, myAllyTeam)
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

function widget:Update(dt)
	--spec, fullview = spGetSpectatingState()
	--if spec then
	--	return
	--end

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
					--Spring.Echo("Anti at",unitID, px, pz,mobileantiinfo[1],mobileantiinfo[2],vbodata[1],vbodata[2])
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
					--Spring.Echo("removal",unitID, losState)
					if losState then
						if not spGetUnitDefID(unitID) then
							removeUnit(unitID, defense)
						end
					end
				end
			end
		end
		--Spring.Echo("removestep", removestep , scanned)
	end
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
	local camheight = camY - math.max(Spring.GetGroundHeight(camX, camZ), 0)
	-- Smoothstep to half line width as camera goes over 2k height to 4k height
	--genType t;  /* Or genDType t; */
    --t = clamp((x - edge0) / (edge1 - edge0), 0.0, 1.0);
    --return t * t * (3.0 - 2.0 * t);

	camheight = math.clamp((camheight - colorConfig.distanceScaleStart) / (colorConfig.distanceScaleEnd - colorConfig.distanceScaleStart), 0, 1)
	--return camheight * camheight * (3 - 2 *camheight)
	return 1
end

local groundnukeair = {"ground","air","nuke"}
local function DRAWRINGS(primitiveType, linethickness)
	local stencilMask
	defenseRangeShader:SetUniform("cannonmode",0)
	for i,allyState in ipairs(allyenemypairs) do
		for j, wt in ipairs(groundnukeair) do
			local defRangeClass = allyState..wt
			local iT = defenseRangeVAOs[defRangeClass]
			stencilMask = 2 ^ ( 4 * (i-1) + (j-1)) -- from 1 to 128
			drawcounts[stencilMask] = iT.usedElements
			if iT.usedElements > 0 and buttonConfig[allyState][wt] then
				if linethickness then
					glLineWidth(colorConfig[wt][linethickness] * cameraHeightFactor)
				end
				glStencilMask(stencilMask)  -- only allow these bits to get written
				glStencilFunc(GL.NOTEQUAL, stencilMask, stencilMask) -- what to do with the stencil
				iT.VAO:DrawArrays(primitiveType,iT.numVertices,0,iT.usedElements,0) -- +1!!!
			end
		end
	end

	defenseRangeShader:SetUniform("cannonmode",1)
	for i,allyState in ipairs(allyenemypairs) do
		local defRangeClass = allyState.."cannon"
		local iT = defenseRangeVAOs[defRangeClass]
		stencilMask = 2 ^ ( 4 * (i-1) + 3)
		drawcounts[stencilMask] = iT.usedElements
		if iT.usedElements > 0 and buttonConfig[allyState]["ground"] then
			if linethickness then
				glLineWidth(colorConfig['cannon'][linethickness] * cameraHeightFactor)
			end
			glStencilMask(stencilMask)
			glStencilFunc(GL.NOTEQUAL, stencilMask, stencilMask)
			iT.VAO:DrawArrays(primitiveType,iT.numVertices,0,iT.usedElements,0) -- +1!!!
		end
	end
end

function widget:DrawWorldPreUnit()
	--if fullview and not enabledAsSpec then
	--	return
	--end
	if chobbyInterface then return end
	if not Spring.IsGUIHidden() and (not WG['topbar'] or not WG['topbar'].showingQuit()) then
		cameraHeightFactor = GetCameraHeightFactor() * 0.5 + 0.5
		glTexture(0, "$heightmap")
		glTexture(1, "$info")

		-- Stencil Setup
		-- 	-- https://learnopengl.com/Advanced-OpenGL/Stencil-testing
		if colorConfig.drawStencil then
			glClear(GL.STENCIL_BUFFER_BIT) -- clear prev stencil
			glDepthTest(false) -- always draw
			glColorMask(false, false, false, false) -- disable color drawing
			glStencilTest(true) -- enable stencil test
			glStencilMask(255) -- all 8 bits
			glStencilOp(GL_KEEP, GL_KEEP, GL_REPLACE) -- Set The Stencil Buffer To 1 Where Draw Any Polygon

			defenseRangeShader:Activate()
			DRAWRINGS(GL.TRIANGLE_FAN) -- FILL THE CIRCLES
			--glLineWidth(math.max(0.1,4 + math.sin(gameFrame * 0.04) * 10))
			glColorMask(true, true, true, true)	-- re-enable color drawing
			glStencilMask(0)

			defenseRangeShader:SetUniform("lineAlphaUniform",colorConfig.externalalpha)
			glDepthTest(GL.LEQUAL) -- test for depth on these outside cases
			DRAWRINGS(GL.LINE_LOOP, 'externallinethickness') -- DRAW THE OUTER RINGS
			glStencilTest(false)

		end

		if colorConfig.drawInnerRings then
			defenseRangeShader:SetUniform("lineAlphaUniform",colorConfig.internalalpha)
			DRAWRINGS(GL.LINE_LOOP, 'internallinethickness') -- DRAW THE INNER RINGS
		end

		defenseRangeShader:Deactivate()

		glTexture(0, false)
		glTexture(1, false)
		glDepthTest(false)
		if false and Spring.GetDrawFrame() % 60 == 0 then
			local s = 'drawcounts: '
			for k,v in pairs(drawcounts) do s = s .. " " .. tostring(k) .. ":" .. tostring(v) end
			Spring.Echo(s)
		end
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
			buttonConfig = data["enabled"]
			--printDebug("enabled config found...")
		end
	end
end


