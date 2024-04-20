include("keysym.h.lua")

local versionNumber = "1.1"

function widget:GetInfo()
	return {
		name    = "Attack Range GL4",
		desc    =
		"[v" .. string.format("%s", versionNumber ) .. "] Displays attack ranges of selected units. Alt+, and alt+. (alt comma and alt period) to cycle backward and forward through display config of current unit (saved through games!). Custom keybind to toggle cursor unit range on and off.",
		author  = "Errrrrrr, Beherith",
		date    = "July 20, 2023",
		license = "GPLv2",
		layer   = -99,
		enabled = true,
	}
end

---------------------------------------------------------------------------------------------------------------------------
-- Bindable action:   cursor_range_toggle
-- The widget's individual unit type's display setup is saved in LuaUI/config/AttackRangeConfig2.lua
---------------------------------------------------------------------------------------------------------------------------
local shift_only = false -- only show ranges when shift is held down
local cursor_unit_range = true -- displays the range of the unit at the mouse cursor (if there is one)
local selectionDisableThreshold = 90	-- turns off when selection is above this number
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

	externalalpha = 0.80, -- alpha of outer rings
	internalalpha = 0.20, -- alpha of inner rings
	fill_alpha = 0.10, -- this is the solid color in the middle of the stencil
	outer_fade_height_difference = 2500, -- this is the height difference at which the outer ring starts to fade out compared to inner rings
	ground = {
		color = { 1.0, 0.22, 0.05, 0.60 },
		fadeparams = { 1500, 2200, 1.0, 0.0 }, -- FadeStart, FadeEnd, StartAlpha, EndAlpha
		groupselectionfadescale = 0.75,
		externallinethickness = 3.0,
		internallinethickness = 2.0,
	},
	nano = {
		color = { 0.24, 1.0, 0.2, 0.40 },
		fadeparams = { 2000, 4000, 1.0, 0.0 }, -- FadeStart, FadeEnd, StartAlpha, EndAlpha
		groupselectionfadescale = 0.05,
		externallinethickness = 3.0,
		internallinethickness = 2.0,
	},
	AA = {
		color = { 0.8, 0.44, 2.0, 0.40 },
		fadeparams = { 1500, 2200, 1.0, 0.0 }, -- FadeStart, FadeEnd, StartAlpha, EndAlpha
		groupselectionfadescale = 0.75,
		externallinethickness = 2.5,
		internallinethickness = 2.0,
	},
	cannon = {
		color = { 1.0, 0.22, 0.05, 0.60 },
		fadeparams = { 1500, 2200, 1.0, 0.0 }, -- FadeStart, FadeEnd, StartAlpha, EndAlpha
		groupselectionfadescale = 0.75,
		externallinethickness = 3.0,
		internallinethickness = 2.0,
	},
}

----------------------------------
local show_selected_weapon_ranges = true
local weaponTypeMap = { 'ground', 'nano', 'AA', 'cannon' }

local unitDefRings = {} --each entry should be a unitdefIDkey to a table:

local vtoldamagetag = Game.armorTypes['vtol']
local defaultdamagetag = Game.armorTypes['default']

-- globals
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
local function tableToString(t)
	local result = ""

	if type(t) ~= "table" then
		result = tostring(t)
	elseif t == nil then
		result = "nil"
	else
		for k, v in pairs(t) do
			result = result .. "[" .. tostring(k) .. "] = "

			if type(v) == "table" then
				result = result .. "{"

				for k2, v2 in pairs(v) do
					result = result .. "[" .. tostring(k2) .. "] = "

					if type(v2) == "table" then
						result = result .. "{"

						for k3, v3 in pairs(v2) do
							result = result .. "[" .. tostring(k3) .. "] = " .. tostring(v3) .. ", "
						end

						result = result .. "}, "
					else
						result = result .. tostring(v2) .. ", "
					end
				end

				result = result .. "}, "
			else
				result = result .. tostring(v) .. ", "
			end
			result = result .. "  "
		end
	end

	return "{" .. result:sub(1, -3) .. "}"
