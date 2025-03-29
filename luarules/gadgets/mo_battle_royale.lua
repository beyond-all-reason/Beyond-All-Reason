local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name		= "Battle Royale",
		desc		= "Implements a shrinking cylinder of death with configurable rate that destroys all units",
		author		= "Beherith",
		date		= "20210827",
		license		= "GNU GPL, v2 or later",
		layer		= 0,
		enabled		= false	--	still WIP
	}
end


--[[
  {
		key    = "battle_royale_starttime",
		name   = "Battle Royale Start Time",
		desc   = "Map starts to shrink at this time (minutes)",
		type   = "number",
		def    = 0.1,
		section= "options",
	},

	 {
	 	key    = 'battle_royale_shrinktime',
	 	name   = 'Battle Royale Shrink Time',
	 	desc   = 'The time it takes (in minutes) to shrink from the edges, to the center of the map.',
	 	type   = 'number',
	 	def    = 2,
	 	section= 'options',
	 },
]]--
-- in minutes
local starttime = tonumber(Spring.GetModOptions().battle_royale_starttime) or -1

-- in minutes, hopefully never less than the commander's walk rate
local shrinktime =tonumber(Spring.GetModOptions().battle_royale_shrinktime) or 5

if (starttime <= 0) then
	return false
end

local startframe = starttime * 60 * 30
local radiussquared = math.pow(Game.mapSizeX * 0.5 , 2) + math.pow(Game.mapSizeZ * 0.5 , 2)
local radius = math.sqrt(radiussquared)
local startradius = radius
local shrinkrate = radius / (shrinktime * 60 * 30)
local mapCenterX = Game.mapSizeX * 0.5
local mapCenterZ = Game.mapSizeZ * 0.5

if gadgetHandler:IsSyncedCode() then
  local function distsqrgreater (a,b,threshold)
    return (a * a + b * b) > threshold
  end

  local function BattleRoyaleDebug()
      Spring.Echo("Battle Royale reset to", startradius/2)
      radius = startradius/2
  end

  function gadget:Initialize()
		gadgetHandler:AddChatAction('battleroyaledebug', BattleRoyaleDebug )
  end

	function gadget:Shutdown()
		gadgetHandler:RemoveChatAction('battleroyaledebug')
	end

  function gadget:GameFrame(gameFrame)
    if gameFrame < startframe then return end
    radius = radius - shrinkrate
    radius = math.max(radius,0)
    radiussquared = radius * radius
	if gameFrame % 11 == 0 then
		local allunits = Spring.GetAllUnits()
		local numdestroyed = 0
		for _,unitID in ipairs(allunits) do
			local ux,uy,uz = Spring.GetUnitPosition(unitID)
			if ux and distsqrgreater(ux - mapCenterX, uz - mapCenterZ, radiussquared) then
			  --Spring.DestroyUnit(unitID, true, false)
			  numdestroyed = numdestroyed + 1
			end
		end
		--Spring.Echo("BattleRoyale radius =", radius, "destroyed", numdestroyed)
	end
    SendToUnsynced("BattleRoyaleRadius", radius)
	end

	function gadget:GameOver()
		gadgetHandler:RemoveGadget(self)
	end


