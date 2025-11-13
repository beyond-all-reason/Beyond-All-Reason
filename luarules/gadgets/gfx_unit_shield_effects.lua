local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name    = "Shield Effects",
		desc    = "Draws variable shields for shielded units",
		author  = "ivand, GoogleFrog",
		date    = "2019",
		license = "GNU GPL, v2 or later",
		layer   = 1500, -- Call ShieldPreDamaged after gadgets which change whether interception occurs
		enabled = true,
	}
end

-----------------------------------------------------------------
-- Global consts
-----------------------------------------------------------------

local GAMESPEED = Game.gameSpeed
local SHIELDARMORID = 4
local SHIELDARMORIDALT = 0
local SHIELDONRULESPARAMINDEX = 531313 -- not a string due to perfmaxxing

-----------------------------------------------------------------
-- Vector math functions (used for hit impact calculations)
-----------------------------------------------------------------

local function Norm(x, y, z)
	return math.sqrt(x*x + y*y + z*z)
end

local function DotProduct(x1, y1, z1, x2, y2, z2)
	return x1*x2 + y1*y2 + z1*z2
end

-- Spherical linear interpolation for impact points
local ALMOST_ONE = 0.999
local function GetSLerpedPoint(x1, y1, z1, x2, y2, z2, w1, w2)
	local dotP = DotProduct(x1, y1, z1, x2, y2, z2)

	if dotP >= ALMOST_ONE then
		return x1, y1, z1
	end

	local A = math.acos(dotP)
	local sinA = math.sin(A)
	local w = 1.0 - (w1 / (w1 + w2))

	local x = (math.sin((1.0 - w) * A) * x1 + math.sin(w * A) * x2) / sinA
	local y = (math.sin((1.0 - w) * A) * y1 + math.sin(w * A) * y2) / sinA
	local z = (math.sin((1.0 - w) * A) * z1 + math.sin(w * A) * z2) / sinA

	return x, y, z
end

-----------------------------------------------------------------
-- Synced part of gadget
-----------------------------------------------------------------

if gadgetHandler:IsSyncedCode() then
	local spSetUnitRulesParam = Spring.SetUnitRulesParam
	local SendToUnsynced = SendToUnsynced
	local INLOS_ACCESS = {inlos = true}
	local gameFrame = 0

	function gadget:GameFrame(n)
		gameFrame = n
	end

	local unitBeamWeapons = {}
	for unitDefID, unitDef in pairs(UnitDefs) do
		local weapons = unitDef.weapons
		local hasbeamweapon = false
		for i=1,#weapons do
			local weaponDefID = weapons[i].weaponDef
			if WeaponDefs[weaponDefID].type == "LightningCannon" or
				WeaponDefs[weaponDefID].type == "BeamLaser" then
				hasbeamweapon = true
			end
		end
		if hasbeamweapon then
			unitBeamWeapons[unitDefID] = {}
			for i=1,#weapons do
				unitBeamWeapons[unitDefID][i] = weapons[i].weaponDef
			end
		end
	end
	local weaponType = {}
	local weaponDamages = {}
	local weaponBeamtime = {}
	for weaponDefID, weaponDef in pairs(WeaponDefs) do
		weaponType[weaponDefID] = weaponDef.type
		weaponDamages[weaponDefID] = {[SHIELDARMORIDALT] = weaponDef.damages[SHIELDARMORIDALT], [SHIELDARMORID] = weaponDef.damages[SHIELDARMORID]}
		weaponBeamtime[weaponDefID] = weaponDef.beamtime
	end

	function gadget:ShieldPreDamaged(proID, proOwnerID, shieldEmitterWeaponNum, shieldCarrierUnitID, bounceProjectile, beamEmitterWeaponNum, beamEmitterUnitID, startX, startY, startZ, hitX, hitY, hitZ)
		local dmgMod = 1
		local weaponDefID
		if proID and proID ~= -1 then
			weaponDefID = Spring.GetProjectileDefID(proID)
		elseif beamEmitterUnitID then -- hitscan weapons
			local uDefID = Spring.GetUnitDefID(beamEmitterUnitID)
			if unitBeamWeapons[ uDefID ] and unitBeamWeapons[ uDefID ][beamEmitterWeaponNum] then
				weaponDefID = unitBeamWeapons[ uDefID ][beamEmitterWeaponNum]
				if weaponType[weaponDefID] ~= "LightningCannon" then
					dmgMod = 1 / (weaponBeamtime[weaponDefID] * GAMESPEED)
				end
			end
		end

		if weaponDefID then
			local dmg = weaponDamages[weaponDefID][SHIELDARMORID]
			if dmg <= 0.1 then --some stupidity here: llt has 0.0001 dmg in weaponDamages[weaponDefID][SHIELDARMORID]
				dmg = weaponDamages[weaponDefID][SHIELDARMORIDALT]
			end

			local x, y, z = Spring.GetUnitPosition(shieldCarrierUnitID)
			local dx, dy, dz
			local onlyMove = false
			if bounceProjectile then
				onlyMove = ((hitX == 0) and (hitY == 0) and (hitZ == 0)) --don't apply as additional damage
				dx, dy, dz = startX - x, startY - y, startZ - z
			else
				dx, dy, dz = hitX - x, hitY - y, hitZ - z
			end
			-- We are reasonably fast, about 1us up to here
			SendToUnsynced("AddShieldHitDataHandler", gameFrame, shieldCarrierUnitID, dmg * dmgMod, dx, dy, dz, onlyMove)
		end

		spSetUnitRulesParam(shieldCarrierUnitID, "shieldHitFrame", gameFrame, INLOS_ACCESS)
		return false
	end

	return
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local spGetMyAllyTeamID     = Spring.GetMyAllyTeamID
local spGetSpectatingState  = Spring.GetSpectatingState
local spGetUnitPosition     = Spring.GetUnitPosition
local spIsSphereInView      = Spring.IsSphereInView
local spGetUnitRotation     = Spring.GetUnitRotation
local spGetUnitShieldState  = Spring.GetUnitShieldState
local spGetUnitIsStunned    = Spring.GetUnitIsStunned
local spGetGameFrame        = Spring.GetGameFrame
local spGetFrameTimeOffset  = Spring.GetFrameTimeOffset

