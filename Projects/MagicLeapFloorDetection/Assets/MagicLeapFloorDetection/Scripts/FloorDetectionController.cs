using System.Collections.Generic;
using UnityEngine;
using UnityEngine.XR.MagicLeap;

namespace MagicLeapFloorDetection {

	[ExecuteInEditMode]
	public class FloorDetectionController : MonoBehaviour {

		//-----------------------------------------------------------------------------------------
		// Constants:
		//-----------------------------------------------------------------------------------------

		private const float DEFAULT_FLOOR_NORMAL_ANGLE_MAX_DELTA = 20;
		private const float DEFAULT_FLOOR_PLANE_Y_MESHING_ERROR_MARGIN = 0.05f;
		private const float DEFAULT_FLOOR_MEASUREMENT_MAX_AGE = 2;

		private const float DEFAULT_BOUNDS_SIZE = 10;

		private static readonly int FLOOR_PLANE_PROPERTY                  = Shader.PropertyToID("_FloorPlane");
		private static readonly int FLOOR_NORMAL_ANGLE_MAX_DELTA_PROPERTY = Shader.PropertyToID("_FloorNormalAngleMaxDelta");

		//-----------------------------------------------------------------------------------------
		// Inspector Variables:
		//-----------------------------------------------------------------------------------------

		[Space]

		[Tooltip("The maximum angle in degrees between a vertex's normal and the floor plane normal within which the vertex is considered to " +
				 "belong to the floor, provided it also falls below the " + nameof(FloorY) + " plus the " + nameof(floorPlaneYMeshingErrorMargin))]
		[SerializeField] protected float floorNormalAngleMaxDelta = DEFAULT_FLOOR_NORMAL_ANGLE_MAX_DELTA;

		[Tooltip("Additional margin used to envelop noise in the spatial map which falls just above the detected floor y but should still be " +
				 "considered part of the floor. This value is only used with the ML Meshing/Raycast API; the " + nameof(FloorY) + " property of " +
				 "this component denotes the de facto floor y.")]
		[SerializeField] protected float floorPlaneYMeshingErrorMargin = DEFAULT_FLOOR_PLANE_Y_MESHING_ERROR_MARGIN;

		[Tooltip("Floor measurements are averaged over time. This value determines the duration in seconds that those measurements factor into " +
				 "our average.")]
		[SerializeField] protected float floorMeasurementMaxAge = DEFAULT_FLOOR_MEASUREMENT_MAX_AGE;

		[Space]

		[Tooltip("The square bounds within which planes will be detected by the Magic Leap Planes API.")]
		[SerializeField] protected float boundsSize = DEFAULT_BOUNDS_SIZE;

		//-----------------------------------------------------------------------------------------
		// Public Properties:
		//-----------------------------------------------------------------------------------------

		public bool HasDetectedFloor { get; protected set; }
		public float FloorY { get; protected set; }

		//-----------------------------------------------------------------------------------------
		// Private Fields:
		//-----------------------------------------------------------------------------------------

		/// <summary>The current Unity <c>Plane</c> describing the normal and distance of our working floor plane.</summary>
		/// <remarks>This is not to be confused with a Magic Leap Planes API <c>MLWorldPlane</c>.</remarks>
		private Plane currFloorPlane;

		/// <summary>The previously set <see cref="floorNormalAngleMaxDelta"/>.</summary>
		/// <remarks>Initialising this to <c>float.NaN</c> ensures we always detect it changing (even to zero) and set it at least once.</remarks>
		private float prevFloorNormalAngleMaxDelta = float.NaN;

		private readonly Queue<FloatMeasurement> floorYMeasurements = new Queue<FloatMeasurement>();

		//-----------------------------------------------------------------------------------------
		// Unity Lifecycle:
		//-----------------------------------------------------------------------------------------

		protected void Awake() {
			
			// set our scale to determine bounds used by Magic Leap Planes API.
			transform.localScale = Vector3.one * boundsSize;
		}

