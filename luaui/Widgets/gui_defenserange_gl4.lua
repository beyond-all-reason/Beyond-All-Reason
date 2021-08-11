include("keysym.h.lua")

local versionNumber = "6.32"

function widget:GetInfo()
	return {
		name      = "Defense Range GL4",
		desc      = "Displays range of defenses (enemy and ally)",
		author    = "Beherith, very_bad_soldier",
		date      = "2021.04.26",
		license   = "Lua: GPLv2, GLSL: (c) Beherith (mysterme@gmail.com)",
		layer     = -100,
		enabled   = false
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
-- separate air and ground types and show based on selection (UNIFORM OR NOT?)
-- better animations!!!
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
--merge mobile antis into this

 
------ CLASSIG DEFENSE RANGE THINGS  --------------
local debug = false --generates debug message
local enabledAsSpec = true

 
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
	armguard = { weapons = { 5} },
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

	armamb = { weapons = { 5,5 } }, --ambusher
	armpb = { weapons = { 5 } }, --pitbull
	armanni = { weapons = { 1 } },
	armflak = { weapons = { 2 } },
	armmercury = { weapons = { 2 } },
	armemp = { weapons = { 1 } },
	armamd = { weapons = { 3 } }, --antinuke

	armbrtha = { weapons = { 5 } },
	armvulc = { weapons = { 5 } },

	-- CORTEX
	cormaw = { weapons = { 1 } },
	corexp = { weapons = { 1 } },
	corllt = { weapons = { 1 } },
	corhllt = { weapons = { 1 } },
	corhlt = { weapons = { 1 } },
	corpun = { weapons = { 5} },
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

	cortoast = { weapons = { 5 } },
	corvipe = { weapons = { 1 } },
	cordoom = { weapons = { 1, 1, 1} },
	corflak = { weapons = { 2 } },
	corscreamer = { weapons = { 2 } },
	cortron = { weapons = { 1 } },
	corfmd = { weapons = { 3 } },
	corint = { weapons = { 5 } },
	corbuzz = { weapons = { 5 } },
	
	armscab =  { weapons = { 3 } },
	armcarry =  { weapons = { 3 } },
	cormabm =  { weapons = { 3 } },
	corcarry =  { weapons = { 3 } },

	-- SCAVENGERS
	scavengerdroppodbeacon_scav = { weapons = { 1 } }
}

