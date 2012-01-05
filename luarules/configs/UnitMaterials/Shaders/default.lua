return {
  vertex = [[
//#define use_normalmapping
//#define flip_normalmap
//#define use_shadows

    %%VERTEX_GLOBAL_NAMESPACE%%

    uniform mat4 camera;   //ViewMatrix (gl_ModelViewMatrix is ModelMatrix!)
    //uniform mat4 cameraInv;
    uniform vec3 cameraPos;
    uniform vec3 sunPos;
    uniform vec3 sunDiffuse;
    uniform vec3 sunAmbient;
	//uniform float frameLoc;
  #ifdef use_shadows
    uniform mat4 shadowMatrix;
    varying vec4 shadowpos;
    #ifndef use_perspective_correct_shadows
      uniform vec4 shadowParams;
    #endif
  #endif

    varying vec3 cameraDir;
    varying vec3 teamColor;
    //varying float fogFactor;

  #ifdef use_normalmapping
    varying vec3 t;
    varying vec3 b;
    varying vec3 n;
  #else
    varying vec3 normalv;
  #endif

    void main(void)
    {
      vec4 vertex = gl_Vertex;
      vec3 normal = gl_Normal;
	 // vertex.xyz+=normal*40*frameLoc;

      %%VERTEX_PRE_TRANSFORM%%

    #ifdef use_normalmapping
      vec3 tangent   = gl_MultiTexCoord5.xyz;
      vec3 bitangent = gl_MultiTexCoord6.xyz;
      t = gl_NormalMatrix * tangent;
      b = gl_NormalMatrix * bitangent;
      n = gl_NormalMatrix * normal;
    #else
      normalv = gl_NormalMatrix * normal;
    #endif

      vec4 worldPos = gl_ModelViewMatrix * vertex;
      gl_Position   = gl_ProjectionMatrix * (camera * worldPos);
      cameraDir     = worldPos.xyz - cameraPos;

    #ifdef use_shadows
      shadowpos = shadowMatrix * worldPos;
      #ifndef use_perspective_correct_shadows
        shadowpos.st = shadowpos.st * (inversesqrt(abs(shadowpos.st) + shadowParams.z) + shadowParams.w) + shadowParams.xy;
      #endif
    #endif

      gl_TexCoord[0].st = gl_MultiTexCoord0.st;
      teamColor = gl_TextureEnvColor[0].rgb;

      //float fogCoord = length(gl_Position.xyz);
      //fogFactor = (gl_Fog.end - fogCoord) * gl_Fog.scale; //gl_Fog.scale := 1.0 / (gl_Fog.end - gl_Fog.start)
      //fogFactor = clamp(fogFactor, 0.0, 1.0);

      %%VERTEX_POST_TRANSFORM%%
    }
  ]],
  fragment = [[
//#define use_normalmapping
//#define flip_normalmap
//#define use_shadows

    %%FRAGMENT_GLOBAL_NAMESPACE%%

    uniform sampler2D textureS3o1;
    uniform sampler2D textureS3o2;
    uniform samplerCube specularTex;
    uniform samplerCube reflectTex;

    uniform vec3 sunPos; // is sunDir!
    uniform vec3 sunDiffuse;
    uniform vec3 sunAmbient;
	uniform float frameLoc;
	uniform float healthLoc;

  #ifdef use_shadows
    #ifdef use_perspective_correct_shadows
      uniform vec4 shadowParams;
    #endif
    varying vec4 shadowpos;
    uniform sampler2DShadow shadowTex;
    uniform float shadowDensity;
  #endif

    varying vec3 teamColor;
    varying vec3 cameraDir;
    //varying float fogFactor;

  #ifdef use_normalmapping
    varying vec3 t;
    varying vec3 b;
    varying vec3 n;
    uniform sampler2D normalMap;
  #else
    varying vec3 normalv;
  #endif

    void main(void)
    {
       %%FRAGMENT_PRE_SHADING%%

    #ifdef use_normalmapping
       vec2 tc = gl_TexCoord[0].st;
      #ifdef flip_normalmap
         tc.t = 1.0 - tc.t;
      #endif
	   vec4 normaltex=texture2D(normalMap, tc);
       vec3 nvTS   = normalize(normaltex.xyz - 0.5);
       vec3 normal = normalize(mat3(t,b,n)  * nvTS);
    #else
       vec3 normal = normalize(normalv);
    #endif
       float a    = max( dot(normal, sunPos), 0.0);
       vec3 light = a * sunDiffuse + sunAmbient;

       vec4 extraColor  = texture2D(textureS3o2, gl_TexCoord[0].st);

       vec3 reflectDir = reflect(cameraDir, normal);
       vec3 specular   = textureCube(specularTex, reflectDir).rgb * extraColor.b * 4.0;
       vec3 reflection = textureCube(reflectTex,  reflectDir).rgb;

    #ifdef use_shadows
       vec4 shadowTC = shadowpos;
      #ifdef use_perspective_correct_shadows
       shadowTC.st = shadowTC.st * (inversesqrt( abs(shadowTC.st) + shadowParams.z) + shadowParams.w) + shadowParams.xy;
      #endif
       float shadow = shadow2DProj(shadowTex, shadowTC).r;
       shadow    = 1.0 - (1.0 - shadow) * shadowDensity;
       light     = mix(sunAmbient, light, shadow);
       specular *= shadow;
    #endif

       reflection  = mix(light, reflection, extraColor.g); // reflection
       reflection += extraColor.rrr*frameLoc; // self-illum

       gl_FragColor     = texture2D(textureS3o1, gl_TexCoord[0].st);
       gl_FragColor.rgb = mix(gl_FragColor.rgb, teamColor.rgb, gl_FragColor.a); // teamcolor
       gl_FragColor.rgb = gl_FragColor.rgb * reflection + specular;
       gl_FragColor.a   = extraColor.a;
	   gl_FragColor.rgb = gl_FragColor.rgb +gl_FragColor.rgb*(normaltex.a-0.5)*healthLoc;
       //gl_FragColor.rgb = mix(gl_Fog.color.rgb, gl_FragColor.rgb, fogFactor); // fog
       //gl_FragColor.a = teamColor.a; // far fading
       //gl_FragColor.rgb = normal;
		//gl_FragColor.g=frameLoc;
       %%FRAGMENT_POST_SHADING%%
    }
  ]],
  uniformInt = {
    textureS3o1 = 0,
    textureS3o2 = 1,
    shadowTex   = 2,
    specularTex = 3,
    reflectTex  = 4,
    normalMap   = 5,
    --detailMap   = 6,
  },
  uniform = {
    sunPos = {gl.GetSun("pos")},
    sunAmbient = {gl.GetSun("ambient" ,"unit")},
    sunDiffuse = {gl.GetSun("diffuse" ,"unit")},
    shadowDensity = {gl.GetSun("shadowDensity" ,"unit")},
    shadowParams  = {gl.GetShadowMapParams()},
   -- frameLoc  = {math.random()}, --!bingo!
    frameLoc  = {math.sin(Spring.GetGameFrame()/3.0)},
  },
  uniformMatrix = {
    shadowMatrix = {gl.GetMatrixData("shadow")},
  },
}
