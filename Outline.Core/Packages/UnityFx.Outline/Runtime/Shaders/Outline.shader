﻿// Copyright (C) 2019-2020 Alexander Bogarsukov. All rights reserved.
// See the LICENSE.md file in the project root for more information.

// Renders outline based on a texture produces by 'UnityF/Outline/RenderColor' output.
// Modified version of 'Custom/Post Outline' shader taken from https://willweissman.wordpress.com/tutorials/shaders/unity-shaderlab-object-outlines/.
Shader "Hidden/UnityFx/Outline"
{
	Properties
	{
		_Width("Outline thickness (in pixels)", Range(1, 32)) = 5
		_Intensity("Outline intensity", Range(0.1, 100)) = 2
		_Color("Outline color", Color) = (1, 0, 0, 1)
	}

	HLSLINCLUDE

		#include "UnityCG.cginc"

		CBUFFER_START(UnityPerMaterial)
			float _Intensity;
			int _Width;
			float4 _Color;
		CBUFFER_END

		UNITY_DECLARE_TEX2D(_MainTex);
		float2 _MainTex_TexelSize;
		UNITY_DECLARE_TEX2D(_MaskTex);
		float _GaussSamples[32];

#if SHADER_TARGET >= 35

		struct appdata_vid
		{
			uint vertexID : SV_VertexID;
		};

		v2f_img vert_35(appdata_vid v)
		{
			v2f_img o;
			UNITY_INITIALIZE_OUTPUT(v2f_img, o);
			UNITY_SETUP_INSTANCE_ID(v);
			UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

			// Generate a triangle in homogeneous clip space, s.t.
			// v0 = (-1, -1, 1), v1 = (3, -1, 1), v2 = (-1, 3, 1).
			float2 uv = float2((v.vertexID << 1) & 2, v.vertexID & 2);
			o.pos = float4(uv * 2 - 1, UNITY_NEAR_CLIP_VALUE, 1);

#if UNITY_UV_STARTS_AT_TOP
			o.uv = half2(uv.x, 1 - uv.y);
#else
			o.uv = uv;
#endif

			return o;
		}

#endif

		v2f_img vert(appdata_img v)
		{
			v2f_img o;
			UNITY_INITIALIZE_OUTPUT(v2f_img, o);
			UNITY_SETUP_INSTANCE_ID(v);
			UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

			o.pos = float4(v.vertex.xy, UNITY_NEAR_CLIP_VALUE, 1);
			o.uv = ComputeScreenPos(o.pos);

			return o;
		}

		float4 frag_h(v2f_img i) : SV_Target
		{
			float TX_x = _MainTex_TexelSize.x;
			float intensity;
			int n = _Width;

			for (int k = -n; k <= n; k += 1)
			{
				intensity += UNITY_SAMPLE_TEX2D(_MainTex, i.uv + float2(k * TX_x, 0)).r * _GaussSamples[abs(k)];
			}

			return intensity;
		}

		float4 frag_v(v2f_img i) : SV_Target
		{
			if (UNITY_SAMPLE_TEX2D(_MaskTex, i.uv).r > 0)
			{
				discard;
			}

			float TX_y = _MainTex_TexelSize.y;
			float intensity;
			int n = _Width;

			for (int k = -n; k <= _Width; k += 1)
			{
				intensity += UNITY_SAMPLE_TEX2D(_MainTex, i.uv + float2(0, k * TX_y)).r * _GaussSamples[abs(k)];
			}

			intensity = _Intensity > 99 ? step(0.01, intensity) : intensity * _Intensity;
			return float4(_Color.rgb, saturate(_Color.a * intensity));
		}

	ENDHLSL

	SubShader
	{
		Cull Off
		ZWrite Off
		ZTest Always
		Lighting Off

		// 0) HPass SM3.5+
		Pass
		{
			HLSLPROGRAM

			#pragma target 3.5
			#pragma vertex vert_35
			#pragma fragment frag_h

			ENDHLSL
		}

		// 1) HPass SM2.0
		Pass
		{
			HLSLPROGRAM

			#pragma vertex vert
			#pragma fragment frag_h

			ENDHLSL
		}

		// 2) VPass SM3.5+
		Pass
		{
			Blend SrcAlpha OneMinusSrcAlpha

			HLSLPROGRAM

			#pragma target 3.5
			#pragma vertex vert_35
			#pragma fragment frag_v

			ENDHLSL
		}

		// 3) VPass SM2.0
		Pass
		{
			Blend SrcAlpha OneMinusSrcAlpha

			HLSLPROGRAM

			#pragma vertex vert
			#pragma fragment frag_v

			ENDHLSL
		}
	}
}