-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------


-----------------------------------------------------------------
-- Global vars
-----------------------------------------------------------------

local ShieldSphereColorParticle = {}
ShieldSphereColorParticle.__index = ShieldSphereColorParticle

local geometryLists = {}

local renderBuckets
local canOutline
local haveTerrainOutline
local haveUnitsOutline

local LuaShader = gl.LuaShader
local shieldShader
local checkStunned = true

-----------------------------------------------------------------
-- Constants
-----------------------------------------------------------------

local MAX_POINTS = 24

-----------------------------------------------------------------
-- Auxilary functions
-----------------------------------------------------------------

function ShieldSphereColorParticle.GetInfo()
	return {
		name		= "ShieldSphereColor",
		backup		= "", --// backup class, if this class doesn't work (old cards,ati's,etc.)
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
	canOutline = LuaShader.isDeferredShadingEnabled and LuaShader.GetAdvShadingActive()
end

function ShieldSphereColorParticle:Draw()
    if checkStunned then
        self.stunned = Spring.GetUnitIsStunned(self.unit)
    end
    if self.stunned then --or Spring.IsUnitIcon(self.unit) then
        return
    end
	
	local radius = self.radius
	local posx, posy, posz = Spring.GetUnitPosition(self.unit)
	local shieldvisible = Spring.IsSphereInView(posx,posy, posz, radius * 1.2)
	
	if not shieldvisible then return end
	
	if not renderBuckets[radius] then
		renderBuckets[radius] = {}
	end

	table.insert(renderBuckets[radius], self)
	

	haveTerrainOutline = haveTerrainOutline or (self.terrainOutline and canOutline)
	haveUnitsOutline = haveUnitsOutline or (self.unitsOutline and canOutline)
end

-- Lua limitations only allow to send 24 bits. Should be enough :)
local function EncodeBitmaskField(bitmask, option, position)
	return math.bit_or(bitmask, ((option and 1) or 0) * math.floor(2 ^ position))
end

local impactInfoStringTable = {} 
for i =1, MAX_POINTS+1 do 
	impactInfoStringTable[i-1] = string.format("impactInfo.impactInfoArray[%d]", i - 1)
end