-- add scavs
local toscav = {}
for k,v in pairs(modConfig["BYAR"]["unitList"]) do
	toscav[#toscav+1] = k
end
for i,k in ipairs(toscav) do
	modConfig["BYAR"]["unitList"][k..'_scav'] =  modConfig["BYAR"]["unitList"][k]
end

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
modConfig["BYAR"]["dps"]["cannon"] = {}
modConfig["BYAR"]["dps"]["cannon"]["min"] = 80
modConfig["BYAR"]["dps"]["cannon"]["max"] = 500
--end of dps-colors


--DEFAULT COLOR CONFIG
--is used when no game-specfic color config is found in current game-definition
local colorConfig = { --An array of R, G, B, MouseAlpha, FadeStart, FadeEnd, StartAlpha, EndAlpha
	enemy = {
		ground = {
			min = {1.0, 0.2, 0.0, 1.0, 2000, 6000, 1.0, 0.2},
			max = {1.0, 1.0, 0.0, 1.0, 2000, 6000, 1.0, 0.2},
		},
		air = {
			min = {0.5, 0.0, 1.0, 1.0, 2000, 6000, 0.8, 0.2},
			max = {0.5, 0.0, 1.0, 1.0, 3000, 6000, 0.8, 0.2},
		},
		nuke =        {1.0, 1.0, 1.0, 1.0, 5000, 4000, 0.6, 0.2},
		cannon = {
			min = {1.0, 1.0, 0.0, 1.0, 2000, 6000, 0.8, 0.2},
			max = {1.0, 1.0, 0.0, 1.0, 10000, 15000, 0.8, 0.2},
		}
	}
}

local mobileAntiUnitDefs = {}
local arm_mobile_anti			= UnitDefNames.armscab.id
local arm_mobile_anti_water		= UnitDefNames.armcarry.id
local cor_mobile_anti			= UnitDefNames.cormabm.id
local cor_mobile_anti_water		= UnitDefNames.corcarry.id
mobileAntiUnitDefs[arm_mobile_anti] = true
mobileAntiUnitDefs[arm_mobile_anti_water] = true
mobileAntiUnitDefs[cor_mobile_anti] = true
mobileAntiUnitDefs[cor_mobile_anti_water] = true

local mobileAntiUnits = {} -- this is a table of unitids that are antis, and we shall put them into this
--each entry will be: unitID = {"allegience","VBOkey"}

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
local buttonConfig = {
	ally = { ground = false, air = false, nuke = false,  radar = false },
	enemy = { ground = true, air = true, nuke = true,  radar = false }
}

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
lineConfig["lineWidth"] = 1.33 -- calcs dynamic now


--------------------------------------------------------------------------------

local GL_LINE_LOOP          = GL.LINE_LOOP
local glDepthTest           = gl.DepthTest
local glLineWidth           = gl.LineWidth
local glTexture             = gl.Texture

local max					= math.max
local min					= math.min
local sqrt					= math.sqrt
local abs					= math.abs
local lower                 = string.lower
local sub                   = string.sub
local upper                 = string.upper
local floor                 = math.floor
local format                = string.format
local PI                    = math.pi
local cos                   = math.cos
local sin                   = math.sin

local spEcho                = Spring.Echo
local spGetGameSeconds      = Spring.GetGameSeconds
local spGetMouseState       = Spring.GetMouseState
local spGetMyPlayerID       = Spring.GetMyPlayerID
local spGetPlayerInfo       = Spring.GetPlayerInfo
local spGetPositionLosState = Spring.GetPositionLosState
local spGetUnitDefID        = Spring.GetUnitDefID
local spGetUnitPosition     = Spring.GetUnitPosition
local spTraceScreenRay      = Spring.TraceScreenRay
local spGetCameraPosition   = Spring.GetCameraPosition
local spGetGroundHeight 	= Spring.GetGroundHeight
local spIsGUIHidden 		= Spring.IsGUIHidden
local spGetLocalTeamID	 	= Spring.GetLocalTeamID

local udefTab				= UnitDefs

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

function init()
	local units = Spring.GetAllUnits()
	for i=1, #units do
		local unitID = units[i]
		UnitDetected(unitID, Spring.GetUnitAllyTeam(unitID) == myAllyTeam)
	end
end

------ GL4 THINGS  -----
-- nukes and cannons:
local largeCircleVBO = nil
local largeCircleSegments = 1024

-- others:
local smallCircleVBO = nil
local smallCircleSegments = 256

local weaponTypeToString = {"ground","air","nuke","ground","cannon"}
local defenseRangeClasses = {'enemyair','enemyground','enemynuke','allyair','allyground','allynuke', 'enemycannon', 'allycannon'}
local defenseRangeVAOs = {}

local circleInstanceVBOLayout = {
		  {id = 1, name = 'posscale', size = 4}, -- a vec4 for pos + scale
		  {id = 2, name = 'color1', size = 4}, --  vec4 the color of this new
		  {id = 3, name = 'visibility', size = 4}, --- vec4 heightdrawstart, heightdrawend, fadefactorin, fadefactorout. 
		  {id = 4, name = 'projectileParams', size = 4}, --- heightboost gradient
		}

local luaShaderDir = "LuaUI/Widgets/Include/"
local LuaShader = VFS.Include(luaShaderDir.."LuaShader.lua")
VFS.Include(luaShaderDir.."instancevbotable.lua")
local sphereCylinderShader = nil
local cannonShader = nil




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

uniform vec4 circleuniforms; // none yet

uniform sampler2D heightmapTex;
uniform sampler2D losTex; // hmm maybe?

out DataVS {
	vec4 worldPos; // pos and radius
	vec4 blendedcolor;
	vec4 alphaControl; // xyzw: circumference progress, outofboundsalpha,  fadealpha ,mousealpha,
};

//__ENGINEUNIFORMBUFFERDEFS__

#line 11000

float heightAtWorldPos(vec2 w){
	vec2 uvhm =   vec2(clamp(w.x,8.0,mapSize.x-8.0),clamp(w.y,8.0, mapSize.y-8.0))/ mapSize.xy; 
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

//    Changes the spherical weapon range into an ellipsoid. Values above 1.0 mean the weapon cannot target as high as it can far, values below 1.0 mean it can target higher than it can far. For example 0.5 would allow the weapon to target twice as high as far.

//float heightBoostFactor default: -1.0

    //Controls the boost given to range by high terrain. Values > 1.0 result in increased range, 0.0 means the cannon has fixed range regardless of height difference to target. Any value < 0.0 (i.e. the default value) result in an automatically calculated value based on range and theoretical maximum range.

#define RANGE posscale.w
#define PROJECTILESPEED projectileParams.x
#define ISCYLINDER projectileParams.y
#define HEIGHTBOOSTFACTOR projectileParams.z
#define HEIGHTMOD projectileParams.w
#define YGROUND posscale.y

void main() {
	// translate to world pos:
	vec4 circleWorldPos = vec4(1.0);
	circleWorldPos.xz = circlepointposition.xy * RANGE +  posscale.xz;
	
	alphaControl = vec4(1.0);
	
	// get heightmap 
	circleWorldPos.y = heightAtWorldPos(circleWorldPos.xz);
	/*
	#ifndef CANNON
		if (ISCYLINDER < 0.5){ // isCylinder
			//simple implementation, 4 samples per point
			for (int i = 0; i<mod(timeInfo.x/4,30); i++){
			//for (int i = 0; i<4; i++){
				// draw vector from centerpoint to new height point and normalize it to range length
				vec3 tonew = circleWorldPos.xyz - posscale.xyz;
				tonew.y *= HEIGHTMOD;
				tonew = normalize(tonew) * RANGE;
				circleWorldPos.xz = posscale.xz + tonew.xz;
				circleWorldPos.y = heightAtWorldPos(circleWorldPos.xz);
			}
		}
	#endif
	
	*/
	#ifndef Cannon
	//circleWorldPos.y+= 500;
	#endif
	
	#ifdef CANNON

		
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
	#endif
	
	circleWorldPos.y += 6; // lift it from the ground
	
	// -- MAP OUT OF BOUNDS
	vec2 mymin = min(circleWorldPos.xz,mapSize.xy - circleWorldPos.xz);
	float inboundsness = min(mymin.x, mymin.y);
	alphaControl.y = 1.0 - clamp(inboundsness*(-0.01),0.0,1.0);

	
	//--- DISTANCE FADE ---
	vec4 camPos = cameraViewInv[3];
	float distToCam = length(posscale.xyz - camPos.xyz); //dist from cam 
	
	alphaControl.z  = clamp((visibility.y -distToCam)/(visibility.y - visibility.x + 1.0),visibility.z,visibility.w);
	#ifdef CANNON
	// cannons should fade distance based on their range
		float cvmin = max(visibility.x, 2* RANGE);
		float cvmax = max(visibility.y, 4* RANGE);
		alphaControl.z  = clamp((cvmin - distToCam)/(cvmax - cvmin + 1.0),visibility.z,visibility.w);
	#endif
	
	
	// --- NO FOG
	//float fogDist = length((cameraView * vec4(circleWorldPos.xyz,1.0)).xyz);
	//float fogFactor = (fogParams.y - fogDist) * fogParams.w;
	//blendedcolor.rgb = mix(color1.rgb, fogColor.rgb, fogFactor);
	blendedcolor.rgb = color1.rgb;
	
	// -- DARKEN OUT OF LOS
	vec4 losTexSample = texture(losTex, vec2(circleWorldPos.x / mapSize.z, circleWorldPos.z / mapSize.w)); // lostex is PO2
	float inlos = dot(losTexSample.rgb,vec3(0.33));
	inlos = clamp(inlos*5 -1.4	, 0.5,1.0); // fuck if i know why, but change this if LOSCOLORS are changed!
	blendedcolor.rgb *= inlos;
	
	// -- TEAMCOLORIZATION
	blendedcolor.a = color1.a; // pass over teamID 
	
	// -- MOUSE DISTANCE ALPHA
	float disttomousefromcenter = RANGE *1.5 - length(posscale.xz - mouseWorldPos.xz); 
	// this will be positive if in mouse, negative else
	float mousealpha = clamp( disttomousefromcenter / (RANGE * 0.33), 0.0, 1.0);
	alphaControl.w = mousealpha;
	alphaControl.w = mousealpha;
	
	
	// ------------ dump the stuff for FS --------------------
	worldPos = circleWorldPos;
	worldPos.a = RANGE;
	alphaControl.x = circlepointposition.z; // save circle progress here
	gl_Position = cameraViewProj * vec4(circleWorldPos.xyz, 1.0);
}
]]

