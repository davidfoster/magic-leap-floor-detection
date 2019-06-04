Shader "David Foster/Simple Floor Visualizer" {
	Properties {
		_WorldColour("World Colour", Color) = (0.5, 0.5, 0.5, 1)
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
				float3 normal : NORMAL;
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};

			struct v2f {
				float4 position : SV_POSITION;
				float3 worldPos : POSITION1;
				float3 normal : NORMAL;
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

				// normalise normals, as the Magic Leap emulator has a bug where it generates floor planes with normal length of 0.01.
				float3 normal = normalize(v.normal);

				// work out the angle delta between our fragment normal and the plane normal.
				float floorPlaneNormalDeltaDegrees = degrees(acos(dot(normal, _FloorPlane.xyz)));

				// calculate signed distance to plane, discarding the vertex by dividing by zero if it is below the distance.
				float distance = dot(worldPos, _FloorPlane.xyz);
				distance = distance + _FloorPlane.w;

				// N.B. uncomment below to effectively discard this vertex by performing an invalid operation (divide by zero).
				//o.position /= lerp(1, lerp(1, 0, step(floorPlaneNormalDeltaDegrees, _FloorNormalAngleMaxDelta)), step(distance, 0));

				// figure out world position.
				o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;

				// pass through normal.
				o.normal = normal;
				return o;
			}

			fixed4 frag (v2f i) : SV_Target {

				// work out the angle delta between our fragment normal and the plane normal.
				float floorPlaneNormalDeltaDegrees = degrees(acos(dot(i.normal, _FloorPlane.xyz)));

				// calculate signed distance to plane and set alpha based on that.
				float distance = dot(i.worldPos, _FloorPlane.xyz);
				distance = distance + _FloorPlane.w;

				// now lerp between world, horizontal surface, and floor colour, based on whether height and normal delta match.
				fixed4 col = lerp(_WorldColour, lerp(_HorizontalSurfaceColour, _FloorColour, step(distance, 0)), step(floorPlaneNormalDeltaDegrees, _FloorNormalAngleMaxDelta));

				return col;
			}
			ENDCG
		}
	}
}