local IterableMap = VFS.Include("LuaRules/Gadgets/Include/IterableMap.lua")

-----------------------------------------------------------------
-- Shield rendering constants
-----------------------------------------------------------------

local MAX_POINTS = 24
local LOS_UPDATE_PERIOD = 10
local HIT_UPDATE_PERIOD = 2

-----------------------------------------------------------------
-- Shield rendering state
-----------------------------------------------------------------

local shieldUnitDefs
local highEnoughQuality = true
local hitUpdateNeeded = false
local myAllyTeamID = spGetMyAllyTeamID()
local shieldUnits = IterableMap.New()

-- Rendering state
local shieldShader
local geometryLists = {}
local renderBuckets
local canOutline
local haveTerrainOutline
local haveUnitsOutline
local checkStunned = true
local checkStunnedTime = 0

-- Shader uniforms cache
local impactInfoStringTable = {}
local impactInfoUniformCache = {}
for i = 1, MAX_POINTS + 1 do
	impactInfoStringTable[i-1] = string.format("impactInfo.impactInfoArray[%d]", i - 1)
end

-- Cached uniform locations (set after shader initialization)
local uTranslationScale, uRotMargin, uEffects, uColor1, uColor2, uImpactCount

local function GetVisibleSearch(x, z, search)
	if not x then
		return false
	end
	for i = 1, #search do
		if Spring.IsPosInAirLos(x + search[i][1], 0, z + search[i][2], myAllyTeamID) then
			return true
		end
	end
	return false
end

local function UpdateVisibility(unitID, unitData, unitVisible, forceUpdate)
	unitVisible = unitVisible or (myAllyTeamID == unitData.allyTeamID)
	if not unitVisible then
		local ux,_,uz = Spring.GetUnitPosition(unitID)
		unitVisible = GetVisibleSearch(ux, uz, unitData.search)
	end

	local unitIsActive = Spring.GetUnitIsActive(unitID)
	if unitIsActive ~= unitData.isActive then
		forceUpdate = true
		unitData.isActive = unitIsActive
	end

	local shieldEnabled = Spring.GetUnitRulesParam(unitID, SHIELDONRULESPARAMINDEX)
	if shieldEnabled == 1 then
		unitVisible = true
	elseif shieldEnabled == 0 then
		unitVisible = false
	end

	if unitVisible == unitData.unitVisible and not forceUpdate then
		return
	end
	unitData.unitVisible = unitVisible

	if unitData.shieldInfo then
		unitData.shieldInfo.visibleToMyAllyTeam = unitIsActive and unitVisible
	end