		protected void Update() {

			// handle updating the global floor plane shader data.
			// N.B. we could technically only do this when our floor position changes in Planes_Updated below, but by doing this in Update, and
			// with the ExecuteInEditMode attribute above, we can update our shaders with floor plane info at edit time by moving our transform.

			// grab the current plane's values prior to recalculation so we can later see if it has changed.
			// N.B. we can do this because Unity's Plane is a struct so prevFloorPlane is a new instance with currFloorPlanes values.
			Plane prevFloorPlane = currFloorPlane;

			// create a new plane at the floor position (plus error margin), using our up as its normal.
			// N.B. the x and z of the floor plane is not important since its x and z extend infinitely orthogonal to the normal.
			Vector3 floorPlanePosition = transform.position;
			floorPlanePosition.y = FloorY + floorPlaneYMeshingErrorMargin;
			currFloorPlane = new Plane(transform.up, floorPlanePosition);

			// if we detect a change in floor plane...
			// N.B. frustratingly, at least as of 2019.1.5f1, Unity have yet to implement IEquatable on Planes.
			if (currFloorPlane.normal != prevFloorPlane.normal || currFloorPlane.distance != prevFloorPlane.distance) {
				
				// create a Vector4 representation of the plane and pass it into all shaders globally.
				Vector4 plane = new Vector4(currFloorPlane.normal.x, currFloorPlane.normal.y, currFloorPlane.normal.z, currFloorPlane.distance);
				Shader.SetGlobalVector(FLOOR_PLANE_PROPERTY, plane);
			}

			// if we detect a change in floor normal angle max delta, update global shader value.
			if (floorNormalAngleMaxDelta == prevFloorNormalAngleMaxDelta) return;
			Shader.SetGlobalFloat(FLOOR_NORMAL_ANGLE_MAX_DELTA_PROPERTY, floorNormalAngleMaxDelta);
			prevFloorNormalAngleMaxDelta = floorNormalAngleMaxDelta;
		}

		//-----------------------------------------------------------------------------------------
		// Event Handlers:
		//-----------------------------------------------------------------------------------------

		// N.B. wired up in the editor.
		public void Planes_Updated(MLWorldPlane[] mlPlanes, MLWorldPlaneBoundaries[] boundaries) {

			foreach (MLWorldPlane mlPlane in mlPlanes) {

				// continue if this is not a floor plane.
				if ((mlPlane.Flags & (uint)SemanticFlags.Floor) == 0) continue;

				// we have a floor, so flag.
				HasDetectedFloor = true;

				// remove prior measurements whose age exceeds the max.
				while (floorYMeasurements.Count > 0 && floorYMeasurements.Peek().Age > floorMeasurementMaxAge) {
					floorYMeasurements.Dequeue();
				}

				// add the new measurement.
				floorYMeasurements.Enqueue(new FloatMeasurement(mlPlane.Center.y));

				// work out and assign average floor plane y.
				float ySum = 0;
				foreach (FloatMeasurement measurement in floorYMeasurements) {
					ySum += measurement.Value;
				}
				FloorY = ySum / floorYMeasurements.Count;
			}
		}

		//-----------------------------------------------------------------------------------------
		// Structs:
		//-----------------------------------------------------------------------------------------

		private struct FloatMeasurement {

			//-----------------------------------------------------------------------------------------
			// Private Fields:
			//-----------------------------------------------------------------------------------------

			private readonly float time;

			//-----------------------------------------------------------------------------------------
			// Public Properties:
			//-----------------------------------------------------------------------------------------

			public float Value { get; }
			public float Age => Time.time - time;

			//-----------------------------------------------------------------------------------------
			// Constructors:
			//-----------------------------------------------------------------------------------------

			public FloatMeasurement(float value) {
				Value = value;
				time  = Time.time;
			}
		}
	}
}