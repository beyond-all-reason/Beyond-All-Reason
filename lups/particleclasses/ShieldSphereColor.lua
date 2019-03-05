-- $Id: ShieldSphereColor.lua 3171 2008-11-06 09:06:29Z det $
-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------


-----------------------------------------------------------------
-- Global vars
-----------------------------------------------------------------

local ShieldSphereColorParticle = {}
ShieldSphereColorParticle.__index = ShieldSphereColorParticle

local geometryLists = {}

local renderBuckets
local haveTerrainOutline
local haveUnitsOutline
local haveEnvironmentReflection

local LuaShader = VFS.Include("LuaRules/Gadgets/Include/LuaShader.lua")
local shieldShader

-----------------------------------------------------------------
-- Constants
-----------------------------------------------------------------

local MAX_POINTS = 8

-----------------------------------------------------------------
-- Auxilary functions
-----------------------------------------------------------------

function ShieldSphereColorParticle.GetInfo()
	return {
		name		= "ShieldSphereColor",
		backup		= "ShieldSphereColorFallback", --// backup class, if this class doesn't work (old cards,ati's,etc.)
		desc		= "",

		layer		= -23, --// extreme simply z-ordering :x

		--// gfx requirement
		fbo			= false,
		shader		= true,
		rtt			= false,
		ctt			= false,
	}
end

ShieldSphereColorParticle.Default = {
	pos				= {0, 0, 0}, -- start pos
	layer			= -23,

	life			= math.huge,

	margin			= 1,

	colormap1		= { {0, 0, 0, 0}, {0, 0, 0, 0} },
	colormap2		= { {0, 0, 0, 0}, {0, 0, 0, 0} },

	repeatEffect	= false,
	shieldSize		= "large",
}

-----------------------------------------------------------------
-- Primary functions
-----------------------------------------------------------------

function ShieldSphereColorParticle:Visible()
	return self.visibleToMyAllyTeam
end

function ShieldSphereColorParticle:BeginDraw()
	renderBuckets = {}
	haveTerrainOutline = false
	haveUnitsOutline = false
	haveEnvironmentReflection = false
end

function ShieldSphereColorParticle:Draw()

	local radius = self.radius
	if not renderBuckets[radius] then
		renderBuckets[radius] = {}
	end

	table.insert(renderBuckets[radius], self)

	haveTerrainOutline = haveTerrainOutline or self.terrainOutline
	haveUnitsOutline = haveUnitsOutline or self.unitsOutline
	haveEnvironmentReflection = haveEnvironmentReflection or self.environmentReflection
end

-- Lua limitations only allow to send 24 bits. Should be enough :)
local function EncodeBitmaskField(bitmask, option, position)
	return math.bit_or(bitmask, ((option and 1) or 0) * math.floor(2 ^ position))
end

