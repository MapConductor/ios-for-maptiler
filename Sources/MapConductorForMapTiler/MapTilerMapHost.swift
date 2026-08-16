import Combine
import Foundation
import MapConductorCore
import MapLibre
import SwiftUI
import UIKit

/// SwiftUI を通さないホストからも MapTiler の地図を使うための入口。
///
/// `MapTilerMapView` の `Coordinator` をそのまま切り出したもの。SwiftUI の
/// `UIViewRepresentable` は薄いラッパーになり、React Native の
/// `reactnative-for-maptiler` はこのクラスを直接使う。
/// `MapLibreMapHost` / `LongdoMapHost` と同じ位置づけ。
///
/// `@_spi(MapConductorDriver)` なのでアプリ向けの凍結 API には載らない
/// （`scripts/api-surface.sh` が見る `.swiftinterface` に SPI は出ない）。
@_spi(MapConductorDriver)
@MainActor
public final class MapTilerMapHost: MapViewCoordinatorBase<MapTilerViewState>, MLNMapViewDelegate {
    /// 明示された鍵が無ければ Info.plist の `MapTilerAPIKey` を使う。
    /// android は AndroidManifest の `MAPTILER_API_KEY` を同じ位置づけで読む。
    ///
    /// `$(...)` を含む値は**展開されなかったビルド設定のプレースホルダ**なので弾く。
    /// そのまま鍵として使うとスタイル URL が 403 になり、「地図が真っ白」という
    /// 原因の分かりにくい形でしか出ない。`LongdoInitSDK.resolveApiKey` と同じ扱い。
    public static func resolveApiKey(_ explicit: String?) -> String {
        if let explicit, !explicit.isEmpty { return explicit }
        guard let value = Bundle.main.object(forInfoDictionaryKey: "MapTilerAPIKey") as? String,
              !value.isEmpty,
              !value.contains("$(")
        else { return "" }
        return value
    }

    /// このホストが持っている API キー（`makeMapView` で決まる）。
    private var resolvedApiKey: String = ""

    /// 地図を作り、デリゲート・初期カメラ・ジェスチャ・バインドまで済ませて返す。
    ///
    /// SwiftUI の `makeUIView` が踏んでいた手順をそのまま公開したもので、
    /// React Native のような非 SwiftUI ホストも**同じ入口を通ること**。
    ///
    /// **`bind(state:mapView:)` と `mapView.delegate = self` を落とさないこと。**
    /// この 2 つが無くてもコンパイルは通り、地図もタイルも普通に描画される。
    /// 死ぬのはカメライベントとオーバーレイだけなので、画面を見ても気づけない
    /// （実機の CameraRestrictionUITests が `cameraReadout` 未更新で検出した）。
    public func makeMapView(
        apiKey: String?,
        cameraRestriction: CameraRestriction?,
        content: MapViewContent
    ) -> MLNMapView {
        if let sdkInitialize = handlers.sdkInitialize {
            Self.runOnce(sdkInitialize)
        }
        resolvedApiKey = Self.resolveApiKey(apiKey)

        let mapView = MLNMapView(frame: .zero)
        // スタイル URL より先にデリゲートを入れる。キャッシュ済みスタイルは即座に
        // 読み込みが終わることがあり、その通知を取り逃すとオーバーレイが待ちっぱなしになる。
        mapView.delegate = self
        // Retina では実解像度で描く（MapTiler はタイルもシンボルもビューの
        // pixel ratio を見る）。
        mapView.contentScaleFactor = UIScreen.main.scale
        mapView.layer.contentsScale = UIScreen.main.scale
        applyStyleIfNeeded(to: mapView)
        // 親タイルの先読みと描画済みタイルのキャッシュ。マーカーのラスタタイルは
        // URL に `version` を持ち、マーカーが変わるたびに上がる
        // （`MapTilerMarkerController.updateTileLayer`）ので、キャッシュが古くなることはない。
        mapView.prefetchesTiles = true
        mapView.tileCacheEnabled = true
        mapView.isScrollEnabled = state.uiSettings.scrollGesture
        mapView.isZoomEnabled = state.uiSettings.zoomGesture
        mapView.isRotateEnabled = state.uiSettings.rotateGesture
        mapView.isPitchEnabled = state.uiSettings.tiltGesture
        let initialCameraState = state.cameraPosition.toMapTilerCameraState()
        // pitch を先に、zoom を後に。逆にすると傾けるたびに地図が遠ざかる
        // （`MapTilerViewController.moveCamera` のコメント参照）。
        let initialCamera = mapView.camera
        initialCamera.centerCoordinate = initialCameraState.center
        initialCamera.heading = initialCameraState.bearing
        initialCamera.pitch = initialCameraState.tilt
        mapView.setCamera(initialCamera, animated: false)
        mapView.setCenter(
            initialCameraState.center,
            zoomLevel: initialCameraState.zoom,
            direction: initialCameraState.bearing,
            animated: false
        )

        let tapGesture = UITapGestureRecognizer(
            target: self,
            action: #selector(MapTilerMapHost.handleMapTap(_:))
        )
        tapGesture.cancelsTouchesInView = false
        mapView.addGestureRecognizer(tapGesture)

        let longPressGesture = UILongPressGestureRecognizer(
            target: self,
            action: #selector(MapTilerMapHost.handleMarkerLongPress(_:))
        )
        longPressGesture.minimumPressDuration = 0.2
        mapView.addGestureRecognizer(longPressGesture)

        attachInfoBubbleContainer(to: mapView)
        self.mapView = mapView
        bind(state: state, mapView: mapView)
        // android-sdk の MapView がコントローラ生成直後に setCameraRestriction するのと同じ位置。
        applyCameraRestriction(cameraRestriction)
        // Ensure overlay controllers subscribe immediately (before the first updateUIView),
        // so early UI actions (e.g. tapping animation buttons) are not missed.
        MCLog.map("MapTilerMapHost.makeMapView updateContent markers=\(content.markers.count) bubbles=\(content.infoBubbles.count)")
        updateContent(content)
        updateInfoBubbleLayouts()
        return mapView
    }

