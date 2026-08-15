import Combine
import Foundation
import MapConductorCore
import MapLibre
import SwiftUI
import UIKit

public struct MapTilerMapView: View {
    @ObservedObject private var state: MapTilerViewState

    private let apiKey: String?
    private let handlers: MapViewHandlers<MapTilerViewState>
    private let cameraRestriction: CameraRestriction?
    private let content: () -> MapViewContent

    /// - Parameter apiKey: MapTiler Cloud API key. If `nil`, it is read from the
    ///   app's Info.plist under the `MapTilerAPIKey` key.
    public init(
        state: MapTilerViewState,
        apiKey: String? = nil,
        cameraRestriction: CameraRestriction? = nil,
        onMapLoaded: OnMapLoadedHandler<MapTilerViewState>? = nil,
        onMapClick: OnMapEventHandler? = nil,
        onMapLongClick: OnMapEventHandler? = nil,
        onCameraMoveStart: OnCameraMoveHandler? = nil,
        onCameraMove: OnCameraMoveHandler? = nil,
        onCameraMoveEnd: OnCameraMoveHandler? = nil,
        sdkInitialize: (() -> Void)? = nil,
        @MapViewContentBuilder content: @escaping () -> MapViewContent = { MapViewContent() }
    ) {
        self.state = state
        self.apiKey = apiKey
        self.handlers = MapViewHandlers(
            onMapLoaded: onMapLoaded,
            onMapClick: onMapClick,
            onMapLongClick: onMapLongClick,
            onCameraMoveStart: onCameraMoveStart,
            onCameraMove: onCameraMove,
            onCameraMoveEnd: onCameraMoveEnd,
            sdkInitialize: sdkInitialize
        )
        self.cameraRestriction = cameraRestriction
        self.content = content
    }

    public var body: some View {
        // The provider's registry is in scope only while content is being assembled —
        // the same window in which Compose provides `LocalMapServiceRegistry` around the
        // content lambda. Bracketing the pass lets a removed plugin be noticed.
        let support = state.serviceRegistry.get(MarkerRenderingSupportKey.self)
        support?.beginContentPass()
        let mapContent = MapServiceRegistryScope.with(state.serviceRegistry) { content() }
        support?.endContentPass()
        return MapViewBase(
            attributionRules: state.mapDesignType.attributionRules,
            camera: state.cameraPosition,
            content: mapContent
        ) {
            MapTilerMapViewRepresentable(
                state: state,
                cameraRestriction: cameraRestriction,
                apiKey: apiKey,
                handlers: handlers,
                content: mapContent
            )
        }
    }
}

/// SwiftUI 側は薄いラッパー。実装は `MapTilerMapHost` にあり、
/// `reactnative-for-maptiler` も同じホストを使う。**手順を二重に持たないこと。**
private struct MapTilerMapViewRepresentable: UIViewRepresentable {
    @ObservedObject var state: MapTilerViewState
    let cameraRestriction: CameraRestriction?

    let apiKey: String?
    let handlers: MapViewHandlers<MapTilerViewState>
    let content: MapViewContent

    func makeCoordinator() -> MapTilerMapHost {
        MapTilerMapHost(state: state, handlers: handlers)
    }

    func makeUIView(context: Context) -> MLNMapView {
        context.coordinator.makeMapView(
            apiKey: apiKey,
            cameraRestriction: cameraRestriction,
            content: content
        )
    }

    func updateUIView(_ uiView: MLNMapView, context: Context) {
        context.coordinator.syncNativeViewSettings(cameraRestriction: cameraRestriction)
        MCLog.map("MapTilerMapView.updateUIView updateContent markers=\(content.markers.count) bubbles=\(content.infoBubbles.count)")
        context.coordinator.updateContent(content)
        context.coordinator.updateInfoBubbleLayouts()
    }

    static func dismantleUIView(_ uiView: MLNMapView, coordinator: MapTilerMapHost) {
        coordinator.unbind()
        uiView.delegate = nil
    }
}
