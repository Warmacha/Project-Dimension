Shader "Custom/RetroGeometry"
{
    Properties
    {
        _BaseColor      ("Base Color",     Color)        = (1, 1, 1, 1)
        _ShadowColor    ("Shadow Color",   Color)        = (0.1, 0.15, 0.4, 1)
        _BaseMap        ("Texture",        2D)           = "white" {}
        _SnapPrecision  ("Snap Precision", Float)        = 64.0
        _AffineBlend    ("Affine Blend",   Range(0, 1))  = 1.0
    }

    SubShader
    {
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" }

        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode" = "UniversalForward" }

            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment Frag
            #pragma multi_compile_fog

            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile_fragment _ _SHADOWS_SOFT

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            CBUFFER_START(UnityPerMaterial)
                float4 _BaseColor;
                float4 _BaseMap_ST;
                float4 _ShadowColor;
                float  _SnapPrecision;
                float  _AffineBlend;
            CBUFFER_END

            TEXTURE2D(_BaseMap);
            SAMPLER(sampler_BaseMap);

            static const float BayerMatrix[16] =
            {
                 0,  8,  2, 10,
                12,  4, 14,  6,
                 3, 11,  1,  9,
                15,  7, 13,  5
            };

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS   : NORMAL;
                float2 uv         : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionCS              : SV_POSITION;
                float3 positionWS              : TEXCOORD0;  // for flat shading DDX/DDY
                noperspective float2 uvAffine  : TEXCOORD1;  // linear interp (no perspective divide)
                float2 uvPerspect              : TEXCOORD2;  // perspective-correct interp
                half fogFactor : TEXCOORD3;
            };

            Varyings Vert(Attributes IN)
            {
                Varyings OUT;

                float3 worldPos = TransformObjectToWorld(IN.positionOS.xyz);

                // Step 1 — vertex snap
                //worldPos = (round(worldPos * _SnapPrecision) / _SnapPrecision);

                float4 clipPos = TransformWorldToHClip(worldPos);
                float2 snapped = round((clipPos.xy / clipPos.w) * _SnapPrecision) / _SnapPrecision;
                clipPos.xy = snapped * clipPos.w;

                OUT.positionCS = clipPos;
                OUT.fogFactor = ComputeFogFactor(clipPos.z);
                OUT.positionWS = worldPos;

                float2 uv      = TRANSFORM_TEX(IN.uv, _BaseMap);
                OUT.uvAffine   = uv;   // noperspective = affine (linear)
                OUT.uvPerspect = uv;   // default = perspective-correct

                return OUT;
            }

            float4 Frag(Varyings IN) : SV_Target
            {
                // Step 2 — affine UV blend
                // TODO: lerp between IN.uvPerspect and IN.uvAffine using _AffineBlend
                half2 uv = IN.uvPerspect;

                uv = lerp(IN.uvPerspect, IN.uvAffine, _AffineBlend);

                half4 baseColor = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, uv) * _BaseColor;

                // Step 3 — flat shading
                // TODO: reconstruct face normal from screen-space derivatives of positionWS
                // hint: normalize(cross(ddx(IN.positionWS), ddy(IN.positionWS)))
                half3 N = normalize(cross(ddy(IN.positionWS), ddx(IN.positionWS)));

                // Step 4 — Lambert diffuse + cel step + dithered shadow
                float4 shadowCoord = TransformWorldToShadowCoord(IN.positionWS);
                Light mainLight    = GetMainLight(shadowCoord);

                // TODO: compute NdotL with N and mainLight.direction
                half NdotL = saturate(dot(N, mainLight.direction));
                // TODO: snap NdotL to 2 cel steps (lit = 1.0, shadow = 0.3)
                NdotL = (NdotL > 0.5 ? 1.0 : 0.3 ) * (mainLight.shadowAttenuation > 0.5 ? 1.0 : 0.0);

                half lit = NdotL > 0.5 ? 1.0 : 0.0;

                half3 litColor = baseColor.rgb * mainLight.color * NdotL;
                half3 shadowColor = baseColor.rgb * _ShadowColor.rgb;
                
                baseColor.rgb = lerp(shadowColor, litColor, lit);
                
                //baseColor.rgb = baseColor.rgb * mainLight.color * NdotL;

                baseColor.rgb = MixFog(baseColor.rgb, IN.fogFactor);

                return float4(baseColor.rgb, 1.0);
            }
            ENDHLSL
        }
    
        Pass
        {
            Name "ShadowCaster"
            Tags { "LightMode" = "ShadowCaster" }
            ZWrite On ZTest LEqual ColorMask 0


            HLSLPROGRAM
            #pragma vertex ShadowVert
            #pragma fragment ShadowFrag
            #pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW
            #pragma multi_compile_instancing

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"

            CBUFFER_START(UnityPerMaterial)
                float4 _BaseColor;
                float4 _BaseMap_ST;
                float4 _ShadowColor;
                float  _SnapPrecision;
                float  _AffineBlend;
            CBUFFER_END

            float3 _LightDirection;
            float3 _LightPosition;

            struct Attributes { float4 positionOS : POSITION; float3 normalOS : NORMAL; UNITY_VERTEX_INPUT_INSTANCE_ID };
            struct Varyings   { float4 positionCS : SV_POSITION; UNITY_VERTEX_INPUT_INSTANCE_ID };

            Varyings ShadowVert(Attributes IN)
            {
                Varyings OUT;
                UNITY_SETUP_INSTANCE_ID(IN);
                UNITY_TRANSFER_INSTANCE_ID(IN, OUT);

                float3 posWS  = TransformObjectToWorld(IN.positionOS.xyz);
                float3 normWS = TransformObjectToWorldNormal(IN.normalOS);

                #if _CASTING_PUNCTUAL_LIGHT_SHADOW
                    float3 lightDir = normalize(_LightPosition - posWS);
                #else
                    float3 lightDir = _LightDirection;
                #endif

                OUT.positionCS = ApplyShadowClamping(
                    TransformWorldToHClip(ApplyShadowBias(posWS, normWS, lightDir)));
                return OUT;
            }

            half4 ShadowFrag(Varyings IN) : SV_Target { return 0; }
            ENDHLSL
        }
    }  
}