    /// `updateUIView` のうち、ネイティブビューへ直接書いていた分。
    ///
    /// ジェスチャとスタイル URL はコントローラ経由ではなくここで適用する。SwiftUI の同期フックは
    /// 常にネイティブビューを持っているのに対し、コントローラはまだ生成されていない／まだ
    /// mapView を保持していないことがあり、その場合に設定が落ちる（実機の UISettingsUITests が
    /// MapLibre/MapTiler/Mapbox で検出）。非 SwiftUI ホストは state を変えたあとに自分で呼ぶ。
    public func syncNativeViewSettings(cameraRestriction: CameraRestriction? = nil) {
        guard let mapView else { return }
        mapView.contentScaleFactor = UIScreen.main.scale
        mapView.layer.contentsScale = UIScreen.main.scale
        applyStyleIfNeeded(to: mapView)
        mapView.isScrollEnabled = state.uiSettings.scrollGesture
        mapView.isZoomEnabled = state.uiSettings.zoomGesture
        mapView.isRotateEnabled = state.uiSettings.rotateGesture
        mapView.isPitchEnabled = state.uiSettings.tiltGesture
        // 制限値が変わったときだけ再適用する（毎フレーム native API を叩かない）。
        applyCameraRestriction(cameraRestriction)
    }

    /// デザインが実際に変わったときだけスタイルを差し替える。
    ///
    /// MapLibre 版は `mapView.styleURL != styleURL` で比較しているが、ここではできない。
    /// **MapTiler のスタイル URL は `?key=` を持つため**、`styleURL` ゲッタの正規化で
    /// 毎フレーム不一致になり、スタイルごと（マーカーも含めて）読み直してマーカー多数の
    /// ズームが極端に遅くなる。比較は `styleId` で行う。
    private func applyStyleIfNeeded(to mapView: MLNMapView) {
        guard state.mapDesignType.styleId != appliedStyleId else { return }
        guard let url = URL(
            string: mapTilerStyleJsonURL(styleId: state.mapDesignType.styleId, apiKey: resolvedApiKey)
        ) else { return }
        mapView.styleURL = url
        appliedStyleId = state.mapDesignType.styleId
    }

