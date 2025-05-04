local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name      = "Unit glass pieces",
		desc      = "Draws semitransparent glass-like unit pieces",
		author    = "ivand",
		date      = "2019",
		license   = "PD",
		layer     = 0,
		enabled   = false,
	}
end

-----------------------------------------------------------------
-- Global Acceleration
-----------------------------------------------------------------

local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitPieceList = Spring.GetUnitPieceList
local spGetUnitTeam = Spring.GetUnitTeam
local spSetUnitPieceVisible = Spring.SetUnitPieceVisible
local spGetUnitIsCloaked = Spring.GetUnitIsCloaked

if gadgetHandler:IsSyncedCode() then -- Synced

local glassUnitDefs = {}

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
	SendToUnsynced("GlassUnitDestroyed", unitID) --TODO: figure out if it's worth performance toll
end

local function ShowHideGlassPiece(unitID, pieceID, show)
	spSetUnitPieceVisible(unitID, pieceID, show)
end

local pieceList
local function FillGlassUnitDefs(unitID, unitDefID)
	if not glassUnitDefs[unitDefID] then
		pieceList = spGetUnitPieceList(unitID)
		for pieceID, pieceName in ipairs(pieceList) do
			if pieceName:find("_glass") then

				if not glassUnitDefs[unitDefID] then
					glassUnitDefs[unitDefID] = {}
				end
				--Spring.Echo(UnitDefs[unitDefID].name,unitID, unitDefID, pieceID, pieceName)
				table.insert(glassUnitDefs[unitDefID], pieceID)
			end
		end
	end
end

function gadget:UnitFinished(unitID, unitDefID)
	FillGlassUnitDefs(unitID, unitDefID)
	if glassUnitDefs[unitDefID] then
		for _, pieceID in ipairs(glassUnitDefs[unitDefID]) do
			ShowHideGlassPiece(unitID, pieceID, false)
		end
	end
end

function gadget:Initialize()
	local allUnits = Spring.GetAllUnits()
	for _, unitID in ipairs(allUnits) do
		local unitDefID = spGetUnitDefID(unitID)
		local unitTeamID = spGetUnitTeam(unitID)
		gadget:UnitFinished(unitID, unitDefID, unitTeamID)
	end
end

function gadget:Shutdown()
	local allUnits = Spring.GetAllUnits()
	for _, unitID in ipairs(allUnits) do
		local unitDefID = spGetUnitDefID(unitID)
		if glassUnitDefs[unitDefID] then
			for _, pieceID in ipairs(glassUnitDefs[unitDefID]) do
				ShowHideGlassPiece(unitID, pieceID, true)
			end
		end
	end
end


else -- Unsynced

-----------------------------------------------------------------
-- Includes
-----------------------------------------------------------------

local LuaShader = VFS.Include("LuaRules/Gadgets/Include/LuaShader.lua")

-----------------------------------------------------------------
-- Acceleration
-----------------------------------------------------------------

local spGetVisibleUnits = Spring.GetVisibleUnits
local spGetTeamColor = Spring.GetTeamColor

local glGetSun = gl.GetSun

local glDepthTest = gl.DepthTest
local glCulling = gl.Culling

local glPushMatrix = gl.PushMatrix
local glPopMatrix = gl.PopMatrix
local glUnitMultMatrix = gl.UnitMultMatrix
local glUnitPieceMultMatrix = gl.UnitPieceMultMatrix
local glUnitPiece = gl.UnitPiece
local glTexture = gl.Texture
local glUnitShapeTextures = gl.UnitShapeTextures

local GL_BACK  = GL.BACK
local GL_FRONT = GL.FRONT

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

uniform float pbrParams[8];

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

vec3 SampleEnvironmentWithRoughness(vec3 samplingVec, float roughness) {
	float maxLodLevel = log2(float(textureSize(reflectTex, 0).x));

	// makes roughness of reflection scale perceptually much more linear
	// Assumes "CubeTexSizeReflection" = 1024
	//maxLodLevel -= 4.0;

	float lodBias = maxLodLevel * roughness;

	return texture(reflectTex, samplingVec, lodBias).rgb;
}

vec3 CustomTM(const vec3 x) {
	return ((x * (pbrParams[0] * x + pbrParams[1])) / (x * (pbrParams[2] * x + pbrParams[3]) + pbrParams[4]));
}