end

local function AddUnit(unitID, unitDefID)
	local def = shieldUnitDefs[unitDefID]
	if not def then
		return
	end

	-- Validate shield capacity
	if not def.shieldCapacity or def.shieldCapacity <= 0 then
		Spring.Echo("Warning: Shield unit " .. unitDefID .. " has invalid capacity: " .. tostring(def.shieldCapacity))
		return
	end

	local shieldInfo = table.copy(def.config)
	shieldInfo.unit = unitID
	shieldInfo.shieldCapacity = def.shieldCapacity
	shieldInfo.visibleToMyAllyTeam = false
	shieldInfo.stunned = false

	local unitData = {
		unitDefID  = unitDefID,
		search     = def.search,
		capacity   = def.shieldCapacity,
		radius     = def.shieldRadius,
		shieldInfo = shieldInfo,
		allyTeamID = Spring.GetUnitAllyTeam(unitID)
	}

	if highEnoughQuality then
		unitData.shieldPos  = def.shieldPos
		unitData.hitData = {}
		unitData.needsUpdate = false
	end

	IterableMap.Add(shieldUnits, unitID, unitData)

	local _, fullview = spGetSpectatingState()
	UpdateVisibility(unitID, unitData, fullview, true)
end

local function RemoveUnit(unitID)
	IterableMap.Remove(shieldUnits, unitID)
end

local AOE_MAX = math.pi / 8.0 -- ~0.4

local LOG10 = math.log(10)

local BIASLOG = 2.5
local LOGMUL = AOE_MAX / BIASLOG

local function CalcAoE(dmg, capacity)
	-- Safeguard against invalid inputs that could produce NaN
	if capacity <= 0 or dmg <= 0 then
		return 0
	end

	local ratio = dmg / capacity

	-- Safeguard against log of very small or invalid values
	if ratio <= 0 then
		return 0
	end

	local aoe = (BIASLOG + math.log(ratio)/LOG10) * LOGMUL
	return (aoe > 0 and aoe or 0)
end

local AOE_SAME_SPOT = AOE_MAX / 3 -- ~0.13, angle threshold in radians.
local AOE_SAME_SPOT_COS = math.cos(AOE_SAME_SPOT) -- about 0.99

--x, y, z here are normalized vectors
local function DoAddShieldHitData(unitData, hitFrame, dmg, x, y, z, onlyMove)
	local hitData = unitData.hitData

	local found = false

	for _, hitInfo in ipairs(hitData) do
		if hitInfo then

			local dist = hitInfo.x * x +  hitInfo.y * y + hitInfo.z *  z -- take dot product of normed vectors to get the cosine of their angle
			-- AoE radius in radians

			if dist >= AOE_SAME_SPOT_COS then
				found = true

				if onlyMove then -- usually true when we are bouncing a projectile
					hitInfo.dmg = dmg
				else -- this is not a bounced projectile
					hitInfo.x, hitInfo.y, hitInfo.z = GetSLerpedPoint(x, y, z, hitInfo.x, hitInfo.y, hitInfo.z, dmg, hitInfo.dmg)
					hitInfo.dmg = dmg + hitInfo.dmg
				end

				hitInfo.aoe = CalcAoE(hitInfo.dmg, unitData.capacity)

				break
			end
		end
	end

	if not found then
		local aoe = CalcAoE(dmg, unitData.capacity)
		table.insert(hitData, {
			hitFrame = hitFrame,
			dmg = dmg,
			aoe = aoe,
			x = x,
			y = y,
			z = z,
		})
	end
	hitUpdateNeeded = true
	unitData.needsUpdate = true
end

local DECAY_FACTOR = 0.2
local MIN_DAMAGE = 3

local function GetShieldHitPositions(unitID)
	local unitData = IterableMap.Get(shieldUnits, unitID)
	return (((unitData and unitData.hitData) and unitData.hitData) or nil)
end

