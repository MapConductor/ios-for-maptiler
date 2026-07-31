# MapTilerMapView

A SwiftUI view that renders a MapTiler map. Accepts a declarative overlay tree via
`@MapViewContentBuilder`. No API key or SDK initialization is required.

## Signature

```swift
public struct MapTilerMapView: View {
    public init(
        state: MapTilerViewState,
        onMapLoaded: OnMapLoadedHandler<MapTilerViewState>? = nil,
        onMapClick: OnMapEventHandler? = nil,
        onCameraMoveStart: OnCameraMoveHandler? = nil,
        onCameraMove: OnCameraMoveHandler? = nil,
        onCameraMoveEnd: OnCameraMoveHandler? = nil,
        @MapViewContentBuilder content: @escaping () -> MapViewContent = { MapViewContent() }
    )
}
```

## Parameters

- `state`
    - Type: `MapTilerViewState`
    - Description: The observable state object controlling camera position and map design.
      Hold with `@StateObject` in the parent view.
- `onMapLoaded`
    - Type: `OnMapLoadedHandler<MapTilerViewState>?`
    - Default: `nil`
    - Description: Called once when the map finishes loading. Receives the `MapTilerViewState`.
- `onMapClick`
    - Type: `OnMapEventHandler?`
    - Default: `nil`
    - Description: Called with the tapped geographic coordinate when the user taps the map.
- `onCameraMoveStart`
    - Type: `OnCameraMoveHandler?`
    - Default: `nil`
    - Description: Called with the camera position when a camera movement begins.
- `onCameraMove`
    - Type: `OnCameraMoveHandler?`
    - Default: `nil`
    - Description: Called continuously with the current camera position during movement.
- `onCameraMoveEnd`
    - Type: `OnCameraMoveHandler?`
    - Default: `nil`
    - Description: Called with the final camera position when movement ends.
- `content`
    - Type: `@MapViewContentBuilder () -> MapViewContent`
    - Default: empty
    - Description: Declarative overlay tree. Supports `Marker`, `Polyline`, `Polygon`,
      `Circle`, `GroundImage`, `RasterLayer`, `InfoBubble`, and `ForArray`.

## Notes

- `MapTilerMapView` does **not** have an `sdkInitialize` parameter. MapTiler requires no API key.

## Example

```swift
import MapConductorForMapTiler
import SwiftUI

struct MyMapScreen: View {
    @StateObject private var mapState = MapTilerViewState(
        mapDesignType: MapTilerDesign.OsmBright,
        cameraPosition: MapCameraPosition(
            position: GeoPoint(latitude: 35.6812, longitude: 139.7671),
            zoom: 13.0
        )
    )

    var body: some View {
        MapTilerMapView(state: mapState)
            .ignoresSafeArea()
    }
}
```
