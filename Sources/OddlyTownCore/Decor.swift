import Foundation

/// Small decorations the user can place in Town Mode. Each has a fixed slot on the
/// town's front row; there is no free-form building.
public enum DecorItem: String, Codable, CaseIterable, Sendable {
    case bench, flowerBox, signpost, sapling, lantern, birdbath, pumpkins, mushrooms

    public var displayName: String {
        switch self {
        case .bench: return "Bench"
        case .flowerBox: return "Flower box"
        case .signpost: return "Signpost"
        case .sapling: return "Sapling"
        case .lantern: return "Lantern"
        case .birdbath: return "Birdbath"
        case .pumpkins: return "Pumpkin patch"
        case .mushrooms: return "Mushrooms"
        }
    }

    public var minimumLevel: Int {
        switch self {
        case .bench, .flowerBox, .signpost: return 1
        case .sapling, .lantern, .birdbath: return 2
        case .pumpkins, .mushrooms: return 3
        }
    }

    /// Residents can sit here.
    public var isSeat: Bool { self == .bench }
}

/// What the user chose in Town Mode: one item (or nothing) per slot, plus
/// decorative features they'd rather not see. Persisted inside `TownState`.
public struct DecorLayout: Codable, Equatable, Sendable {
    public static let slotCount = 4
    /// Features that are purely decorative and may be hidden. Buildings tied to
    /// growth or activity can't be hidden, so progress always stays visible.
    public static let hideableFeatures: Set<TownFeature> = [.youngTree, .picketFence, .wildflowers, .lamppost, .festivalBunting]
    public static let standard = DecorLayout(slots: [.bench, nil, .flowerBox, nil])

    public private(set) var slots: [DecorItem?]
    public private(set) var hiddenFeatures: Set<TownFeature>

    public init(slots: [DecorItem?] = [], hiddenFeatures: Set<TownFeature> = []) {
        self.slots = Self.normalized(slots)
        self.hiddenFeatures = hiddenFeatures.intersection(Self.hideableFeatures)
    }

    public func item(inSlot slot: Int) -> DecorItem? {
        slots.indices.contains(slot) ? slots[slot] : nil
    }

    public mutating func place(_ item: DecorItem?, inSlot slot: Int) {
        guard slots.indices.contains(slot) else { return }
        slots[slot] = item
    }

    public mutating func setHidden(_ hidden: Bool, _ feature: TownFeature) {
        guard Self.hideableFeatures.contains(feature) else { return }
        if hidden { hiddenFeatures.insert(feature) } else { hiddenFeatures.remove(feature) }
    }

    /// Slot → item for items the town's level allows. Locked items stay saved but aren't shown.
    public func visibleItems(level: Int) -> [Int: DecorItem] {
        var result: [Int: DecorItem] = [:]
        for (slot, item) in slots.enumerated() {
            if let item, item.minimumLevel <= level { result[slot] = item }
        }
        return result
    }

    private static func normalized(_ slots: [DecorItem?]) -> [DecorItem?] {
        let trimmed = Array(slots.prefix(slotCount))
        return trimmed + Array(repeating: nil, count: slotCount - trimmed.count)
    }

    private enum CodingKeys: String, CodingKey { case slots, hiddenFeatures }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let rawSlots = (try? c.decodeIfPresent([String?].self, forKey: .slots)) ?? []
        let rawHidden = (try? c.decodeIfPresent([String].self, forKey: .hiddenFeatures)) ?? []
        self.init(
            slots: rawSlots.map { $0.flatMap(DecorItem.init(rawValue:)) },
            hiddenFeatures: Set(rawHidden.compactMap(TownFeature.init(rawValue:)))
        )
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(slots.map { $0?.rawValue }, forKey: .slots)
        try c.encode(hiddenFeatures.map(\.rawValue).sorted(), forKey: .hiddenFeatures)
    }
}
