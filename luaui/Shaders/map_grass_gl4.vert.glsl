#version 420
#line 10000

// This shader is Copyright (c) 2024 Beherith (mysterme@gmail.com) and licensed under the MIT License


//__DEFINES__
/*
#define MAPCOLORFACTOR 0.4
#define    DARKENBASE 0.5
#define    ALPHATHRESHOLD 0.02
#define    WINDSTRENGTH 1.0
#define    WINDSCALE 0.33
#define    FADESTART 2000
#define    FADEEND 3000
*/

#if COMPACTVBO == 1

  layout (location = 0) in vec4 pos_u;
  layout (location = 1) in vec4 norm_v;

  layout (location = 7) in vec4 instancePosRotSize; //x, rot, z, size
  vec3 vertexPos = pos_u.xyz;
  vec3 vertexNormal = norm_v.xyz;
  vec2 texcoords0 = vec2(pos_u.w, norm_v.w);
#else
  layout (location = 0) in vec3 vertexPos;
  layout (location = 1) in vec3 vertexNormal;
  layout (location = 2) in vec3 stangent;
  layout (location = 3) in vec3 ttangent;
  layout (location = 4) in vec2 texcoords0;
  layout (location = 5) in vec2 texcoords1;
  layout (location = 6) in float pieceindex;
  layout (location = 7) in vec4 instancePosRotSize; //x, rot, z, size
#endif

uniform vec4 grassuniforms; //windx, windz, 0, globalalpha
uniform float distanceMult; //yes this is the additional distance multiplier

uniform sampler2D grassBladeColorTex;

uniform sampler2D mapGrassColorModTex;
uniform sampler2D grassWindPerturbTex;
uniform sampler2DShadow shadowTex;
uniform sampler2D losTex;
uniform sampler2D heightmapTex;

out DataVS {
	//vec3 worldPos;
  //vec3 Normal;
  vec4 texCoord0;
  //vec3 Tangent;
  //vec3 Bitangent;
  vec4 mapColor; //alpha contains fog factor
  //vec4 grassNoise;
  vec4 instanceParamsVS; // x is distance from camera
  
	#if DEBUG == 1 
    vec4 debuginfo;
  #endif
};

//__ENGINEUNIFORMBUFFERDEFS__

#line 10770

