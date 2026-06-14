Shader "Custom/BillboardSpriteWithShadows"
{
    Properties
    {
        [MainColor] _BaseColor("Base Color", Color) = (1, 1, 1, 1)
        [MainTexture] _BaseMap("Base Map", 2D) = "white" {}
        _Cutoff("Alpha Cutoff", Range(0, 1)) = 0.5
        
        [Header(Billboard Lighting Settings)]
        _NormalBlend("Normal Blend (0=Camera, 1=Up)", Range(0, 1)) = 0.7
        
        [Header(Lighting Settings)]
        _LightingSteps("Lighting Steps (Posterization)", Range(2, 16)) = 4
        _AmbientStrength("Ambient Strength", Range(0, 1)) = 0.3
        
        [Header(Pixel Grid Settings)]
        [Toggle(USE_PIXEL_GRID)] _UsePixelGrid("Use Pixel Grid Lighting", Float) = 0
        _PixelGridSize("Pixel Grid Size", Range(8, 128)) = 32
    }

    SubShader
    {
        Tags 
        { 
            "RenderType" = "TransparentCutout" 
            "RenderPipeline" = "UniversalPipeline"
            "Queue" = "AlphaTest"
        }

        // Main lighting pass
        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode" = "UniversalForward" }

            Cull Off
            ZWrite On

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            
            // Local shader features
            #pragma shader_feature_local USE_PIXEL_GRID

            // URP shader features
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            #pragma multi_compile_fragment _ _SCREEN_SPACE_OCCLUSION
            #pragma multi_compile_fragment _ _LIGHT_LAYERS
            #pragma multi_compile_fragment _ _LIGHT_COOKIES
            #pragma multi_compile _ _FORWARD_PLUS

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/RealtimeLights.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
                float3 normalOS : NORMAL;
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 positionWS : TEXCOORD1;
                float3 normalWS : TEXCOORD2;
                float3 viewDirWS : TEXCOORD3;
            };

            TEXTURE2D(_BaseMap);
            SAMPLER(sampler_BaseMap);

            CBUFFER_START(UnityPerMaterial)
                half4 _BaseColor;
                float4 _BaseMap_ST;
                float _Cutoff;
                float _NormalBlend;
                float _LightingSteps;
                float _AmbientStrength;
                float _PixelGridSize;
            CBUFFER_END

            // Calculate virtual normal for billboarded sprite
            float3 GetBillboardVirtualNormal(float3 viewDirWS, float3 normalWS, float blend)
            {
                // Get camera forward projected onto XZ plane
                float3 cameraForwardXZ = normalize(float3(viewDirWS.x, 0, viewDirWS.z));
                
                // The "virtual" normal should point away from camera on XZ plane
                // This makes the sprite appear as if it's a vertical plane in world space
                float3 virtualNormal = normalize(float3(-cameraForwardXZ.x, 0, -cameraForwardXZ.z));
                
                // Blend between pure billboard normal and virtual standing normal
                virtualNormal = lerp(normalWS, virtualNormal, blend);
                
                return normalize(virtualNormal);
            }

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                
                VertexPositionInputs positionInputs = GetVertexPositionInputs(IN.positionOS.xyz);
                OUT.positionHCS = positionInputs.positionCS;
                OUT.positionWS = positionInputs.positionWS;
                OUT.uv = TRANSFORM_TEX(IN.uv, _BaseMap);
                
                // Calculate normal
                VertexNormalInputs normalInputs = GetVertexNormalInputs(IN.normalOS);
                OUT.normalWS = normalInputs.normalWS;
                
                // View direction
                OUT.viewDirWS = GetWorldSpaceViewDir(positionInputs.positionWS);
                
                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                // Sample texture
                half4 albedo = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, IN.uv) * _BaseColor;
                
                // Alpha cutout
                clip(albedo.a - _Cutoff);
                
                // Calculate virtual normal for lighting
                float3 viewDir = normalize(IN.viewDirWS);
                float3 virtualNormal = GetBillboardVirtualNormal(viewDir, IN.normalWS, _NormalBlend);
                
                // Snap to pixel grid if enabled
                float3 lightingPositionWS = IN.positionWS;
                #ifdef USE_PIXEL_GRID
                    // Snap world position to grid cells
                    // Use round() instead of floor() to handle negative coordinates correctly
                    float gridCellSize = 1.0 / _PixelGridSize;
                    lightingPositionWS = round(IN.positionWS / gridCellSize) * gridCellSize;
                #endif
                
                // Get main light with shadows (use snapped position for grid effect)
                float4 shadowCoord = TransformWorldToShadowCoord(lightingPositionWS);
                Light mainLight = GetMainLight(shadowCoord);
                
                // Calculate raw lighting value
                float NdotL = saturate(dot(virtualNormal, mainLight.direction));
                
                // Posterize the lighting
                float posterizedLight = floor(NdotL * _LightingSteps) / _LightingSteps;
                
                // Apply shadow attenuation to posterized light
                half3 lighting = mainLight.color * mainLight.shadowAttenuation * posterizedLight;
                
                // Add additional lights
                #if defined(_ADDITIONAL_LIGHTS)
                    #if defined(_FORWARD_PLUS)
                        // Forward+ path (URP 14+)
                        uint meshRenderingLayers = GetMeshRenderingLayer();
                        InputData inputData = (InputData)0;
                        inputData.normalizedScreenSpaceUV = GetNormalizedScreenSpaceUV(IN.positionHCS);
                        inputData.positionWS = lightingPositionWS;
                        
                        LIGHT_LOOP_BEGIN(pixelLightCount)
                            Light additionalLight = GetAdditionalLight(lightIndex, lightingPositionWS, half4(1, 1, 1, 1));
                            
                            #ifdef _LIGHT_LAYERS
                            if (IsMatchingLightLayer(additionalLight.layerMask, meshRenderingLayers))
                            #endif
                            {
                                // Calculate lighting contribution with virtual normal
                                float additionalNdotL = saturate(dot(virtualNormal, additionalLight.direction));
                                
                                // Posterize the additional light
                                float posterizedAdditionalLight = floor(additionalNdotL * _LightingSteps) / _LightingSteps;
                                
                                // Apply light color, attenuation to posterized light
                                half3 additionalLighting = additionalLight.color * additionalLight.distanceAttenuation * additionalLight.shadowAttenuation * posterizedAdditionalLight;
                                
                                lighting += additionalLighting;
                            }
                        LIGHT_LOOP_END
                    #else
                        // Standard path (URP 13 and earlier)
                        uint pixelLightCount = GetAdditionalLightsCount();
                        #ifdef _LIGHT_LAYERS
                            uint meshRenderingLayers = GetMeshRenderingLayer();
                        #endif
                        
                        for (uint lightIndex = 0u; lightIndex < pixelLightCount; ++lightIndex)
                        {
                            Light additionalLight = GetAdditionalLight(lightIndex, lightingPositionWS, half4(1, 1, 1, 1));
                            
                            #ifdef _LIGHT_LAYERS
                            if (IsMatchingLightLayer(additionalLight.layerMask, meshRenderingLayers))
                            #endif
                            {
                                // Calculate lighting contribution with virtual normal
                                float additionalNdotL = saturate(dot(virtualNormal, additionalLight.direction));
                                
                                // Posterize the additional light
                                float posterizedAdditionalLight = floor(additionalNdotL * _LightingSteps) / _LightingSteps;
                                
                                // Apply light color, attenuation to posterized light
                                half3 additionalLighting = additionalLight.color * additionalLight.distanceAttenuation * additionalLight.shadowAttenuation * posterizedAdditionalLight;
                                
                                lighting += additionalLighting;
                            }
                        }
                    #endif
                #endif
                
                // Add ambient (also posterized for consistency)
                float posterizedAmbient = floor(_AmbientStrength * _LightingSteps) / _LightingSteps;
                lighting += half3(posterizedAmbient, posterizedAmbient, posterizedAmbient);
                
                // Apply lighting to albedo
                half3 finalColor = albedo.rgb * lighting;
                
                return half4(finalColor, albedo.a);
            }
            ENDHLSL
        }

        // Depth only pass
        Pass
        {
            Name "DepthOnly"
            Tags { "LightMode" = "DepthOnly" }

            ZWrite On
            ColorMask 0
            Cull Off

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float2 uv : TEXCOORD0;
            };

            TEXTURE2D(_BaseMap);
            SAMPLER(sampler_BaseMap);

            CBUFFER_START(UnityPerMaterial)
                half4 _BaseColor;
                float4 _BaseMap_ST;
                float _Cutoff;
                float _NormalBlend;
                float _LightingSteps;
                float _AmbientStrength;
                float _PixelGridSize;
            CBUFFER_END

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.uv = TRANSFORM_TEX(IN.uv, _BaseMap);
                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                half alpha = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, IN.uv).a * _BaseColor.a;
                clip(alpha - _Cutoff);
                return 0;
            }
            ENDHLSL
        }
    }
}