void main(void){
	vec4 tex1Color = texture(tex1, uv);
	vec4 tex2Color = texture(tex2, uv);

	vec3 normal = NORM2SNORM(texture(normalTex, uv).xyz);

	vec3 diffColor = mix(tex1Color.rgb, teamColor.rgb, tex1Color.a);

	vec3 N = normalize(mat3(T, B, vertexN) * normal);
	N = mix(-N, N, float(gl_FrontFacing));

	float metalness = clamp(tex2Color.g, 0.04, 1.0);
	float roughness = clamp(tex2Color.b, 0.04, 1.0);

	float roughness4 = roughness * roughness;
	roughness4 *= roughness4;

	float R0v = mix(R0, 1.0, metalness);

	vec3 V = normalize(viewCameraDir);
	vec3 I = -V;

	vec3 H = normalize(L + V); //half vector

	vec3 Rl = reflect(I, N);

	// getSpecularDominantDirection (Filament)
	Rl = mix(Rl, N, roughness4);

	float NdotV = clamp(dot(N, V), 0.0, 1.0);
	float HdotN = clamp(dot(H, N), 0.0, 1.0);

	float fresnel = R0v + (1.0 - R0v) * pow((1.0 - NdotV), 5.0);
	vec3 reflColor = REFL_MULT * SampleEnvironmentWithRoughness(Rl, roughness).rgb;
	reflColor *= fresnel;

	reflColor += pbrParams[6] * GetSpecularBlinnPhong(HdotN, roughness); // pbrParams[6] is sun mult

	gl_FragColor.rgb  = pbrParams[7] * (diffColor + reflColor); // pbrParams[7] is exposure
	gl_FragColor.rgb  = CustomTM(gl_FragColor.rgb);

	gl_FragColor.a = NORM2SNORM(tex2Color.a);
}

]]

-----------------------------------------------------------------
-- Global variables
-----------------------------------------------------------------

local udIDs = {}

local solidUnitDefs = {}
local glassUnitDefs = {}

local teamColors = {}
local glassUnits = {}

local pieceList

local sunChanged = true
local glassShader

local isSpec, fullview = Spring.GetSpectatingState()
local myAllyTeamID = Spring.GetMyAllyTeamID()
local myTeamID = Spring.GetMyTeamID()

local unitTextureFilesArray = VFS.DirList("unittextures/")
local unitTextureFiles = {}
for _, path in pairs(unitTextureFilesArray) do
	unitTextureFiles[path] = true
end

local normalMaps = {}
for unitDefID, unitDef in pairs(UnitDefs) do
	local unitNormalTexture = unitDef.customParams.normaltex
	if unitNormalTexture and (
			unitTextureFiles[string.lower(unitNormalTexture)] or
			VFS.FileExists(unitNormalTexture)) then
		normalMaps[unitDefID] = unitNormalTexture
	else
		normalMaps[unitDefID] = "unittextures/blank_normal.dds"
	end
end

function gadget:PlayerChanged(playerID)
	local prevFullview = fullview
	local prevMyAllyTeamID = myAllyTeamID
	isSpec, fullview = Spring.GetSpectatingState()
	myAllyTeamID = Spring.GetMyAllyTeamID()
	myTeamID = Spring.GetMyTeamID()
	if fullview ~= prevFullview or myAllyTeamID ~= prevMyAllyTeamID then
		teamColors = {}
		glassUnits = {}
		UpdateAllGlassUnits()
	end
end



local function RenderGlassUnits()
	if #glassUnits == 0 then
		return
	end


	glDepthTest(true)

	glassShader:ActivateWith( function()
		glTexture(3, "$reflection")

		glassShader:SetUniformMatrix("viewInvMat", "viewinverse")

		if sunChanged then
			glassShader:SetUniformFloatAlways("sunSpecular", glGetSun("specular" ,"unit"))
			glassShader:SetUniformFloatAlways("sunPos", glGetSun("pos"))

			glassShader:SetUniformFloatArrayAlways("pbrParams", {
				Spring.GetConfigFloat("tonemapA", 4.8),
				Spring.GetConfigFloat("tonemapB", 0.8),
				Spring.GetConfigFloat("tonemapC", 3.35),
				Spring.GetConfigFloat("tonemapD", 1.0),
				Spring.GetConfigFloat("tonemapE", 1.15),
				Spring.GetConfigFloat("envAmbient", 0.3),
				Spring.GetConfigFloat("unitSunMult", 1.35),
				Spring.GetConfigFloat("unitExposureMult", 1.0),
			})

			sunChanged = false
		end
		for i = 1, #glassUnits do
			local unitID = glassUnits[i]
			local unitDefID = udIDs[unitID]
			glUnitShapeTextures(unitDefID, true)
			glTexture(2, normalMaps[unitDefID])

			local glassUnitDef = glassUnitDefs[unitDefID]

			glCulling(GL_FRONT)
			for j = 1, #glassUnitDef do
				local pieceID = glassUnitDef[j]
				glPushMatrix()
					glUnitMultMatrix(unitID)
					glUnitPieceMultMatrix(unitID, pieceID)
					glUnitPiece(unitID, pieceID)
				glPopMatrix()
			end

			glCulling(GL_BACK)
			for j = 1, #glassUnitDef do
				local pieceID = glassUnitDef[j]
				glPushMatrix()
					glUnitMultMatrix(unitID)
					glUnitPieceMultMatrix(unitID, pieceID)
					glUnitPiece(unitID, pieceID)
				glPopMatrix()
			end
			--glUnitShapeTextures(unitDefID, false)
			--glTexture(2, false)
		end

		glTexture(0, false)
		glTexture(1, false)
		glTexture(2, false)
		glTexture(3, false)

	end)

	glDepthTest(false)
	glCulling(false)