function ShieldSphereColorParticle:EndDraw()
	if next(renderBuckets) == nil then return end  
	if tracy then tracy.ZoneBeginN("Shield:EndDraw") end 
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

	local gf = Spring.GetGameFrame() + Spring.GetFrameTimeOffset()
	local uniformLocations = shieldShader.uniformLocations
	local glUniform = gl.Uniform
	local glUniformInt = gl.UniformInt
	
	local spGetUnitPosition = Spring.GetUnitPosition
	local spIsSphereInView = Spring.IsSphereInView
	local spGetUnitRotation = Spring.GetUnitRotation
	local spGetUnitShieldState = Spring.GetUnitShieldState

	shieldShader:Activate()
	
		shieldShader:SetUniformFloat("gameFrame", gf)
		shieldShader:SetUniformMatrix("viewMat", "view")
		shieldShader:SetUniformMatrix("projMat", "projection")

		for _, rb in pairs(renderBuckets) do
			
			for _, info in ipairs(rb) do
				local unitID = info.unit
				local posx, posy, posz = spGetUnitPosition(unitID)
				if spIsSphereInView(posx, posy, posz, info.radius * 1.2) then
				posx, posy, posz = posx + info.pos[1], posy + info.pos[2], posz + info.pos[3]

				local pitch, yaw, roll = spGetUnitRotation(unitID)
				
				glUniform(uniformLocations["translationScale"], posx, posy, posz, info.radius)
				glUniform(uniformLocations["rotMargin"], pitch, yaw, roll, info.margin)

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
				
				glUniformInt(uniformLocations['effects'], info.optionX)

				
				local _, charge = spGetUnitShieldState(unitID)
				if charge ~= nil then
					
					local frac = charge / (info.shieldCapacity or 10000)
					
					if frac > 1 then frac = 1 elseif frac < 0 then frac = 0 end
					local fracinv = 1.0 - frac
					
					local colormap1 = info.colormap1[1]
					local colormap2 = info.colormap1[2]
					
					local col1r = frac * colormap1[1] + fracinv * colormap2[1]
					local col1g = frac * colormap1[2] + fracinv * colormap2[2]
					local col1b = frac * colormap1[3] + fracinv * colormap2[3]
					local col1a = frac * colormap1[4] + fracinv * colormap2[4]
					
					glUniform(uniformLocations['color1'],col1r, col1g, col1b, col1a )
					
					colormap1 = info.colormap2[1]
					colormap2 = info.colormap2[2]
					
					col1r = frac * colormap1[1] + fracinv * colormap2[1]
					col1g = frac * colormap1[2] + fracinv * colormap2[2]
					col1b = frac * colormap1[3] + fracinv * colormap2[3]
					col1a = frac * colormap1[4] + fracinv * colormap2[4]
					
					glUniform(uniformLocations['color2'],col1r, col1g, col1b, col1a )
					
				end

				--means high quality shield rendering is in place
				if (GG and GG.GetShieldHitPositions and info.impactAnimation) then
					local hitTable = GG.GetShieldHitPositions(unitID)

					if hitTable then
						local hitPointCount = math.min(#hitTable, MAX_POINTS)
						--Spring.Echo("hitPointCount", hitPointCount)
						glUniformInt(uniformLocations["impactInfo.count"], hitPointCount)
						for i = 1, hitPointCount do
							local hx, hy, hz, aoe = hitTable[i].x, hitTable[i].y, hitTable[i].z, hitTable[i].aoe
							glUniform(uniformLocations[impactInfoStringTable[i-1]], hx, hy, hz, aoe)
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

	gl.DepthTest(true)
	gl.DepthMask(false) --"BK OpenGL state resets", was true
	if tracy then tracy.ZoneEnd() end 
end

-----------------------------------------------------------------
-- Other functions
-----------------------------------------------------------------

function ShieldSphereColorParticle:Initialize()
	local shieldShaderVert = VFS.LoadFile("lups/shaders/ShieldSphereColor.vert")
	local shieldShaderFrag = VFS.LoadFile("lups/shaders/ShieldSphereColor.frag")

	shieldShaderFrag = shieldShaderFrag:gsub("###DEPTH_CLIP01###", (Platform.glSupportClipSpaceControl and "1" or "0"))
	shieldShaderFrag = shieldShaderFrag:gsub("###MAX_POINTS###", MAX_POINTS)
	
	local uniformFloats = {
			color1 = {1,1,1,1},
			color2 = {1,1,1,1},
			translationScale = {1,1,1,1},
			rotMargin = {1,1,1,1},
			optionX = {1,1,1,1},
			effects = {1,1,1,1},
			["impactInfo.count"] = 1,
		}
	for i =1, MAX_POINTS+1 do 
		uniformFloats[impactInfoStringTable[i-1]] = {0,0,0,0}
	end

	shieldShader = LuaShader({
		vertex = shieldShaderVert,
		fragment = shieldShaderFrag,
		uniformInt = {
			mapDepthTex = 0,
			modelsDepthTex = 1,
		},
		uniformFloat = uniformFloats,
	}, "ShieldSphereColor")
	shieldShader:Initialize()

	geometryLists = {
		large = gl.CreateList(DrawIcosahedron, 5, false),
		small = gl.CreateList(DrawIcosahedron, 4, false),
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

local time = 0
function ShieldSphereColorParticle:Update(n)
    time = time + n
    if time > 40 then
        checkStunned = true
        time = 0
    else
        checkStunned = false
    end
end

-- used if repeatEffect=true;
function ShieldSphereColorParticle:ReInitialize()
	self.dieGameFrame = self.dieGameFrame + self.life
end

function ShieldSphereColorParticle.Create(Options)
	local newObject = table.merge(ShieldSphereColorParticle.Default, Options)

	-- overwriting for teamcolored shields
	--local r,g,b = Spring.GetTeamColor(Spring.GetUnitTeam(Options.unit))
	--newObject.colormap1 = {{(r*0.7)+0.4, (g*0.7)+0.4, (b*0.7)+0.4, Options.colormap1[1][4]},   {(r*0.7)+0.4, (g*0.7)+0.4, (b*0.7)+0.4, Options.colormap1[2][4]}}
	--newObject.colormap2 = {{(r*0.35)+0.2, (g*0.35)+0.2, (b*0.35)+0.2, Options.colormap2[1][4]},   {(r*0.35)+0.15, (g*0.35)+0.2, (b*0.35)+0.2, Options.colormap2[2][4]} }

	setmetatable(newObject,ShieldSphereColorParticle)	-- make handle lookup
	newObject:CreateParticle()
	return newObject
end

function ShieldSphereColorParticle:Destroy()

end

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

return ShieldSphereColorParticle
