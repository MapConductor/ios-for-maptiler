import Foundation
import MapConductorCore

private let maplibreToGoogleZoomOffset = 1.0

extension ZoomAltitudeConverterProtocol where Self == MapTilerZoomAltitudeConverter {
    static var maplibre: MapTilerZoomAltitudeConverter { MapTilerZoomAltitudeConverter() }
}

/// 統一ズーム（Google Maps 基準・256px タイル）⇄ 高度の変換。
///
/// MapTiler は MapLibre と同じ 512px タイルのベクタエンジンなので、
/// 統一ズームはネイティブズーム + 1。
/// 換算式はコアの ``WebMercatorZoomAltitudeConverter`` にある。
class MapTilerZoomAltitudeConverter: WebMercatorZoomAltitudeConverter {
    init(zoom0Altitude: Double = AbstractZoomAltitudeConverter.defaultZoom0Altitude) {
        super.init(zoom0Altitude: zoom0Altitude, zoomOffset: maplibreToGoogleZoomOffset)
    }

    /// GoogleZoom ≈ MapTilerSDK.zoom + 1.0
    static func maplibreZoomToGoogleZoom(_ zoom: Double) -> Double {
        (zoom + maplibreToGoogleZoomOffset).clamped(to: 0 ... 22)
    }

    static func googleZoomToMaplibreZoom(_ zoom: Double) -> Double {
        (zoom - maplibreToGoogleZoomOffset).clamped(to: 0 ... 22)
    }
}

extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
