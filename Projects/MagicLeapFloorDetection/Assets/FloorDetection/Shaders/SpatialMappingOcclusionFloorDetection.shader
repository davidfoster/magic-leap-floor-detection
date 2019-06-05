Shader "David Foster/Spatial Mapping Occlusion (Floor Detection)" {
	Properties {
		_FloorNormalAngleMaxDelta("Floor Normal Angle Max Delta", Range(0, 90)) = 20
	}

	SubShader {

		// render the Occlusion shader before all opaque geometry to prime the depth buffer.
		Tags { "Queue"="Geometry-1" }

		ZWrite On
		ZTest LEqual
		ColorMask 0

		Pass {
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			#include "UnityCG.cginc"

			uniform float _FloorNormalAngleMaxDelta;

			// global floor plane property.
			uniform float4 _FloorPlane;

			struct appdata {
				float4 vertex : POSITION;
				float3 normal : NORMAL;
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};

			struct v2f {
				float4 position : SV_POSITION;
				UNITY_VERTEX_OUTPUT_STEREO
			};

			v2f vert (appdata v) {
				v2f o;
				UNITY_SETUP_INSTANCE_ID(v);
				UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
				
				// calculate the position in clip space to render the object.
				o.position = UnityObjectToClipPos(v.vertex);
								
				// calculate world position of vertex.
				float4 worldPos = mul(unity_ObjectToWorld, v.vertex);

				// normalise normals, as the Magic Leap simulator has a bug where it generates floor meshes with normal length of 0.01.
				float3 normal = normalize(v.normal);

				// work out the angle delta between our vertex normal and the plane normal.
				float floorPlaneNormalDeltaDegrees = degrees(acos(dot(normal, _FloorPlane.xyz)));

				// calculate signed distance to plane.
				float distance = dot(worldPos, _FloorPlane.xyz);
				distance = distance + _FloorPlane.w;

				// if the position is below the plane and normal points sufficiently along the plane normal, effectively discard this
				// vertex by performing an invalid operation (divide by zero).
				o.position /= lerp(1, lerp(1, 0, step(floorPlaneNormalDeltaDegrees, _FloorNormalAngleMaxDelta)), step(distance, 0));

				return o;
			}

			fixed4 frag (v2f i) : SV_Target {

				// simply return black, which renders as transparent on the Magic Leap and HoloLens.
				return fixed4(0, 0, 0, 0);
			}
			ENDCG
		}
	}
}