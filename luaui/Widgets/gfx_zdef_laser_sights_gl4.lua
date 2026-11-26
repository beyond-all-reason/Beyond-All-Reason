local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "BAR Zombie Defense GL4 Tactical Laser Sights",
		desc = "GL4 Instanced scrolling-pulse laser sights: Green (Infantry), Blue (Tank & MRAP), Red (Aircraft)",
		author = "BAR Zombie Defense",
		date = "2026",
		license = "GNU GPL, v2 or later",
		layer = 3,
		enabled = true,
	}
end

-- Localized math & Spring APIs for high-FPS hot loop
local os_clock = os.clock
local mathFloor = math.floor
local mathSin = math.sin
local mathMax = math.max

local spGetAllUnits = Spring.GetAllUnits
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitPosition = Spring.GetUnitPosition
local spGetUnitViewPosition = Spring.GetUnitViewPosition
local spGetUnitWeaponTarget = Spring.GetUnitWeaponTarget
local spGetUnitRulesParam = Spring.GetUnitRulesParam
local spGetUnitPieceMap = Spring.GetUnitPieceMap
local spGetUnitPiecePosDir = Spring.GetUnitPiecePosDir
local spGetGroundHeight = Spring.GetGroundHeight
local spGetCameraPosition = Spring.GetCameraPosition
local spValidUnitID = Spring.ValidUnitID
local spIsUnitInView = Spring.IsUnitInView
local spIsSphereInView = Spring.IsSphereInView
local spIsGUIHidden = Spring.IsGUIHidden

local glDepthTest = gl.DepthTest
local glDepthMask = gl.DepthMask
local glBlending = gl.Blending
local glTexture = gl.Texture
local glColor = gl.Color
local glLineWidth = gl.LineWidth
local glBeginEnd = gl.BeginEnd
local glVertex = gl.Vertex
local glActiveShader = gl.ActiveShader
local glDrawGroundCircle = gl.DrawGroundCircle

local GL_SRC_ALPHA = GL.SRC_ALPHA
local GL_ONE = GL.ONE
local GL_ONE_MINUS_SRC_ALPHA = GL.ONE_MINUS_SRC_ALPHA
local GL_LINES = GL.LINES
local GL_TRIANGLE_STRIP = GL.TRIANGLE_STRIP
local GL_LEQUAL = GL.LEQUAL

--------------------------------------------------------------------------------
-- Configuration: 3 Distinct Military Class Laser Sights
-- Uses the exact GL4 instanced ribbon + scrolling line.dds pulse + additive bloom
--------------------------------------------------------------------------------
local LINE_IMG = ":n:LuaUI/Images/commandsfx/line.dds"
local LINE_TEX_LENGTH = 3.0
local LINE_TEX_SPEED = 4.0
local GL4_MAX_BEAMS = 1024
local GL4_FLOATS_PER_BEAM = 12 -- 3 x vec4 per instance

-- Class styles: { r, g, b, alpha, width, ringRadius, ringAlpha, muzzleYOff, isAir }
local CLASS_STYLES = {
	-- Infantry: Crisp Tactical Green Laser Sight
	zdef_infantry    = { 0.14, 1.00, 0.36, 0.72, 2.5, 5.0,  0.42, 10.2, false },
	zdef_paratrooper = { 0.14, 1.00, 0.36, 0.74, 2.6, 5.0,  0.44, 10.2, false },
	-- Mechanized / Armor: Vivid Tactical Blue Laser Sight
	zdef_mrap        = { 0.16, 0.62, 1.00, 0.88, 4.0, 9.0,  0.65, 13.0, false },
	zdef_tank        = { 0.14, 0.56, 1.00, 0.92, 5.0, 12.0, 0.72, 14.5, false },
	-- Air Support: Bold High-Contrast Red Target Designator Laser
	zdef_c130        = { 1.00, 0.16, 0.16, 0.92, 5.8, 24.0, 0.78, -5.0, true  },
	zdef_a10         = { 1.00, 0.14, 0.14, 0.96, 6.2, 28.0, 0.85, -4.0, true  },
	zdef_fighter     = { 1.00, 0.12, 0.14, 0.96, 6.2, 30.0, 0.85, -4.0, true  },
}