local function ProcessHitTable(unitData, gameFrame)
	unitData.needsUpdate = false
	local hitData = unitData.hitData

	--apply decay over time first
	for i = #hitData, 1, -1 do
		local hitInfo = hitData[i]
		if hitInfo then
			local mult = math.exp(-DECAY_FACTOR*(gameFrame - hitInfo.hitFrame))
			hitInfo.dmg = hitInfo.dmg * mult
			hitInfo.hitFrame = gameFrame

			hitInfo.aoe = CalcAoE(hitInfo.dmg, unitData.capacity)

			if hitInfo.dmg <= MIN_DAMAGE then
				table.remove(hitData, i)
				hitInfo = nil
			else
				unitData.needsUpdate = true
			end
		end
	end
	if unitData.needsUpdate then
		hitUpdateNeeded = true
		table.sort(hitData, function(a, b) return (((a and b) and a.dmg > b.dmg) or false) end)
	end
	return unitData.needsUpdate
end

local function AddShieldHitData(_, hitFrame, unitID, dmg, dx, dy, dz, onlyMove)
	local unitData = IterableMap.Get(shieldUnits, unitID)
	if unitData and unitData.hitData then
		local rdx, rdy, rdz = dx - unitData.shieldPos[1], dy - unitData.shieldPos[2], dz - unitData.shieldPos[3]
		local norm = Norm(rdx, rdy, rdz)
		if math.abs(norm - unitData.radius) <= unitData.radius * 0.05 then
			rdx, rdy, rdz = rdx / norm, rdy / norm, rdz / norm
			DoAddShieldHitData(unitData, hitFrame, dmg, rdx, rdy, rdz, onlyMove)
		end
	end
end

-----------------------------------------------------------------
-- Geometry generation functions
-----------------------------------------------------------------

local function DrawIcosahedron(subd, cw)
	local sqrt = math.sqrt
	local sin = math.sin
	local cos = math.cos
	local atan2 = math.atan2
	local acos = math.acos

	local function normalize(vertex)
		local r = sqrt(vertex[1]*vertex[1] + vertex[2]*vertex[2] + vertex[3]*vertex[3])
		vertex[1], vertex[2], vertex[3] = vertex[1] / r, vertex[2] / r, vertex[3] / r
		return vertex
	end

	local function midpoint(pt1, pt2)
		return { (pt1[1] + pt2[1]) / 2, (pt1[2] + pt2[2]) / 2, (pt1[3] + pt2[3]) / 2}
	end

	local function subdivide(pt1, pt2, pt3)
		local pt12 = normalize(midpoint(pt1, pt2))
		local pt13 = normalize(midpoint(pt1, pt3))
		local pt23 = normalize(midpoint(pt2, pt3))

		-- CCW order, starting from leftmost
		return {
			{pt12, pt13, pt1},
			{pt2, pt23, pt12},
			{pt12, pt23, pt13},
			{pt23, pt3, pt13},
		}
	end

	local function GetSphericalUV(f)
		local u = atan2(f[3], f[1]) / math.pi -- [-0.5 <--> 0.5]
		local v = acos(f[2]) / math.pi --[0 <--> 1]
		return u * 0.5 + 0.5, 1.0 - v
	end

	--------------------------------------------

	local X = 1
	local Z = (1 + sqrt(5)) / 2

	local vertexes0 = {
		{-X, 0.0, Z}, {X, 0.0, Z}, {-X, 0.0, -Z}, {X, 0.0, -Z},
		{0.0, Z, X}, {0.0, Z, -X}, {0.0, -Z, X}, {0.0, -Z, -X},
		{Z, X, 0.0}, {-Z, X, 0.0}, {Z, -X, 0.0}, {-Z, -X, 0.0},
	}

	for _, vert in ipairs(vertexes0) do
		vert = normalize(vert)
	end

	local fi0 = {
		{1,5,2}, {1,10,5}, {10,6,5}, {5,6,9}, {5,9,2},
		{9,11,2}, {9,4,11}, {6,4,9}, {6,3,4}, {3,8,4},
		{8,11,4}, {8,7,11}, {8,12,7}, {12,1,7}, {1,2,7},
		{7,2,11}, {10,1,12}, {10,12,3}, {10,3,6}, {8,3,12},
	}

	if cw then -- re-wind to clockwise order
		for i = 1, #fi0 do
			fi0[i][2], fi0[i][3] = fi0[i][3], fi0[i][2]
		end
	end

	local faces0 = {}
	for i = 1, #fi0 do
		faces0[i] = {vertexes0[fi0[i][1]], vertexes0[fi0[i][2]], vertexes0[fi0[i][3]]}
	end

	local faces = faces0

	subd = subd or 1

	for s = 2, subd do
		local newfaces = {}
		for fii = 1, #faces do
			local newsub = subdivide(faces[fii][1], faces[fii][2], faces[fii][3])
			for _, tri in ipairs(newsub) do
				table.insert(newfaces, tri)
			end
		end
		faces = newfaces
	end

	gl.BeginEnd(GL.TRIANGLES, function()
		for _, face in ipairs(faces) do
			gl.TexCoord(GetSphericalUV(face[1]))
			gl.Normal(face[1][1], face[1][2], face[1][3])
			gl.Vertex(face[1][1], face[1][2], face[1][3])

			gl.TexCoord(GetSphericalUV(face[2]))
			gl.Normal(face[2][1], face[2][2], face[2][3])
			gl.Vertex(face[2][1], face[2][2], face[2][3])

			gl.TexCoord(GetSphericalUV(face[3]))
			gl.Normal(face[3][1], face[3][2], face[3][3])
			gl.Vertex(face[3][1], face[3][2], face[3][3])
		end
	end)