// pre vs opt pure vs load is 182 -> 155 fps
void main() {
  // Early bail visibility culling, if instancePosRotSize.xyz is not in camera frustum, skip it:

  vec4 worldPos = vec4(instancePosRotSize.x, 0.0, instancePosRotSize.z, 1.0);
  vec4 clipPos = cameraViewProj * vec4(worldPos.xyz, 1.0);
  if (abs(clipPos.x / clipPos.w) > 1.1) {
    gl_Position = vec4(2.0, 2.0, 2.0, 1.0); // Cull by moving out of clip space
    return;
  }

  vec3 grassVertWorldPos = vertexPos * instancePosRotSize.w; // scale it
  mat3 rotY = rotation3dY(instancePosRotSize.y); // poor mans random rotate

  grassVertWorldPos.xz = (rotY * grassVertWorldPos).xz + instancePosRotSize.xz; // rotate Y and move to world pos
  
	#if DEBUG == 1 
    debuginfo.xyz = rotY*vertexNormal;
  #endif
  //--- Heightmap sampling
  vec2 ts = vec2(textureSize(heightmapTex, 0));
  vec2 uvHM =   vec2(clamp(grassVertWorldPos.x,8.0,mapSize.x-8.0),clamp(grassVertWorldPos.z,8.0, mapSize.y-8.0))/ mapSize.xy; // this proves to be an actually useable heightmap i think.
  grassVertWorldPos.y = (vertexPos.y +0.5) *instancePosRotSize.w + textureLod(heightmapTex, uvHM, 0.0).x;

  //--- LOS tex
  vec4 losTexSample = texture(losTex, vec2(grassVertWorldPos.x / mapSize.z, grassVertWorldPos.z / mapSize.w)); // lostex is PO2
  instanceParamsVS.z = dot(losTexSample.rgb,vec3(0.33));
  instanceParamsVS.z = clamp(instanceParamsVS.z*1.5 , 0.0,1.0);
  //debuginfo = losTexSample;

  //--- SHADOWS ---
  float shadow = 1.0;

  #ifdef HASSHADOWS
    #define SHADOWOFFSET 4.0
    vec4 shadowVertexPos;
    shadowVertexPos = shadowView * vec4(grassVertWorldPos+ vec3(SHADOWOFFSET, 0.0, SHADOWOFFSET),1.0);
    shadowVertexPos.xy += vec2(0.5);
    shadow += clamp(textureProj(shadowTex, shadowVertexPos), SHADOWFACTOR, 1.0);
    shadowVertexPos = shadowView * vec4(grassVertWorldPos+ vec3(-SHADOWOFFSET, 0.0, -SHADOWOFFSET),1.0);
    shadowVertexPos.xy += vec2(0.5);
    shadow += clamp(textureProj(shadowTex, shadowVertexPos), SHADOWFACTOR, 1.0);
    shadowVertexPos = shadowView * vec4(grassVertWorldPos+ vec3(-SHADOWOFFSET, 0.0, SHADOWOFFSET),1.0);
    shadowVertexPos.xy += vec2(0.5);
    shadow += clamp(textureProj(shadowTex, shadowVertexPos), SHADOWFACTOR, 1.0);
    shadowVertexPos = shadowView * vec4(grassVertWorldPos+ vec3(SHADOWOFFSET, 0.0, -SHADOWOFFSET),1.0);
    shadowVertexPos.xy += vec2(0.5);
    shadow += clamp(textureProj(shadowTex, shadowVertexPos), SHADOWFACTOR, 1.0);
    shadow = shadow*0.2;
  #endif

  instanceParamsVS.y = clamp(shadow,SHADOWFACTOR,1.0);

  //--- MAP COLOR BLENDING
  mapColor = texture(mapGrassColorModTex, vec2(grassVertWorldPos.x / mapSize.x, grassVertWorldPos.z / mapSize.y)); // sample minimap

  //--- WIND NOISE
  //Sample wind noise texture depending on wind speed and scale:
  vec4 grassNoise = texture(grassWindPerturbTex, vec2(grassVertWorldPos.xz + grassuniforms.xy*WINDSCALE) * WINDSAMPLESCALE);

  //Adjust the sampled grass noise:
  grassNoise = (grassNoise - 0.5 ).xzyw; //scale and swizzle normals

  //Shade the patches to be darker when 'flattened' by noise
  float shadeamount = grassNoise.y *2.0; //0-1
  shadeamount = (shadeamount -0.66) *3.0;
  grassNoise.y *2.0;


  grassNoise.y = grassNoise.y -0.4;

  instanceParamsVS.w = mix(vec3(0.0,1.0,0.0),vec3(0.0,shadeamount,0.0), texcoords0.y).y;

  grassVertWorldPos = grassVertWorldPos.xyz +  grassNoise.rgb * vertexPos.y * instancePosRotSize.w * WINDSTRENGTH * grassuniforms.z; // wind is a factor of


  //--- FOG ----

  float fogDist = length((cameraView * vec4(grassVertWorldPos,1.0)).xyz);
  float fogFactor = (fogParams.y - fogDist) * fogParams.w;
  mapColor.a = smoothstep(0.0,1.0,fogFactor);
  mapColor.a = 1.0; // DEBUG FOR NOW AS FOG IS BORKED

  //--- DISTANCE FADE ---
  vec4 camPos = cameraViewInv[3];
  float distToCam = length(grassVertWorldPos.xyz - camPos.xyz); //dist from cam
  instanceParamsVS.x = clamp((FADEEND * distanceMult - distToCam)/(FADEEND * distanceMult - FADESTART * distanceMult),0.0,1.0);


  //--- ALPHA CULLING BASED ON QUAD NORMAL
  texCoord0.w  = dot(rotY*vertexNormal, normalize(camPos.xyz - grassVertWorldPos.xyz));

  // ------------ dump the stuff for FS --------------------
  texCoord0.xy = texcoords0.xy;
  //Normal = rotY * vertexNormal;
  //Tangent = rotY * ttangent;
  gl_Position = cameraViewProj * vec4(grassVertWorldPos.xyz, 1.0);

}