end


local function UpdateGlassUnit(unitID)
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

	if spGetUnitIsCloaked(unitID) then --cloaked unit
		return
	end

	if not glassUnitDefs[unitDefID] then -- unknown unitdef
		pieceList = spGetUnitPieceList(unitID)
		for pieceID, pieceName in ipairs(pieceList) do
			if pieceName:find("_glass") then

				if not glassUnitDefs[unitDefID] then
					glassUnitDefs[unitDefID] = {}
				end
				--Spring.Echo(unitID, unitDefID, pieceID, pieceName)
				table.insert(glassUnitDefs[unitDefID], pieceID)
			end
		end

		if not glassUnitDefs[unitDefID] then --no glass pieces found
			solidUnitDefs[unitDefID] = true
		end
	end

	if glassUnitDefs[unitDefID] then --unitdef with glass pieces
		table.insert(glassUnits, unitID)
		teamColors[unitID] = { spGetTeamColor(spGetUnitTeam(unitID)) }
	end
end

function UpdateAllGlassUnits()
	teamColors = {}
	glassUnits = {}
	local units
	if fullview then
		units = Spring.GetAllUnits()
	else
		units = CallAsTeam(myTeamID, spGetVisibleUnits, -1, nil, false)
	end
	for i=1, #units do
		UpdateGlassUnit(units[i])
	end
end

----------------------------------------------------------------------

local function GlassUnitDestroyed(unitID)
	udIDs[unitID] = nil
	--glassUnits[unitID] = nil
	teamColors[unitID] = nil
end

function gadget:UnitTaken(unitID, unitDefID, newTeam, oldTeam)
	teamColors[unitID] = { spGetTeamColor(newTeam) }
end

function gadget:UnitEnteredLos(unitID, unitTeam, allyTeam, unitDefID)
	if (glassUnitDefs[unitDefID] or not solidUnitDefs[unitDefID]) and CallAsTeam(myTeamID, Spring.IsUnitVisible, unitID, nil, false) then
		UpdateGlassUnit(unitID)
	end
end

function gadget:UnitLeftLos(unitID, unitTeam, allyTeam, unitDefID)
	if (glassUnitDefs[unitDefID] or not solidUnitDefs[unitDefID]) and not CallAsTeam(myTeamID, Spring.IsUnitVisible, unitID, nil, false) then
		GlassUnitDestroyed(unitID)
	end
end

function gadget:UnitCloaked(unitID, unitDefID, unitTeam)
	if (glassUnitDefs[unitDefID] or not solidUnitDefs[unitDefID]) then
		GlassUnitDestroyed(unitID)
	end
end

function gadget:UnitDecloaked(unitID, unitDefID, unitTeam)
	if (glassUnitDefs[unitDefID] or not solidUnitDefs[unitDefID]) and CallAsTeam(myTeamID, Spring.IsUnitVisible, unitID, nil, false) then
		UpdateGlassUnit(unitID)
	end
end

----------------------------------------------------------------------
function gadget:GameFrame(gf)
	if gf % 7 == 1 then
		UpdateAllGlassUnits()
	end
end

function gadget:DrawWorld()
	RenderGlassUnits()
end

local function GlassUpdateSun()
	sunChanged = true
end

function gadget:SunChanged()
	GlassUpdateSun()
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
	gadgetHandler:AddChatAction("GlassUpdateSun", GlassUpdateSun)
	UpdateAllGlassUnits()
end

function gadget:Shutdown()
	glassShader:Finalize()

	gadgetHandler.RemoveSyncAction("GlassUnitDestroyed")
	gadgetHandler:RemoveChatAction("GlassUpdateSun")
end

end -- unsynced