local fsSrc =  [[
#version 330

#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require

//__DEFINES__

#line 20000

uniform vec4 circleuniforms; 

uniform sampler2D heightmapTex;
uniform sampler2D losTex; // hmm maybe?

//__ENGINEUNIFORMBUFFERDEFS__

in DataVS {
	vec4 worldPos; // w = range
	vec4 blendedcolor;
	vec4 alphaControl;// xyzw: circumference progress, outofboundsalpha,  fadealpha ,mousealpha,
};

out vec4 fragColor;

void main() {
	fragColor.rgba = vec4(1.0);
	fragColor.rgb = blendedcolor.rgb;
	
	// mousepos teamcolorization
	uint teamidx = uint(blendedcolor.a);
	float animationmix = clamp( sign(fract(alphaControl.x * worldPos.w*0.1 - timeInfo.y*0.2) - 0.75),0.0,1.0);
	vec3 teamcolorized = mix(blendedcolor.rgb, teamColor[teamidx].rgb, animationmix * alphaControl.w);
	//fragColor.rgb = teamcolorized; //removed for now
	
	//mousepos alpha override
	
	fragColor.a = clamp((alphaControl.z+clamp(alphaControl.w,0.0,1.0))*0.5, 0.0,1.0);
	//	fragColor.a = clamp(alphaControl.z, 0.0,1.0);
	
	
	
	// outofbounds
	fragColor.a *= alphaControl.y;		
	
	
	if (fragColor.a < 0.01) // needed for depthmask
	discard;
}
]]