function ShieldSphereColorParticle:EndDraw()
	--ideally do sorting of renderBuckets
	gl.Blending("alpha")
	gl.DepthTest(true)
	gl.DepthMask(false)

	if haveTerrainOutline then
		gl.Texture(0, "$map_gbuffer_zvaltex")
	end

	if haveUnitsOutline then
		gl.Texture(1, "$model_gbuffer_zvaltex")
	end
	
	if haveEnvironmentReflection then
		gl.Texture(2, "$reflection")
	end

	local gf = Spring.GetGameFrame()

	shieldShader:ActivateWith(function ()
		shieldShader:SetUniformFloat("gameFrame", gf)
		shieldShader:SetUniformFloat("viewPortSize", vsx, vsy)
		shieldShader:SetUniformMatrix("viewMat", "view")
		shieldShader:SetUniformMatrix("projMat", "projection")

		for _, rb in pairs(renderBuckets) do
			for _, info in ipairs(rb) do
				local posx, posy, posz = Spring.GetUnitPosition(info.unit)
				posx, posy, posz = posx + info.pos[1], posy + info.pos[2], posz + info.pos[3]

				local pitch, yaw, roll = Spring.GetUnitRotation(info.unit)

				shieldShader:SetUniformFloat("translationScale", posx, posy, posz, info.radius)
				shieldShader:SetUniformFloat("rotPYR", pitch, yaw, roll)

				local optionY = 0
				optionY = EncodeBitmaskField(optionY, info.terrainOutline, 1)
				optionY = EncodeBitmaskField(optionY, info.unitsOutline, 2)
				optionY = EncodeBitmaskField(optionY, info.environmentReflection, 3)
				optionY = EncodeBitmaskField(optionY, info.impactAnimation, 4)

				shieldShader:SetUniformInt("effects",
					((info.specularExp and info.specularExp > 0) and math.floor(info.specularExp)) or 0,
					optionY
				)

				local col1, col2 = GetShieldColor(info.unit, info)
				shieldShader:SetUniformFloat("color1", col1[1], col1[2], col1[3], col1[4])
				shieldShader:SetUniformFloat("color2", col2[1], col2[2], col2[3], col2[4])

				--means high quality shield rendering is in place
				if (GG and GG.GetShieldHitPositions and info.impactAnimation) then
					local hitTable = GG.GetShieldHitPositions(info.unit)

					if hitTable and hitTable[1] then

						Spring.Utilities.TableEcho(hitTable, "hitTable")

						local hitPointCount = math.min(#hitTable, MAX_POINTS)
						for i = 1, hitPointCount do
							shieldShader:SetUniformInt("impactInfo.count", hitPointCount)

							local hx, hy, hz, aoe = hitTable[i].x, hitTable[i].y, hitTable[i].z, hitTable[i].aoe
							shieldShader:SetUniformFloat(string.format("impactInfo[%d].impactPoint", i), hx, hy, hz, aoe)
						end

					end
				end

				gl.CallList(geometryLists[info.shieldSize])
			end
		end
	end)

	if haveTerrainOutline then
		gl.Texture(0, false)
	end

	if haveUnitsOutline then
		gl.Texture(1, false)
	end
	
	if haveEnvironmentReflection then
		gl.Texture(2, false)
	end

	gl.DepthTest(true)
	gl.DepthMask(true)
end

-----------------------------------------------------------------
-- Other functions
-----------------------------------------------------------------

function ShieldSphereColorParticle:Initialize()
	local shieldShaderVert = VFS.LoadFile("lups/shaders/ShieldSphereColor.vert")
	local shieldShaderFrag = VFS.LoadFile("lups/shaders/ShieldSphereColor.frag")

	shieldShaderFrag = shieldShaderFrag:gsub("###DEPTH_CLIP01###", (Platform.glSupportClipSpaceControl and "1" or "0"))
	shieldShaderFrag = shieldShaderFrag:gsub("###MAX_POINTS###", MAX_POINTS)

	shieldShader = LuaShader({
		vertex = shieldShaderVert,
		fragment = shieldShaderFrag,
		uniformInt = {
			mapDepthTex = 0,
			modelsDepthTex = 1,
			reflectionTex = 2,
		},
		uniformFloat = {
			sunDir = { gl.GetSun("pos") },
		}
	}, "ShieldSphereColor")
	shieldShader:Initialize()

	geometryLists = {
		large = gl.CreateList(DrawSphere, 0, 0, 0, 1, 38),
		small = gl.CreateList(DrawSphere, 0, 0, 0, 1, 24),
	}
end

function ShieldSphereColorParticle:Finalize()
	shieldShader:Finalize()

	for _, list in pairs(geometryLists) do
		gl.DeleteList(list)
	end
end

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

function ShieldSphereColorParticle:CreateParticle()
	self.dieGameFrame = Spring.GetGameFrame() + self.life
end

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

function ShieldSphereColorParticle:Update()
end

-- used if repeatEffect=true;
function ShieldSphereColorParticle:ReInitialize()
	self.dieGameFrame = self.dieGameFrame + self.life
end

function ShieldSphereColorParticle.Create(Options)
	local newObject = MergeTable(Options, ShieldSphereColorParticle.Default)
	setmetatable(newObject,ShieldSphereColorParticle)	-- make handle lookup
	newObject:CreateParticle()
	return newObject
end

function ShieldSphereColorParticle:Destroy()

end

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

return ShieldSphereColorParticle