    weak var mapView: MLNMapView?
    // updateUIView から applyUISettings を呼ぶため private を外している。
    private(set) var controller: MapTilerViewController?
    private var markerController: MapTilerMarkerController?
    private var groundImageController: MapTilerGroundImageController?
    private var rasterController: MapTilerRasterLayerController?
    private var circleController: MapTilerCircleController?
    private var polylineController: MapTilerPolylineController?
    private var polygonController: MapTilerPolygonController?
    private var hullPolygonController: MapTilerPolygonController?
    private var overlayScope: MapOverlayScope?
    private var infoBubbleCoordinator: InfoBubbleOverlayCoordinator?
    private lazy var strategyManager = StrategyMarkerManager<MLNPointFeature, MapTilerMarkerRenderer>(
        makeRenderer: { [weak self] strategy in
            guard let mapView = self?.mapView else { fatalError("mapView unavailable") }
            let layer = MarkerLayer(
                sourceId: "mapconductor-cluster-source-\(UUID().uuidString)",
                layerId: "mapconductor-cluster-layer-\(UUID().uuidString)"
            )
            return MapTilerMarkerRenderer(mapView: mapView, markerManager: strategy.markerManager, markerLayer: layer)
        },
        shouldAddMarkers: { [weak self] in self?.isStyleLoaded ?? false },
        currentCamera: { [weak self] in
            guard let self, let mapView = self.mapView else { return nil }
            return self.currentCameraPosition(from: mapView)
        }
    )
    private var isStyleLoaded = false
    /// android-sdk の `cameraRestriction?.let { controller.setCameraRestriction(it) }` 相当。
    /// 変化検知は `MapViewCoordinatorBase.applyCameraRestriction(_:to:)` が行う。
    public func applyCameraRestriction(_ restriction: CameraRestriction?) {
        applyCameraRestriction(restriction, to: controller)
    }
    private weak var loadedStyle: MLNStyle?

    /// The `styleId` currently applied to the map view. Used to reset the
    /// style only when the design changes (see updateUIView), not every frame.
    var appliedStyleId: String?

