# Magic Leap Floor Detection ![stability-wip](https://img.shields.io/badge/stability-work_in_progress-lightgrey.svg)

Detect and display the floor in Magic Leap Unity projects with this expansion to the ML SDK Meshing example scene.

## Dependencies

* Lumin SDK v0.20.0.
* Magic Leap Unity® Package v0.20.0.
* Unity 2019.1.5f1 with Lumin OS (Magic Leap) Build Support.

It will likely work in other versions of Unity 2019, but I make no guarantees. 😎

## How to Use

All Magic Leap code and content is .gitignored so as to abide by the terms of the Independent Creator Program.

To use this example, either (in order of simplicity):

1. Import [MagicLeapFloorDetection.unitypackage](https://github.com/davidfoster/magic-leap-floor-detection/blob/develop/Packages/MagicLeapFloorDetection.unitypackage) into an existing ML Unity project.
2. Import the ML Unity package included with the SDK into the project under [_Projects/MagicLeapFloorDetection_](https://github.com/davidfoster/magic-leap-floor-detection/blob/develop/Projects/MagicLeapFloorDetection), then import ML Remote support libraries ("_Magic Leap > ML Remote > Import Support Libraries_" menu item inside of Unity).
   * Make sure the Lumin platform is active in Build Settings or you will receive a "No ML VRDevice loaded" error.

## Examples

In these examples, vertices are rendered in yellow whose normals fall within a specified degree delta of the floor normal. Of those vertices, those who fall below the detected floor `position.y` are considered to be a part of the floor, and are rendered in green.

By default, the degree delta is `20`° and the floor normal is world `Vector3.up`. The rendered detected floor `y` also includes an error margin (default: `0.05`) to envelop noise in the spatial map which falls just above the de facto detected floor `y` but should still be considered a part of the floor.

### Simple Floor Visualizer

<img src="https://github.com/davidfoster/magic-leap-floor-detection/blob/develop/Examples/simple-floor-visualizer-example.png" alt="Simple Floor Visualizer." width="392" height="294" />

### Spatial Mapper Meshing Wireframe

<img src="https://github.com/davidfoster/magic-leap-floor-detection/blob/develop/Examples/spatial-mapper-meshing-wireframe-example.png" alt="Spatial Mapper Meshing Wireframe." width="392" height="294" />

### Spatial Mapper Meshing Point Cloud

<img src="https://github.com/davidfoster/magic-leap-floor-detection/blob/develop/Examples/spatial-mapper-meshing-point-cloud-example.png" alt="Spatial Mapper Meshing Point Cloud." width="392" height="294" />

### Spatial Mapper Meshing Occlusion

In this example, the spatial mapper meshing visualizer is not rendering green. The green is coming from a separate quad located under the world. Because the meshing visualizer in occlusion mode renders pixels to the depth buffer (`ZWrite On`), we actually want to discard vertices considered to belong to the floor so that they do not occlude objects under the floor.

Vertex 'discarding' is done in the vertex program by performing an invalid operation on the vertex position (division by zero). This behaviour is undefined but works in OpenGL ES and OpenGL Core and is much more performant than a true `discard` in the fragment program because it avoids a branching operation.

<img src="https://github.com/davidfoster/magic-leap-floor-detection/blob/develop/Examples/spatial-mapper-meshing-occlusion-example.png" alt="Spatial Mapper Meshing Occlusion." width="392" height="294" />

N.B. aforementioned vertex discarding is purely visual; floor mesh colliders are present despite floor occlusion not rendering.

## Gotchas

* When using the ML Remote simulator, floor meshes in particular are generated with normals of magnitude `0.01`. We can easily account for this (and have) in each shader but it adds an extra `normalize` operation and, likely, a square root. Even if we are performing a square root, [square roots are two orders of magnitude faster GPU-side](http://supercomputingblog.com/cuda/performance-of-sqrt-in-cuda/), so it's not _that_ bad. I'll keep an eye on updates to the Lumin SDK which might render this operation redundant. A bug report has been filed with Magic Leap.
   *  I say 'likely' because some graphics math libraries use an inverse square root on the dot product of the vector to approximate magnitude while avoiding a square root and a division.
   * For more supplementary fun on this topic, see the legendary [Fast Inverse Square Root](https://en.wikipedia.org/wiki/Fast_inverse_square_root).

## Limitations

* This implementation is naive in that it necessarily assumes that the floor has uniform surface tangents and a consistent vertical position. This approach will work well in most situations (even situations where the floor is uneven but averages out well) but will fail in some such as near stairs or on sloped surfaces.
   * One approach to remedy this limitation is to scattergun ML Raycast API calls and construct a new mesh based on smoothed contact points, then pass this into each shader. That said, at least in my investigations, relying solely on Raycast/Meshing APIs for floor position will lead to small error drifts above actual floor position.

## License

This project is licensed under the [MIT license](https://github.com/davidfoster/magic-leap-floor-detection/blob/develop/LICENSE).