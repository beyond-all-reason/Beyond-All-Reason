-- $Id: unit_icongenerator.lua 3909 2009-02-05 22:49:55Z jk $
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  file:    unit_icongenerator.lua
--  brief:
--  author:  jK
--
--  Copyright (C) 2007.
--  Licensed under the terms of the GNU GPL, v2 or later.
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

--[[
example usage (need cheats):
/luarules buildicons all
/luarules buildicon armcom
]]--
--TODO:
--1. make blue water drop 256
--2. fix the culling of floating structures
--3. make units get their default stance (e.g. armcom)

local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "IconGenerator",
		desc = "/luarules buildicon(s) [unitdefname|all]",
		author = "jK",
		date = "Oct 01, 2008",
		license = "GNU GPL, v2 or later",
		layer = -10,
		enabled = true
	}
end

--local renderOverlay = false

if gadgetHandler:IsSyncedCode() then


	local units = {}
	local createunits = {}
	local curTeam
	local nextUnitX, nextUnitZ = 100, 100

	local function GameFrame(_, n)
		local new = {}
		for i = 1, #units do
			if (units[i].frame + 5) == n then
				Spring.DestroyUnit(units[i].id, false, true)
			elseif units[i].frame == n then
				SendToUnsynced("buildicon_unitcreated", units[i].id, units[i].defname)
				new[#new + 1] = units[i]
			else
				new[#new + 1] = units[i]
			end
		end
		units = new

		if #units > 10 then
			return
		end
		if #units == 0 then
			curTeam = nil
		end

		local leftunits = {}
		for i, cunit in ipairs(createunits) do
			if #units > 10 or (curTeam and cunit.team ~= curTeam) then
				leftunits[#leftunits + 1] = cunit
			else
				local lus = false
				local x, z = nextUnitX, nextUnitZ
				nextUnitX = nextUnitX + 200
				if (nextUnitX >= Game.mapSizeX) then
					nextUnitX, nextUnitZ = 100, nextUnitZ + 200
				end
				local y = Spring.GetGroundHeight(0, 0)
				Spring.LevelHeightMap(x - 50, z - 50, x + 50, z + 50, y)

				local uid = Spring.CreateUnit(cunit.defname, x, y, z, "south", 0)    -- FIXME needs to be a non-gaia team if gaia doesn't have its unitlimit assigned

				if uid then
					units[#units + 1] = { id = uid, defname = cunit.defname, frame = n + cunit.time }
					curTeam = cunit.team

					Spring.SetUnitNeutral(uid, true)
					Spring.GiveOrderToUnit(uid, CMD.FIRE_STATE, { 0 }, 0)
					Spring.GiveOrderToUnit(uid, CMD.STOP, {}, 0)

					local env = Spring.UnitScript.GetScriptEnv(uid)
					if env then
						lus = true
					end

					if lus then
						if env.Activate then
							Spring.UnitScript.CallAsUnit(uid, env.Activate)
						end
					else
						Spring.CallCOBScript(uid, "Activate", 0)
					end

					if cunit.move then
						if lus then
							if env.StartMoving then
								Spring.UnitScript.CallAsUnit(uid, env.StartMoving)
							end
						else
							Spring.CallCOBScript(uid, "StartMoving", 0)
						end
					end

					if cunit.attack and not lus then
						local angle = (cunit.shotAngle / 180) * 32768

						Spring.CallCOBScript(uid, "AimPrimary", 0, Spring.GetHeadingFromVector(0, 1), angle)
						Spring.CallCOBScript(uid, "AimWeapon1", 0, Spring.GetHeadingFromVector(0, 1), angle)

						Spring.CallCOBScript(uid, "AimSecondary", 0, Spring.GetHeadingFromVector(0, 1), angle)
						Spring.CallCOBScript(uid, "AimWeapon2", 0, Spring.GetHeadingFromVector(0, 1), angle)

						Spring.CallCOBScript(uid, "AimTertiary", 0, Spring.GetHeadingFromVector(0, 1), angle)
						Spring.CallCOBScript(uid, "AimWeapon3", 0, Spring.GetHeadingFromVector(0, 1), angle)

					end
				end
			end
		end
		createunits = leftunits

		if #units == 0 and #createunits == 0 then
			nextUnitX, nextUnitZ = 100, 100
			gadget.GameFrame = nil
			gadgetHandler:UpdateCallIn("GameFrame")
			gadgetHandler:UpdateCallIn("GameFrame")
		end
	end

	function gadget:RecvLuaMsg(msg, playerID)
		if msg:sub(1, 9) == "buildicon" then
			if not Spring.IsCheatingEnabled() then
				Spring.SendMessageToPlayer(playerID, "Cheating must be enabled")
				return true
			end

			local msg = msg:sub(11, msg:len())
			local d = msg:find(";", nil, true)
			local defname = msg:sub(1, d - 1)
			local a = msg:find(";", d + 1, true)
			local attack = (msg:sub(d + 1, a - 1) == "1")
			local m = msg:find(";", a + 1, true)
			local move = (msg:sub(a + 1, m - 1) == "1")
			local t = msg:find(";", m + 1, true)
			local teamID = tonumber(msg:sub(m + 1, t - 1))
			local w = msg:find(";", t + 1, true)
			local wait = tonumber(msg:sub(t + 1, w - 1))
			local sa = msg:find(";", w + 1, true)
			local shotAngle = tonumber(msg:sub(w + 1, sa - 1))

			createunits[#createunits + 1] = { defname = defname, team = teamID, move = move, attack = attack, time = wait, shotAngle = shotAngle }

			gadget.GameFrame = GameFrame
			gadgetHandler:UpdateCallIn("GameFrame")
			gadgetHandler:UpdateCallIn("GameFrame")
			return true
		end
	end


	--------------------------------------------------------------------------------
	--------------------------------------------------------------------------------
else
	--------------------------------------------------------------------------------
	--------------------------------------------------------------------------------

	--// we render in a higher resolution, so we can detect the boundings and center the icon
	--// and replace AA by scaling the final icon down to the desired size
	local renderX, renderY

	local fbo
	local pre_shader, clear_shader, post_shader
	local albedo_tex, normal_tex, depth_tex
	local final_tex, final_fbo
	local halo_shader

	--------------------------------------------------------------------------------
	--------------------------------------------------------------------------------

	local scheme
	local ratio, ratio_name
	local iconX, iconY
	local outdir

	local unitAnimCfg = {}
	local post_tex, post_fbo

	--------------------------------------------------------------------------------
	--------------------------------------------------------------------------------

	--// some OpenGl consts

	local GL_RGBA = 0x1908
	local GL_RGBA16F_ARB = 0x881A
	local GL_DEPTH_COMPONENT32 = 0x81A7
	local GL_COLOR_ATTACHMENT0_EXT = 0x8CE0
	local GL_COLOR_ATTACHMENT1_EXT = 0x8CE1
	local GL_READ_FRAMEBUFFER_EXT = 0x8CA8

	--------------------------------------------------------------------------------
	--------------------------------------------------------------------------------

	local autoConfigs = {}

	scheme = "" --// global var!

	local function include(filedir, filename, env)
		if VFS.FileExists(filename, VFS.RAW_ONLY) then
			return VFS.Include(filename, env, VFS.RAW_ONLY)
		else
			return VFS.Include(filedir .. filename, env, VFS.ZIP_ONLY)
		end
	end

	local function LoadScheme()
		local G = getfenv()
		G["scheme"] = scheme
		G["ratio"] = ratio
		G["ratio_name"] = ratio_name
		G["iconX"] = iconX
		G["iconY"] = iconY

		autoConfigs = {} --// reset

		include("LuaRules/Configs/", "icon_generator.lua")

		setmetatable(unitConfigs, { __index = autoConfigs })
	end

	--------------------------------------------------------------------------------
	--------------------------------------------------------------------------------

	local function blend(a, b, mix)
		if mix > 1 then
			mix = 1
		end
		return a * (1 - mix) + b * mix
	end

	local function round(num, idp)
		local mult = 10 ^ (idp or 0)
		return math.floor(num * mult + 0.5) / mult
	end

	--------------------------------------------------------------------------------
	--------------------------------------------------------------------------------

	local function CreateResources()
		renderX, renderY = iconX * renderScale, iconY * renderScale

		local texOpt = {
			border = false,
			min_filter = GL.LINEAR,
			mag_filter = GL.LINEAR,
			wrap_s = GL.CLAMP_TO_EDGE,
			wrap_t = GL.CLAMP_TO_EDGE,
		}

		texOpt.format = GL_RGBA16F_ARB
		albedo_tex = gl.CreateTexture(renderX, renderY, texOpt)

		texOpt.format = GL_RGBA16F_ARB
		normal_tex = gl.CreateTexture(renderX, renderY, texOpt)

		texOpt.format = GL_DEPTH_COMPONENT32
		depth_tex = gl.CreateTexture(renderX, renderY, texOpt)

		fbo = gl.CreateFBO({
			color0 = albedo_tex,
			color1 = normal_tex,
			depth = depth_tex,
			drawbuffers = { GL_COLOR_ATTACHMENT0_EXT, GL_COLOR_ATTACHMENT1_EXT },
		})

		texOpt.format = GL_RGBA
		post_tex = gl.CreateTexture(renderX, renderY, texOpt)
		post_fbo = gl.CreateFBO({ color0 = post_tex })

		texOpt.format = GL_RGBA
		final_tex = gl.CreateTexture(iconX, iconY, texOpt)
		final_fbo = gl.CreateFBO({ color0 = final_tex })

		pre_shader = gl.CreateShader({
			vertex = [[
      #version 150 compatibility
      varying vec3 normal;
      varying vec4 pos;
      varying float clamp;

      varying float aoTerm;

      void main(void) {
        gl_FrontColor = gl_Color;
        gl_TexCoord[0] = gl_MultiTexCoord0;

         aoTerm= max(0.4,fract(gl_MultiTexCoord0.s*16384.0)*1.3); // great
        clamp = gl_MultiTexCoord1.x;
        normal = gl_Normal;

        pos = gl_ModelViewMatrix * gl_Vertex;

        gl_Position = gl_ProjectionMatrix * (gl_TextureMatrix[0] * pos);
      }
    ]],
			fragment = [[
	  #version 150 compatibility
      uniform sampler2D unitTex;
      uniform sampler2D unitTex2;


      varying vec3 normal;
      varying vec4 pos;
      varying float clamp;

      in float aoTerm;
      void main(void) {
        ;//if (pos.y<clamp) discard;

        gl_FragData[0]     = texture2D(unitTex,gl_TexCoord[0].st) *  aoTerm;
		gl_FragData[2] = texture2D(unitTex2,gl_TexCoord[0].st);
        gl_FragData[0].rgb = mix(gl_FragData[0].rgb, gl_Color.rgb, gl_FragData[0].a);
		gl_FragData[0].rgb += (gl_FragData[2].rrr)*0.5;
        gl_FragData[0].a   = gl_FragCoord.z; //we save and read t from here cuz of the higher precision (the depthtex uses just bytes)
        gl_FragData[1]     = vec4(normal,1.0);
      }
    ]],
			uniformInt = {
				unitTex = 0,
				unitTex2 = 1,
			},
		})

		if not pre_shader then
			Spring.Log(gadget:GetInfo().name, LOG.ERROR, gl.GetShaderLog())
		end

		post_shader = gl.CreateShader({
			vertex = [[
	  #version 150 compatibility
      void main()
      {
         gl_TexCoord[0] = gl_Vertex;
         gl_FrontColor  = gl_Color;
         gl_Position    = vec4( (gl_Vertex.xy-0.5)*2.0,1.0,1.0);
      }
    ]],
			fragment = [[
      #version 150 compatibility
      uniform sampler2D albedoTex;
      uniform sampler2D normalTex;
      //////////////////////////////////////////////////
      // Main

      vec4 GetDepthsAO(vec2 texel,float depth) {
        vec4 depths = vec4(texture2D(albedoTex, gl_TexCoord[0].st+vec2(texel.x, 0.0) ).a,
                    texture2D(albedoTex, gl_TexCoord[0].st+vec2(0.0, texel.y) ).a,
                    texture2D(albedoTex, gl_TexCoord[0].st+vec2(-texel.x,0.0) ).a,
                    texture2D(albedoTex, gl_TexCoord[0].st+vec2(0.0,-texel.y) ).a);

        depths.r = (depths.r==0.0) ? depth : depths.r;
        depths.g = (depths.g==0.0) ? depth : depths.g;
        depths.b = (depths.b==0.0) ? depth : depths.b;
        depths.a = (depths.a==0.0) ? depth : depths.a;
        return depths;
      }

      vec4 GetDepthsOL(vec2 texel) {
        return vec4(texture2D(albedoTex, gl_TexCoord[0].st+vec2(texel.x, 0.0) ).a,
                    texture2D(albedoTex, gl_TexCoord[0].st+vec2(0.0, texel.y) ).a,
                    texture2D(albedoTex, gl_TexCoord[0].st+vec2(-texel.x,0.0) ).a,
                    texture2D(albedoTex, gl_TexCoord[0].st+vec2(0.0,-texel.y) ).a);
      }

      vec4 GetDepthsOL2(vec2 texel) {
        return vec4(texture2D(albedoTex, gl_TexCoord[0].st+vec2(texel.x,  texel.y) ).a,
                    texture2D(albedoTex, gl_TexCoord[0].st+vec2(texel.x, -texel.y) ).a,
                    texture2D(albedoTex, gl_TexCoord[0].st+vec2(-texel.x, texel.y) ).a,
                    texture2D(albedoTex, gl_TexCoord[0].st+vec2(-texel.x,-texel.y) ).a);
      }

      void main(void)
      {
        vec4 albedo = texture2D(albedoTex, gl_TexCoord[0].st);
        vec4 normal = texture2D(normalTex, gl_TexCoord[0].st);
        float depth = albedo.a;

        vec2 texel  = vec2(dFdx(gl_TexCoord[0].s),dFdy(gl_TexCoord[0].t));
        vec4 depths;

      // ambient occlusion
        float ao = 0.0;
        float aoMultiplier = 3.0 * ]] .. (aoContrast or 1) .. [[;
        float aoTolerance = 0.0 + ]] .. (aoTolerance or 0) .. [[;

        depths = GetDepthsAO(texel,depth);
        depths = clamp(depth - depths - aoTolerance,0.0,1.0) * aoMultiplier;
        ao += dot(depths,vec4(1.0));

        depths = GetDepthsAO(texel*2.0,depth);
        depths = clamp(depth - depths - aoTolerance,0.0,1.0) * aoMultiplier;
        //depths = clamp(depths,0.0,0.2);
        ao += dot(depths,vec4(1.0));

        depths = GetDepthsAO(texel*3.0,depth);
        depths = clamp(depth - depths - aoTolerance,0.0,1.0) * aoMultiplier;
        ao += dot(depths,vec4(1.0));

        ao = min(pow(ao,float(]] .. (aoPower or 1) .. [[)),1.0);


      // outline
        float ol = 0.0;
        float olMultiplier = 1.7 * float(]] .. (olContrast or 1) .. [[);
        float olTolerance = 0.0 + float(]] .. (olTolerance or 0) .. [[);

        depths = GetDepthsOL(texel);
        depths = clamp(depths - vec4(depth) - olTolerance,0.0,0.1);
        ol += dot(depths,vec4(olMultiplier));

        depths = GetDepthsOL(texel*2.0);
        depths = clamp(depths - vec4(depth) - olTolerance,0.0,0.02);
        ol += dot(depths,vec4(olMultiplier));

        depths = GetDepthsOL2(texel*2.5);
        depths = clamp(depths - vec4(depth) - olTolerance,0.0,0.01);
        ol += dot(depths,vec4(olMultiplier));

        ol *= smoothstep(0.1,0.0,depth);

      // final composition
        vec4 color1 = vec4(vec3((1.0 - ao) * normal.w),normal.w); // ambient occlusion

        gl_FragData[0] = color1;

      ]] .. (((not textured) and '/*') or '') .. [[
        vec3 lightPos     = vec3(]] .. (lightPos[1] .. ',' .. lightPos[2] .. ',' .. lightPos[3]) .. [[);
        vec3 lightDiffuse = vec3(]] .. (lightDiffuse[1] .. ',' .. lightDiffuse[2] .. ',' .. lightDiffuse[3]) .. [[);
        vec3 lightAmbient = vec3(]] .. (lightAmbient[1] .. ',' .. lightAmbient[2] .. ',' .. lightAmbient[3]) .. [[);
        gl_FragData[0].rgb  = albedo.rgb * (max(dot(normal.xyz,lightPos),0.0) * lightDiffuse + lightAmbient);
        gl_FragData[0].rgb *= min(vec3(1.0),color1.rgb);
      ]] .. (((not textured) and '*/') or '') .. [[

        gl_FragData[0] = mix(gl_FragData[0], vec4(0.0,0.0,0.0,1.0), ol);  // outline
      }
    ]],
			uniformInt = {
				albedoTex = 0,
				normalTex = 1,
			},
		})

		if not post_shader then
			Spring.Log(gadget:GetInfo().name, LOG.ERROR, gl.GetShaderLog())
		end

		halo_shader = gl.CreateShader({
			vertex = [[
	  #version 150 compatibility
      void main()
      {
         gl_TexCoord[0] = gl_MultiTexCoord0;
         gl_FrontColor  = gl_Color;
         gl_Position    = vec4( gl_Vertex.xy ,1.0,1.0);
      }
    ]],
			fragment = [[
	  #version 150 compatibility
      uniform sampler2D albedoTex;
      uniform sampler2D normalTex;

      //////////////////////////////////////////////////
      // Main

      vec4 GetDepths(vec2 texel) {
        return vec4(texture2D(albedoTex, gl_TexCoord[0].st+vec2(texel.x,  0.0) ).a,
                    texture2D(albedoTex, gl_TexCoord[0].st+vec2(0.0,  texel.y) ).a,
                    texture2D(albedoTex, gl_TexCoord[0].st+vec2(-texel.x, 0.0) ).a,
                    texture2D(albedoTex, gl_TexCoord[0].st+vec2(0.0, -texel.y) ).a);
      }

      vec4 GetDepths2(vec2 texel) {
        return vec4(texture2D(albedoTex, gl_TexCoord[0].st+vec2(texel.x,  texel.y) ).a,
                    texture2D(albedoTex, gl_TexCoord[0].st+vec2(texel.x, -texel.y) ).a,
                    texture2D(albedoTex, gl_TexCoord[0].st+vec2(-texel.x, texel.y) ).a,
                    texture2D(albedoTex, gl_TexCoord[0].st+vec2(-texel.x,-texel.y) ).a);
      }


      void main(void)
      {
        vec2 texel  = vec2(dFdx(gl_TexCoord[0].s),dFdy(gl_TexCoord[0].t));
        vec4 depths;

        // halo
        float hl = 0.0;
        float hlMultiplier = 0.017;

        float l = length(vec2(7.0,7.0));
        for (int x=-7; x<=7; x++) {
          for (int y=-7; y<=7; y++) {
            vec2 r = vec2(float(x),float(y));
            float a = smoothstep(0.0,l,l-length(r));
            float d = 1.0 - texture2D(albedoTex, gl_TexCoord[0].st + vec2(texel.x, texel.y) * r ).a;
            hl += step(0.001,d) * a * hlMultiplier;
          }
        }

        gl_FragData[0] = vec4(vec3(1.0),min(hl,0.9));
      }
    ]],
			uniformInt = {
				--depthTex = 2,
			},
		})

		if not halo_shader then
			Spring.Log(gadget:GetInfo().name, LOG.ERROR, gl.GetShaderLog())
		end

		clear_shader = gl.CreateShader({
			fragment = [[
	  #version 150 compatibility
      void main(void) {
        gl_FragData[0] = vec4(0.0);
        gl_FragData[1] = vec4(0.0);
      }
    ]]
		})

		if not clear_shader then
			Spring.Log(gadget:GetInfo().name, LOG.ERROR, gl.GetShaderLog())
		end
	end

	--------------------------------------------------------------------------------
	--------------------------------------------------------------------------------

	function FreeResources()
		gl.DeleteTexture(albedo_tex)
		gl.DeleteTexture(normal_tex)
		gl.DeleteTexture(depth_tex)
		gl.DeleteFBO(fbo)
		gl.DeleteShader(pre_shader)

		gl.DeleteShader(clear_shader)

		gl.DeleteTexture(post_tex)
		gl.DeleteFBO(post_fbo)
		gl.DeleteShader(post_shader)

		gl.DeleteTexture(final_tex)
		gl.DeleteFBO(final_fbo)

		gl.DeleteShader(halo_shader)

		fbo = nil
		pre_shader, clear_shader, post_shader = nil, nil, nil, nil
		albedo_tex, normal_tex, depth_tex = nil, nil, nil
		final_tex, final_fbo = nil, nil
		post_tex, post_fbo = nil, nil
		halo_shader = nil
	end

	--------------------------------------------------------------------------------
	--------------------------------------------------------------------------------

	local function CheckOutsideBoundings(left, bottom, width, height, wantedSpace)
		local to = math.min(0, (renderY - wantedSpace) - (bottom + height))
		local ro = math.min(0, (renderX - wantedSpace) - (left + width))
		local bo = math.max(0, wantedSpace - bottom)
		local lo = math.max(0, wantedSpace - left)

		if (to < 0 and bo > 0) or (ro < 0 and lo > 0) then
			return false --zoom out!
		end

		return ro + lo, to + bo
	end

	local function GetBound1(pixels, start, finish, dirX, dirY, length)
		local bound
		for i = start, finish, ((start > finish) and -1) or 1 do
			for n = 0, length do
				if pixels[1 + i * dirY + n * dirX][1 + i * dirX + n * dirY][4] > 0 then
					bound = i
					break
				end
			end
			if bound then
				break
			end
		end
		return bound
	end

	local function GetBound2(p, start, finish, dirX, dirY, length)
		local bound
		for i = start, finish, ((start > finish) and -1) or 1 do
			local pixels = gl.ReadPixels(i * dirX, i * dirY, (dirY > 0 and length) or 1, (dirX > 0 and length) or 1)
			for n = 1, length do
				if pixels[n][4] > 0 then
					bound = i
					break
				end
			end
			if bound then
				break
			end
		end
		return bound
	end

	local function DetectBoundings()
		local GetBound = ((iconX * iconY) < (128 * 128) and GetBound1) or GetBound2
		local pixels
		if iconX * iconY < 128 * 128 then
			pixels = gl.ReadPixels(0, 0, renderX, renderY)
		end
		local top = GetBound(pixels, renderY - 1, 0, 0, 1, renderX - 1)
		local bottom = GetBound(pixels, 0, renderY - 1, 0, 1, renderX - 1)
		local right = GetBound(pixels, renderX - 1, 0, 1, 0, renderY - 1)
		local left = GetBound(pixels, 0, renderX - 1, 1, 0, renderY - 1)
		return top, left, bottom, right
	end


	--------------------------------------------------------------------------------
	--------------------------------------------------------------------------------

	local function GetUnitDefDims(udid)
		local dims = Spring.GetUnitDefDimensions(udid)
		local midx, midy, midz = (dims.maxx + dims.minx) * 0.5, (math.max(0, dims.maxy) + math.max(0, dims.miny)) * 0.5, (dims.maxz + dims.minz) * 0.5
		local ax = math.max(math.abs(dims.maxx - midx), math.abs(dims.minx - midx))
		local ay = math.max(math.abs(dims.maxy - midy), math.abs(dims.miny - midy))
		local az = math.max(math.abs(dims.maxz - midz), math.abs(dims.minz - midz))
		local radius = ((ax * ax + ay * ay + az * az) ^ 0.5)
		return midx, midy, midz, radius
	end

	--------------------------------------------------------------------------------
	--------------------------------------------------------------------------------
	local i = 0

	local function DrawIcon(udid, teamID, uid)
		local cfg = unitConfigs[udid]
		local midx, midy, midz, radius = GetUnitDefDims(udid)

		radius = radius * cfg.zoom
		gl.MultiTexCoord(1, cfg.clamp)

		gl.Blending(false)
		gl.DepthTest(true)
		gl.DepthMask(true)
		gl.MatrixMode(GL.PROJECTION)
		gl.PushMatrix()
		gl.LoadIdentity()
		gl.Ortho(-radius * renderScale, radius * renderScale, -radius * renderScale * ratio, radius * renderScale * ratio, -radius * 4, radius * 4)
		gl.ActiveTexture(0, gl.MatrixMode, GL.TEXTURE)
		gl.PushMatrix()
		gl.LoadIdentity()

		gl.Rotate(cfg.angle, 1, 0, 0)
		if cfg.rotation then
			gl.Rotate(cfg.rotation, 0, 1, 0)
		end
		if cfg.rot == "right" then
			gl.Rotate(45, 0, 1, 0)
		elseif cfg.rot == "left" then
			gl.Rotate(-45, 0, 1, 0)
		elseif type(cfg.rot) == "number" then
			gl.Rotate(cfg.rot, 0, 1, 0)
		else
			gl.Rotate(45, 0, 1, 0)
		end

		--gl.Translate((midx+cfg.offset[1]) * cfg.zoom,(midy+cfg.offset[2]) * cfg.zoom,0)--midz+cfg.offset[3])
		--gl.Translate((midx+cfg.offset[1])*renderScale,(midy+cfg.offset[2])*renderScale,0)
		gl.Translate((midx + cfg.offset[1]), (midy + cfg.offset[2]), 0)
		gl.Translate(0, -radius * renderScale * 0.5, 0)

		gl.MatrixMode(GL.MODELVIEW)
		gl.PushMatrix()
		gl.LoadIdentity()

		if (uid) then
			gl.UnitTextures(uid, true)
			gl.UnitRaw(uid, true, -1)
			gl.UnitTextures(uid, false)
		else
			gl.UnitShapeTextures(udid, true)
			gl.UnitShape(udid, teamID, true)
			--gl.UnitShape(udid, teamID, false, false, true))
			gl.UnitShapeTextures(udid, false)
		end

		gl.ActiveTexture(0, gl.MatrixMode, GL.TEXTURE)
		gl.PopMatrix()
		gl.MatrixMode(GL.PROJECTION)
		gl.PopMatrix()
		gl.MatrixMode(GL.MODELVIEW)
		gl.PopMatrix()
		gl.DepthMask(false)
		gl.DepthTest(false)
		i = i + 1
		--gl.SaveImage(0,0,renderX,renderY, outdir .. "/" .. UnitDefs[udid].name .. i .. imageExt,{alpha=true})
	end

	local function myGLClear()
		gl.Color(1, 1, 1, 0)

		gl.Blending(false)

		gl.PushMatrix()
		gl.LoadIdentity()
		gl.MatrixMode(GL.PROJECTION)
		gl.PushMatrix()
		gl.LoadIdentity()

		gl.DepthMask(true)
		gl.ActiveFBO(fbo, gl.Clear, GL.DEPTH_BUFFER_BIT)
		gl.DepthMask(false)

		gl.UseShader(clear_shader)
		gl.ActiveFBO(fbo, gl.TexRect, -1, -1, 1, 1)
		gl.UseShader(0)
		gl.ActiveFBO(post_fbo, gl.Clear, GL.COLOR_BUFFER_BIT, 0, 0, 0, 0)

		gl.PopMatrix()
		gl.MatrixMode(GL.MODELVIEW)
		gl.PopMatrix()
	end

	local function DrawIconPost()
		gl.Blending(false)

		gl.Texture(0, albedo_tex)
		gl.Texture(1, normal_tex)
		--gl.Texture(2,depth_tex)

		gl.TexRect(0, 0, 1, 1)

		gl.Texture(0, false)
		gl.Texture(1, false)
		--gl.Texture(2,false)
	end

	--------------------------------------------------------------------------------
	--------------------------------------------------------------------------------

	local function DrawBackground(background)
		if type(background) == "table" then
			local cnt = #background

			local elements = {}
			for i = 1, cnt - 1 do
				for n = 1, 4 do
					elements[#elements + 1] = {
						v = {}
					}
				end
			end

			gl.Shape(GL.QUADS, elements)
		else
			gl.Texture(background)
			gl.TexRect(-1, -1, 1, 1)
			gl.Texture(false)
		end
	end

	local function Background(unitdefid)
		local udef = UnitDefs[unitdefid]
		for i = 1, #backgrounds do
			local bg = backgrounds[i]
			if type(bg.check) == "table" then
				local fulfill = true
				for key, value in pairs(bg.check) do
					if type(value) == "function" then
						fulfill = value(udef[key])
					else
						fulfill = (udef[key] == value)
					end
					if not fulfill then
						break
					end
				end

				if fulfill then
					DrawBackground(bg.texture)
					break
				end
			end
		end
	end

	local function Overlay(unitdefid)
		local waterunit, amfibianunit, builderunit = false, false, false
		if (UnitDefs[unitdefid].waterline ~= nil and UnitDefs[unitdefid].waterline > 0) or (UnitDefs[unitdefid].minWaterDepth ~= nil and UnitDefs[unitdefid].minWaterDepth > 0) then
			waterunit = true
			if UnitDefs[unitdefid].levelGround == false then
				amfibianunit = true
			end

		end
		if (UnitDefs[unitdefid].maxWaterDepth ~= nil and UnitDefs[unitdefid].maxWaterDepth >= 255 and (UnitDefs[unitdefid].waterline == nil or UnitDefs[unitdefid].waterline <= 0)) and (UnitDefs[unitdefid].minWaterDepth == nil or UnitDefs[unitdefid].minWaterDepth <= 0) then
			amfibianunit = true
		end
		if (UnitDefs[unitdefid].isBuilder == true and UnitDefs[unitdefid].canMove == true) or (UnitDefs[unitdefid].name == 'armnanotc' or UnitDefs[unitdefid].name == 'armnanotcplat' or UnitDefs[unitdefid].name == 'cornanotc' or UnitDefs[unitdefid].name == 'cornanotcplat') then
			builderunit = true
		end

		if amfibianunit then
			gl.Texture("LuaRules/Images/amfibianunit.png")
			gl.TexRect(-1, -1, 1, 1)
			gl.Texture(false)
		elseif waterunit then
			gl.Texture("LuaRules/Images/waterunit.png")
			gl.TexRect(-1, -1, 1, 1)
			gl.Texture(false)
		end
		if builderunit then
			gl.Texture("LuaRules/Images/constructionunit.png")
			gl.TexRect(-1, -1, 1, 1)
			gl.Texture(false)
		end
		--if (UnitDefs[unitdefid].buildSpeed ~= nil and UnitDefs[unitdefid].buildSpeed > 0) and  (UnitDefs[unitdefid].canAssist == nil or UnitDefs[unitdefid].canAssist == true) then
		--  gl.Texture(":n:LuaRules/Images/constructionunit.png")
		--  gl.TexRect(-1,-1,1,1)
		--  gl.Texture(false)
		--end
	end

	--------------------------------------------------------------------------------
	--------------------------------------------------------------------------------

	local function PrepareForScaling(bottom, left, width, height, wantedX, wantedY, border)
		local scaleX, scaleY = width / wantedX, height / wantedY
		local wantX, wantY = wantedX * scaleY + border * scaleY * 2, height + border * scaleY * 2
		if scaleX > scaleY then
			wantX, wantY = width + border * scaleX * 2, wantedY * scaleX + border * scaleX * 2
		end

		local marginX, marginY = wantX - width, wantY - height
		local leftmargin, btmmargin = marginX * 0.5 - (marginX * 0.5) % 1, marginY * 0.5 - (marginY * 0.5) % 1

		local bottom, left = bottom - btmmargin, left - leftmargin
		local height = height + marginY
		local width = width + marginX

		if scaleX > scaleY then
			bottom, left = bottom - border * scaleX, left - border * scaleX
			width, height = width + border * scaleX * 2, height + border * scaleX * 2
		else
			bottom, left = bottom - border * scaleY, left - border * scaleY
			width, height = width + border * scaleY * 2, height + border * scaleY * 2
		end

		left, bottom, width, height = round(left), round(bottom), round(width), round(height)

		return left, bottom, width, height
	end

	local function CheckBoundings(udid, top, left, bottom, right, scale, border)
		--// some render context and icon dimensions
		local scaledBorder = border * scale
		local totalBorder = scaledBorder * 2
		local wantedSpace = math.min(math.min(renderX, renderY) / 5, scaledBorder * 2)
		local spaceX, spaceY = renderX - scaledBorder, renderY - scaledBorder
		local scaledX, scaledY = iconX * scale, iconY * scale
		local wantedX, wantedY = (scaledX - totalBorder), (scaledY - totalBorder)

		local height = top - bottom
		local width = right - left

		local left_, bottom_, width_, height_ = PrepareForScaling(bottom, left, width, height, wantedX, wantedY, border)

		if top >= spaceY or right >= spaceX or left <= scaledBorder or bottom <= scaledBorder then
			local offX, offY = CheckOutsideBoundings(left, bottom, width, height, wantedSpace)
			if offX then
				offX, offY = offX * autoConfigs[udid].attempt, offY * autoConfigs[udid].attempt
				--Spring.Echo(i,UnitDefs[udid].name .. ": offsetting",offX,offY,"",left,bottom,width,height,renderX,renderY,autoConfigs[udid].zoom)
				autoConfigs[udid].offset = { autoConfigs[udid].offset[1] + offX, autoConfigs[udid].offset[2] + offY, 0 }
				return false, left_, bottom_, width_, height_
			else
				--// zoom out!
			end
		end

		if math.abs(math.min(wantedX - width, wantedY - height)) > 3 then
			--Spring.Echo(i,UnitDefs[udid].name .. ": zoom (factor:" .. math.max(height/wantedY,width/wantedX) .. ")",width,height,wantedX,wantedY,autoConfigs[udid].zoom)
			autoConfigs[udid].zoom = blend(autoConfigs[udid].zoom, autoConfigs[udid].zoom * math.max(height / wantedY, width / wantedX), autoConfigs[udid].attempt)
			return false, left_, bottom_, width_, height_
		end

		if bottom_ + height_ > renderY or left_ < 0 or bottom_ < 0 or left_ + width_ > renderX then
			local offX, offY = CheckOutsideBoundings(left_, bottom_, width_, height_, wantedSpace)
			if offX then
				Spring.Echo(i, UnitDefs[udid].name .. ": Boundings outside of the texture", offX, offY)
				autoConfigs[udid].offset = { autoConfigs[udid].offset[1] + offX, autoConfigs[udid].offset[2] + offY, 0 }
				return false, left_, bottom_, width_, height_
			else
				Spring.Echo(i, UnitDefs[udid].name .. ": Render Context too small (you have to increase renderX&renderY)")
			end
		end

		return true, left_, bottom_, width_, height_
	end

	local function CenterIcon(udid)
		local ac = autoConfigs[udid]
		ac.attempt = (ac.attempt or (1 / 0.99)) * 0.99

		local top, left, bottom, right
		if unitAnimCfg[udid] and unitAnimCfg[udid][ac.attempt] then
			-- when for anim-gif rotating, use same center cfg
			top, left, bottom, right = unitAnimCfg[udid][ac.attempt][1], unitAnimCfg[udid][ac.attempt][2], unitAnimCfg[udid][ac.attempt][3], unitAnimCfg[udid][ac.attempt][4]
		else
			top, left, bottom, right = DetectBoundings()
			if not unitAnimCfg[udid] then
				unitAnimCfg[udid] = {}
			end
			if not unitAnimCfg[udid][ac.attempt] then
				unitAnimCfg[udid][ac.attempt] = {}
			end
			unitAnimCfg[udid][ac.attempt][1], unitAnimCfg[udid][ac.attempt][2], unitAnimCfg[udid][ac.attempt][3], unitAnimCfg[udid][ac.attempt][4] = top, left, bottom, right
		end
		--local top,left,bottom,right = DetectBoundings()

		if not top then
			autoConfigs[udid].offset = { autoConfigs[udid].offset[1], autoConfigs[udid].offset[2] - 10, 0 }
			--Spring.Echo(UnitDefs[udid].name .. ": empty model")
			return false, 0, 0, 1, 1
		end

		local ac = autoConfigs[udid]
		local uc = unitConfigs[udid]
		ac.attempt = (ac.attempt or (1 / 0.99)) * 0.99
		return CheckBoundings(udid, top, left, bottom, right, ac.scale, round(uc.border * (iconX + iconY) * 0.5))
	end

	--------------------------------------------------------------------------------
	--------------------------------------------------------------------------------

	local jobs = {}
	local jobsInSynced = 0

	local function ProcessJobs()
		--//note: we have a LIFO stack
		for i = #jobs, 1, -1 do
			if jobs[i]() ~= false then
				jobs[i] = nil
			else
				break
			end
		end

		if #jobs == 0 then
			gadget.DrawGenesis = nil
			gadgetHandler:UpdateCallIn("DrawGenesis")
		end
	end

	--function gadget:DrawGenesis()
	--	ProcessJobs()
	--end

	local function GetFaction(unitdef)
		local name = unitdef.name
		if string.find(name, "_scav") then
			return 'scav'
		elseif string.sub(name, 1, 3) == "arm" then
			return 'arm'
		elseif string.sub(name, 1, 3) == "cor" then
			return 'cor'
		elseif string.sub(name, 1, 3) == "leg" then
			return 'legion'
		elseif string.find(name, 'raptor') then
			return 'raptor'
		end
		return 'unknown'
	end

	local function CreateIcon(udid, uid)
		local faction = GetFaction(UnitDefs[udid])

		local cfg = unitConfigs[udid]

		local attempts = 0
		local result
		local left, bottom = 0, 0
		local width, height = 0, 0

		if (not cfg.empty) then
			repeat
				myGLClear()

				gl.Color(factionColors(faction))

				gl.UseShader(pre_shader)
				gl.ActiveFBO(fbo, DrawIcon, udid, factionTeams[faction], uid)
				gl.UseShader(post_shader)
				gl.ActiveFBO(post_fbo, DrawIconPost)
				gl.UseShader(0)

				gl.Flush()
				gl.ActiveFBO(post_fbo, GL_READ_FRAMEBUFFER_EXT, function()
					result, left, bottom, width, height = CenterIcon(udid)
				end)

				attempts = attempts + 1
			until (result or (attempts >= cfg.attempts))
		else
			myGLClear()
		end

		--// take screenshot
		gl.ActiveFBO(final_fbo, true, function()

			gl.Clear(GL.COLOR_BUFFER_BIT, 0, 0, 0, 0)
			gl.Color(1, 1, 1, 1)
			if (background) then
				Background(udid)
			end

			if (halo) then
				gl.UseShader(halo_shader)
				gl.Blending("add")
				gl.BlendEquationSeparate(0x8006, 0x8008)
				gl.BlendFuncSeparate(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA, GL.ONE, GL.ONE)
				gl.Texture(2, depth_tex)
				gl.TexRect(-1, -1, 1, 1,
					left / (renderX), bottom / (renderY),
					(left + width) / (renderX), (bottom + height) / (renderY))
				gl.Texture(2, false)
				gl.BlendEquationSeparate(0x8006, 0x8006)
				gl.BlendFuncSeparate(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA, GL.ONE, GL.ZERO)
				gl.UseShader(0)
			end

			gl.Blending("reset")
			gl.Texture(post_tex)
			gl.TexRect(-1, -1, 1, 1,
				left / (renderX), bottom / (renderY),
				(left + width) / (renderX), (bottom + height) / (renderY))
			--if renderOverlay then
			--  Overlay(udid)	-- draw water drop if water unit
			--end

			gl.Blending(false)
			gl.Texture(false)

			local outfile = (outdir) .. "/" .. (UnitDefs[udid].name)
			if cfg.frame ~= nil then
				outfile = outfile .. '_' .. cfg.frame
			end
			outfile = outfile .. (imageExt)

			--if (VFS.FileExists(outfile, VFS.RAW)) then
			--  os.remove(outfile)
			--end

			gl.SaveImage(0, 0, iconX, iconY, outfile, { alpha = true })
		end)

		if (not result and not cfg.empty) then
			Spring.Log(gadget:GetInfo().name, LOG.ERROR, "icongen: " .. (UnitDefs[udid].name) .. ": give up :<")
		end
	end

	local function AddUnitJob(udid, angle, frame)

		--// generate unit icon settings (and merge defaults)
		local cfg = unitConfigs[udid] or {}
		autoConfigs[udid] = {}
		local auto = autoConfigs[udid]
		setmetatable(auto, { __index = defaults })
		setmetatable(cfg, { __index = auto })

		if angle then
			unitConfigs[udid].rotation = angle
		end
		if frame then
			unitConfigs[udid].frame = frame
		end

		if (cfg.unfold) then
			--// unit does some unfolding/animation in cob,
			--// so we need to create it first

			jobsInSynced = jobsInSynced + 1

			local factionTeam = factionTeams[GetFaction(UnitDefs[udid] or {})]

			local msg = "buildicon " ..
				UnitDefs[udid].name .. ";" ..
				((cfg.attack and "1") or "0") .. ";" ..
				((cfg.move and "1") or "0") .. ";" ..
				factionTeam .. ";" ..
				(cfg.wait) .. ";" ..
				(cfg.shotangle or "0") .. ";"

			Spring.SendLuaRulesMsg(msg)
			return
		end

		CreateIcon(udid)
	end

	local function AddJob(fnc)
		jobs[#jobs + 1] = fnc
	end

	local function WaitForSyncedJobs()
		return (jobsInSynced == 0)
	end

	---------------------------------------------------------------------------------
	---------------------------------------------------------------------------------

	local schemes, resolutions, ratios = {}, {}, {}

	local function BuildIcon(cmd, line, words, playerID)
		if (not Spring.IsCheatingEnabled()) then
			Spring.Echo("Cheating must be enabled")
			return false
		end
		--if (not Spring.GetModUICtrl()) then
		--  Spring.Echo("ModUICtrl is needed (type /luamoduictrl 1)")
		--  return false
		--end
		if (final_tex or #jobs > 0) then
			Spring.Echo("Wait until current process is finished")
			return false
		end

		if (words[1] and words[1] ~= "all" and not UnitDefNames[words[1]]) then
			Spring.Echo("No such unit found")
			return false
		end

		--//note: we have a LIFO stack
		for _, res in pairs(resolutions) do
			for _, _scheme in pairs(schemes) do
				for _ratio_name, _ratio in pairs(ratios) do


					AddJob(FreeResources)

					AddJob(WaitForSyncedJobs)
					if words[1] and words[1] ~= "all" then
						AddJob(function()
							AddUnitJob(UnitDefNames[words[1]].id, words[2], words[3])
						end)
						Spring.Echo('buildicon: ' .. words[1] .. '  ' .. (words[3] or ''))
					else
						for udid = #UnitDefs, 1, -1 do
							AddJob(function()
								AddUnitJob(udid)
							end)
						end
					end

					AddJob(CreateResources)

					AddJob(function()
						scheme = _scheme
						ratio, ratio_name = _ratio, _ratio_name
						iconX, iconY = res[1], res[2]

						outdir = "buildicons/" .. (scheme) .. "_" .. (ratio_name) .. "_" .. (iconX) .. "x" .. (iconY)
						Spring.CreateDir(outdir)

						if words[3] then
							-- if animation
							outdir = "buildicons/" .. (scheme) .. "_" .. (ratio_name) .. "_" .. (iconX) .. "x" .. (iconY) .. '/' .. words[1]
							Spring.CreateDir(outdir)
						end

						LoadScheme()
					end)
				end
			end
		end

		gadget.DrawGenesis = ProcessJobs
		gadgetHandler:UpdateCallIn("DrawGenesis")
	end

	local function UnitCreated(_, uid, defname)
		jobsInSynced = jobsInSynced - 1

		local uid, defname = uid, defname
		jobs[#jobs + 1] = function()
			CreateIcon(UnitDefNames[defname].id, uid)
		end

		gadget.DrawGenesis = ProcessJobs
		gadgetHandler:UpdateCallIn("DrawGenesis")
	end

	function gadget:Initialize()
		--// get all known configurations
		schemes, resolutions, ratios = include("LuaRules/Configs/", "icon_generator.lua", { info = true })

		gadgetHandler:AddChatAction("buildicon", BuildIcon, " : auto generates creates buildicons")
		gadgetHandler:AddChatAction("buildicons", BuildIcon, " : auto generates creates buildicons")
		gadgetHandler:AddSyncAction("buildicon_unitcreated", UnitCreated)
	end

	---------------------------------------------------------------------------------
	---------------------------------------------------------------------------------
end
