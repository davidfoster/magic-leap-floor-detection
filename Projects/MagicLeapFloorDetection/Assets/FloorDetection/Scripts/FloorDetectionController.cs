using System.Collections.Generic;
using UnityEngine;
using UnityEngine.XR.MagicLeap;

[ExecuteInEditMode]
public class FloorDetectionController : MonoBehaviour {
	
	//-----------------------------------------------------------------------------------------
	// Constants:
	//-----------------------------------------------------------------------------------------

	private const float DEFAULT_FLOOR_PLANE_PADDING = 0.05f;
	private const float DEFAULT_FLOOR_MEASUREMENT_MAX_AGE = 2;

	private const float DEFAULT_BOUNDS_SIZE = 10;

	private static readonly int FLOOR_PLANE_PROPERTY = Shader.PropertyToID("_FloorPlane");

	//-----------------------------------------------------------------------------------------
	// Inspector Variables:
	//-----------------------------------------------------------------------------------------

	[Header("References")]

	[Tooltip("Materials whose shaders require the floor plane normal and position.")]
	[SerializeField] protected Material[] floorPlaneMaterials;

	[Header("Options")]

	[Tooltip("Additional padding used to envelop noise in the spatial map which falls just above the detected floor y but should still be " +
	         "considered part of the floor.")]
	[SerializeField] protected float floorPlanePadding = DEFAULT_FLOOR_PLANE_PADDING;

	[Tooltip("Floor measurements are averaged over time. This value determines the duration that those measurements factor into our average.")]
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

	private readonly Queue<FloatMeasurement> floorYMeasurements = new Queue<FloatMeasurement>();

	//-----------------------------------------------------------------------------------------
	// Unity Lifecycle:
	//-----------------------------------------------------------------------------------------

	protected void Awake() {

		// set our scale to determine bounds used by Magic Leap Planes API.
		transform.localScale = Vector3.one * boundsSize;
	}

	protected void Update() {

		// handle updating materials who need floor plane information.
		// N.B. we could technically only do this when our floor position changes in Planes_Updated below, but by doing this in Update,
		// and with the ExecuteInEditMode attribute above, we can update our materials with floor plane info at edit time.
		if (floorPlaneMaterials == null || floorPlaneMaterials.Length == 0) return;

		// create a plane at the floor position (plus padding), using our up as its normal.
		// N.B. the x and z of the floor plane is not important since its x and z extend infinitely orthogonal to the normal.
		Vector3 floorPlanePosition = transform.position;
		floorPlanePosition.y = FloorY + floorPlanePadding;
		Plane plane = new Plane(transform.up, floorPlanePosition);

		// create a Vector4 representation of the plane that we can pass into our shader.
		Vector4 planeRepresentation = new Vector4(plane.normal.x, plane.normal.y, plane.normal.z, plane.distance);

		// pass the plane vector into each material.
		foreach (Material mat in floorPlaneMaterials) {
			if (mat == null) continue;
			mat.SetVector(FLOOR_PLANE_PROPERTY, planeRepresentation);
		}
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