-- $Id$
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local GADGET_DIR = "LuaRules/Configs/"

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local pieceDLs = {}

local function UnitCreated(unitID, material, materialID)
  local pieceMap = Spring.GetUnitPieceMap(unitID)
  local flagPieces = {"gbrflag", "gerflag", "usflag", "rusflag"}

  for i=1,#flagPieces do
    local pieceID = pieceMap[ flagPieces[i] ]
    if (pieceID) then
      local dl = pieceDLs[i]
      if (not dl) then
        dl = gl.CreateList(function()
          gl.MultiTexCoord(4,100)
          gl.UnitPiece(unitID, pieceID)
          gl.MultiTexCoord(4,0)
        end)
        pieceDLs[i] = dl
      end
      Spring.UnitRendering.SetPieceList(unitID,materialID,pieceID,dl)
    end
  end
end


local function DrawUnit(unitID, material)
  gl.Uniform(material.frameLoc, (Spring.GetGameFrame() + Spring.GetFrameTimeOffset())/10)

  --// engine should still draw it (we just set the uniforms for the shader)
  return false
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local materials = {
   flagShader = {
      shaderDefinitions = {
	"#define use_perspective_correct_shadows",
        "#define use_normalmapping",
      },
      shaderPlugins = {
        VERTEX_GLOBAL_NAMESPACE = [[
          uniform float frame2;
        ]],
        VERTEX_PRE_TRANSFORM = [[
          if (gl_MultiTexCoord4.x > 10.0) {
            float a;
            vec3 n = vec3(0.0);

	    a = (vertex.x * 0.5 + frame2);
	    vertex.z += 1.35 * sin(a) * max(vertex.x, -1.0);
            n += vec3(-1.0, 0.0, cos(a)) * max(vertex.x, -1.0) / sqrt(1.0+cos(a)*cos(a));

	    a = (vertex.x * 0.5 + frame2 + vertex.y * 0.5);
	    vertex.z += 0.2 * sin(a) * max(vertex.x, -1.0);
            n += vec3(-1.0, 0.0, cos(a)) * 0.13 * max(vertex.x, -1.0) / sqrt(1.0+cos(a)*cos(a));

	    a = (vertex.x * 0.5 + frame2 - 0.33);
	    vertex.y += 0.8 * sin(a) * max(vertex.x, -1.0);
            n += vec3(0.0, cos(a), -1.0) * 0.8 * max(vertex.x, -1.0) / sqrt(1.0+cos(a)*cos(a));

            normal = normalize(mix(normal,n,0.65));
          }
        ]],
      },
      shader    = include(GADGET_DIR .. "UnitMaterials/Shaders/default.lua"),
      force     = true,
      usecamera = false,
      culling   = GL.BACK,
      texunits  = {
        [0] = '%%UNITDEFID:0',
        [1] = '%%UNITDEFID:1',
        [2] = '$shadow',
        [3] = '$specular',
        [4] = '$reflection',
        [5] = 'unittextures/Flags_normals.dds',
      },
      UnitCreated = UnitCreated,
      DrawUnit = DrawUnit,
   },
}



--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- affected unitdefs

local unitMaterials = {}

unitMaterials.flag = {
	"flagShader",
}

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

return materials, unitMaterials

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