end

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
			local color = colorConfig[weaponTypeMap[weaponType]].color
			local fadeparams = colorConfig[weaponTypeMap[weaponType]].fadeparams

			local isCylinder = weaponDef.cylinderTargeting and 1 or 0
			local isDgun = (weaponDef.type == "DGun") and 1 or 0

			local wName = weaponDef.name
			if (weaponDef.type == "AircraftBomb") or (wName:find("bogus")) then
				range = 0
			end
			--Spring.Echo("weaponNum: ".. weaponNum ..", name: " .. tableToString(weaponDef.name))
			local groupselectionfadescale = colorConfig[weaponTypeMap[weaponType]].groupselectionfadescale
			local ringParams = { range, color[1], color[2], color[3], color[4],
				fadeparams[1], fadeparams[2], fadeparams[3], fadeparams[4],
				weaponDef.projectilespeed or 1,
				isCylinder,
				weaponDef.heightBoostFactor or 0,
				weaponDef.heightMod or 0,
				groupselectionfadescale,
				weaponType,
				isDgun
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
local spGetUnitAllyTeam     = Spring.GetUnitAllyTeam
local spGetMouseState       = Spring.GetMouseState
local spTraceScreenRay      = Spring.TraceScreenRay
local GetModKeyState        = Spring.GetModKeyState
local GetInvertQueueKey     = Spring.GetInvertQueueKey
local GetActiveCommand      = Spring.GetActiveCommand
local GetSelectedUnits      = Spring.GetSelectedUnits
local chobbyInterface

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
		Spring.Echo("Range visibility of " .. ally .. " " .. rangetype .. " attacks set to", enabled)
		return true
	end

	return false
end

------ GL4 THINGS  -----
-- AA and cannons:
local largeCircleVBO = nil
local largeCircleSegments = 512

-- others:
local smallCircleVBO = nil
local smallCircleSegments = 128

local weaponTypeToString = { "ground", "nano", "AA", "cannon", }
local allyenemypairs = { "ally", "enemy" }
local attackRangeClasses = { 'enemyground', 'enemyAA', 'enemynano', 'allyground', 'allyAA', 'enemycannon', 'allycannon',
	'allynano' }
local attackRangeVAOs = {}

local circleInstanceVBOLayout = {
	{ id = 1, name = 'posscale',         size = 4 }, -- a vec4 for pos + scale
	{ id = 2, name = 'color1',           size = 4 }, --  vec4 the color of this new
	{ id = 3, name = 'visibility',       size = 4 }, --- vec4 heightdrawstart, heightdrawend, fadefactorin, fadefactorout
	{ id = 4, name = 'projectileParams', size = 4 }, --- heightboost gradient
	{ id = 5, name = 'additionalParams', size = 4 }, --- groupselectionfadescale, +3 additional reserved
	{ id = 6, name = 'instData',         size = 4, type = GL.UNSIGNED_INT },
}

local luaShaderDir = "LuaUI/Widgets/Include/"
local LuaShader = VFS.Include(luaShaderDir .. "LuaShader.lua")
VFS.Include(luaShaderDir .. "instancevbotable.lua")
local attackRangeShader = nil


local function goodbye(reason)
	Spring.Echo("AttackRange GL4 widget exiting with reason: " .. reason)
	widgetHandler:RemoveWidget()
end

local function makeCircleVBO(circleSegments)
	circleSegments  = circleSegments - 1 -- for po2 buffers
	local circleVBO = gl.GetVBO(GL.ARRAY_BUFFER, true)
	if circleVBO == nil then goodbye("Failed to create circleVBO") end

	local VBOLayout = {
		{ id = 0, name = "position", size = 4 },
	}

	local VBOData = {}

	for i = 0, circleSegments do -- this is +1
		VBOData[#VBOData + 1] = math.sin(math.pi * 2 * i / circleSegments) -- X
		VBOData[#VBOData + 1] = math.cos(math.pi * 2 * i / circleSegments) -- Y
		VBOData[#VBOData + 1] = i / circleSegments -- circumference [0-1]
		VBOData[#VBOData + 1] = 0
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
	#extension GL_ARB_uniform_buffer_object : require
	#extension GL_ARB_shader_storage_buffer_object : require
	#extension GL_ARB_shading_language_420pack: require
	#line 10000

	//__DEFINES__

	layout (location = 0) in vec4 circlepointposition;
	layout (location = 1) in vec4 posscale;
	layout (location = 2) in vec4 color1;
	layout (location = 3) in vec4 visibility; // FadeStart, FadeEnd, StartAlpha, EndAlpha
	layout (location = 4) in vec4 projectileParams; // projectileSpeed, iscylinder!!!! , heightBoostFactor , heightMod
	layout (location = 5) in vec4 additionalParams; // groupselectionfadescale, weaponType, +2 reserved
	layout (location = 6) in uvec4 instData;

	uniform float lineAlphaUniform = 1.0;
	uniform float cannonmode = 0.0;
	uniform float fadeDistOffset = 0.0;

	uniform sampler2D heightmapTex;
	uniform sampler2D losTex; // hmm maybe?

	out DataVS {
		flat vec4 blendedcolor;
		vec4 circleprogress;
		float groupselectionfadescale;
		float weaponType;
	};

	//__ENGINEUNIFORMBUFFERDEFS__


	struct SUniformsBuffer {
		uint composite; //     u8 drawFlag; u8 unused1; u16 id;

		uint unused2;
		uint unused3;
		uint unused4;

		float maxHealth;
		float health;
		float unused5;
		float unused6;

		vec4 drawPos;
		vec4 speed;
		vec4[4] userDefined; //can't use float[16] because float in arrays occupies 4 * float space
	};

	layout(std140, binding=1) readonly buffer UniformsBuffer {
		SUniformsBuffer uni[];
	};

	#define UNITID (uni[instData.y].composite >> 16)


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

	#define ISDGUN additionalParams.z

	void main() {
		// Get the center pos of the unit
		vec3 modelWorldPos = uni[instData.y].drawPos.xyz;

		circleprogress.xy = circlepointposition.xy;
		circleprogress.w = circlepointposition.z;
		blendedcolor = color1;
		groupselectionfadescale = additionalParams.x;
		weaponType = additionalParams.y;

		// translate to world pos:
		vec4 circleWorldPos = vec4(1.0);
		float range2 = RANGE;
		if (ISDGUN > 0.5) {
			circleWorldPos.xz = circlepointposition.xy * RANGE * 1.05 + modelWorldPos.xz;
		} else {
			circleWorldPos.xz = circlepointposition.xy * RANGE +  modelWorldPos.xz;
		}

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
					circleWorldPos.xz = circlepointposition.xy * radius + modelWorldPos.xz;
					float newY = heightAtWorldPos(circleWorldPos.xz );
					yDiff = abs(circleWorldPos.y - newY);
					circleWorldPos.y = max(0, newY);
					heightDiff = circleWorldPos.y - modelWorldPos.y;
					adjRadius = GetRange2DCannon(heightDiff * HEIGHTMOD, PROJECTILESPEED, rangeFactor, HEIGHTBOOSTFACTOR);
			}
		}else{
			if (ISCYLINDER < 0.5){ // isCylinder
				//simple implementation, 4 samples per point
				//for (int i = 0; i<mod(timeInfo.x/4,30); i++){
				for (int i = 0; i<8; i++){
					// draw vector from centerpoint to new height point and normalize it to range length
					vec3 tonew = circleWorldPos.xyz - modelWorldPos.xyz;
					tonew.y *= HEIGHTMOD;

					tonew = normalize(tonew) * RANGE;
					circleWorldPos.xz = modelWorldPos.xz + tonew.xz;
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
		float distToCam = length(modelWorldPos.xyz - camPos.xyz); //dist from cam
		// FadeStart, FadeEnd, StartAlpha, EndAlpha
		float fadeDist = visibility.y - visibility.x;
		if (ISDGUN > 0.5) {
			FADEALPHA  = clamp((visibility.y + fadeDistOffset + 1000 - distToCam)/(fadeDist),visibility.w,visibility.z);
		} else {
			FADEALPHA  = clamp((visibility.y + fadeDistOffset - distToCam)/(fadeDist),visibility.w,visibility.z);
		}
		//FADEALPHA  = clamp((visibility.y + fadeDistOffset - distToCam)/(fadeDist),visibility.w,visibility.z);

		//--- Optimize by anything faded out getting transformed back to origin with 0 range?
		//seems pretty ok!
		if (FADEALPHA < 0.001) {
			circleWorldPos.xyz = modelWorldPos.xyz;
		}

		if (cannonmode > 0.5){
		// cannons should fade distance based on their range
			//float cvmin = max(visibility.x+fadeDistOffset, 2* RANGE);
			//float cvmax = max(visibility.y+fadeDistOffset, 4* RANGE);
			//FADEALPHA = clamp((cvmin - distToCam)/(cvmax - cvmin + 1.0),visibility.z,visibility.w);
		}

		blendedcolor = color1;

		// -- DARKEN OUT OF LOS
		//vec4 losTexSample = texture(losTex, vec2(circleWorldPos.x / mapSize.z, circleWorldPos.z / mapSize.w)); // lostex is PO2
		//float inlos = dot(losTexSample.rgb,vec3(0.33));
		//inlos = clamp(inlos*5 -1.4	, 0.5,1.0); // fuck if i know why, but change this if LOSCOLORS are changed!
		//blendedcolor.rgb *= inlos;

		// --- YES FOG
		float fogDist = length((cameraView * vec4(circleWorldPos.xyz,1.0)).xyz);
		float fogFactor = clamp((fogParams.y - fogDist) * fogParams.w, 0, 1);
		blendedcolor.rgb = mix(fogColor.rgb, vec3(blendedcolor), fogFactor);


		// -- IN-SHADER MOUSE-POS BASED HIGHLIGHTING
		float disttomousefromunit = 1.0 - smoothstep(48, 64, length(modelWorldPos.xz - mouseWorldPos.xz));
		// this will be positive if in mouse, negative else
		float highlightme = clamp( (disttomousefromunit ) + 0.0, 0.0, 1.0);
		MOUSEALPHA = 0.1* highlightme;

		// ------------ dump the stuff for FS --------------------
		//worldPos = circleWorldPos;
		//worldPos.a = RANGE;
		alphaControl.x = circlepointposition.z; // save circle progress here
		gl_Position = cameraViewProj * vec4(circleWorldPos.xyz, 1.0);

		//lets blend the alpha here, and save work in FS:
		float outalpha = OUTOFBOUNDSALPHA * (MOUSEALPHA + FADEALPHA *  lineAlphaUniform);
		blendedcolor.a *= outalpha ;
		if (ISDGUN > 0.5) {
			blendedcolor.a = clamp(blendedcolor.a * 3, 0.1, 1.0);
		}
		//blendedcolor.rgb = vec3(fract(distToCam/100));
	}
	]]

local fsSrc = [[
	#version 330

	#extension GL_ARB_uniform_buffer_object : require
	#extension GL_ARB_shading_language_420pack: require

	//_DEFINES__

	#line 20000

	uniform float selUnitCount = 1.0;
	uniform float selBuilderCount = 1.0;
	uniform float drawAlpha = 1.0;
	uniform float drawMode = 0.0;

	//_ENGINEUNIFORMBUFFERDEFS__

	in DataVS {
		flat vec4 blendedcolor;
		vec4 circleprogress;
		float groupselectionfadescale;
		float weaponType;
	};

	out vec4 fragColor;

	void main() {
		// -- we need to mod alpha based on groupselectionfadescale and weaponType
		// -- innerRingDim = group_selection_fade_scale * 0.1 * numUnitsSelected
		float numUnitsSelected = selUnitCount;

		// -- nano is 2
		if(weaponType == 2.0) {
			numUnitsSelected = selBuilderCount;
		}
		numUnitsSelected = clamp(numUnitsSelected, 1, 25);

		float innerRingDim = groupselectionfadescale * 0.1 * numUnitsSelected;
		float finalAlpha = drawAlpha;
		if(drawMode == 2.0) {
			finalAlpha = drawAlpha / pow(innerRingDim, 2);
		}
		finalAlpha = clamp(finalAlpha, 0.0, 1.0);

		fragColor = vec4(blendedcolor.x, blendedcolor.y, blendedcolor.z, blendedcolor.w * finalAlpha);
	}
]]

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
local myTeam = Spring.GetMyTeamID()

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
					entry.weapons[weaponNum] = 4 -- weaponTypeMap[4] is "cannon"
				else
					entry.weapons[weaponNum] = 1 -- weaponTypeMap[1] is "ground"
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
			cacheTable[1] = mpx
			cacheTable[2] = mpy
			cacheTable[3] = mpz
			local vaokey = allystring .. weaponTypeToString[weaponType]

			for i = 1, 16 do
				cacheTable[i + 3] = ringParams[i]
			end

			if false then
				local s = ' '
				for i = 1, 20 do
					s = s .. "; " .. tostring(cacheTable[i])
				end
				if true then
					Spring.Echo("Adding rings for", unitID, x, z)
					Spring.Echo("added", vaokey, s)
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
			--Spring.Echo(vaoKey,instanceKey)
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
	for _, unitID in ipairs(Spring.GetTeamUnits(Spring.GetMyTeamID())) do
		if unitBuilder[spGetUnitDefID(unitID)] then
			builders[unitID] = true
		end
	end
end

local function makeShaders()
	local engineUniformBufferDefs = LuaShader.GetEngineUniformBufferDefs()
	vsSrc = vsSrc:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineUniformBufferDefs)
	fsSrc = fsSrc:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineUniformBufferDefs)
	attackRangeShader = LuaShader(
		{
			vertex = vsSrc:gsub("//__DEFINES__", "#define MYGRAVITY " .. tostring(Game.gravity + 0.1)),
			fragment = fsSrc,
			uniformInt = {
				heightmapTex = 0,
				losTex = 1,
			},
			uniformFloat = {
				lineAlphaUniform = 1,
				cannonmode = 0,
			},
		},
		"attackRangeShader GL4"
	)
	local shaderCompiled = attackRangeShader:Initialize()
	if not shaderCompiled then
		goodbye("Failed to compile attackRangeShader GL4 ")
		return false
	end
	return true
end

local function initGL4()
	smallCircleVBO = makeCircleVBO(smallCircleSegments)
	largeCircleVBO = makeCircleVBO(largeCircleSegments)
	for i, atkRangeClass in ipairs(attackRangeClasses) do
		attackRangeVAOs
		[atkRangeClass] = makeInstanceVBOTable(circleInstanceVBOLayout, 20, atkRangeClass.. "_attackrange_gl4", 6) -- 6 is unitIDattribID (instData)
		if atkRangeClass:find("cannon", nil, true) or atkRangeClass:find("AA", nil, true) then
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
		local newVAO = makeVAOandAttach(attackRangeVAOs
			[atkRangeClass].vertexVBO, attackRangeVAOs
			[atkRangeClass].instanceVBO)
		attackRangeVAOs
		[atkRangeClass].VAO = newVAO
	end
	return makeShaders()
end

local function toggleShowSelectedRanges(on)
	if show_selected_weapon_ranges == on then return end
	show_selected_weapon_ranges = on
end

local function toggleCursorRange(_, _, args)
	cursor_unit_range = not cursor_unit_range
	Spring.Echo("Cursor unit range set to: " .. (cursor_unit_range and "ON" or "OFF"))
end

function widget:Initialize()
	if not gl.CreateShader then -- no shader support, so just remove the widget itself, especially for headless
		widgetHandler:RemoveWidget(self)
		return
	end
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

	myAllyTeam = Spring.GetMyAllyTeamID()
	local allyteamlist = Spring.GetAllyTeamList()

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
end

local gameFrame = 0

function widget:GameFrame(gf)
	gameFrame = gf
end

local function RefreshSelectedUnits()
	local newSelUnits = {}
	for i, unitID in ipairs(selectedUnits) do
		newSelUnits[unitID] = true
		if not selUnits[unitID] and selUnitCount < math.floor(selectionDisableThreshold * selectionDisableThresholdMult) then
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

-- direction should be 1 or -1 (next or previous bitmap value)
local function CycleUnitDisplay(direction)
	if (selUnitCount > 1) or (selUnitCount == 0) then
		Spring.Echo("Please select only one unit to change display setting!")
		return
	end
	local unitID = selectedUnits[1]
	if not unitID then return end

	local alliedUnit = (spGetUnitAllyTeam(unitID) == myAllyTeam)
	local allystring = alliedUnit and "ally" or "enemy"
	local unitDefID = spGetUnitDefID(unitID)
	if unitMaxWeaponRange[unitDefID] == 0 and not unitBuilder[unitDefID] then
		Spring.Echo("Unit has no weapon range!")
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
	Spring.Echo("Changed range display of " .. name ..
		" to config " .. tostring(bitmap) ..
		": " .. tableToString(unitToggles[name][allystring]))

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

function widget:KeyPress(key, mods, isRepeat)
	if key == 304 then
		shifted = true
	end
	if key == 46 and mods.alt then
		CycleUnitDisplay(1) -- cycle forward
	end
	if key == 44 and mods.alt then
		CycleUnitDisplay(-1) -- cycle backward
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
				glStencilFunc(GL_NOTEQUAL, stencilMask, stencilMask) -- what to do with the stencil
				iT.VAO:DrawArrays(primitiveType, iT.numVertices, 0, iT.usedElements, 0) -- +1!!!
			end
		end
	end

	attackRangeShader:SetUniform("cannonmode", 1)
	for i, allyState in ipairs(allyenemypairs) do
		local atkRangeClass = allyState .. "cannon"
		local iT = attackRangeVAOs[atkRangeClass]
		local stencilOffset = colorConfig.cannon_separate_stencil and 3 or 0
		stencilMask = 2 ^ (4 * (i - 1) + stencilOffset) -- if 0 then it's on the same as "ground"
		drawcounts[stencilMask] = iT.usedElements
		if iT.usedElements > 0 then
			if linethickness then
				glLineWidth(colorConfig['cannon'][linethickness] * cameraHeightFactor)
			end
			glStencilMask(stencilMask)
			glStencilFunc(GL_NOTEQUAL, stencilMask, stencilMask)
			iT.VAO:DrawArrays(primitiveType, iT.numVertices, 0, iT.usedElements, 0) -- +1!!!
		end
	end
end

function widget:DrawWorldPreUnit()
	if chobbyInterface then return end
	if not Spring.IsGUIHidden() and (not WG['topbar'] or not WG['topbar'].showingQuit()) then
		cameraHeightFactor = GetCameraHeightFactor() * 0.5 + 0.5
		glTexture(0, "$heightmap")
		glTexture(1, "$info")

		-- Stencil Setup
		-- 	-- https://learnopengl.com/Advanced-OpenGL/Stencil-testing
		if colorConfig.drawStencil then
			glClear(GL_STENCIL_BUFFER_BIT)   -- clear prev stencil
			glDepthTest(false)               -- always draw
			glStencilTest(true)              -- enable stencil test
			glStencilMask(255)               -- all 8 bits
			glStencilOp(GL_KEEP, GL_KEEP, GL_REPLACE) -- Set The Stencil Buffer To 1 Where Draw Any Polygon

			attackRangeShader:Activate()

			attackRangeShader:SetUniform("selUnitCount", selUnitCount)
			attackRangeShader:SetUniform("selBuilderCount", selBuilderCount)
			attackRangeShader:SetUniform("drawMode", 0.0)

			attackRangeShader:SetUniform("drawAlpha", colorConfig.fill_alpha)
			attackRangeShader:SetUniform("fadeDistOffset", colorConfig.outer_fade_height_difference)
			DRAWRINGS(GL_TRIANGLE_FAN) -- FILL THE CIRCLES
			glLineWidth(math.max(0.1, 4 + math.sin(gameFrame * 0.04) * 10))
			glColorMask(true, true, true, true) -- re-enable color drawing
			glStencilMask(0)

			attackRangeShader:SetUniform("lineAlphaUniform", colorConfig.externalalpha)

			glDepthTest(GL_LEQUAL) -- test for depth on these outside cases

			attackRangeShader:SetUniform("drawMode", 1.0)
			attackRangeShader:SetUniform("drawAlpha", 1.0)
			DRAWRINGS(GL_LINE_LOOP, 'externallinethickness') -- DRAW THE OUTER RINGS
			-- This is the correct way to exit out of the stencil mode, to not break drawing of area commands:
			glStencilTest(false)
			glStencilMask(255)
			glStencilOp(GL_KEEP, GL_KEEP, GL_KEEP)
			glClear(GL_STENCIL_BUFFER_BIT)
			-- All the above are needed :(
		end

		if colorConfig.drawInnerRings then
			attackRangeShader:SetUniform("lineAlphaUniform", colorConfig.internalalpha)
			attackRangeShader:SetUniform("drawMode", 2.0)
			attackRangeShader:SetUniform("fadeDistOffset", 0)
			DRAWRINGS(GL_LINE_LOOP, 'internallinethickness') -- DRAW THE INNER RINGS
		end

		attackRangeShader:Deactivate()

		glTexture(0, false)
		glTexture(1, false)
		glDepthTest(false)
	end
end

-- Need to add all the callins for handling unit creation/destruction/gift of builders
function widget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
	if unitTeam == myAllyTeam and unitBuilder[unitDefID] then
		builders[unitID] = true
	end
end

function widget:UnitGiven(unitID, unitDefID, newTeam, oldTeam)
	if newTeam == myAllyTeam and unitBuilder[unitDefID] then
		builders[unitID] = true
	end
end

function widget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam)
	if unitTeam == myAllyTeam and unitBuilder[unitDefID] then
		builders[unitID] = nil
		RemoveSelectedUnit(unitID, false)
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
