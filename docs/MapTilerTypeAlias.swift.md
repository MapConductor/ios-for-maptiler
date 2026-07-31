# MapTilerTypeAlias

Type aliases that map MapTiler SDK concrete types to the generic names used by the SDK's overlay
system.

## Aliases

- `MapTilerActualMarker`
    - Type: `MLNPointFeature`
    - Description: The MapTiler feature type used internally by the marker controller and
      renderer.
- `MapTilerActualPolyline`
    - Type: `MLNPolyline`
    - Description: The MapTiler shape type used for polyline rendering.
- `MapTilerActualCircle`
    - Type: `MLNPolygon`
    - Description: The MapTiler shape type used for circle rendering. Circles are approximated
      as polygons.
- `MapTilerActualPolygon`
    - Type: `MLNPolygon`
    - Description: The MapTiler shape type used for polygon rendering.

## Signature

```swift
public typealias MapTilerActualMarker   = MLNPointFeature
public typealias MapTilerActualPolyline = MLNPolyline
public typealias MapTilerActualCircle   = MLNPolygon
public typealias MapTilerActualPolygon  = MLNPolygon
```