local function makeShaders()
	local blen = LuaShader.GetAdvShadingActive()
	local engineUniformBufferDefs = LuaShader.GetEngineUniformBufferDefs()
	vsSrc = vsSrc:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineUniformBufferDefs)
	fsSrc = fsSrc:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineUniformBufferDefs)
	sphereCylinderShader =  LuaShader(
    {
      vertex = vsSrc:gsub("//__DEFINES__", "#define MYGRAVITY "..tostring(Game.gravity+0.1)),
      fragment = fsSrc,
      --geometry = gsSrc, no geom shader for now
      uniformInt = {
        heightmapTex = 0,
        losTex = 1,
        },
      uniformFloat = {
        circleuniforms = {1,1,1,1},
      },
    },
    "sphereCylinderShader GL4"
  )
  shaderCompiled = sphereCylinderShader:Initialize()
  if not shaderCompiled then goodbye("Failed to compile sphereCylinderShader GL4 ") end
  
  cannonShader =  LuaShader(
    {
      vertex = vsSrc:gsub("//__DEFINES__", "#define CANNON 1\n#define MYGRAVITY "..tostring(Game.gravity+0.01)),
      fragment = fsSrc,
      --geometry = gsSrc, no geom shader for now
      uniformInt = {
        heightmapTex = 0, 
		losTex = 1, 
        },
      uniformFloat = {
        circleuniforms = {1,1,1,1},
      },
    },
    "cannonShader GL4"
  )
  shaderCompiled = cannonShader:Initialize()
  if not shaderCompiled then goodbye("Failed to compile cannonShader GL4 ") end
  
  
end

