Shader "David Foster/Spatial Mapping Wireframe (Floor Detection)" {
	Properties {
		_WireThickness ("Wire Thickness", RANGE(0, 800)) = 100
		_WorldColour("World Colour", Color) = (0.5, 0.5, 0.5, 1)
		_HorizontalSurfaceColour("Horizontal Surface Colour", Color) = (1, 1, 0, 1)
		_FloorColour("Floor Colour", Color) = (0, 1, 0, 1)
		_FloorNormalAngleMaxDelta("Floor Normal Angle Max Delta", Range(0, 90)) = 20
	}

	SubShader {
		Tags { "RenderType"="Opaque" }

		Pass {
			// wireframe shader based on the the following
			// http://developer.download.nvidia.com/SDK/10/direct3d/Source/SolidWireframe/Doc/SolidWireframe.pdf

			CGPROGRAM
			#pragma vertex vert
			#pragma geometry geom
			#pragma fragment frag

			#include "UnityCG.cginc"

			uniform float _WireThickness;

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

			struct v2g {
				float4 projectionSpaceVertex : SV_POSITION;
				float4 worldSpacePosition : TEXCOORD1;
				float3 normal : NORMAL;
				UNITY_VERTEX_OUTPUT_STEREO_EYE_INDEX
			};

			struct g2f {
				float4 projectionSpaceVertex : SV_POSITION;
				float4 worldSpacePosition : TEXCOORD0;
				float4 dist : TEXCOORD1;
				float3 normal : NORMAL;
				UNITY_VERTEX_OUTPUT_STEREO
			};

			v2g vert (appdata v) {
				v2g o;
				UNITY_SETUP_INSTANCE_ID(v);
				UNITY_INITIALIZE_OUTPUT_STEREO_EYE_INDEX(o);

				o.projectionSpaceVertex = UnityObjectToClipPos(v.vertex);
				o.worldSpacePosition = mul(unity_ObjectToWorld, v.vertex);

				// normalise normals, as the Magic Leap simulator has a bug where it generates floor meshes with normal length of 0.01.
				o.normal = normalize(v.normal);

				return o;
			}

			[maxvertexcount(3)]
			void geom(triangle v2g i[3], inout TriangleStream<g2f> triangleStream) {
				UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i[0]);

				float2 p0 = i[0].projectionSpaceVertex.xy / i[0].projectionSpaceVertex.w;
				float2 p1 = i[1].projectionSpaceVertex.xy / i[1].projectionSpaceVertex.w;
				float2 p2 = i[2].projectionSpaceVertex.xy / i[2].projectionSpaceVertex.w;

				float2 edge0 = p2 - p1;
				float2 edge1 = p2 - p0;
				float2 edge2 = p1 - p0;

				// N.B. to find the distance to the opposite edge, we take the formula for finding the area of a triangle Area = Base/2 * Height,
				// and solve for the Height = (Area * 2)/Base. We can get the area of a triangle by taking its cross product divided by 2.
				// However we can avoid dividing our area/base by 2 since our cross product will already be double our area.
				float area = abs(edge1.x * edge2.y - edge1.y * edge2.x);
				float wireThickness = 800 - _WireThickness;

				g2f o;
				UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
				o.worldSpacePosition = i[0].worldSpacePosition;
				o.projectionSpaceVertex = i[0].projectionSpaceVertex;
				o.dist.xyz = float3( (area / length(edge0)), 0.0, 0.0) * o.projectionSpaceVertex.w * wireThickness;
				o.dist.w = 1.0 / o.projectionSpaceVertex.w;
				o.normal = i[0].normal;
				triangleStream.Append(o);

				o.worldSpacePosition = i[1].worldSpacePosition;
				o.projectionSpaceVertex = i[1].projectionSpaceVertex;
				o.dist.xyz = float3(0.0, (area / length(edge1)), 0.0) * o.projectionSpaceVertex.w * wireThickness;
				o.dist.w = 1.0 / o.projectionSpaceVertex.w;
				o.normal = i[1].normal;
				triangleStream.Append(o);

				o.worldSpacePosition = i[2].worldSpacePosition;
				o.projectionSpaceVertex = i[2].projectionSpaceVertex;
				o.dist.xyz = float3(0.0, 0.0, (area / length(edge2))) * o.projectionSpaceVertex.w * wireThickness;
				o.dist.w = 1.0 / o.projectionSpaceVertex.w;
				o.normal = i[2].normal;
				triangleStream.Append(o);
			}

			fixed4 frag (g2f i) : SV_Target {
				
				float minDistanceToEdge = min(i.dist[0], min(i.dist[1], i.dist[2])) * i.dist[3];

				// early out if we know we are not on a line segment.
				if (minDistanceToEdge > 0.9) {
					return fixed4(0,0,0,0);
				}

				// smooth our line out.
				float t = exp2(-2 * minDistanceToEdge * minDistanceToEdge);

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
				
				// work out the angle delta between our fragment normal and the plane normal.
				float floorPlaneNormalDeltaDegrees = degrees(acos(dot(i.normal, _FloorPlane.xyz)));

				// calculate signed distance to plane and set alpha based on that.
				float distance = dot(i.worldSpacePosition, _FloorPlane.xyz);
				distance = distance + _FloorPlane.w;

				// now lerp between world, horizontal surface, and floor colour, based on whether height and normal delta match.
				fixed4 wireColor = lerp(_WorldColour, lerp(_HorizontalSurfaceColour, _FloorColour, step(distance, 0)), step(floorPlaneNormalDeltaDegrees, _FloorNormalAngleMaxDelta));

				fixed4 finalColor = lerp(float4(0, 0, 0, 1), wireColor, t);
				finalColor.a = t;

				return finalColor;
			}
			ENDCG
		}
	}
}