    func bind(state: MapTilerViewState, mapView: MLNMapView) {
        // A strategy can be connected after mapViewDidFinishLoadingMap (the plugin drives
        // this now, during content assembly), so a freshly created renderer has to be given
        // the already-loaded style instead of waiting for a style callback that has passed.
        strategyManager.onRendererCreated = { [weak self] renderer in
            guard let self, self.isStyleLoaded, let style = self.mapView?.style else { return }
            renderer.onStyleLoaded(style)
            self.strategyManager.flush()
        }
        // Publish marker rendering as a map-scoped capability. Add-on modules resolve it
        // from the registry; this provider never learns that clustering exists.
        state.serviceRegistry.put(MarkerRenderingSupportKey.self, strategyManager)

        let controller = MapTilerViewController(mapView: mapView)
        self.controller = controller
        state.setController(controller)
        // 拡張モジュール（ヒートマップ等）がオーバーレイコントローラを登録できるようにする。
        state.serviceRegistry.put(OverlayControllerRegistryKey.self, controller.overlayControllers)
        state.setMapViewHolder(controller.typedHolder)

        let markerController = MapTilerMarkerController(mapView: mapView) { [weak self] id in
            self?.infoBubbleCoordinator?.updateInfoBubblePosition(for: id)
        }
        self.markerController = markerController

        let groundImageController = MapTilerGroundImageController(mapView: mapView)
        self.groundImageController = groundImageController

        let rasterController = MapTilerRasterLayerController(mapView: mapView)
        self.rasterController = rasterController

        let circleController = MapTilerCircleController(mapView: mapView)
        self.circleController = circleController

        let polylineController = MapTilerPolylineController(mapView: mapView)
        self.polylineController = polylineController

        let polygonController = MapTilerPolygonController(mapView: mapView)
        self.polygonController = polygonController
        self.hullPolygonController = MapTilerPolygonController(mapView: mapView)

        // クリックカスケードとスロット解決がここから kind で引く。
        // **登録を忘れるとタップに反応しなくなる。**
        controller.registerOverlayController(markerController)
        controller.registerOverlayController(circleController)
        controller.registerOverlayController(polylineController)
        controller.registerOverlayController(polygonController)
        controller.registerOverlayController(groundImageController)
        controller.registerOverlayController(rasterController)

        let overlayScope = MapOverlayScope()
        self.overlayScope = overlayScope
        bindOverlayCollector(overlayScope.circleCollector, to: circleController)
        bindOverlayCollector(overlayScope.polylineCollector, to: polylineController)
        bindOverlayCollector(overlayScope.polygonCollector, to: polygonController)
        bindOverlayCollector(overlayScope.rasterLayerCollector, to: rasterController)
        // GroundImage is not a core GroundImageController subclass on MapTiler,
        // so it stays on its own sync path (below), not the collector.

        if let loadedStyle {
            applyLoadedStyle(loadedStyle)
        }
        self.infoBubbleCoordinator = InfoBubbleOverlayCoordinator(
            container: infoBubbleContainer,
            project: { [weak self] point in
                guard let mapView = self?.mapView else { return nil }
                let coordinate = CLLocationCoordinate2D(latitude: point.latitude, longitude: point.longitude)
                return mapView.convert(coordinate, toPointTo: mapView)
            },
            projectionGate: screenProjectionGate(feature: "InfoBubble"),
            resolveMarkerStateForIcon: { [weak markerController] id, bubbleMarker in
                markerController?.getMarkerState(for: id) ?? bubbleMarker
            },
            iconMetrics: { [weak markerController] markerState in
                let icon = markerController?.getIcon(for: markerState) ?? (markerState.icon ?? DefaultMarkerIcon()).toBitmapIcon()
                return MarkerIconMetrics(size: icon.size, anchor: icon.anchor, infoAnchor: icon.infoAnchor)
            }
        )

        // Screen-space marker animation layer: shares the info-bubble
        // container (inserted below the bubbles) and the map projection.
        markerController.renderer.animationOverlay = MarkerAnimationOverlayCoordinator(
            container: infoBubbleContainer,
            project: { [weak self] point in
                guard let mapView = self?.mapView else { return nil }
                let coordinate = CLLocationCoordinate2D(latitude: point.latitude, longitude: point.longitude)
                let p = mapView.convert(coordinate, toPointTo: mapView)
                return (p.x.isFinite && p.y.isFinite) ? p : nil
            },
            projectionGate: screenProjectionGate(feature: "marker animation overlay")
        )
    }

    public func unbind() {
        // 登録した capability を取り下げる。レジストリの持ち主は state で、ビューより長生きするため、
        // ここで外さないと破棄済みのコントローラを掴んだまま残る。
        state.serviceRegistry.removeProviderRegistrations()
        markerController?.renderer.animationOverlay?.unbind()
        markerController?.renderer.animationOverlay = nil
        // 登録済みオーバーレイコントローラ（拡張モジュール含む）を破棄する。
        controller?.destroy()
        state.setController(nil)
        state.setMapViewHolder(nil)
        controller = nil
        markerController?.unbind()
        markerController = nil
        groundImageController?.unbind()
        groundImageController = nil
        rasterController?.unbind()
        rasterController = nil
        circleController?.unbind()
        circleController = nil
        polylineController?.unbind()
        polylineController = nil
        polygonController?.unbind()
        polygonController = nil
        hullPolygonController?.unbind()
        hullPolygonController = nil
        overlayScope?.clear()
        overlayScope = nil
        infoBubbleCoordinator?.unbind()
        infoBubbleCoordinator = nil
        strategyManager.clear()
        isStyleLoaded = false
        loadedStyle = nil
    }

    public func updateContent(_ content: MapViewContent) {
        if let mapView {
            polylineController?.setCurrentCameraPosition(currentCameraPosition(from: mapView))
        }
        infoBubbleCoordinator?.syncInfoBubbles(content.infoBubbles)
        markerController?.tilingOptions = content.markerTilingOptions
        markerController?.syncMarkers(content.markers)
        groundImageController?.syncGroundImages(content.groundImages)
        overlayScope?.rasterLayerCollector.sync(content.rasterLayers.map { $0.state })
        overlayScope?.circleCollector.sync(content.circles.map { $0.state })
        overlayScope?.polylineCollector.sync(content.polylines.map { $0.state })
        overlayScope?.polygonCollector.sync(content.polygons.map { $0.state })
        for handler in content.polygonSyncHandlers {
            let hullController = hullPolygonController
            handler.bindPolygonSync { [weak hullController] states in
                await hullController?.add(data: states)
            }
        }
        infoBubbleCoordinator?.updateAllLayouts()
    }