local function initGL4()
	smallCircleVBO = makeCircleVBO(smallCircleSegments)
	largeCircleVBO = makeCircleVBO(largeCircleSegments)
	for i,defRangeClass in ipairs(defenseRangeClasses) do
		defenseRangeVAOs[defRangeClass] = makeInstanceVBOTable(circleInstanceVBOLayout,16,defRangeClass)
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
	
	makeShaders()
end

function widget:Initialize()
	state["myPlayerID"] = spGetLocalTeamID()

	DetectMod()

	initGL4()
	
	init()

	WG['defrange'] = {}
	WG['defrange'].getAllyAir = function()
		return buttonConfig.ally.air
	end
	WG['defrange'].setAllyAir = function(value)
		buttonConfig.ally.air = value
	end
	WG['defrange'].getAllyGround = function()
		return buttonConfig.ally.ground
	end
	WG['defrange'].setAllyGround = function(value)
		buttonConfig.ally.ground = value
	end
	WG['defrange'].getAllyNuke = function()
		return buttonConfig.ally.nuke
	end
	WG['defrange'].setAllyNuke = function(value)
		buttonConfig.ally.nuke = value
	end
	WG['defrange'].getEnemyAir = function()
		return buttonConfig.enemy.air
	end
	WG['defrange'].setEnemyAir = function(value)
		buttonConfig.enemy.air = value
	end
	WG['defrange'].getEnemyGround = function()
		return buttonConfig.enemy.ground
	end
	WG['defrange'].setEnemyGround = function(value)
		buttonConfig.enemy.ground = value
	end
	WG['defrange'].getEnemyNuke = function()
		return buttonConfig.enemy.nuke
	end
	WG['defrange'].setEnemyNuke = function(value)
		buttonConfig.enemy.nuke = value
	end
	
end

function widget:UnitTaken(unitID, unitDefID, unitTeam, newTeam)
	UnitDetected( unitID, true, unitTeam, unitDefID )
end

function widget:UnitGiven(unitID, unitDefID, unitTeam, oldTeam)
	UnitDetected( unitID, true, unitTeam, unitDefID )
end

function widget:UnitCreated( unitID,  unitDefID,  unitTeam)
	UnitDetected( unitID, true, unitTeam, unitDefID )
end

function widget:UnitEnteredLos(unitID, unitTeam, allyTeam, unitDefID)
	UnitDetected( unitID, false, unitTeam, unitDefID )
end