local unitDefStyle = {} -- unitDefID -> style table
local flarePieceCache = {} -- unitDefID -> pieceID or false
local unitTargetHold = {} -- unitID -> { tid, tx, ty, tz, expireTime } (smooths brief burst gaps)
local trackedUnits = {} -- unitID -> unitDefID (only laser-capable military units — avoids scanning 900 zombies every frame!)

local gl4 = nil
local prevOsClock = os_clock()
local texOffset = 0.0

-- Pre-allocated target reticle ring buffer for DrawWorld pass
local ringCount = 0
local ringX, ringY, ringZ = {}, {}, {}
local ringR, ringColR, ringColG, ringColB, ringColA, ringIsAir = {}, {}, {}, {}, {}, {}

--------------------------------------------------------------------------------
-- GL4 Instanced Shader & VAO Setup (#version 330)
--------------------------------------------------------------------------------
local function InitGL4()
	if not gl.GetVBO or not gl.GetVAO or not gl.CreateShader then
		return false
	end

	local vertSrc = [[
		#version 330

		// Per-vertex static quad corner
		layout(location = 0) in vec2 a_corner;

		// Per-instance laser beam segment (12 floats = 3 vec4s)
		layout(location = 1) in vec4 a_posStart;  // startX, startY, startZ, endX
		layout(location = 2) in vec4 a_posEndW;   // endY, endZ, width, alpha
		layout(location = 3) in vec4 a_colorTex;  // r, g, b, texOffset

		uniform mat4 u_viewMat;
		uniform mat4 u_projMat;
		uniform vec3 u_camPos;
		uniform float u_lineTexLen;

		out vec4 v_color;
		out vec2 v_texCoord;
		out vec2 v_uvAlong;

		void main() {
			vec3 sPos = a_posStart.xyz;
			vec3 ePos = vec3(a_posStart.w, a_posEndW.xy);
			float w = a_posEndW.z;

			vec3 delta = ePos - sPos;
			float dist3D = length(delta);
			vec3 segDir = (dist3D > 0.001) ? (delta / dist3D) : vec3(0.0, 0.0, 1.0);

			float side = a_corner.x * 2.0 - 1.0; // -1..+1 across ribbon width
			float along = a_corner.y;            // 0 = muzzle, 1 = target
			vec3 centerPos = mix(sPos, ePos, along);

			// 3D Camera-facing billboard expansion so both ground lasers and steep aircraft dive lasers
			// stay razor-sharp from TA overhead AND close 360-degree TPS orbit angles!
			vec3 viewDir = normalize(u_camPos - centerPos);
			vec3 perp = cross(segDir, viewDir);
			float perpLen = length(perp);
			if (perpLen > 0.001) {
				perp /= perpLen;
			} else {
				vec2 dXZ = delta.xz;
				float lXZ = length(dXZ);
				perp = (lXZ > 0.001) ? vec3(-dXZ.y / lXZ, 0.0, dXZ.x / lXZ) : vec3(1.0, 0.0, 0.0);
			}

			vec3 pos = centerPos + perp * (w * 0.5 * side);
			gl_Position = u_projMat * u_viewMat * vec4(pos, 1.0);

			v_color = vec4(a_colorTex.rgb, a_posEndW.w);
			v_uvAlong = a_corner;

			// Scrolling pulse texture coordinates along beam from muzzle -> target
			float texLen = dist3D / max(1.0, u_lineTexLen * max(2.8, w));
			v_texCoord.x = (1.0 - along) * (texLen + 1.0) - a_colorTex.w;
			v_texCoord.y = a_corner.x;
		}
	]]

	local fragSrc = [[
		#version 330

		uniform sampler2D u_tex;

		in vec4 v_color;
		in vec2 v_texCoord;
		in vec2 v_uvAlong;

		out vec4 fragColor;

		void main() {
			vec4 texSample = texture(u_tex, v_texCoord);

			// Gaussian bright inner laser filament + scrolling BAR pulse texture
			float across = abs(v_uvAlong.x * 2.0 - 1.0);
			float core = exp(-across * across * 8.5);
			float halo = exp(-across * across * 2.2);

			// Smooth muzzle attachment & target fade
			float endFade = smoothstep(0.0, 0.025, v_uvAlong.y) * smoothstep(1.0, 0.965, v_uvAlong.y);

			float pulseAlpha = max(texSample.a * 0.92, core * 0.46 + halo * 0.14);
			vec3 tintedRGB = mix(v_color.rgb, vec3(1.0, 1.0, 1.0), core * 0.52);
			vec3 finalRGB = tintedRGB * (0.72 + 0.58 * texSample.rgb);

			fragColor = vec4(finalRGB, v_color.a * pulseAlpha * endFade);
		}
	]]

	local shader = gl.CreateShader({
		vertex = vertSrc,
		fragment = fragSrc,
		uniformInt = { u_tex = 0 },
		uniformFloat = { u_lineTexLen = LINE_TEX_LENGTH },
	})
	if not shader then
		Spring.Echo("[ZDEF Laser Sights GL4] Shader compile failed: " .. tostring(gl.GetShaderLog()))
		return false
	end

	local locs = {
		viewMat = gl.GetUniformLocation(shader, "u_viewMat"),
		projMat = gl.GetUniformLocation(shader, "u_projMat"),
		camPos = gl.GetUniformLocation(shader, "u_camPos"),
		lineTexLen = gl.GetUniformLocation(shader, "u_lineTexLen"),
	}

	local quadVBO = gl.GetVBO(GL.ARRAY_BUFFER, false)
	if not quadVBO then
		gl.DeleteShader(shader)
		return false
	end
	quadVBO:Define(4, { { id = 0, name = "a_corner", size = 2 } })
	quadVBO:Upload({ 0, 0, 1, 0, 0, 1, 1, 1 })

	local instVBO = gl.GetVBO(GL.ARRAY_BUFFER, true)
	if not instVBO then
		gl.DeleteShader(shader)
		return false
	end
	instVBO:Define(GL4_MAX_BEAMS, {
		{ id = 1, name = "a_posStart", size = 4 },
		{ id = 2, name = "a_posEndW", size = 4 },
		{ id = 3, name = "a_colorTex", size = 4 },
	})

	local vao = gl.GetVAO()
	if not vao then
		gl.DeleteShader(shader)
		return false
	end
	vao:AttachVertexBuffer(quadVBO)
	vao:AttachInstanceBuffer(instVBO)
	if gl.InstanceVBOTable and gl.InstanceVBOTable.fillVAOSlots then
		gl.InstanceVBOTable.fillVAOSlots(vao, false, true)
	end

	gl4 = {
		shader = shader,
		locs = locs,
		vao = vao,
		quadVBO = quadVBO,
		instVBO = instVBO,
		beamData = {},
	}
	return true
end

local function ShutdownGL4()
	if gl4 then
		if gl4.shader then
			gl.DeleteShader(gl4.shader)
		end
		gl4.vao = nil
		gl4.instVBO = nil
		gl4.quadVBO = nil
		gl4 = nil
	end
end

--------------------------------------------------------------------------------
-- Unit Tracking (O(N_military) instead of scanning 900+ zombies every frame!)
--------------------------------------------------------------------------------
local function registerUnit(uid, uDefID)
	uDefID = uDefID or spGetUnitDefID(uid)
	if uDefID and unitDefStyle[uDefID] then
		trackedUnits[uid] = uDefID
		if flarePieceCache[uDefID] == nil and spGetUnitPieceMap then
			local pmap = spGetUnitPieceMap(uid)
			if pmap then
				flarePieceCache[uDefID] = pmap["flare"] or pmap["barrel"] or pmap["larm_r"] or false
			else
				flarePieceCache[uDefID] = false
			end
		end
	end
end

function widget:Initialize()
	unitDefStyle = {}
	flarePieceCache = {}
	trackedUnits = {}
	unitTargetHold = {}

	for uDefID, uDef in pairs(UnitDefs or {}) do
		if uDef and uDef.name and CLASS_STYLES[uDef.name] then
			unitDefStyle[uDefID] = CLASS_STYLES[uDef.name]
		end
	end

	if not InitGL4() then
		Spring.Echo("[ZDEF Laser Sights GL4] GL4 unavailable — disabling widget.")
		widgetHandler:RemoveWidget(self)
		return
	end

	local allUnits = spGetAllUnits()
	if allUnits then
		for i = 1, #allUnits do
			registerUnit(allUnits[i])
		end
	end
end

function widget:Shutdown()
	ShutdownGL4()
	trackedUnits = {}
	unitTargetHold = {}
end

function widget:UnitCreated(unitID, unitDefID)
	registerUnit(unitID, unitDefID)
end

function widget:UnitFinished(unitID, unitDefID)
	registerUnit(unitID, unitDefID)
end

function widget:UnitEnteredLos(unitID, unitTeam)
	registerUnit(unitID)
end

function widget:UnitDestroyed(unitID)
	trackedUnits[unitID] = nil
	unitTargetHold[unitID] = nil
end

--------------------------------------------------------------------------------
-- Hoisted GL4 Shader Draw Callback (Zero per-frame closure allocation)
--------------------------------------------------------------------------------
local gl4BeamCount = 0
local camX, camY, camZ = 0, 500, 0
local function gl4DrawFunc()
	local locs = gl4.locs
	gl.UniformMatrix(locs.viewMat, "camera")
	gl.UniformMatrix(locs.projMat, "projection")
	gl.Uniform(locs.camPos, camX, camY, camZ)
	gl.Uniform(locs.lineTexLen, LINE_TEX_LENGTH)
	gl4.vao:DrawArrays(GL_TRIANGLE_STRIP, 4, 0, gl4BeamCount)
end

local function getMuzzleWorldPos(uid, uDefID, style)
	local pID = flarePieceCache[uDefID]
	if pID and spGetUnitPiecePosDir then
		local px, py, pz = spGetUnitPiecePosDir(uid, pID)
		if px and py and pz then
			return px, py, pz
		end
	end
	local ux, uy, uz
	if spGetUnitViewPosition then
		ux, uy, uz = spGetUnitViewPosition(uid)
	else
		ux, uy, uz = spGetUnitPosition(uid)
	end
	if ux and uy and uz then
		return ux, uy + style[8], uz
	end
	return nil
end

function widget:DrawWorld()
	if not gl4 or spIsGUIHidden() then
		return
	end
	local gfx = WG and WG.ZDEF_GFX
	if gfx and gfx.lasers == false then
		return
	end

	local now = os_clock()
	local dt = now - prevOsClock
	if dt < 0 or dt > 0.25 then dt = 0.016 end
	prevOsClock = now

	texOffset = texOffset - dt * LINE_TEX_SPEED
	texOffset = texOffset - mathFloor(texOffset)

	camX, camY, camZ = spGetCameraPosition()
	camX, camY, camZ = camX or 0, camY or 500, camZ or 0

	local beamData = gl4.beamData
	local beamCount = 0
	ringCount = 0

	for uid, uDefID in pairs(trackedUnits) do
		if not spValidUnitID(uid) then
			trackedUnits[uid] = nil
			unitTargetHold[uid] = nil
		elseif beamCount < GL4_MAX_BEAMS then
			local style = unitDefStyle[uDefID]
			local isAir = style[9]
			local tx, ty, tz = nil, nil, nil

			if isAir then
				-- Aircraft (C-130, A-10, F-16): RED laser driven by active air-strike target params
				if (spGetUnitRulesParam(uid, "zdef_laser_active") or 0) == 1 then
					local ltx = spGetUnitRulesParam(uid, "zdef_laser_tx")
					local ltz = spGetUnitRulesParam(uid, "zdef_laser_tz")
					if ltx and ltz then
						tx = ltx
						tz = ltz
						ty = (spGetGroundHeight(tx, tz) or 50) + 4.0
					end
				end
			elseif spGetUnitWeaponTarget then
				-- Infantry (GREEN) & Tank/MRAP (BLUE): live Weapon #1 target with 0.22s hold-smoothing over burst pauses
				local tType, _, tData = spGetUnitWeaponTarget(uid, 1)
				if tType == 1 and type(tData) == "number" and spValidUnitID(tData) then
					local ex, ey, ez = spGetUnitPosition(tData)
					if ex and ey and ez then
						tx, ty, tz = ex, ey + 8.5, ez
						local hold = unitTargetHold[uid]
						if not hold then
							hold = {}
							unitTargetHold[uid] = hold
						end
						hold.tid = tData
						hold.tx, hold.ty, hold.tz = tx, ty, tz
						hold.expireTime = now + 0.22
					end
				elseif tType == 2 and type(tData) == "table" and tData[1] and tData[3] then
					tx, ty, tz = tData[1], (tData[2] or spGetGroundHeight(tData[1], tData[3]) or 50) + 4.0, tData[3]
					local hold = unitTargetHold[uid]
					if not hold then
						hold = {}
						unitTargetHold[uid] = hold
					end
					hold.tid = nil
					hold.tx, hold.ty, hold.tz = tx, ty, tz
					hold.expireTime = now + 0.16
				else
					local hold = unitTargetHold[uid]
					if hold and now < hold.expireTime then
						if hold.tid then
							if spValidUnitID(hold.tid) then
								local ex, ey, ez = spGetUnitPosition(hold.tid)
								if ex and ey and ez then
									tx, ty, tz = ex, ey + 8.5, ez
								end
							end
						else
							tx, ty, tz = hold.tx, hold.ty, hold.tz
						end
					elseif hold then
						unitTargetHold[uid] = nil
					end
				end
			end

			if tx and ty and tz then
				local sx, sy, sz = getMuzzleWorldPos(uid, uDefID, style)
				if sx and sy and sz then
					-- Frustum cull beams completely outside camera view
					if spIsUnitInView(uid) or spIsSphereInView(tx, ty, tz, 32) then
						local base = beamCount * GL4_FLOATS_PER_BEAM
						beamCount = beamCount + 1
						-- a_posStart: startX, startY, startZ, endX
						beamData[base + 1] = sx
						beamData[base + 2] = sy
						beamData[base + 3] = sz
						beamData[base + 4] = tx
						-- a_posEndW: endY, endZ, width, alpha
						beamData[base + 5] = ty
						beamData[base + 6] = tz
						beamData[base + 7] = style[5]
						beamData[base + 8] = style[4]
						-- a_colorTex: r, g, b, texOffset (slight per-unit phase stagger looks super organic!)
						beamData[base + 9]  = style[1]
						beamData[base + 10] = style[2]
						beamData[base + 11] = style[3]
						beamData[base + 12] = texOffset + ((uid % 17) * 0.058)

						-- Queue target designator reticle ring on ground/target
						ringCount = ringCount + 1
						ringX[ringCount] = tx
						ringY[ringCount] = ty
						ringZ[ringCount] = tz
						ringR[ringCount] = style[6]
						ringColR[ringCount] = style[1]
						ringColG[ringCount] = style[2]
						ringColB[ringCount] = style[3]
						ringColA[ringCount] = style[7]
						ringIsAir[ringCount] = isAir
					end
				end
			end
		end
	end

	if beamCount == 0 then
		return
	end

	-- Pass 1: ONE single GL4 instanced draw call for ALL Green / Blue / Red laser ribbons with additive bloom!
	glDepthTest(GL_LEQUAL)
	glDepthMask(false)
	glBlending(GL_SRC_ALPHA, GL_ONE)

	gl4.instVBO:Upload(beamData, -1, 0, 1, beamCount * GL4_FLOATS_PER_BEAM)
	glTexture(0, LINE_IMG)
	gl4BeamCount = beamCount
	glActiveShader(gl4.shader, gl4DrawFunc)
	glTexture(0, false)

	-- Pass 2: Crisp Additive Target-Lock Designator Rings (Green dot / Blue armor lock / Red pulsing air-strike lock)
	local drawRings = not (gfx and gfx.laserRings == false)
	if drawRings and glDrawGroundCircle and ringCount > 0 then
		local pulse = 0.78 + 0.22 * mathSin(now * 8.5)
		for i = 1, ringCount do
			local rx, ry, rz = ringX[i], ringY[i], ringZ[i]
			local rad = ringR[i]
			local cr, cg, cb, ca = ringColR[i], ringColG[i], ringColB[i], ringColA[i]
			if ringIsAir[i] then
				glLineWidth(2.2)
				glColor(cr, cg, cb, ca * pulse)
				glDrawGroundCircle(rx, ry, rz, rad, 24)
				glLineWidth(1.3)
				glColor(1.0, 0.55, 0.55, ca * 0.78)
				glDrawGroundCircle(rx, ry, rz, rad * 0.42, 16)
				local crLen = rad * 0.65
				local gy = (spGetGroundHeight(rx, rz) or ry) + 2.5
				glBeginEnd(GL_LINES, function()
					glVertex(rx - crLen, gy, rz); glVertex(rx + crLen, gy, rz)
					glVertex(rx, gy, rz - crLen); glVertex(rx, gy, rz + crLen)
				end)
			else
				glLineWidth(rad >= 9.0 and 1.6 or 1.1)
				glColor(cr, cg, cb, ca)
				glDrawGroundCircle(rx, ry, rz, rad, 14)
			end
		end
	end

	glLineWidth(1.0)
	glBlending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
	glDepthMask(true)
	glDepthTest(false)
	glColor(1, 1, 1, 1)
end
