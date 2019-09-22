function gadget:GetInfo()
	return {
		name      = "Unit glass pieces",
		desc      = "Draws semitransparent glass-like unit pieces",
		author    = "ivand",
		date      = "2019",
		license   = "PD",
		layer     = 0,
		enabled   = true,
	}
end


if (gadgetHandler:IsSyncedCode()) then -- Synced



function gadget:UnitDestroyed(unitID)
	SendToUnsynced("GlassUnitDestroyed", unitID) --TODO: figure out if it's worth performance toll
end


else -- Unsynced

-----------------------------------------------------------------
-- Includes
-----------------------------------------------------------------

local LuaShader = VFS.Include("LuaRules/Gadgets/Include/LuaShader.lua")

-----------------------------------------------------------------
-- Acceleration
-----------------------------------------------------------------

local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitPieceList = Spring.GetUnitPieceList
local spGetVisibleUnits = Spring.GetVisibleUnits
local spGetUnitTeam = Spring.GetUnitTeam
local spGetTeamColor = Spring.GetTeamColor


local glDepthTest = gl.DepthTest
local glCulling = gl.Culling
--local glBlending = gl.Blending

local glPushPopMatrix = gl.PushPopMatrix
local glUnitMultMatrix = gl.UnitMultMatrix
local glUnitPieceMultMatrix = gl.UnitPieceMultMatrix
local glUnitPiece = gl.UnitPiece
local glTexture = gl.Texture
local glUnitShapeTextures = gl.UnitShapeTextures

local GL_BACK = GL.BACK

-----------------------------------------------------------------
-- Shader sources
-----------------------------------------------------------------

vertGlass =
[[
#version 150 compatibility
#line 100054

uniform vec3 sunPos;
//uniform mat4 viewMat;
uniform mat4 viewInvMat;

out Data {
	vec3 T;
	vec3 B;
	vec3 vertexN;

	vec3 L;

	vec3 viewCameraDir;

	vec2 uv;
};

void main() {
	// view space?
	T = mat3(viewInvMat) * (gl_NormalMatrix * gl_MultiTexCoord5.xyz);
	B = mat3(viewInvMat) * (gl_NormalMatrix * gl_MultiTexCoord6.xyz);
	vertexN = mat3(viewInvMat) * (gl_NormalMatrix * gl_Normal);

	vec4 worldVertPos = viewInvMat * (gl_ModelViewMatrix * gl_Vertex);
	vec4 worldCamPos = viewInvMat * vec4(0.0, 0.0, 0.0, 1.0);

	viewCameraDir = worldCamPos.xyz - worldVertPos.xyz;

	L = sunPos;

	uv = gl_MultiTexCoord0.xy;

	gl_Position = gl_ModelViewProjectionMatrix * gl_Vertex;
}
]]

fragGlass =
[[
#version 150 compatibility
#line 200094

uniform sampler2D tex1;
uniform sampler2D tex2;
uniform sampler2D normalTex;
uniform samplerCube reflectTex;

uniform vec4 teamColor;

uniform vec3 sunSpecular;

// Indices of refraction
const float air = 1.0;
const float glass = 1.5;

// Air to glass ratio of the indices of refraction (Eta)
const float eta = air / glass;

// see http://en.wikipedia.org/wiki/Refractive_index Reflectivity
const float R0 = ((air - glass) * (air - glass)) / ((air + glass) * (air + glass));

in Data {
	vec3 T;
	vec3 B;
	vec3 vertexN;

	vec3 L;

	vec3 viewCameraDir;

	vec2 uv;
};

#define NORM2SNORM(value) (value * 2.0 - 1.0)
#define SNORM2NORM(value) (value * 0.5 + 0.5)

#define REFL_MULT 1.35

vec3 GetSpecularBlinnPhong(float HdotN, float roughness) {
	float power = 2.0 / max(roughness * 0.25, 0.01);
	float powerNorm = (power + 8.0) / 32.0;
	return sunSpecular * pow(HdotN, power) * powerNorm;
}

void main(void){
	vec4 tex1Color = texture(tex1, uv);
	vec4 tex2Color = texture(tex2, uv);

	vec3 normal = NORM2SNORM(texture(normalTex, uv).xyz);

	vec3 diffColor = mix(tex1Color.rgb, teamColor.rgb, tex1Color.a);

	vec3 N = normalize(mat3(T, B, vertexN) * normal);
//	N = mix(-N, N, float(gl_FrontFacing));

	float metalness = tex2Color.g;
	float R0v = mix(R0, 1.0, metalness);

	vec3 V = normalize(viewCameraDir);
	vec3 I = -V;

	vec3 H = normalize(L + V); //half vector

	vec3 Rl = reflect(I, N);

	float NdotV = clamp(dot(N, V), 0.0, 1.0);
	float HdotN = clamp(dot(H, N), 0.0, 1.0);

	float fresnel = R0v + (1.0 - R0v) * pow((1.0 - NdotV), 5.0);
	vec3 reflColor = REFL_MULT * texture(reflectTex, Rl).rgb;
	reflColor *= fresnel;

	float roughness = tex2Color.b;
	reflColor += GetSpecularBlinnPhong(HdotN, roughness) * mix(0.1, 1.0, metalness);

//	tex2Color.a = 0.35;
	gl_FragColor.rgb = diffColor + reflColor;
	gl_FragColor.a = mix(2.0 * tex2Color.a, 1.0, fresnel);
}

]]

