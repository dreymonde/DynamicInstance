import Foundation

@dynamicMemberLookup
public struct Dynamic<T> {
    fileprivate init(value: T, dynamic: DynamicInstance) {
        self.value = value
        self.dynamic = dynamic
    }

    public var value: T
    public var dynamic: DynamicInstance

    public subscript<V>(dynamicMember keyPath: KeyPath<T, V>) -> V {
        return value[keyPath: keyPath]
    }
}

extension Dynamic where T: Encodable {
    public init(_ value: T) {
        self.value = value
        do {
            let coded = try DynamicInstance.jsonEncoder.encode(value)
            self.dynamic = try DynamicInstance(jsonData: coded)
        } catch {
            self.dynamic = DynamicInstance.empty
        }
    }
}

extension Dynamic where T: Decodable {
    public init(decoding dynamincInstance: DynamicInstance) throws {
        self.dynamic = dynamincInstance
        self.value = try dynamincInstance._decode(T.self)
    }
}

protocol ExplicitlyDynamic { }

extension Dynamic where T: ExplicitlyDynamic {
    subscript<V>(dynamicMember keyPath: KeyPath<DynamicInstance, V>) -> V {
        return self.dynamic[keyPath: keyPath]
    }
}