    // MARK: - MLNMapViewDelegate

    public func mapView(_ mapView: MLNMapView, didFinishLoading style: MLNStyle) {
        isStyleLoaded = true
        loadedStyle = style
        applyLoadedStyle(style)
    }

    private func applyLoadedStyle(_ style: MLNStyle) {
        groundImageController?.onStyleLoaded(style)
        rasterController?.onStyleLoaded(style)
        polygonController?.onStyleLoaded(style)
        hullPolygonController?.onStyleLoaded(style)
        polylineController?.onStyleLoaded(style)
        circleController?.onStyleLoaded(style)
        markerController?.onStyleLoaded(style)
        // Re-emit collector-routed overlays now the style is ready, in case
        // add() ran before load (idempotent). Parity with Mapbox.
        overlayScope?.rasterLayerCollector.flush()
        overlayScope?.circleCollector.flush()
        overlayScope?.polylineCollector.flush()
        overlayScope?.polygonCollector.flush()
        strategyManager.renderer?.onStyleLoaded(style)
        strategyManager.flush()
    }

    public func mapViewDidFinishLoadingMap(_ mapView: MLNMapView) {
        performMapLoadedOnce {
            controller?.notifyMapInitialized()
            onMapLoaded?(state)
        }
        updateInfoBubbleLayouts()
    }

    /// ジェスチャーによるカメラ変更を範囲制限で拒否する（MapLibre と同じ仕組み）。
    /// このデリゲートはプログラム的なカメラ変更では呼ばれないため、そちらは
    /// `regionDidChangeAnimated` 側のクランプが担当する。
    public func mapView(
        _ mapView: MLNMapView,
        shouldChangeFrom oldCamera: MLNMapCamera,
        to newCamera: MLNMapCamera,
        reason: MLNCameraChangeReason
    ) -> Bool {
        controller?.shouldAllowGestureCameraChange(
            from: oldCamera.centerCoordinate,
            to: newCamera.centerCoordinate
        ) ?? true
    }

    public func mapView(_ mapView: MLNMapView, regionWillChangeAnimated animated: Bool) {
        let camera = currentCameraPosition(from: mapView)
        polylineController?.setCurrentCameraPosition(camera)
        controller?.notifyCameraMoveStart(camera)
        onCameraMoveStart?(camera)
        // Removed async Task calls to prevent crashes
        // Geometry layers don't need to respond to camera changes
        Task { [weak self] in
            await self?.strategyManager.onCameraChanged(camera)
        }
        updateInfoBubbleLayouts()
    }

    public func mapViewRegionIsChanging(_ mapView: MLNMapView) {
        let camera = currentCameraPosition(from: mapView)
        state.updateCameraPosition(camera)
        polylineController?.setCurrentCameraPosition(camera)
        controller?.notifyCameraMove(camera)
        onCameraMove?(camera)
        // Removed async Task calls to prevent crashes
        // Geometry layers don't need to respond to camera changes
        Task { [weak self] in
            await self?.strategyManager.onCameraChanged(camera)
        }
        updateInfoBubbleLayouts()
    }

    public func mapView(_ mapView: MLNMapView, regionDidChangeAnimated animated: Bool) {
        let camera = currentCameraPosition(from: mapView)
        // パン範囲の制限に違反していれば矩形内へ引き戻す（MapTiler(MapLibre) iOS には
        // ネイティブの範囲制限 API が無いため）。再適用すると regionDidChange が再発火し、
        // そこでは補正不要になり通常フローへ進む。
        if controller?.applyCameraRestrictionCorrectionIfNeeded(camera) == true { return }
        state.updateCameraPosition(camera)
        polylineController?.setCurrentCameraPosition(camera)
        controller?.notifyCameraMoveEnd(camera)
        onCameraMoveEnd?(camera)
        // Removed async Task calls to prevent crashes
        // Geometry layers don't need to respond to camera changes
        Task { [weak self] in
            await self?.strategyManager.onCameraChanged(camera)
        }
        updateInfoBubbleLayouts()
    }