else
	-------------------------
	--    UNSYNCED CODE    --
	-------------------------
  local luaShaderDir = "LuaUI/Include/"
  local LuaShader = VFS.Include(luaShaderDir.."LuaShader.lua")
  VFS.Include(luaShaderDir.."instancevbotable.lua")

  local circleSegments = 1024
  local circleShader = nil
  local circleInstanceVBO = nil

  local minY, maxY
  local hextexture = "LuaUI/Images/hexgrid.tga"

  local function goodbye(reason)
    Spring.Echo("Ground Circle GL4 widget exiting with reason: "..reason)
    if circleShader then circleShader:Finalize() end
  end

  local vsSrc = [[
  #version 420
  #line 10000
  //__DEFINES__
  layout (location = 0) in vec4 circlepointposition; // points of the circle
  layout (location = 1) in vec4 posrad; // per-instance parameters
  layout (location = 2) in vec4 color;  // per-instance
  uniform vec4 circleuniforms; // none yet

  uniform sampler2D hexTex;
  out DataVS {
    vec4 worldPos; // pos and radius
    vec4 blendedcolor;
    float worldscale_circumference;
  };
  //__ENGINEUNIFORMBUFFERDEFS__
  #line 11000
  float heightAtWorldPos(vec2 w){
    vec2 uvhm =   vec2(clamp(w.x,8.0,mapSize.x-8.0),clamp(w.y,8.0, mapSize.y-8.0))/ mapSize.xy;
    return textureLod(heightmapTex, uvhm, 0.0).x;
  }
  void main() {
    vec4 circleWorldPos = posrad;
    circleWorldPos.xz = circlepointposition.xz * circleWorldPos.w +  circleWorldPos.xz;

    // get heightmap
    if (circlepointposition.y > 0)
       circleWorldPos.y = circleuniforms.x;
    else
      circleWorldPos.y = circleuniforms.y;


    // -- MAP OUT OF BOUNDS
    vec2 mymin = min(circleWorldPos.xz,mapSize.xy - circleWorldPos.xz);
    float inboundsness = min(mymin.x, mymin.y);

    // dump to FS
    worldscale_circumference = (posrad.w) * (circlepointposition.w-0.5) * 0.62831853;
    worldPos = circleWorldPos;
    blendedcolor = color;
    blendedcolor.a *= 1.0 - clamp(inboundsness*(-0.03),0.0,1.0);
    gl_Position = cameraViewProj * vec4(circleWorldPos.xyz, 1.0);
  }
  ]]

  local fsSrc =  [[
  #version 330
  #extension GL_ARB_uniform_buffer_object : require
  #extension GL_ARB_shading_language_420pack: require
  #line 20000
  uniform vec4 circleuniforms;
  uniform sampler2D heightmapTex;
  uniform sampler2D hexTex;
  //__ENGINEUNIFORMBUFFERDEFS__
  //__DEFINES__
  in DataVS {
    vec4 worldPos; // w = range
    vec4 blendedcolor;
    float worldscale_circumference;
  };
  out vec4 fragColor;
  void main() {
    vec2 UV;
    UV.y = ((worldPos.y - circleuniforms.x)) / 64.0 ;
    UV.x = worldscale_circumference /(  8 );// (2.0*3.141592));
    vec4 hex = texture2D(hexTex, UV);

    fragColor.rgba = blendedcolor.rgba;

    fragColor.rgb = hex.rgb;
    // out color
    vec4 wallcolor = vec4(0.0);
    // Dark Blue matrix
    wallcolor = mix(wallcolor, vec4(0.1, 0.3, 0.9, 0.5), hex.r);

    // light blue edges
    wallcolor = mix(wallcolor, vec4(0.2, 0.6, 1.0, 1.0), hex.b);

    // pulsing effect for the alpha glow channel:
    float timemod = 0.1 + 10 * max(0.0,(sin(0.1*(worldscale_circumference+ worldPos.y*0.1) + (timeInfo.x + timeInfo.w) *0.02)-0.9));
    wallcolor += mix(wallcolor, vec4(0.5, 1.0, 1.0, 1.0), (1.0 - hex.a) * timemod);
    fragColor.rgba = wallcolor;
    fragColor.a *= blendedcolor.a;

  }
  ]]

  local function initgl4()
    local engineUniformBufferDefs = LuaShader.GetEngineUniformBufferDefs()
    vsSrc = vsSrc:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineUniformBufferDefs)
    fsSrc = fsSrc:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineUniformBufferDefs)
    circleShader =  LuaShader(
    {
      vertex = vsSrc:gsub("//__DEFINES__", "#define MYGRAVITY " .. tostring(Game.gravity+0.1)),
      fragment = fsSrc:gsub("//__DEFINES__", "#define USE_STIPPLE ".. tostring(0) ),
      --geometry = gsSrc, no geom shader for now
      uniformInt = {
        hexTex = 0,
      },
      uniformFloat = {
        circleuniforms = {1,1,1,1}, -- unused
      },
    },
    "ground circles shader GL4"
    )
    shaderCompiled = circleShader:Initialize()
    if not shaderCompiled then goodbye("Failed to compile circleShader GL4 ") end
    local circleVBO,numVertices = makeCylinderVBO(circleSegments)
    local circleInstanceVBOLayout = {
        {id = 1, name = 'posrad', size = 4}, -- the start pos + radius
        {id = 2, name = 'color', size = 4}, --- color
      }
    circleInstanceVBO = makeInstanceVBOTable(circleInstanceVBOLayout,32, "groundcirclevbo")
    circleInstanceVBO.numVertices = numVertices
    circleInstanceVBO.vertexVBO = circleVBO
    circleInstanceVBO.VAO = makeVAOandAttach(circleInstanceVBO.vertexVBO,       circleInstanceVBO.instanceVBO)
  end

  local battleroyaleradius = -1
	local function BattleRoyaleRadius(_, radius)
    if battleroyaleradius == -1 then
      Spring.SendMessage("Battle Royale has begun, you have ".. tostring(shrinktime) .. " minutes left")
    end
    battleroyaleradius = radius
    pushElementInstance(circleInstanceVBO,
        {Game.mapSizeX/2, 0, Game.mapSizeZ/2, battleroyaleradius,
        1.0,0.0,0.0, 1.0,
        },
        0,  -- key is gonna be zero for my dummy face
        true -- overwrite
      )
	end

  local function BattleRoyaleDebug()
  end

  function gadget:Initialize()
    minY, maxY = Spring.GetGroundExtremes ( )
		gadgetHandler:AddSyncAction("BattleRoyaleRadius", BattleRoyaleRadius)
    initgl4()
  end

	function gadget:Shutdown()
  end

  function gadget:DrawWorld()
    if circleInstanceVBO.usedElements > 0 then
      gl.DepthMask(false) --"BK OpenGL state resets", default is already false, could remove
      gl.DepthTest(true)
      gl.AlphaTest(GL.GREATER, 0)
      gl.Blending(GL.SRC_ALPHA, GL.ONE)
      gl.Texture(0,hextexture)
      circleShader:Activate()
      circleShader:SetUniform("circleuniforms", minY, maxY + 32, 1.0, 1.0) -- unused
      circleInstanceVBO.VAO:DrawArrays(GL.TRIANGLES, circleInstanceVBO.numVertices, 0, circleInstanceVBO.usedElements, 0)
      circleShader:Deactivate()
      gl.Texture(0, false)
      gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
      gl.AlphaTest(false)
      gl.DepthTest(false)
      --gl.DepthMask(false)  --"BK OpenGL state resets", already set as false
    end
  end

end
