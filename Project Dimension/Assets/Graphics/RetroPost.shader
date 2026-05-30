Shader "Hidden/RetroPost"
{
    Properties
    {
        _Tint           ("Tint", Color)   = (1, 1, 1, 1)
        _ScanlineOpacity("Scanline Opacity", Range(0, 1)) = 0.35
        _ColorSteps     ("Color Steps",   Range(2, 16))   = 8
        _DitherStrength ("Dither Strength", Range(0, 1))  = 1.0
    }

    SubShader
    {
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" }
        ZWrite Off
        ZTest Always
        Cull Off
        Blend Off

        Pass
        {
            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment Frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"

            float4 _Tint;
            float  _ScanlineOpacity;
            float  _ColorSteps;
            float  _DitherStrength;

            // 4x4 Bayer matrix, values 0-15
            static const float BayerMatrix[16] =
            {
                 0,  8,  2, 10,
                12,  4, 14,  6,
                 3, 11,  1,  9,
                15,  7, 13,  5
            };

            float4 Frag(Varyings input) : SV_Target
            {
                float2 uv = input.texcoord;

                // Step 1 — sample and tint
                float4 color = SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_PointClamp, uv);
                color *= _Tint;

                // Step 2 — Bayer dither + color quantization
                //uint2 px = uint2(uv * _ScreenParams.xy);
                uint2 px = uint2(uv * _BlitTexture_TexelSize.wz);

                half threshold = BayerMatrix[(px.x % 4) + (px.y % 4) * 4] / 15.0;

                color.rgb += (threshold - 0.5) * _DitherStrength;
                color.rgb = floor(color.rgb * _ColorSteps + 0.5) / _ColorSteps;

                // Step 3 — scanline bands
                half scanline = frac(uv.y * _BlitTexture_TexelSize.w) < 0.5 ? 1.0 : 0.0;

                color.rgb -= scanline *_ScanlineOpacity;

                return color;
            }
            ENDHLSL
        }
    }
}
