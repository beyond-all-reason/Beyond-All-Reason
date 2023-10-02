function gadget:GetInfo()
	return {
		name    = "Unit tint API",
		desc    = "API for modders to tint units (kinda like in say WC3)",
		author  = "trepan (xray shader), Sprung (api)",
		license = "GNU GPL, v2 or later (xray), Public Domain (api)",
		date    = "2023-09-17",
		layer   = 0,
		enabled = true,
	}
end

local TINT_MAGIC = 'unit_tint'
if gadgetHandler:IsSyncedCode() then
	function GG.TintUnit(unitID, r_or_table, g, b)
		if not r_or_table then
			SendToUnsynced(TINT_MAGIC, unitID)
		elseif type(r_or_table) == 'table' then
			SendToUnsynced(TINT_MAGIC, unitID, r_or_table[1], r_or_table[2], r_or_table[3])
		else
			SendToUnsynced(TINT_MAGIC, unitID, r_or_table, g, b)
		end
	end

	return
end


local gl = gl
local glColor = gl.Color
local glUseShader = gl.UseShader
local glDepthTest = gl.DepthTest
local glPolygonOffset = gl.PolygonOffset
local glBlendEquation = gl.BlendEquation
local glBlending = gl.Blending
local glUnit = gl.Unit
local GL_DST_COLOR = GL.DST_COLOR
local GL_ZERO = GL.ZERO
local GL_FUNC_ADD = GL.FUNC_ADD
local GL_SRC_ALPHA = GL.SRC_ALPHA
local GL_ONE_MINUS_SRC_ALPHA = GL.ONE_MINUS_SRC_ALPHA
local scALL_ACCESS_TEAM = Script.ALL_ACCESS_TEAM
local spGetLocalTeamID = Spring.GetLocalTeamID
local CallAsTeam = CallAsTeam

local shader
local tintedUnits = {}

function TintUnit(unitID, r_or_table, g, b)
	if not r_or_table then
		tintedUnits[unitID] = nil
	elseif type(r_or_table) == 'table' then
		tintedUnits[unitID] = r_or_table
	else
		tintedUnits[unitID] = {r_or_table, g, b}
	end
end

function gadget:UnitDestroyed(unitID)
	tintedUnits[unitID] = nil
end

function gadget:RecvFromSynced(magic, unitID, r, g, b)
	if magic ~= TINT_MAGIC then
		return
	end

	if r then
		tintedUnits[unitID] = {r, g, b}
	else
		tintedUnits[unitID] = nil
	end
end

function gadget:Initialize()

	local glCreateShader = gl.CreateShader
	if not glCreateShader then
		Spring.Log("Tint API (unit_tint.lua)", LOG.ERROR, "Potato with no shaders, exiting")
		GG.TintUnit = function() end
		gadgetHandler:RemoveGadget()
		return
	end

	shader = glCreateShader({
		vertex = [[
			varying vec3 color;
			void main() {
				color = gl_Color.rgb;
				gl_Position = gl_ProjectionMatrix * gl_ModelViewMatrix * gl_Vertex;
			}
		]],

		fragment = [[
			varying vec3 color;
			void main() {
				gl_FragColor.rgb = color; // using `gl_Color.rgb` directly doesn't seem to work
			}
		]],
	})

	if not shader then
		Spring.Log("Tint API (unit_tint.lua)", LOG.ERROR, "Xray shader compilation failed", gl.GetShaderLog())
		GG.TintUnit = function() end
		gadgetHandler:RemoveGadget()
		return
	end

	GG.TintUnit = TintUnit
end

local function DrawWorldFunc()
	glUseShader(shader)
	glBlendEquation(GL_FUNC_ADD)
	glBlending(GL_DST_COLOR, GL_ZERO)
	glDepthTest(true)
	glPolygonOffset(-2, -2)

	for unitID, colour in pairs(tintedUnits) do
		if Spring.IsUnitVisible(unitID) then
			glColor(colour[1], colour[2], colour[3])
			glUnit(unitID, true, -1)
		end
	end

	glPolygonOffset(false)
	glDepthTest(false)
	glBlending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
	glUseShader(0)
	glColor(1, 1, 1, 1)
end

local function DrawWorldFuncTeamWrapper()
	local isSpec, specFullView = Spring.GetSpectatingState
	if isSpec and specFullView then
		CallAsTeam(scALL_ACCESS_TEAM, DrawWorldFunc)
	else
		CallAsTeam(spGetLocalTeamID(), DrawWorldFunc)
	end
end

-- FIXME: optimize to only run if something is actually tinted!
gadget.DrawWorld           = DrawWorldFuncTeamWrapper
gadget.DrawWorldRefraction = DrawWorldFuncTeamWrapper

function gadget:Shutdown()
	if shader then
		gl.DeleteShader(shader)
		shader = nil
	end
end

local tintUnitDefIDs = {}
for i = 1, #UnitDefs do
	local tint = UnitDefs[i].customParams.model_tint
	if tint then
		local rs, gs, bs = tint:match("(%S+)%s*(%S+)%s*(%S+)")
		local r, g, b = tonumber(rs), tonumber(gs), tonumber(bs)
		if r and g and b then
			tintUnitDefIDs[i] = {r, g, b}
		end
	end
end

if next(tintUnitDefIDs) then
	function gadget:UnitCreated(unitID, unitDefID)
		local tint = tintUnitDefIDs[unitDefID]
		if not tint then
			return
		end

		TintUnit(unitID, tint)
	end
end
