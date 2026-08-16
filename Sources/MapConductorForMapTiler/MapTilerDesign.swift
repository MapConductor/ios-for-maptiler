import Foundation
import MapConductorCore

public protocol MapTilerMapDesignTypeProtocol: MapDesignTypeProtocol where Identifier == String {
    /// MapTiler Cloud map id (e.g. `streets-v2`, `satellite`).
    var styleId: String { get }
}

public typealias MapTilerMapDesignType = any MapTilerMapDesignTypeProtocol

/// MapTiler map design (a MapTiler Cloud reference style).
///
/// `id` / `getValue()` is the stable key (used for save/restore and as the map
/// re-init trigger); the value actually loaded is the MapTiler style.json for
/// `styleId`, resolved with the view's API key. Mirrors android `MapTilerDesign`
/// and the react `MapTilerDesign` one-to-one (same 16 named designs).
public struct MapTilerDesign: MapTilerMapDesignTypeProtocol, Hashable {
    public let id: String
    public let styleId: String
    public let attributionRules: [AttributionRule]

    public init(id: String, styleId: String, attributionRules: [AttributionRule] = []) {
        self.id = id
        self.styleId = styleId
        self.attributionRules = attributionRules
    }

    public func getValue() -> String {
        "mapDesign_id=\(id),style=\(styleId)"
    }

    public static let Streets = MapTilerDesign(id: "Streets", styleId: "streets-v2")
    public static let StreetsDark = MapTilerDesign(id: "StreetsDark", styleId: "streets-v2-dark")
    public static let StreetsLight = MapTilerDesign(id: "StreetsLight", styleId: "streets-v2-light")
    public static let Basic = MapTilerDesign(id: "Basic", styleId: "basic-v2")
    public static let Bright = MapTilerDesign(id: "Bright", styleId: "bright-v2")
    public static let Satellite = MapTilerDesign(id: "Satellite", styleId: "satellite")
    public static let Outdoor = MapTilerDesign(id: "Outdoor", styleId: "outdoor-v2")
    public static let Winter = MapTilerDesign(id: "Winter", styleId: "winter-v2")
    public static let Topo = MapTilerDesign(id: "Topo", styleId: "topo-v2")
    public static let Toner = MapTilerDesign(id: "Toner", styleId: "toner-v2")
    public static let Dataviz = MapTilerDesign(id: "Dataviz", styleId: "dataviz")
    public static let Backdrop = MapTilerDesign(id: "Backdrop", styleId: "backdrop")
    public static let Ocean = MapTilerDesign(id: "Ocean", styleId: "ocean")
    public static let Landscape = MapTilerDesign(id: "Landscape", styleId: "landscape")
    public static let Aquarelle = MapTilerDesign(id: "Aquarelle", styleId: "aquarelle")
    public static let OpenStreetMap = MapTilerDesign(id: "OpenStreetMap", styleId: "openstreetmap")

    /// Every SDK-provided design (used by the design selector page and by `fromId`).
    public static let all: [MapTilerDesign] = [
        Streets, StreetsDark, StreetsLight, Basic, Bright, Satellite, Outdoor, Winter,
        Topo, Toner, Dataviz, Backdrop, Ocean, Landscape, Aquarelle, OpenStreetMap,
    ]

    /// Restores a design from a saved `id`; falls back to ``Streets`` when unknown.
    ///
    /// The React Native bridge sends the bare `id` (not `getValue()`), so this is the
    /// only lookup on that path. Mirrors android `MapTilerDesign.fromId` and
    /// ``LongdoDesign/fromId(_:)`` one-to-one.
    public static func fromId(_ id: String?) -> MapTilerDesign {
        all.first { $0.id == id } ?? Streets
    }
}

/// Builds the MapTiler Cloud style.json URL for a map id and API key.
///
/// MapTiler serves MapLibre GL styles from
/// `https://api.maptiler.com/maps/<id>/style.json?key=<key>`. The key is
/// required for the tiles to load. Module-internal (not part of the public API),
/// mirroring the react provider where the URL builder is not exported.
func mapTilerStyleJsonURL(styleId: String, apiKey: String) -> String {
    "https://api.maptiler.com/maps/\(styleId)/style.json?key=\(apiKey)"
}