end

-----------------------------------------------------------------
-- Shield configuration
-----------------------------------------------------------------

local function LoadShieldConfig()
	local ShieldSphereBase = {
		colormap1 = {{0.99, 0.99, 0.90, 0.002}, {0.6, 0.30, 0.09, 0.0}},
		colormap2 = {{0.7, 0.7, 0.7, 0.001}, {0.05, 0.03, 0.0, 0.0}},
		terrainOutline = true,
		unitsOutline = true,
		impactAnimation = true,
		impactChrommaticAberrations = false,
		impactHexSwirl = false,
		impactScaleWithDistance = true,
		impactRipples = true,
		vertexWobble = true,
		bandedNoise = true,
	}

	local SEARCH_SMALL = {
		{0, 0},
		{1, 0},
		{-1, 0},
		{0, 1},
		{0, -1},
	}

	local SEARCH_MULT = 1
	local SEARCH_BASE = 16
	local DIAG = 1/math.sqrt(2)

	local SEARCH_LARGE = {
		{0, 0},
		{1, 0},
		{-1, 0},
		{0, 1},
		{0, -1},
		{DIAG, DIAG},
		{-DIAG, DIAG},
		{DIAG, -DIAG},
		{-DIAG, -DIAG},
	}
	local searchSizes = {}

	local configTable = {}
	for unitDefID = 1, #UnitDefs do
		local ud = UnitDefs[unitDefID]

		if ud.customParams.shield_radius then
			local radius = tonumber(ud.customParams.shield_radius)
			if not searchSizes[radius] then
				local searchType = (radius > 250 and SEARCH_LARGE) or SEARCH_SMALL
				local search = {}
				for i = 1, #searchType do
					search[i] = {SEARCH_MULT*(radius + SEARCH_BASE)*searchType[i][1], SEARCH_MULT*(radius + SEARCH_BASE)*searchType[i][2]}
				end
				searchSizes[radius] = search
			end

			local myShield = table.copy(ShieldSphereBase)
			if radius > 250 then
				myShield.shieldSize = "large"
				myShield.margin = 0.35
			else
				myShield.shieldSize = "small"
				myShield.margin = 0.2
			end
			myShield.radius = radius
			myShield.pos = {0, tonumber(ud.customParams.shield_emit_height) or 0, tonumber(ud.customParams.shield_emit_offset) or 0}

			local strengthMult = tonumber(ud.customParams.shield_color_mult)
			if strengthMult then
				myShield.colormap1[1][4] = strengthMult * myShield.colormap1[1][4]
				myShield.colormap1[2][4] = strengthMult * myShield.colormap1[2][4]
			end

			-- Special handling for raptors
			if string.find(ud.name, "raptor_", nil, true) then
				myShield.colormap1 = {{0.3, 0.9, 0.2, 1.2}, {0.6, 0.4, 0.1, 1.2}}
			end

			configTable[unitDefID] = {
				config = myShield,
				search = searchSizes[radius],
				shieldCapacity = tonumber(ud.customParams.shield_power),
				shieldPos = myShield.pos,
				shieldRadius = radius,
			}
		end
	end

	return configTable
