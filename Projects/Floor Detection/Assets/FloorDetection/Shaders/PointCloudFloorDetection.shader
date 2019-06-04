Shader "David Foster/Point Cloud (Floor Detection)" {
	Properties {
		_PointSize("Point Size", Float) = 5
		_WorldColour("World Colour", Color) = (1, 1, 1, 1)
		_HorizontalSurfaceColour("Horizontal Surface Colour", Color) = (1, 1, 0, 1)
		_FloorColour("Floor Colour", Color) = (0, 1, 0, 1)
		_FloorNormalAngleMaxDelta("Floor Normal Angle Max Delta", Range(0, 90)) = 20
	}

	SubShader {
		Pass {
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			#include "UnityCG.cginc"

			uniform float4 _WorldColour;
			uniform float4 _HorizontalSurfaceColour;
			uniform float4 _FloorColour;

			uniform float _FloorNormalAngleMaxDelta;

			uniform float4 _FloorPlane;

			struct appdata {
				float4 vertex : POSITION;
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};

			struct v2f {
				float4 vertex : POSITION;
				float4 pointColor : COLOR;
				float pointSize : PSIZE;
				UNITY_VERTEX_OUTPUT_STEREO
			};

			float _PointSize;

			v2f vert(appdata v) {
				v2f o;
				UNITY_SETUP_INSTANCE_ID(v);
				UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

				o.vertex = UnityObjectToClipPos(v.vertex);
				o.pointSize = _PointSize;

				const fixed4 colors[11] = {
					fixed4(1.0, 1.0, 1.0, 1.0),  // white.
					fixed4(1.0, 0.0, 0.0, 1.0),  // red.
					fixed4(0.0, 1.0, 0.0, 1.0),  // green.
					fixed4(0.0, 0.0, 1.0, 1.0),  // blue.
					fixed4(1.0, 1.0, 0.0, 1.0),  // yellow.
					fixed4(0.0, 1.0, 1.0, 1.0),  // cyan/aqua.
					fixed4(1.0, 0.0, 1.0, 1.0),  // magenta.
					fixed4(0.5, 0.0, 0.0, 1.0),  // maroon.
					fixed4(0.0, 0.5, 0.5, 1.0),  // teal.
					fixed4(1.0, 0.65, 0.0, 1.0), // orange.
					fixed4(1.0, 1.0, 1.0, 1.0)   // white.
				};

				float cameraToVertexDistance = distance(_WorldSpaceCameraPos, v.vertex);
				int index = clamp(floor(cameraToVertexDistance), 0, 10);

				o.pointColor = colors[index];

				return o;
			}

			fixed4 frag(v2f i) : SV_Target {
				UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(i);
				return i.pointColor;
			}
			ENDCG
		}
	}
}