    @objc func handleMapTap(_ recognizer: UITapGestureRecognizer) {
        guard let mapView = mapView, recognizer.state == .ended else { return }
        let point = recognizer.location(in: mapView)

        // Ensure polyline hit-testing uses the current zoom even if no region-change callbacks have fired yet.
        polylineController?.setCurrentCameraPosition(currentCameraPosition(from: mapView))

        if markerController?.handleTap(at: point) == true {
            updateInfoBubbleLayouts()
            return
        }
        if handleStrategyTap(at: point) {
            updateInfoBubbleLayouts()
            return
        }

        let coordinate = mapView.convert(point, toCoordinateFrom: mapView)
        let geoPoint = GeoPoint(latitude: coordinate.latitude, longitude: coordinate.longitude, altitude: 0)
        // circle → groundImage → polyline → polygon の一本道。
        // 順序と先勝ちはコアの dispatchOverlayTap が持つ。
        // 移行前はここで circle → polyline → polygon → groundImage の独自順だった。
        if controller?.dispatchOverlayTap(position: geoPoint) == true {
            updateInfoBubbleLayouts()
            return
        }
        controller?.notifyMapClick(geoPoint)
        onMapClick?(geoPoint)
    }

    @objc func handleMarkerLongPress(_ recognizer: UILongPressGestureRecognizer) {
        let handledByMarker = markerController?.handleLongPress(recognizer) ?? false
        if !handledByMarker, recognizer.state == .began, let mapView {
            let point = recognizer.location(in: mapView)
            let coordinate = mapView.convert(point, toCoordinateFrom: mapView)
            let geoPoint = GeoPoint(latitude: coordinate.latitude, longitude: coordinate.longitude, altitude: 0)
            controller?.notifyMapLongClick(geoPoint)
            onMapLongClick?(geoPoint)
        }
        updateInfoBubbleLayouts()
    }

    // MARK: - Helper Methods

    private func currentCameraPosition(from mapView: MLNMapView) -> MapCameraPosition {
        let visibleBounds = mapView.visibleCoordinateBounds
        let bounds = GeoRectBounds(
            southWest: GeoPoint(
                latitude: visibleBounds.sw.latitude,
                longitude: visibleBounds.sw.longitude,
                altitude: 0
            ),
            northEast: GeoPoint(
                latitude: visibleBounds.ne.latitude,
                longitude: visibleBounds.ne.longitude,
                altitude: 0
            )
        )
        // 4 隅の逆投影は全プロバイダ共通なのでコアの buildVisibleRegion を使う。
        // bounds だけはネイティブの visibleCoordinateBounds の方が正確なので差し替える。
        let corners = MapTilerMapViewHolder(mapView: mapView).buildVisibleRegion()
        let visibleRegion = VisibleRegion(
            bounds: bounds,
            nearLeft: corners?.nearLeft,
            nearRight: corners?.nearRight,
            farLeft: corners?.farLeft,
            farRight: corners?.farRight
        )
        return mapView.toMapCameraPosition(
            logicalTiltHint: controller?.lastLogicalTilt,
            visibleRegion: visibleRegion
        )
    }

    public func updateInfoBubbleLayouts() {
        infoBubbleCoordinator?.updateAllLayouts()
    }

    private func handleStrategyTap(at point: CGPoint) -> Bool {
        guard let markerId = strategyManager.renderer?.markerId(at: point),
              let state = strategyManager.controller?.markerManager.getEntity(markerId)?.state,
              state.clickable else { return false }
        strategyManager.controller?.dispatchClick(state)
        return true
    }

    private func geoPoint(at point: CGPoint, mapView: MLNMapView) -> GeoPoint? {
        guard !mapView.bounds.isEmpty else { return nil }
        let coordinate = mapView.convert(point, toCoordinateFrom: mapView)
        return GeoPoint(latitude: coordinate.latitude, longitude: coordinate.longitude, altitude: 0)
    }
}