end

-----------------------------------------------------------------

-- Lua limitations only allow to send 24 bits. Should be enough :)
local function EncodeBitmaskField(bitmask, option, position)
	return math.bit_or(bitmask, ((option and 1) or 0) * math.floor(2 ^ position))
end

local function InitializeShader()
	local LuaShader = gl.LuaShader

	-- Check if shader files exist
	if not VFS.FileExists("shaders/ShieldSphereColor.vert") then
		Spring.Echo("Shield shader error: shaders/ShieldSphereColor.vert not found!")
		return false
	end
	if not VFS.FileExists("shaders/ShieldSphereColor.frag") then
		Spring.Echo("Shield shader error: shaders/ShieldSphereColor.frag not found!")
		return false
	end

	local shieldShaderVert = VFS.LoadFile("shaders/ShieldSphereColor.vert")
	local shieldShaderFrag = VFS.LoadFile("shaders/ShieldSphereColor.frag")

	if not shieldShaderVert or not shieldShaderFrag then
		Spring.Echo("Shield shader error: Failed to load shader files!")
		return false
	end

	shieldShaderFrag = shieldShaderFrag:gsub("###DEPTH_CLIP01###", (Platform.glSupportClipSpaceControl and "1" or "0"))
	shieldShaderFrag = shieldShaderFrag:gsub("###MAX_POINTS###", MAX_POINTS)

	local uniformFloats = {
		color1 = {1,1,1,1},
		color2 = {1,1,1,1},
		translationScale = {1,1,1,1},
		rotMargin = {1,1,1,1},
		["impactInfo.count"] = 1,
	}
	for i = 1, MAX_POINTS + 1 do
		uniformFloats[impactInfoStringTable[i-1]] = {0,0,0,0}
	end

	shieldShader = LuaShader({
		vertex = shieldShaderVert,
		fragment = shieldShaderFrag,
		uniformInt = {
			mapDepthTex = 0,
			modelsDepthTex = 1,
			effects = 0,
		},
		uniformFloat = uniformFloats,
	}, "ShieldSphereColor")

	local shaderCompiled = shieldShader:Initialize()
	if not shaderCompiled then
		Spring.Echo("Shield shader failed to compile!")
		shieldShader = nil
		return false
	end

	-- Verify shader object is valid
	if not shieldShader or not shieldShader.uniformLocations then
		Spring.Echo("Shield shader object is invalid after initialization!")
		shieldShader = nil
		return false
	end

	-- Cache uniform locations for performance
	local uniformLocations = shieldShader.uniformLocations
	uTranslationScale = uniformLocations["translationScale"]
	uRotMargin = uniformLocations["rotMargin"]
	uEffects = uniformLocations['effects']
	uColor1 = uniformLocations['color1']
	uColor2 = uniformLocations['color2']
	uImpactCount = uniformLocations["impactInfo.count"]

	-- Cache impact info uniform locations
	for i = 1, MAX_POINTS do
		impactInfoUniformCache[i] = uniformLocations[impactInfoStringTable[i-1]]
	end

	geometryLists = {
		large = gl.CreateList(DrawIcosahedron, 5, false),
		small = gl.CreateList(DrawIcosahedron, 4, false),
	}

	return true
end

local function FinalizeShader()
	if shieldShader then
		shieldShader:Finalize()
		shieldShader = nil
	end

	for _, list in pairs(geometryLists) do
		gl.DeleteList(list)
	end
	geometryLists = {}
end

-----------------------------------------------------------------
-- Shield rendering
-----------------------------------------------------------------