function UnitDetected( unitID, allyTeam, teamId , unitDefID )
	if unitDefID == nil then unitDefID = spGetUnitDefID(unitID) end
	
	if canMove[unitDefID] and not  mobileAntiUnitDefs[unitDefID] then
			return
	end

	if (not unitNumWeapons[unitDefID]) and unitRadius[unitDefID] and unitRadius[unitDefID] < 100 then
			--not interesting, has no weapons and no radar coverage, lame
			return
	end
	
	local tag
	
	local tabValue = defences[unitID]
	if tabValue ~= nil and tabValue[1] ~= allyTeam then
		--unit already known
		return
	end
	
	local key = tostring(unitID)
	--local x, y, z --= spGetUnitPosition(unitID)
	
	-- bugged, midpos === aimpos!, try --local wx, wy, wz = Spring.GetUnitWeaponVectors ( unitID, i ) instead?
	local x, y, z ,mpx, mpy, mpz, apx, apy, apz = spGetUnitPosition( unitID,true,true)  -- aimpos Spring.GetUnitPosition ( number unitID [, bool midPos [, bool aimPos ]] ) 

	y = apy
	local range = 0
	local weaponType = 0
	local dps
	local weaponDef


	printDebug( unitName[unitDefID] )
	local foundWeapons = {}
	local instanceKeys = {}
	if unitNumWeapons[unitDefID] then
		for i=1, unitNumWeapons[unitDefID] do
			if currentModConfig["unitList"][unitName[unitDefID]] == nil or currentModConfig["unitList"][unitName[unitDefID]]["weapons"][i] == nil then
				printDebug("Weapon skipped! Name: "..  unitName[unitDefID] .. " weaponidx: " .. i )
			else
				--get definition from weapon table
				weaponDef = weapTab[ unitWeapons[unitDefID][i] ]

				range = weaponDef.range --get normal weapon range

				weaponType = currentModConfig["unitList"][unitName[unitDefID]]["weapons"][i]
				printDebug("Weapon #" .. i .. " Range: " .. range )

				local dam = weaponDef.damages
				local dps, damage, color1, color2
				local team = "ally"
				

				--check if dps-depending colors should be used
				if currentModConfig["armorTags"] ~= nil then
					printDebug("DPS colors!")
					if weaponType == 1 or weaponType == 4 then	 -- show combo units with ground-dps-colors
						tag = currentModConfig["armorTags"] ["ground"]
					elseif weaponType == 5 then
						tag = currentModConfig["armorTags"] ["cannon"]
					elseif weaponType == 2 then
						tag = currentModConfig["armorTags"] ["air"]
					elseif weaponType == 3 then -- antinuke
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

					color1, color2 = GetColorsByTypeAndDps( dps, weaponType, ( allyTeam == false ) )
				else
					printDebug("Default colors!")
					team = "ally"
					if allyTeam then
						team = "enemy"
					end

					if weaponType == 1 or weaponType == 4 then	 -- show combo units with ground-dps-colors
						color1 = colorConfig[team]["ground"]["min"]
						color2 = colorConfig[team]["air"]["min"]
					elseif weaponType == 5 then
						color1 = colorConfig[team]["cannon"]["min"]
					elseif weaponType == 2 then
						color1 = colorConfig[team]["air"]["min"]
					elseif weaponType == 3 then -- antinuke
						color1 = colorConfig[team]["nuke"]
					end
				end

				foundWeapons[i] = { weaponType = weaponType, range = range, color1 = color1, color2 = color2 }
				printDebug("Detected Weapon - weaponType: " .. weaponType .. " Range: " .. range )
				
				-- add to new version!
				local isCylinder = 1
				if weaponType == 1 or weapontype == 4 then -- all non-cannon ground weapons are spheres
					isCylinder = 0
				end
				
				local newkey = tostring(unitID) .. tostring( unitDefID) .. tostring( i) .. '_' .. tostring(x) .. '_' .. tostring(z)
				--Spring.Echo("weaponType", weaponType, "weaponDef.projectilespeed",weaponDef.projectilespeed,"weaponDef.heightBoostFactor",weaponDef.heightBoostFactor,"weaponDef.heightMod",weaponDef.heightMod)
				
				local myData = {
					x,y,z,range,
					color1[1],color1[2],color1[3],teamId,
					-- // fadeend, fadestart
					color1[5],color1[6],0.0,1.0, 
					
					--//projectileParams : projectileSpeed, rangeFactor, heightBoostFactor , heightMod
					weaponDef.projectilespeed,isCylinder,weaponDef.heightBoostFactor,weaponDef.heightMod
				}
				local vaokey =  team .. weaponTypeToString[weaponType]

				pushElementInstance(defenseRangeVAOs[vaokey],myData,newkey)
				instanceKeys[vaokey] = newkey
				if mobileAntiUnitDefs[unitDefID] then
					Spring.Echo("Spotted mobile anti", unitID, vaokey, newkey)
					mobileAntiUnits[unitID] = {vaokey,newkey}
				end
	
				
			end
		end
	end
	printDebug("Adding UnitID " .. unitID .. " WeaponCount: " .. #foundWeapons ) --.. "W1: " .. foundWeapons[1]["weaponType"])
	--todo return earlier!
	defences[unitID] = { allyState = ( allyTeam == false ), pos = {x, y, z}, unitId = unitID, unitDefID = unitDefID, instanceKeys = instanceKeys}
	--defences[unitID]["weapons"] = foundWeapons

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
	elseif type == 5 then
		if isEnemy then
			color1 = GetColorByDps( dps, true, "cannon" )
		else
			color1 = GetColorByDps( dps, false, "cannon")
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

function GetColorByDps( dps, isEnemy, typeStr )
	if dps == nil then dps = 1 end
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
	for i=1,8 do
		color[i] =  ( ( ( 1.0 -  factor ) * colorConfig[team][typeStr]["min"][i] ) + ( factor * colorConfig[team][typeStr]["max"][i] ) )
	--	printDebug( "#" .. i .. ":" .. "min: " .. colorConfig[team][typeStr]["min"]["color"][i] .. " max: " .. colorConfig[team][typeStr]["max"]["color"][i] .. " calc: " .. color[i] )
	end
	return color
end

function CheckSpecState()
	local playerID = spGetMyPlayerID()
	if select(3,spGetPlayerInfo(playerID,false)) == true then
		widgetHandler:RemoveWidget()
		return false
	end

	return true
end

function widget:UnitDestroyed(unitID, unitDefID, teamID)
	if mobileAntiUnits[unitID] then
		popElementInstance(defenseRangeVAOs[mobileAntiUnits[unitID][1]],mobileAntiUnits[unitID][2])
		mobileAntiUnits[unitID] = nil
		defences[unitID] = nil
	end
end

function widget:Update(dt)
	if fullview and not enabledAsSpec then
		return
	end

	local timef = spGetGameSeconds()
	local time = floor(timef)

	if (timef - updateTimes["line"]) > 0.2 and timef ~= updateTimes["line"] then
		updateTimes["line"] = timef
        lineConfig["lineWidth"] = 1.33
	end
	
	for unitID, mobileantiinfo in pairs(mobileAntiUnits) do
		local px, py, pz = spGetUnitPosition(unitID)
		if px then
			local vbodata = getElementInstanceData(defenseRangeVAOs[mobileantiinfo[1]],mobileantiinfo[2])
			--Spring.Echo("Anti at",unitID, px, pz,mobileantiinfo[1],mobileantiinfo[2],vbodata[1],vbodata[2])
			vbodata[1] = px
			vbodata[2] = py
			vbodata[3] = pz
			pushElementInstance(defenseRangeVAOs[mobileantiinfo[1]],vbodata,mobileantiinfo[2],true)
		end
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
			local _, losState, _ = spGetPositionLosState(x, y, z)
			if losState then
				if not spGetUnitDefID(def["unitId"]) then
					printDebug("Unit killed.")
					defences[k] = nil
					for vaoKey, instanceKey in pairs(def.instanceKeys) do
						popElementInstance(defenseRangeVAOs[vaoKey],instanceKey)
					end
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
		glLineWidth(lineConfig["lineWidth"])
		glDepthTest(GL.LEQUAL)
		gl.DepthMask(true)

		glTexture(0, "$heightmap")
		glTexture(1, "$info")
		
		sphereCylinderShader:Activate()
		for _,allyState in ipairs({"ally","enemy"}) do
			for j, wt in ipairs({"ground","air","nuke"}) do
				local defRangeClass = allyState..wt
				local iT = defenseRangeVAOs[defRangeClass]
				if iT.usedElements > 0 and buttonConfig[allyState][wt] then
					--	Spring.Echo(defRangeClass,iT.usedElements)
					iT.VAO:DrawArrays(GL.LINE_STRIP,iT.numVertices,0,iT.usedElements,0) -- +1!!!
				end
			end
		end
		sphereCylinderShader:Deactivate()
		
		cannonShader:Activate()
		for i,allyState in ipairs({"ally","enemy"}) do
			local defRangeClass = allyState.."cannon"
			local iT = defenseRangeVAOs[defRangeClass]
			if iT.usedElements > 0 and  buttonConfig[allyState]["ground"] then
				iT.VAO:DrawArrays(GL.LINE_STRIP,iT.numVertices,0,iT.usedElements,0) -- +1!!!
			end
		end
		cannonShader:Deactivate()
		
		glTexture(0, false)
		glTexture(1, false)
		glDepthTest(GL.ALWAYS)
		gl.DepthMask(false)
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
	data["enabled"] = buttonConfig
	return data
end

function widget:SetConfigData(data)
	if data ~= nil then
		if data["enabled"] ~= nil then
			buttonConfig = data["enabled"]
			printDebug("enabled config found...")
		end
	end
end

