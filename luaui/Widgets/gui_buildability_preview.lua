function widget:GetInfo()
	return {
		name = "Buildbility Preview",
		desc = "Shows where structures can be built on terrain",
		author = "Beherith",
		date = "2024.08.14",
		license = "GPL v2",
		layer = 0,
		enabled = true
	}
end

------- GL4 NOTES -----
-- There is regular radar and advanced radar, assumed to have identical ranges!

--Engine implementatoin:
--[[

// find the reference height for a build-position
// against which to compare all footprint squares
float CGameHelper::GetBuildHeight(const float3& pos, const UnitDef* unitdef, bool synced)
{
	RECOIL_DETAILED_TRACY_ZONE;
	// we are not going to terraform the ground for mobile units
	// (so we do not care about maxHeightDif constraints either)
	// TODO: maybe respect waterline if <pos> is in water
	if (!unitdef->IsImmobileUnit() || !unitdef->levelGround) {
		if (unitdef->floatOnWater)
			return CGround::GetHeightAboveWater(pos.x, pos.z, synced);
		else
			return CGround::GetHeightReal(pos.x, pos.z, synced);
	}

	const float* orgHeightMap = readMap->GetOriginalHeightMapSynced();
	const float* curHeightMap = readMap->GetCornerHeightMapSynced();

	if (!synced) {
		orgHeightMap = readMap->GetCornerHeightMapUnsynced();
		curHeightMap = readMap->GetCornerHeightMapUnsynced();
	}

	const float maxDifHgt = unitdef->maxHeightDif;

	float minHgt = readMap->GetCurrMinHeight();
	float maxHgt = readMap->GetCurrMaxHeight();

	unsigned int numBorderSquares = 0;
	float sumBorderSquareHeight = 0.0f;

	constexpr int xsize = 1;
	constexpr int zsize = 1;

	// top-left footprint corner (sans clamping)
	const int px = (pos.x - (xsize * (SQUARE_SIZE >> 1))) / SQUARE_SIZE;
	const int pz = (pos.z - (zsize * (SQUARE_SIZE >> 1))) / SQUARE_SIZE;
	// top-left and bottom-right footprint corner (clamped)
	const int x1 = std::clamp(px        , 0, mapDims.mapx);
	const int z1 = std::clamp(pz        , 0, mapDims.mapy);
	const int x2 = std::clamp(x1 + xsize, 0, mapDims.mapx);
	const int z2 = std::clamp(z1 + zsize, 0, mapDims.mapy);

	for (int x = x1; x <= x2; x++) {
		for (int z = z1; z <= z2; z++) {
			const float sqOrgHgt = orgHeightMap[z * mapDims.mapxp1 + x];
			const float sqCurHgt = curHeightMap[z * mapDims.mapxp1 + x];
			const float sqMinHgt = std::min(sqCurHgt, sqOrgHgt);
			const float sqMaxHgt = std::max(sqCurHgt, sqOrgHgt);

			if (x == x1 || x == x2 || z == z1 || z == z2) {
				sumBorderSquareHeight += sqCurHgt;
				numBorderSquares += 1;
			}

			// restrict the range of {min,max}Hgt to
			// the minimum and maximum square height
			// within the footprint
			minHgt = std::max(minHgt, sqMinHgt - maxDifHgt);
			maxHgt = std::min(maxHgt, sqMaxHgt + maxDifHgt);
		}
	}

	// find the average height of the footprint-border squares
	float avgHgt = sumBorderSquareHeight / numBorderSquares;

	// and clamp it to [minH, maxH] if necessary
	if (avgHgt < minHgt && minHgt < maxHgt) { avgHgt = minHgt + 0.01f; }
	if (avgHgt > maxHgt && maxHgt > minHgt) { avgHgt = maxHgt - 0.01f; }

	if (avgHgt < 0.0f && unitdef->floatOnWater)
		avgHgt = -unitdef->waterline;

	return avgHgt;
}


And then:
where pos.y = GetBuildHeight(pos,unitDef,synced)


CGameHelper::BuildSquareStatus CGameHelper::TestBuildSquare(
	const float3& pos,
	const int2& xrange,
	const int2& zrange,
	const BuildInfo& buildInfo,
	const MoveDef* moveDef,
	CFeature*& feature,
	int allyteam,
	bool synced
) {
	RECOIL_DETAILED_TRACY_ZONE;
	assert(pos.IsInBounds());

	const int sqx = unsigned(pos.x) / SQUARE_SIZE;
	const int sqz = unsigned(pos.z) / SQUARE_SIZE;

	const float groundHeight = CGround::GetApproximateHeightUnsafe(sqx, sqz, synced);
	const UnitDef* unitDef = buildInfo.def;

	if (!CheckTerrainConstraints(unitDef, moveDef, pos.y, groundHeight, CGround::GetSlope(pos.x, pos.z, synced)))


Finally:


bool CGameHelper::CheckTerrainConstraints(
	const UnitDef* unitDef,
	const MoveDef* moveDef,
	float wantedHeight, //pos.y
	float groundHeight, // CGround::GetApproximateHeightUnsafe(sqx, sqz, synced);
	float groundSlope,
	float* clampedHeight

	if (unitDef->IsImmobileUnit())
		slopeCheck |= (std::abs(wantedHeight - groundHeight) <= unitDef->maxHeightDif);


]]--

local SHADERRESOLUTION = 16 -- THIS SHOULD MATCH RADARMIPLEVEL!

-- params that need to passed in:
-- maxanglediff
-- footprintx
-- footprintz 
-- waterline
-- Grid is 16x16
-- 

-- Globals
local mousepos = { 0, 0, 0 }
local spGetActiveCommand = Spring.GetActiveCommand

local luaShaderDir = "LuaUI/Widgets/Include/"
local LuaShader = VFS.Include(luaShaderDir .. "LuaShader.lua")
VFS.Include(luaShaderDir .. "instancevbotable.lua")

local buildabiltyPreviewShader = nil
local autoreload = true

local gridVAO = nil
local gridSize = 16

local buildables = {} -- table of unitDefID -> {footprintx, footprintz, maxanglediff, waterline}

for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.isBuilding and unitDef.isImmobile then
		--buildables[unitDefID] = { unitDef.xsize, unitDef.zsize, unitDef.maxanglediff or 10, unitDef.waterline }
		buildables[unitDefID] = { unitDef.xsize, unitDef.zsize, unitDef.maxHeightDif, unitDef.waterline, unitDef.maxSlope }
	end
end

local vsSrcPath = "LuaUI/Widgets/Shaders/buildability_preview.vert.glsl"
local fsSrcPath = "LuaUI/Widgets/Shaders/buildability_preview.frag.glsl"

local shaderSourceCache = {
		vssrcpath = vsSrcPath,
		fssrcpath = fsSrcPath,
		shaderName = "buildabiltyPreviewShader GL4",
		uniformInt = {
				heightmapTex = 0,
			},
		uniformFloat = {
			unitcenter_range = { 2000, 100, 2000, 2000 },
			builddata = {10,12,10, -20},
		  },
		shaderConfig = {
			GRIDSIZE = gridSize,
		},
	}


function widget:Initialize()
	if not gl.CreateShader then -- no shader support, so just remove the widget itself, especially for headless
		widgetHandler:RemoveWidget()
		return
	end

	buildabiltyPreviewShader = LuaShader.CheckShaderUpdates(shaderSourceCache, 1.0)

	if not buildabiltyPreviewShader then
		Spring.Echo("Failed to compile buildabiltyPreviewShader  GL4 ")
		widgetHandler:RemoveWidget()
		return
	end

	local smol, smolsize = makePlaneVBO(1, 1, gridSize)
	local smoli, smolisize = makePlaneIndexVBO(gridSize, gridSize)
	gridVAO = gl.GetVAO()
	gridVAO:AttachVertexBuffer(smol)
	gridVAO:AttachIndexBuffer(smoli)
end


function widget:DrawWorldPreUnit()
	if autoreload then
		buildabiltyPreviewShader = LuaShader.CheckShaderUpdates(shaderSourceCache, 1.0 ) or buildabiltyPreviewShader
	end

	if Spring.IsGUIHidden() or (WG['topbar'] and WG['topbar'].showingQuit()) then
		return
	end

	local cmdID = select(2, spGetActiveCommand())
	if cmdID == nil or cmdID >= 0 then  return end
	cmdID = -cmdID
	
	local a,b,c,d,e,f,g,h = spGetActiveCommand()
	--Spring.Echo(a,b,c,d,e,f,g,h )
	--Spring.Echo(Spring.GetActiveCmdDesc(1) )
	--Spring.Echo(Spring.GetBuildFacing())

	if not buildables[cmdID] then
		return
	end

	local mx, my, lp, mp, rp, offscreen = Spring.GetMouseState()
	local _, coords = Spring.TraceScreenRay(mx, my, true)
	if coords then
		mousepos = { coords[1], coords[2], coords[3] }
	end

	local builddata = buildables[cmdID]
	local xsize,zsize, maxHeightDif, waterline, maxSlope =builddata[1], builddata[2], builddata[3], builddata[4], builddata[5]

	if Spring.GetBuildFacing() % 2 == 1 then
		xsize, zsize = zsize, xsize
	end

	Spring.Echo("DRAWING, ", cmdID, xsize,zsize, maxHeightDif, waterline, maxSlope)
	gl.DepthTest(false)
	gl.Culling(GL.BACK)
	gl.Texture(0, "$heightmap")
	buildabiltyPreviewShader:Activate()
	buildabiltyPreviewShader:SetUniform("unitcenter_range",
		math.floor((mousepos[1] + 8) / (SHADERRESOLUTION )) * (SHADERRESOLUTION ),
		mousepos[2],
		math.floor((mousepos[3] + 8) / (SHADERRESOLUTION )) * (SHADERRESOLUTION ),
		0
	)

	buildabiltyPreviewShader:SetUniform("builddata",xsize, zsize, maxHeightDif, waterline	)
	 
	buildabiltyPreviewShader:SetUniform("resolution", gridSize)

	gridVAO:DrawElements(GL.TRIANGLES)

	buildabiltyPreviewShader:Deactivate()
	gl.Texture(0, false)
	gl.Culling(false)
	gl.DepthTest(true)
end