function gadget:DrawWorld()
	if not shieldShader then
		return
	end

	-- Additional safety check to ensure shader is actually usable
	if not shieldShader.uniformLocations or not uTranslationScale then
		return
	end

	-- BeginDraw
	renderBuckets = {}
	haveTerrainOutline = false
	haveUnitsOutline = false
	canOutline = gl.LuaShader.isDeferredShadingEnabled and gl.LuaShader.GetAdvShadingActive()

	-- Update stunned check throttling
	checkStunnedTime = checkStunnedTime + 1
	if checkStunnedTime > 40 then
		checkStunned = true
		checkStunnedTime = 0
	else
		checkStunned = false
	end

	-- Draw (collect visible shields into render buckets)
	for unitID, unitData in IterableMap.Iterator(shieldUnits) do
		if unitData.shieldInfo then
			local info = unitData.shieldInfo

			if checkStunned then
				info.stunned = spGetUnitIsStunned(unitID)
			end

			if not info.stunned and info.visibleToMyAllyTeam then
				local radius = info.radius
				local posx, posy, posz = spGetUnitPosition(unitID)

				if posx then
					local shieldvisible = spIsSphereInView(posx, posy, posz, radius * 1.2)

					if shieldvisible then
						local bucket = renderBuckets[radius]
						if not bucket then
							bucket = {}
							renderBuckets[radius] = bucket
						end

						-- Store unitID and unitData directly to avoid table allocation
						bucket[#bucket + 1] = unitID
						bucket[#bucket + 1] = unitData

						haveTerrainOutline = haveTerrainOutline or (info.terrainOutline and canOutline)
						haveUnitsOutline = haveUnitsOutline or (info.unitsOutline and canOutline)
					end
				end
			end
		end
	end

	-- EndDraw (render all buckets)
	if next(renderBuckets) == nil then
		return
	end

	if tracy then tracy.ZoneBeginN("Shield:EndDraw") end

	gl.Blending("alpha")
	gl.DepthTest(GL.LEQUAL)
	gl.DepthMask(false)

	if haveTerrainOutline then
		gl.Texture(0, "$map_gbuffer_zvaltex")
	end

	if haveUnitsOutline then
		gl.Texture(1, "$model_gbuffer_zvaltex")
	end

	local gf = spGetGameFrame() + spGetFrameTimeOffset()
	local glUniform = gl.Uniform
	local glUniformInt = gl.UniformInt

	shieldShader:Activate()

	shieldShader:SetUniformFloat("gameFrame", gf)
	shieldShader:SetUniformMatrix("viewMat", "view")
	shieldShader:SetUniformMatrix("projMat", "projection")

	for _, rb in pairs(renderBuckets) do
		-- Iterate in pairs (unitID, unitData)
		for i = 1, #rb, 2 do
			local unitID = rb[i]
			local unitData = rb[i + 1]
			local info = unitData.shieldInfo

			local posx, posy, posz = spGetUnitPosition(unitID)

			if posx then
				posx, posy, posz = posx + info.pos[1], posy + info.pos[2], posz + info.pos[3]

				local pitch, yaw, roll = spGetUnitRotation(unitID)

				glUniform(uTranslationScale, posx, posy, posz, info.radius)
				glUniform(uRotMargin, pitch, yaw, roll, info.margin)

				if not info.optionX then
					local optionX = 0
					optionX = EncodeBitmaskField(optionX, info.terrainOutline and canOutline, 1)
					optionX = EncodeBitmaskField(optionX, info.unitsOutline and canOutline, 2)
					optionX = EncodeBitmaskField(optionX, info.impactAnimation, 3)
					optionX = EncodeBitmaskField(optionX, info.impactChrommaticAberrations, 4)
					optionX = EncodeBitmaskField(optionX, info.impactHexSwirl, 5)
					optionX = EncodeBitmaskField(optionX, info.bandedNoise, 6)
					optionX = EncodeBitmaskField(optionX, info.impactScaleWithDistance, 7)
					optionX = EncodeBitmaskField(optionX, info.impactRipples, 8)
					optionX = EncodeBitmaskField(optionX, info.vertexWobble, 9)
					info.optionX = optionX
				end

				glUniformInt(uEffects, info.optionX)

				local _, charge = spGetUnitShieldState(unitID)
				if charge and info.shieldCapacity and info.shieldCapacity > 0 then
					local frac = charge / info.shieldCapacity

					if frac > 1 then frac = 1 elseif frac < 0 then frac = 0 end
					
					-- Additional NaN safety check
					if frac ~= frac then frac = 0 end -- NaN check (NaN != NaN)
					
					local fracinv = 1.0 - frac

					local colormap1 = info.colormap1[1]
					local colormap2 = info.colormap1[2]

					-- Safety check for colormap values
					if colormap1 and colormap2 and colormap1[1] and colormap2[1] then
						local col1r = frac * colormap1[1] + fracinv * colormap2[1]
						local col1g = frac * colormap1[2] + fracinv * colormap2[2]
						local col1b = frac * colormap1[3] + fracinv * colormap2[3]
						local col1a = frac * colormap1[4] + fracinv * colormap2[4]

						glUniform(uColor1, col1r, col1g, col1b, col1a)
					end

					colormap1 = info.colormap2[1]
					colormap2 = info.colormap2[2]

					-- Safety check for colormap values
					if colormap1 and colormap2 and colormap1[1] and colormap2[1] then
						local col1r = frac * colormap1[1] + fracinv * colormap2[1]
						local col1g = frac * colormap1[2] + fracinv * colormap2[2]
						local col1b = frac * colormap1[3] + fracinv * colormap2[3]
						local col1a = frac * colormap1[4] + fracinv * colormap2[4]

						glUniform(uColor2, col1r, col1g, col1b, col1a)
					end
				end

				-- Impact animation
				if highEnoughQuality and info.impactAnimation then
					local hitData = unitData.hitData
					if hitData then
						local hitPointCount = math.min(#hitData, MAX_POINTS)
						glUniformInt(uImpactCount, hitPointCount)
						for j = 1, hitPointCount do
							local hit = hitData[j]
							glUniform(impactInfoUniformCache[j], hit.x, hit.y, hit.z, hit.aoe)
						end
					end
				end

				gl.CallList(geometryLists[info.shieldSize])
			end
		end
	end

	shieldShader:Deactivate()

	if haveTerrainOutline then
		gl.Texture(0, false)
	end

	if haveUnitsOutline then
		gl.Texture(1, false)
	end

	gl.DepthTest(false)
	gl.DepthMask(false)

	if tracy then tracy.ZoneEnd() end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
	RemoveUnit(unitID)
end

function gadget:UnitFinished(unitID, unitDefID, unitTeam)
	if shieldUnitDefs[unitDefID] then
		AddUnit(unitID, unitDefID)
	end
end

function gadget:UnitTaken(unitID, unitDefID, newTeam, oldTeam)
	local unitData = IterableMap.Get(shieldUnits, unitID)
	if unitData then
		unitData.allyTeamID = Spring.GetUnitAllyTeam(unitID)
	end
end

function gadget:PlayerChanged()
	myAllyTeamID = spGetMyAllyTeamID()
end

function gadget:GameFrame(n)
	if highEnoughQuality and hitUpdateNeeded and (n % HIT_UPDATE_PERIOD == 0) then
		hitUpdateNeeded = false
		for unitID, unitData in IterableMap.Iterator(shieldUnits) do
			if unitData and unitData.hitData then
				local phtRes = ProcessHitTable(unitData, n)
				hitUpdateNeeded = hitUpdateNeeded or phtRes
			end
		end
	end

	if n % LOS_UPDATE_PERIOD == 0 then
		local _, fullview = spGetSpectatingState()
		for unitID, unitData in IterableMap.Iterator(shieldUnits) do
			UpdateVisibility(unitID, unitData, fullview)
		end
	end
end

function gadget:Initialize(n)
	-- Load shield configuration
	shieldUnitDefs = LoadShieldConfig()

	-- Initialize shader and geometry
	local shaderSuccess = InitializeShader()
	if not shaderSuccess then
		Spring.Echo("Shield gadget: Failed to initialize shader, disabling")
		gadgetHandler:RemoveGadget(self)
		return
	end

	if highEnoughQuality then
		gadgetHandler:AddSyncAction("AddShieldHitDataHandler", AddShieldHitData)
		GG.GetShieldHitPositions = GetShieldHitPositions
	end

	-- Add existing units
	local allUnits = Spring.GetAllUnits()
	for i = 1, #allUnits do
		local unitID = allUnits[i]
		local unitDefID = Spring.GetUnitDefID(unitID)
		local unitTeam = Spring.GetUnitTeam(unitID)
		if unitDefID and unitTeam then
			gadget:UnitFinished(unitID, unitDefID, unitTeam)
		end
	end
end

function gadget:Shutdown()
	if highEnoughQuality then
		gadgetHandler:RemoveSyncAction("AddShieldHitDataHandler", AddShieldHitData)
		GG.GetShieldHitPositions = nil
	end

	-- Cleanup shader
	FinalizeShader()

	-- Remove all units
	local allUnits = Spring.GetAllUnits()
	for i = 1, #allUnits do
		local unitID = allUnits[i]
		RemoveUnit(unitID)
	end
end
