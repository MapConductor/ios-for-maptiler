import Combine
import CoreGraphics
import CoreLocation
import Foundation
import MapConductorCore
import MapLibre
import QuartzCore
import Swift
import SwiftUI
import UIKit
import _Concurrency
import _StringProcessing
import _SwiftConcurrencyShims
public protocol MapTilerMapDesignTypeProtocol : MapConductorCore.MapDesignTypeProtocol where Self.Identifier == Swift.String {
  var styleId: Swift.String { get }
}
public typealias MapTilerMapDesignType = any MapConductorForMapTiler.MapTilerMapDesignTypeProtocol
public struct MapTilerDesign : MapConductorForMapTiler.MapTilerMapDesignTypeProtocol, Swift.Hashable {
  public let id: Swift.String
  public let styleId: Swift.String
  public let attributionRules: [MapConductorCore.AttributionRule]
  public init(id: Swift.String, styleId: Swift.String, attributionRules: [MapConductorCore.AttributionRule] = [])
  public func getValue() -> Swift.String
  public static let Streets: MapConductorForMapTiler.MapTilerDesign
  public static let StreetsDark: MapConductorForMapTiler.MapTilerDesign
  public static let StreetsLight: MapConductorForMapTiler.MapTilerDesign
  public static let Basic: MapConductorForMapTiler.MapTilerDesign
  public static let Bright: MapConductorForMapTiler.MapTilerDesign
  public static let Satellite: MapConductorForMapTiler.MapTilerDesign
  public static let Outdoor: MapConductorForMapTiler.MapTilerDesign
  public static let Winter: MapConductorForMapTiler.MapTilerDesign
  public static let Topo: MapConductorForMapTiler.MapTilerDesign
  public static let Toner: MapConductorForMapTiler.MapTilerDesign
  public static let Dataviz: MapConductorForMapTiler.MapTilerDesign
  public static let Backdrop: MapConductorForMapTiler.MapTilerDesign
  public static let Ocean: MapConductorForMapTiler.MapTilerDesign
  public static let Landscape: MapConductorForMapTiler.MapTilerDesign
  public static let Aquarelle: MapConductorForMapTiler.MapTilerDesign
  public static let OpenStreetMap: MapConductorForMapTiler.MapTilerDesign
  public static func == (a: MapConductorForMapTiler.MapTilerDesign, b: MapConductorForMapTiler.MapTilerDesign) -> Swift.Bool
  public typealias Identifier = Swift.String
  public func hash(into hasher: inout Swift.Hasher)
  public var hashValue: Swift.Int {
    get
  }
}
@_Concurrency.MainActor @preconcurrency public struct MapTilerMapView : SwiftUICore.View {
  @_Concurrency.MainActor @preconcurrency public init(state: MapConductorForMapTiler.MapTilerViewState, apiKey: Swift.String? = nil, cameraRestriction: MapConductorCore.CameraRestriction? = nil, onMapLoaded: MapConductorCore.OnMapLoadedHandler<MapConductorForMapTiler.MapTilerViewState>? = nil, onMapClick: MapConductorCore.OnMapEventHandler? = nil, onMapLongClick: MapConductorCore.OnMapEventHandler? = nil, onCameraMoveStart: MapConductorCore.OnCameraMoveHandler? = nil, onCameraMove: MapConductorCore.OnCameraMoveHandler? = nil, onCameraMoveEnd: MapConductorCore.OnCameraMoveHandler? = nil, sdkInitialize: (() -> Swift.Void)? = nil, @MapConductorCore.MapViewContentBuilder content: @escaping () -> MapConductorCore.MapViewContent = { MapViewContent() })
  @_Concurrency.MainActor @preconcurrency public var body: some SwiftUICore.View {
    get
  }
  public typealias Body = @_opaqueReturnTypeOf("$s015MapConductorForA5Tiler0adA4ViewV4bodyQrvp", 0) __
}
public typealias MapTilerActualMarker = MapLibre.MLNPointFeature
public typealias MapTilerActualPolyline = MapLibre.MLNPolyline
public typealias MapTilerActualCircle = MapLibre.MLNPolygon
public typealias MapTilerActualPolygon = MapLibre.MLNPolygon
final public class MapTilerViewState : MapConductorCore.MapViewState<MapConductorForMapTiler.MapTilerMapDesignType> {
  final public var mapViewHolder: MapConductorForMapTiler.MapTilerMapViewHolder? {
    get
  }
  override final public var id: Swift.String {
    get
  }
  override final public var cameraPosition: MapConductorCore.MapCameraPosition {
    get
  }
  override final public var mapDesignType: MapConductorForMapTiler.MapTilerMapDesignType {
    get
    set
  }
  override final public var uiSettings: MapConductorCore.MapUISettings {
    get
    set
  }
  public init(id: Swift.String, mapDesignType: MapConductorForMapTiler.MapTilerMapDesignType = MapTilerDesign.Streets, cameraPosition: MapConductorCore.MapCameraPosition = .Default, uiSettings: MapConductorCore.MapUISettings = MapUISettings())
  convenience public init(mapDesignType: MapConductorForMapTiler.MapTilerMapDesignType = MapTilerDesign.Streets, cameraPosition: MapConductorCore.MapCameraPosition = .Default, uiSettings: MapConductorCore.MapUISettings = MapUISettings())
  override final public func moveCameraTo(cameraPosition: MapConductorCore.MapCameraPosition, durationMillis: MapConductorCore.Long? = 0)
  override final public func fitBounds(bounds: MapConductorCore.GeoRectBounds, padding: Swift.Int)
  override final public func moveCameraTo(position: MapConductorCore.GeoPoint, durationMillis: MapConductorCore.Long? = 0)
  override final public func getMapViewHolder() -> MapConductorCore.AnyMapViewHolder?
  @objc deinit
}
@_hasMissingDesignatedInitializers final public class MapTilerMapViewHolder : MapConductorCore.MapViewHolderProtocol {
  final public let mapView: MapLibre.MLNMapView
  final public let map: MapLibre.MLNMapView
  final public func toScreenOffset(position: any MapConductorCore.GeoPointProtocol) -> CoreFoundation.CGPoint?
  final public func fromScreenOffset(offset: CoreFoundation.CGPoint) async -> MapConductorCore.GeoPoint?
  final public func fromScreenOffsetSync(offset: CoreFoundation.CGPoint) -> MapConductorCore.GeoPoint?
  public typealias ActualMap = MapLibre.MLNMapView
  public typealias ActualMapView = MapLibre.MLNMapView
  @objc deinit
}
extension MapConductorForMapTiler.MapTilerMapView : Swift.Sendable {}
