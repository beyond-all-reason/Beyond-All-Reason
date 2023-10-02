function gadget:GetInfo()
	return {
		name    = "Unit glow API",
		desc    = "API for modders to make units glow",
		author  = "trepan (xray shader), Sprung (api)",
		license = "GNU GPL, v2 or later (xray), Public Domain (api)",
		date    = "2023-09-17",
		layer   = 1, -- after tint (so it doesn't get tinted itself)
		enabled = true,
	}
end

local GLOW_MAGIC = 'unit_glow'
if gadgetHandler:IsSyncedCode() then
	function GG.GlowUnit(unitID, r_or_table, g, b, a)
		if not r_or_table then
			SendToUnsynced(GLOW_MAGIC, unitID)
		elseif type(r_or_table) == 'table' then
			SendToUnsynced(GLOW_MAGIC, unitID, r_or_table[1], r_or_table[2], r_or_table[3], r_or_table[4])
		else
			SendToUnsynced(GLOW_MAGIC, unitID, r_or_table, g, b, a)
		end
	end

	return
end


local gl = gl
local glColor = gl.Color
local glUseShader = gl.UseShader
local glDepthTest = gl.DepthTest
local glPolygonOffset = gl.PolygonOffset
local glUnit = gl.Unit
local scALL_ACCESS_TEAM = Script.ALL_ACCESS_TEAM
local spGetLocalTeamID = Spring.GetLocalTeamID
local CallAsTeam = CallAsTeam

local shader
local glowingUnits = {}

function GlowUnit(unitID, r_or_table, g, b, a)
	if not r_or_table then
		glowingUnits[unitID] = nil
	elseif type(r_or_table) == 'table' then
		glowingUnits[unitID] = r_or_table
	else
		glowingUnits[unitID] = {r_or_table, g, b, a}
	end
end

function gadget:UnitDestroyed(unitID)
	glowingUnits[unitID] = nil
end

function gadget:RecvFromSynced(magic, unitID, r, g, b, a)
	if magic ~= GLOW_MAGIC then
		return
	end

	if r then
		glowingUnits[unitID] = {r, g, b, a}
	else
		glowingUnits[unitID] = nil
	end
end

function gadget:Initialize()
	local glCreateShader = gl.CreateShader
	if not glCreateShader then
		Spring.Log("Glow API (unit_glow.lua)", LOG.ERROR, "Potato with no shaders, exiting")
		GG.GlowUnit = function() end
		gadgetHandler:RemoveGadget()
		return
	end

	shader = glCreateShader({
		vertex = [[
			varying vec3 normal;
			varying vec3 eyeVec;
			varying vec4 color;
			uniform mat4 camera;
			uniform mat4 caminv;

			void main() {
				vec4 P = gl_ModelViewMatrix * gl_Vertex;
				eyeVec = P.xyz;
				normal  = gl_NormalMatrix * gl_Normal;
				color = gl_Color.rgba;
				gl_Position = gl_ProjectionMatrix * P;
			}
		]],

		fragment = [[
			varying vec3 normal;
			varying vec3 eyeVec;
			varying vec4 color;

			void main() {
				float opac = dot(normalize(normal), normalize(eyeVec));
				opac = pow(1.0 - abs(opac), 2);
				gl_FragColor.rgba = color;
				gl_FragColor.a = gl_FragColor.a * opac;
			}
		]],
	})

	if not shader then
		Spring.Log("Glow API (unit_glow.lua)", LOG.ERROR, "Xray shader compilation failed", gl.GetShaderLog())
		GG.GlowUnit = function() end
		gadgetHandler:RemoveGadget()
		return
	end

	GG.GlowUnit = GlowUnit
end

local function DrawWorldFunc()
	glUseShader(shader)
	glDepthTest(true)
	glPolygonOffset(-2, -2)

	for unitID, colour in pairs(glowingUnits) do
		if Spring.IsUnitVisible(unitID) then
			glColor(colour[1], colour[2], colour[3], colour[4] or 1)
			glUnit(unitID, true, -1)
		end
	end

	glPolygonOffset(false)
	glDepthTest(false)
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

-- FIXME: optimize to only run if something is actually glowing!
gadget.DrawWorld           = DrawWorldFuncTeamWrapper
gadget.DrawWorldRefraction = DrawWorldFuncTeamWrapper

function gadget:Shutdown()
	if shader then
		gl.DeleteShader(shader)
		shader = nil
	end
end

local glowUnitDefIDs = {}
for i = 1, #UnitDefs do
	local glow = UnitDefs[i].customParams.model_glow
	if glow then
		local rs, gs, bs, as = glow:match("(%S+)%s*(%S+)%s*(%S+)%s*(%S*)")
		local r, g, b, a = tonumber(rs), tonumber(gs), tonumber(bs), tonumber(as)
		if r and g and b then
			glowUnitDefIDs[i] = {r, g, b, a}
		end
	end
end

if next(glowUnitDefIDs) then
	function gadget:UnitCreated(unitID, unitDefID)
		local glow = glowUnitDefIDs[unitDefID]
		if not glow then
			return
		end

		GlowUnit(unitID, glow)
	end
end