-----------------------------------------------------------------
-- Global variables
-----------------------------------------------------------------


local udIDs = {}
local teamIDs = {}
local normalMaps = {}
--local teamColors = {}

local solidUnitDefs = {}
local glassUnitDefs = {}

local glassUnits = {}

local pieceList
local allUnits

local sunChanged = true
local glassShader

local function GetNormalMap(unitDefID)
	local udef = UnitDefs[unitDefID]
	local udefCM = udef.customParams

	if udefCM and udefCM.normaltex and VFS.FileExists(udefCM.normaltex) then
		return udefCM.normaltex
	else
		return "unittextures/blank_normal.dds"
	end
end

local function UpdateGlassUnits(unitID)
	if not udIDs[unitID] then
		udIDs[unitID] = spGetUnitDefID(unitID)
	end
	local unitDefID = udIDs[unitID]

	if not unitDefID then --unidentified object ?
		return
	end

	if solidUnitDefs[unitDefID] then --a known solid unitDef
		return
	end

	if not glassUnitDefs[unitDefID] then -- unknown unitdef
		pieceList = Spring.GetUnitPieceList(unitID)
		for pieceID, pieceName in ipairs(pieceList) do
			if pieceName:find("_glass") then

				if not glassUnitDefs[unitDefID] then
					glassUnitDefs[unitDefID] = {}
				end
				Spring.Echo(unitID, unitDefID, pieceID, pieceName)
				table.insert(glassUnitDefs[unitDefID], pieceID)
			end
		end
		normalMaps[unitDefID] = GetNormalMap(unitDefID)

		if not glassUnitDefs[unitDefID] then --no glass pieces found
			solidUnitDefs[unitDefID] = true
		end
	end

	if glassUnitDefs[unitDefID] then --unitdef with glass pieces
		glassUnits[unitID] = true
		teamIDs[unitID] = spGetUnitTeam(unitID)
	end
end

local function GlassUnitDestroyed(unitID)
	udIDs[unitID] = nil
	glassUnits[unitID] = nil
	teamIDs[unitID] = nil
end

function gadget:UnitTaken(unitID, unitDefID, newTeam, oldTeam)
	teamIDs[unitID] = newTeam
end

local function RenderGlassUnits()
	glDepthTest(true)
	glCulling(GL_BACK)

	glassShader:ActivateWith( function()
		glTexture(3, "$reflection")

		glassShader:SetUniformMatrix("viewInvMat", "viewinverse")

		if sunChanged then
			glassShader:SetUniformFloat("sunSpecular", gl.GetSun("specular" ,"unit"))
			glassShader:SetUniformFloat("sunPos", gl.GetSun("pos"))

			sunChanged = false
		end

		for unitID, _ in pairs(glassUnits) do
			local unitDefID = udIDs[unitID]
			local teamID = teamIDs[unitID]

			glUnitShapeTextures(unitDefID, true)
			--glTexture(0, string.format("%%%d:0", unitDefID))
			--glTexture(1, string.format("%%%d:1", unitDefID))
			glTexture(2, normalMaps[unitDefID])

				local tr, tg, tb, ta = spGetTeamColor(teamID) -- TODO optimize
				glassShader:SetUniformFloat("teamColor", tr, tg, tb, ta)

				for _, pieceID in ipairs(glassUnitDefs[unitDefID]) do --go over pieces list
					glPushPopMatrix( function()
						glUnitMultMatrix(unitID)
						glUnitPieceMultMatrix(unitID, pieceID)
						glUnitPiece(unitID, pieceID)
					end)
				end

			glUnitShapeTextures(unitDefID, false)
			--glTexture(0, false)
			--glTexture(1, false)
			glTexture(2, false)
		end

		glTexture(3, false)
	end)

	glDepthTest(false)
	glCulling(false)
end

function gadget:SunChanged()
	sunChanged = true
end

function gadget:GameFrame(gf)
	allUnits = spGetVisibleUnits(-1, nil, false)
	for _, uID in ipairs(allUnits) do
		UpdateGlassUnits(uID)
	end
end

function gadget:DrawWorld()
	RenderGlassUnits()
end

function gadget:Initialize()
	glassShader = LuaShader({
		vertex = vertGlass,
		fragment = fragGlass,
		uniformInt = {
			tex1 = 0,
			tex2 = 1,
			normalTex = 2,
			reflectTex = 3,
		},
		uniformFloat = {
		},
	}, "Glass Shader")

	glassShader:Initialize()

	gadgetHandler:AddSyncAction("GlassUnitDestroyed", GlassUnitDestroyed)
end

function gadget:Shutdown()
	glassShader:Finalize()

	gadgetHandler.RemoveSyncAction("GlassUnitDestroyed")
end

end -- unsynced