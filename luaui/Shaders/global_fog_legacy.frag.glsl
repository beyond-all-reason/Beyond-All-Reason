
/*	
	// compilation helpers
	float collectedShadow = 0;
	
	float collectedNoise = 0.0;  // total noise we marched through
	
	// TODO: fix warps sampling zero simplex!
	vec2 mymin = min(mapWorldPos.xz,mapSize.xy - mapWorldPos.xz);
	float outofboundsness = min(mymin.x, mymin.y); 
	float inlos = 0;
	vec4 densityposition = vec4(0);
	
	float heightFogTopInv = 1.0 / heightFogTop; 
	
	#if (USELOS == 1)
		inlos = losLevelAtWorldPos( mapWorldPos.xyz);
		bool outofmap = any(lessThan(vec4(mapWorldPos.xz, mapSize.xy),  vec4(0.0, 0.0, mapWorldPos.xz)));
		if (outofmap) inlos = 0;
	#endif 
	
	fragColor.rgba = vec4(fract(rayStart*0.01),1.0);
	//return;
	
	#if (RAYTRACING == 0)
		// With raytracing off, we have a bit more freedom in the height-based fog.
		collectedShadow = 1.0;
		
		// Modulate the noise based on its depth below fogplane, this is 1 at 0 height, and 0 at heightFogTop
		float rayStartDepthRatio = 1.0 - rayStart.y * heightFogTopInv;
		rayStartDepthRatio = clamp(rayStartDepthRatio * HEIGHTDENSITY, 0, 1);
		
		float rayEndDepthRatio = 1.0 - rayEnd.y * heightFogTopInv;
		rayEndDepthRatio = clamp(rayEndDepthRatio * HEIGHTDENSITY, 0, 1);
		
		float rayDepthratio = (rayStartDepthRatio + rayEndDepthRatio) * 0.5;
		
		
		// Fog reaches full density at half depth to waterplane
		heightBasedFog *= rayDepthratio;
		
	#else
		#if 0
		// Always marching from most distant point to closest point
		// =============== For quad message passing: =====================

		
		//fragColor.rgba = vec4(threadMask.rgb,1.0); return;
		//fragColor.rgba = vec4(quadVector.ryx,1.0); return;
		
		mat4 smoothThreadMatrix = quadGetThreadMatrix(0.6);
		
		// This weights own pixels more then neighbours, by a tiny bit.
		float sf = 0.75;//sin(timeInfo.z*0.01) * 0.0;
		//vec4 selfweight = vec4(0.25) + vec4(sf, -sf/3,-sf/3,-sf/3);
		// ==============   End Quad Message Passing ====================
		
		vec4 blueNoiseSample = textureLod(blueNoise64,gl_FragCoord.xy/64, 0);
		float noiseValues[CLOUDSTEPS+1];
		vec4 shadedFogColor = vec4(0);
		noiseValues[0] = 1;
		
		const float stepsInv = 1.0 / HEIGHTSHADOWSTEPS;

		//vec3 noiseOffset = vec3(0, - time*4, 0) * NOISESCALE1024 * WINDSTRENGTH * 0.3;
		float rayJitterOffset = 0;
		
		//manually set packedNoiseLod
		packedNoiseLod = floor(lengthMapFromCam * 0.00003 * noiseLFParams.x);
		
		// in-progress blending
		vec4 groundRGBA = vec4(shadowedColor.rgb, 0);
		
		mat3 rot3 = transpose(mat3(vec3(0.3120517, -0.7351478,  0.6018150), 
						 vec3(0.9490337,  0.2116918, -0.2334984),
						 vec3(0.0442566,  0.6440064,  0.7637389)));
						 
		if (rayLength> 0.1 && inlos < 0.99) { 
			#if 1 //newest method with no interleaving to prevent membus hammering
				// First we walk through the noise samples at each position, with a bit of jitter added 
				fragColor.rgb = blueNoiseSample.rgb;

				rayJitterOffset = rand(screenUV + vec2(time) * 0.0000) * 1.0  ;
				vec3 rayStep = (rayEnd - rayStart) / CLOUDSTEPS;
				float stepLength = rayLength/CLOUDSTEPS;
				
				vec4 quadoffsets = vec4(0,0.25,0.5, 0.75) * 1.0; 
				vec3 quadStep = rayStep * dot(threadMask,quadoffsets);
				
				#if (CLOUDSTEPS > 0)
				float noiseJitterOffset = rayJitterOffset * (1.0 / CLOUDSTEPS);
				for (uint ns = 0; ns < CLOUDSTEPS; ns++){
						vec3 rayPos = rayStart + rayStep * (float(ns) + rayJitterOffset*0.00 );
						
						#if 1
							vec3 noisePos = rot3 * rayPos * NOISESCALE1024 * noiseLFParams.x * 1.0 + noiseOffset; // this sure as fuck aint free!
							//vec4 simplexDeriv = vec4(0.0); // no-op
							//vec4 simplexDeriv = SimplexPerlin3D_Deriv(noisePos);
							//vec4 simplexDeriv = FBMNoise3DDeriv(noisePos + FBMNoise3D((noisePos +  noiseOffset) * 1.42) * 2 );
							//vec4 simplexDeriv = vec4(FBMNoise3D(noisePos));
							//vec4 simplexDeriv = vec4(FBMNoise3D(noisePos)) +  vec4(FBMNoise3D(noisePos+1));
							//vec4 simplexDeriv = FBMNoise3DDeriv(noisePos);
							//vec4 simplexDeriv = vec4(FBMNoise3D(noisePos + FBMNoise3D(noisePos * 1.42) * 2 ));
							//vec4 simplexDeriv = vec4(SimplexPerlin3D(noisePos));
							vec4 freqs = vec4(1.1,3.1,5.1,7.1);
							vec4 weights = 1.0/freqs;
							float fastQuadFBM3Dnoise = FBMNoise3D(0.33*noisePos * dot(threadMask, freqs)) * dot(threadMask, weights);
							//vec4 simplexDeriv = vec4(quadGatherWeighted(fastQuadFBM3Dnoise));
							
							float quadSin = sin(dot(vec4(noisePos.xz,noisePos.xz),threadMask) * dot(freqs,threadMask) * 0.01) * 10;
							//vec4 simplexDeriv =  vec4(quadGatherWeighted(quadSin));
							//float quadFBMNoise2D = FBMNoise2D(noisePos.xz * dot(threadMask, freqs)) * 1;
							
							//vec4 simplexDeriv =  vec4(quadGatherSumFloat(FBMNoise2D(rayPos.xz * dot(threadMask, freqs) * 0.002) * 0.3));  
							//vec4 simplexDeriv =  texture(heightmapTex, (rayPos.xz * 0.0002) * 0.01);  
							vec4 simplexDeriv =  texture(uniformNoiseTex, (rayPos.xyz * 0.0002 * noiseHFParams.x)) * (0.01+noiseLFParams.y);  
							//vec4 simplexDeriv =  vec4(FBMNoise2D(rayPos.xz *0.01)) * 0.1;  
							
							//vec4 simplexDeriv = quadFBM(noisePos* noiseLFParams.y, freqs, screenUV, gl_FragCoord.xy*2);
							//simplexDeriv = vec4(0.0);
							fragColor.rgba = vec4(simplexDeriv.rgb, 1.0);
							//return;
							vec3 qfbm = simplexDeriv.rgb;// *noiseLFParams.y;
							fragColor.rgba = vec4(simplexDeriv.rgb,1.0);
							//return ;
							float simplexnoise = simplexDeriv.r;
							//densityposition.xzy += simplexDeriv.yzw;// * simplexDeriv.x;
							//float simplexnoise =  SimplexPerlin3D(rayPos * NOISESCALE1024 * noiseLFParams.x * 1.0 + noiseOffset); // range [-1;1]
							//float simplexnoise =  SimplexPerlin3D(rayPos * NOISESCALE1024 * noiseLFParams.x * 1.0 + noiseOffset); // range [-1;1]
						#endif
						
						#line 35300
						vec4 textureNoise = vec4(qfbm.r); // None
						#if (TEXTURESAMPLER == 1)
							#if (QUADNOISEFETCHING == 0)
								vec3 noiseTexUVW = (rayPos * NOISESCALE1024 * noiseHFParams.x + noiseOffset + qfbm * 1.1);
								textureNoise = getPackedNoise(noiseTexUVW.xyz); 
							#else
								//noiseTexUVW = (rayPos * NOISESCALE1024 * noiseHFParams.x + noiseOffset + qfbm * 0.1);
								vec3 noiseTexUVW = ((rayPos + quadStep) * NOISESCALE1024 * noiseHFParams.x + noiseOffset + qfbm * 1.1);
								textureNoise = getPackedNoise(noiseTexUVW.xyz ); // texture(ttt, Pos + stepsize * dot(threadMask, offsets)).r * dot(threadMask, weights);
								#if 1 // use gathersum
									//vec4 weightedGather = quadGather(textureNoise.r);
									textureNoise.r = quadGatherWeighted(textureNoise.r);
								#endif
								
							#endif 
						#endif
						#if (TEXTURESAMPLER == 2)
							textureNoise = texture(heightmapTex, (noiseTexUVW.xz + noiseTexUVW.z * 0.5)); 
						#endif
						#if (TEXTURESAMPLER == 3)
							textureNoise = texture(noise64cube, noiseTexUVW.xzy); // almost universally the best :'( 
						#endif
						#if (TEXTURESAMPLER == 4)
							textureNoise = vec4(FBMNoise3D(noiseTexUVW.xyz)); 
						#endif
						#if (TEXTURESAMPLER == 5)
							textureNoise = vec4(Value3D(noiseTexUVW.xyz)); 
						#endif
						#if (TEXTURESAMPLER == 6)
							textureNoise = vec4(SimplexPerlin3D(noiseTexUVW.xyz)); 
						#endif
						
						simplexnoise = simplexnoise - noiseLFParams.y;
						
						// Modulate the noise based on its depth below fogplane, this is 1 at 0 height, and 0 at heightFogTop
						float rayDepthratio = clamp((1.0 - rayPos.y * heightFogTopInv) * HEIGHTDENSITY,0,1);
						
						float clampedNoise = clamp( cloudDensity * (textureNoise.r * noiseLFParams.x - noiseLFParams.y) * rayDepthratio * stepLength, 0, 1);
						noiseValues[ns] = clampedNoise;
						float shadeFactor = max(0.0, textureNoise.g -noiseLFParams.y) ;
						vec3 fogShaded = mix(heightFogColor.rgb, shadowedColor.rgb,  rayDepthratio * rayDepthratio* shadeFactor*0 );
						//clampedNoise = step(sin(time * 0.01) * 0.1 + 0.5, clampedNoise);
						fogRGBA.rgb = fogShaded.rgb * clampedNoise + fogRGBA.rgb * (1.0 - clampedNoise);
						fogRGBA.a = clampedNoise + fogRGBA.a * (1.0 - clampedNoise); // the sA*sA term is questionable here!
				}
				#endif
				
	
				#if (HEIGHTSHADOWSTEPS > 0)
					float shadowJitterOffset = rayJitterOffset;
					rayStep = (rayEnd - rayStart) / HEIGHTSHADOWSTEPS;
					float numShadowSamplesTaken = 0;
					for (uint i = 0; i < HEIGHTSHADOWSTEPS; i++){
						uint noiseIndex = (i * CLOUDSTEPS) / HEIGHTSHADOWSTEPS;
						float currentnoise = 1;//noiseValues[noiseIndex];
						if (currentnoise > 0 || 1 == 1){
						//if (currentnoise > 0.01){
							vec3 rayPos = rayStart + rayStep * (float(i) + rayJitterOffset );
							
							float localShadow= shadowAtWorldPos(rayPos); // 1 for lit, 0 for unlit
							
							
							float shadowDelta = 0.25 * (abs(dFdx(localShadow)) + abs(dFdy(localShadow)));
							float rayDepthratio = clamp((1.0 - rayPos.y * heightFogTopInv) * HEIGHTDENSITY,0,1);
							
							localShadow = mix(shadowDelta, 1.0 - shadowDelta, localShadow);
							collectedShadow += max(localShadow, 1.0 - rayDepthratio);
							numShadowSamplesTaken += 1.0;
						}
					}
					collectedShadow = collectedShadow/numShadowSamplesTaken;
				#else
				#endif
				
				#if (CLOUDSHADOWS > 0 && CLOUDSTEPS > 0)
					float cloudstrength  =0; // yes indeedy do
					// adjust rayEnd to point from rayStart to the sun direction!
					// the pos at which the vector in sun dir intercepts fog plane
					// could use a lower res, or a forced lower LOD bias for sampling at speed?
					// TODO: this means we actually have to get back to 3 pass rendering, at the very least :/ 
					 
					float shadowRayStart = shadowAtWorldPos(rayStart + sunDir.xyz * 1);
					
					
					if (mapdepth < 0.9998 && shadowRayStart > -1.75){
						
						
						
						float shadowJitterOffset = rayJitterOffset;
						rayStep = sunDir.xyz * ((heightFogTop - rayStart.y) / sunDir.y) / CLOUDSHADOWS;
						quadStep = rayStep * dot(threadMask,quadoffsets) * NOISESCALE1024 * noiseHFParams.x;
						float stepLength = length(rayStep);
						float numShadowSamplesTaken = 0;
						for (uint i = 0; i < CLOUDSHADOWS; i++){
							vec3 rayPos = rayStart + rayStep * (float(i) + rayJitterOffset *0.00001);
							vec3 noiseTexUVW = (rayPos * NOISESCALE1024 * noiseHFParams.x + noiseOffset + 0.0 * 0.1);
							//vec4 textureNoise = texture(noise64cube, noiseTexUVW.xzy, 1); // give it a hefty LOD bias for speed and clarity
							#if QUADNOISEFETCHING == 0
								vec4 textureNoise = getPackedNoise(noiseTexUVW.xyz);
							#else
								vec4 textureNoise = getPackedNoise(noiseTexUVW.xyz + quadStep * 0.02);  // TODO: give it a hefty LOD bias for speed and clarity
								
							#endif
							
							
							float rayDepthratio = clamp((1.0 - rayPos.y * heightFogTopInv) * HEIGHTDENSITY,0,1);
							
							float clampedTextureNoise = max(0.0, (textureNoise.r - noiseLFParams.y) * (1.0 - noiseLFParams.y));
							cloudstrength += clampedTextureNoise * rayDepthratio;
							
							float clampedNoise = clamp(cloudDensity * (textureNoise.r * noiseLFParams.x - noiseLFParams.y) * rayDepthratio * stepLength, 0, 1);
							groundRGBA.a = clampedNoise + groundRGBA.a * (1.0 - clampedNoise);
							//if (rayPos.y > heightFogTop) groundRGBA.rgba = vec4(1.0);
						}
						
						cloudstrength = cloudstrength/CLOUDSHADOWS;
						//collectedShadow -= cloudstrength *10;
						//heightBasedFog = 10000;
						float shadtest = sin(time * 0.1) * 0.5  + 0.5;
						shadtest = shadowedColor.a;
						groundRGBA.a = clamp(groundRGBA.a,0,1);
						groundRGBA.a = groundRGBA.a  * shadtest;
						groundRGBA.rgb = mix(fogRGBA.rgb, groundRGBA.rgb,  groundRGBA.a);
						//groundRGBA = vec4(shadowedColor.rgb, cloudstrength * 10);
					}
				#endif
				//fogRGBA.a = 0;
				fogRGBA.rgb = fogRGBA.rgb * fogRGBA.a + groundRGBA.rgb * (1.0 - fogRGBA.a);
				fogRGBA.a   = groundRGBA.a * (1.0 - fogRGBA.a) + fogRGBA.a;
				//fogRGBA = vec4( fogRGBA.rgb  + groundRGBA.rgb * (1.0 - fogRGBA.a), groundRGBA.a * (1.0 - fogRGBA.a) + fogRGBA.a);
				//fogRGBA =groundRGBA;
				fragColor.rgba = fogRGBA;
				//fragColor.rgba = groundRGBA;
				return;
				//collectedShadow = 1.0;
				
			#else
				#if 0 // old deprecated method
					float rayJitterOffset = (1 * rand(screenUV)) *  stepsInv;
					#if (HEIGHTSHADOWSTEPS > 0)
					for (uint i = 0; i < HEIGHTSHADOWSTEPS; i++){
						float f = float(i) stepsInv;
						vec3 rayPos = mix(rayStart.xyz, rayEnd, f + rayJitterOffset);
						
						float localShadow= shadowAtWorldPos(rayPos); // 1 for lit, 0 for unlit
						float shadowDelta = 0.25 * (abs(dFdx(localShadow)) + abs(dFdy(localShadow)));
						
						localShadow = mix(shadowDelta, 1.0 - shadowDelta, localShadow);
						collectedShadow += localShadow;
					}
					
					collectedShadow *= stepsInv;
					collectedShadow = collectedShadow * collectedShadow;
					#else
						collectedShadow = 1.0;
					#endif
					#if (CLOUDSTEPS > 0)
						for (uint i = 0; i < (CLOUDSTEPS); i++){
							float f = float(i) / (CLOUDSTEPS);
							vec3 rayPos = mix(rayStart.xyz, rayEnd, f + 0.005 * rayJitterOffset);
						//if (1 == 1){
							vec4 localNoise =  texture(noise64cube, rayPos.xyz * NOISESCALE1024  + noiseOffset); // TODO: SUBSAMPLE THIS ONE!
							
							float simplexnoise = SimplexPerlin3D ((rayPos ) * NOISESCALE1024 * noiseLFParams.x + noiseOffset);

							float thisraynoise = max(0,localNoise.a + noiseLFParams.y - simplexnoise);
							collectedNoise += thisraynoise;
						}
						heightBasedFog *= collectedNoise/(CLOUDSTEPS);
					#endif
					
				#else // new interleaved sampling
					#if ((HEIGHTSHADOWSTEPS > 0) && (CLOUDSTEPS >0))
						float numShadowSamplesTaken = 0.001;
						uint shadowSteps = HEIGHTSHADOWSTEPS / CLOUDSTEPS;
						float rayJitterOffset = (1 * rand(screenUV)) * stepsInv ;
						for (uint n = 0; n < CLOUDSTEPS; n ++){
							float f = float(n) / CLOUDSTEPS;
							
							vec3 rayPos = mix(rayStart.xyz, rayEnd, f + 0.5 * rayJitterOffset);
							
							//vec4 localNoise =  texture(noise64cube, rayPos.xyz * NOISESCALE1024 + noiseOffset); // TODO: SUBSAMPLE THIS ONE!
							vec3 skewed3dpos = (rayPos.xyz * NOISESCALE1024 * noiseHFParams.x + noiseOffset) * vec3(1,4,1);
							float localNoise = 1.0 - texture(noise64cube, skewed3dpos.xzy).r; // TODO: SUBSAMPLE THIS ONE!
							#if 1
								float simplexnoise =  SimplexPerlin3D((rayPos) * NOISESCALE1024 * noiseHFParams.x +
								noiseOffset) * noiseLFParams.y;
							#else // yeah nested perlin is uggo
								float a = 0.001;
								vec3 swirlpos = rayPos.xyz * vec3(1.0, 1.1, 1.2) * a + vec3(time)*a * 0.0001 ;
								vec3 swirly = vec3(Value3D(swirlpos.xyz * 1.1 + 31.33), Value3D(swirlpos.yzx * 1.4 + 60.66), Value3D(swirlpos.zxy)); 
								float simplexnoise = SimplexPerlin3D(swirlpos + swirly * 1.5) * 0.5 + 0.5;
								//perlinswirl = noise(swirlpos + swirly * 3);
							#endif
							float thisraynoise = max(0, localNoise.r + noiseLFParams.y - simplexnoise);
							
							// Modulate the noise based on its depth below fogplane, this is 1 at 0 height, and 0 at heightFogTop
							float rayDepthratio = 1.0 - rayPos.y / (heightFogTop);
							
							// Fog reaches full density at half depth to waterplane
							rayDepthratio = clamp(rayDepthratio * HEIGHTDENSITY, 0, 1);
							

							
							collectedNoise += thisraynoise * rayDepthratio;
							
							densityposition += vec4(rayPos*thisraynoise, thisraynoise); // collecting the 'center' of the noise cloud
							//if (thisraynoise > 0) { // only sample shadow if we have actual fog here!
								for (uint m = 0; m < shadowSteps; m++){ // step through the small local volume 
									f += (float(m)) * stepsInv; 
									//float f = (float(m) + float(n) * CLOUDSTEPS)/ steps;
									vec3 rayPos = mix(rayStart.xyz, rayEnd, f + rayJitterOffset);
									
									float localShadow= shadowAtWorldPos(rayPos); // 1 for lit, 0 for unlit
									float shadowDelta = 0.25 * (abs(dFdx(localShadow)) + abs(dFdy(localShadow))); // magic smoothing using adjacent pixels
									
									localShadow = mix(shadowDelta, 1.0 - shadowDelta, localShadow);
									collectedShadow += localShadow;
									numShadowSamplesTaken += 1.0;
								}
							//}
						}
						collectedShadow /= numShadowSamplesTaken; // get the true litness by only taking into account actual samples taken
						
						//apply shadow power:
						collectedShadow = pow(collectedShadow, 2* shadowedColor.a);
						
						densityposition.xyz /= densityposition.w;

						heightBasedFog *= collectedNoise/(CLOUDSTEPS);
					#else // fall back to retard mode
						collectedShadow = 1.0;
						densityposition.xyz = (rayStart + rayEnd)*0.5;
					#endif
				
				#endif
			#endif
		}else{
			collectedShadow = 1.0;
		}
		#endif
	#endif
	//modulate the height based component only, not the distance based component
	
	// but modulate _before_ addition!
	//const float expfactor = fogExpFactor * -0.0001;
	
	// Modulate distance fog density with angle of ray compared to sky?
	//vec3 camToMapNorm = normalize(mapFromCam);
	//float rayUpness = 1.0;
	if (camToMapNorm.y > 0) {
		rayUpness = pow(1.0 - camToMapNorm.y, 8.0);
		distanceFogAmount *= rayUpness;
	}
	
	
	// reduce height-based fog for in-los areas:
	heightBasedFog *= (1.0 - inlos);
	
	// Modulate the amount of fog based on how shadowed it is, by adding more fog to shadowed areas
	heightBasedFog += heightBasedFog * smoothstep( 0.0,1.0, 1.0 - collectedShadow); 
	
	// TODO, COMPLETELY SEPARATE HEIGHT AND DISTANCE BASED FOGS!
	//float heightBasedFogExp = exp(heightBasedFog * expfactor);
	
	
	
	// Sum the two components of fog by multiplication?
	float totalfog = heightBasedFogExp * distanceFogAmountExp;
	
	// Clamp the total amout of fog at 99% outputfogalpha, see quilezs Almost Identity (II)
	totalfog = sqrt(totalfog * totalfog + (1.0 - heightFogColor.a) * 0.1);
	fragColor.a = min(1.0, max(0, 1.0 - totalfog));
	
	// Colorize fog based on view angle: TODO do this on center weight of both !
	float sunAngleCos =  dot( camToMapNorm, sunDir.xyz); // this goes from into sun at 1 to sun behind us at -1 
	float sunPower = (1.0 + distanceFogColor.a * 8);
	float sunRatio = 1.0;
	if (sunAngleCos < 0 ){ // SUN IS BEHIND US
		sunPower *= 2;
		sunAngleCos *= -1.0;
		sunRatio = 0.2;
	}
	float sphericalharmonic = pow(sunAngleCos, sunPower) * sunRatio;
	
	vec3 chromaSphericalHarmonic = pow(vec3(sunAngleCos), vec3(sunPower) * vec3(1.0, 1.0 + SUNCHROMASHIFT, 1.0 + 2.0 * SUNCHROMASHIFT)) * sunRatio;
	
	// CHROMA SHIFTING?
	
	
	// This will be our output color
	vec3 fogColor = heightFogColor.rgb;
	
	//colorize based on the sun level
	//fogColor = mix(fogColor, 2*distanceFogColor.rgb, sphericalharmonic);
	fogColor = mix(fogColor, 2*distanceFogColor.rgb, chromaSphericalHarmonic);
	
	// Set the base color depending on how shadowed it is, 
	// shadowed components should tend toward heightFogColor
	vec3 heightFogColor = mix(heightFogColor.rgb, fogColor, collectedShadow);
	
	// Darkened the shadowed bits towards shadowedColor
	fragColor.rgb = mix(vec3(shadowedColor), heightFogColor.rgb, collectedShadow);	
	
	//Calculate backscatter color from minimap if possible?
	#if (USEMINIMAP == 1) 
		vec4 minimapcolor = textureLod(miniMapTex, heighmapUVatWorldPosMirrored(mapWorldPos.xz), 4.0);
		//if (camToMapNorm.y > 0 && mapdepth > 0.9999) rayUpness = 0;
		fragColor.rgb += minimapcolor.rgb * MINIMAPSCATTER * collectedShadow * rayUpness ;
	#endif
	
	// Colorize the fog wether its in shadow or not
	float heightDistFogRatio = heightBasedFog / (heightBasedFog + distanceFogAmount);
	// Above that, mix back regular fog color for distance based fog
	fragColor.rgb = mix( fogColor.rgb, fragColor.rgb,heightDistFogRatio);
	
	// get noise gradient and colorize with that
	vec3 fognormal = normalize(densityposition.xyz);
	
	float fogSun = 1.0 + clamp(dot(fognormal, sunDir.xyz), -1, 1);
	//fragColor.rgb *= fogSun;
	
	//fragColor.rgb = vec3(densityposition.g);
	//fragColor.a = 1.0;  

	return;
	*/