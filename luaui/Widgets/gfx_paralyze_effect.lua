function widget:GetInfo()
	return {
		name = "Paralyze Effect",
		desc = "",
		author = "Floris (extracted from healthbars widget)",
		date = "August 2020",
		layer = -10,
		enabled = true
	}
end

local paraTexture = "LuaUI/Images/paralyzed.png"

local GL_TEXTURE_GEN_MODE = GL.TEXTURE_GEN_MODE
local GL_EYE_PLANE = GL.EYE_PLANE
local GL_EYE_LINEAR = GL.EYE_LINEAR
local GL_T = GL.T
local GL_S = GL.S
local GL_ONE = GL.ONE
local GL_SRC_ALPHA = GL.SRC_ALPHA
local GL_ONE_MINUS_SRC_ALPHA = GL.ONE_MINUS_SRC_ALPHA
local glUnit = gl.Unit
local glTexGen = gl.TexGen
local glTexCoord = gl.TexCoord
local glPolygonOffset = gl.PolygonOffset
local glBlending = gl.Blending
local glTexture = gl.Texture
local glColor = gl.Color
local glDepthTest = gl.DepthTest

local GetCameraVectors = Spring.GetCameraVectors
local GetGameFrame = Spring.GetGameFrame
local IsGUIHidden = Spring.IsGUIHidden
local GetUnitIsStunned = Spring.GetUnitIsStunned
local IsUnitVisible = Spring.IsUnitVisible
local GetUnitHealth = Spring.GetUnitHealth

local abs = math.abs

local paraUnits = {}
local gameFrame = GetGameFrame()
local prevGameFrame = gameFrame
local numParaUnits = 0

local function init()
	paraUnits = {}
	numParaUnits = 0
	local allUnits = Spring.GetAllUnits()
	for i=1, #allUnits do
		local unitID = allUnits[i]
		if GetUnitIsStunned(unitID) then
			local health,maxHealth,paralyzeDamage,capture,build = GetUnitHealth(unitID)
			if paralyzeDamage and paralyzeDamage > 0 then
				paraUnits[unitID] = true
				numParaUnits = numParaUnits + 1
			end
		end
	end
end


function widget:Initialize()
	init()
end

function widget:PlayerChanged(playerID)
	local myPlayerID = Spring.GetMyPlayerID()
	if playerID == myPlayerID then
		init()
	end
end

function widget:Update(dt)
	local gameFrame = GetGameFrame()
	if gameFrame ~= prevGameFrame then
		prevGameFrame = gameFrame

		for unitID, _ in pairs(paraUnits) do
			if not GetUnitIsStunned(unitID) then
				paraUnits[unitID] = nil
				numParaUnits = numParaUnits - 1
			end
		end
	end
end

function widget:DrawWorld()
	--if Spring.IsGUIHidden() then return end

	if numParaUnits > 0 then
		glDepthTest(true)
		glPolygonOffset(-2, -2)
		glBlending(GL_SRC_ALPHA, GL_ONE)

		local shift = widgetHandler:GetHourTimer() / 15

		glTexCoord(0, 0)
		glTexGen(GL_T, GL_TEXTURE_GEN_MODE, GL_EYE_LINEAR)
		local cvs = GetCameraVectors()
		local v = cvs.right
		glTexGen(GL_T, GL_EYE_PLANE, v[1] * 0.008, v[2] * 0.008, v[3] * 0.008, shift)
		glTexGen(GL_S, GL_TEXTURE_GEN_MODE, GL_EYE_LINEAR)
		v = cvs.forward
		glTexGen(GL_S, GL_EYE_PLANE, v[1] * 0.008, v[2] * 0.008, v[3] * 0.008, shift)
		glTexture(paraTexture)

		glColor(0.4, 0.4, 1, 1)
		for unitID, _ in pairs(paraUnits) do
			if IsUnitVisible(unitID, 50, true) then
				glUnit(unitID, true)
			end
		end

		glTexture(false)
		glTexGen(GL_T, false)
		glTexGen(GL_S, false)
		glBlending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
		glPolygonOffset(false)
		glDepthTest(false)

		glColor(1, 1, 1, 1)
	end
end


function widget:UnitDestroyed(unitID, unitDefID, unitTeam)
	if paraUnits[unitID] then
		paraUnits[unitID] = nil
		numParaUnits = numParaUnits - 1
	end
end


function widget:UnitDamaged(unitID, unitDefID, unitTeam, damage, paralyzer)
	if paralyzer and GetUnitIsStunned(unitID) then
		paraUnits[unitID] = true
		numParaUnits = numParaUnits + 1
	end
end
