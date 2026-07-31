# MapTilerViewState

`MapTilerViewState` manages the state of a `MapTilerMapView`, including the camera position and
the map design type. It is an `ObservableObject` — changes to its published properties
automatically trigger SwiftUI view updates.

Typically held with `@StateObject` in the parent view and passed to `MapTilerMapView`.

## Signature

```swift
public final class MapTilerViewState: MapViewState<MapTilerMapDesignType>
```

## Initializers

### `init(id:mapDesignType:cameraPosition:)`

Creates an instance with an explicit identifier. Defaults to `MapTilerDesign.DemoTiles`.

```swift
public init(
    id: String,
    mapDesignType: MapTilerMapDesignType = MapTilerDesign.DemoTiles,
    cameraPosition: MapCameraPosition = .Default
)
```

### `init(mapDesignType:cameraPosition:)`

Creates an instance with an auto-generated UUID identifier. Defaults to
`MapTilerDesign.OsmBright`.

```swift
public convenience init(
    mapDesignType: MapTilerMapDesignType = MapTilerDesign.OsmBright,
    cameraPosition: MapCameraPosition = .Default
)
```

**Parameters (shared)**

- `id`
    - Type: `String`
    - Description: A stable identifier for this state instance. The convenience initializer
      generates a `UUID` automatically.
- `mapDesignType`
    - Type: `MapTilerMapDesignType`
    - Description: The initial map style. The designated init defaults to `DemoTiles`; the
      convenience init defaults to `OsmBright`.
- `cameraPosition`
    - Type: `MapCameraPosition`
    - Default: `.Default`
    - Description: The initial camera position (location, zoom, bearing, tilt).

## Properties

- `id` — Type: `String` — The unique identifier of this state instance.
- `cameraPosition` — Type: `MapCameraPosition` — The current camera position. Updated
  automatically as the user pans or zooms the map.
- `mapDesignType` — Type: `MapTilerMapDesignType` — The active map style.

## Methods

### `moveCameraTo(cameraPosition:durationMillis:)`

```swift
public override func moveCameraTo(
    cameraPosition: MapCameraPosition,
    durationMillis: Long? = 0
)
```

### `moveCameraTo(position:durationMillis:)`

```swift
public override func moveCameraTo(
    position: GeoPoint,
    durationMillis: Long? = 0
)
```

**Parameters (shared)**

- `durationMillis`
    - Type: `Long?`
    - Default: `0`
    - Description: Animation duration in milliseconds. `0` or `nil` moves the camera instantly.
