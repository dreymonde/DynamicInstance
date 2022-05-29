import Foundation

@dynamicMemberLookup
public enum DynamicInstance {
    case object(Any)
    case empty
    
    public var _dictionary: [String: DynamicInstance]? {
        _rawDictionary?.mapValues(DynamicInstance.object)
    }
    
    public var _alwaysDictionary: [String: DynamicInstance] {
        _dictionary ?? [:]
    }

    public var _rawDictionary: [String: Any]? {
        switch self {
        case .object(let obj):
            return obj as? [String: Any]
        case .empty:
            return nil
        }
    }

    public var _array: [DynamicInstance]? {
        return _rawArray?.map(DynamicInstance.object)
    }
    
    public var _alwaysArray: [DynamicInstance] {
        _array ?? []
    }
    
    public var _rawArray: [Any]? {
        switch self {
        case .object(let obj):
            if let array = obj as? [Any] {
                return array
            } else {
                return nil
            }
        default:
            return nil
        }
    }

    public var _raw: Any? {
        switch self {
        case .object(let obj):
            return obj
        case .empty:
            return nil
        }
    }
    
    public init(_ raw: Any) {
        assert(raw is DynamicInstance == false, "don't create DynamicInstance from another DynamicInstance")
        self = .object(raw)
    }

    public init(_ dictionary: [String: Any]) {
        assert(dictionary.compactMapValues({ $0 as? DynamicInstance }).isEmpty, "don't create DynamicInstance from another DynamicInstance")
        self = .object(dictionary)
    }

    public init(jsonData data: Data, options: JSONSerialization.ReadingOptions = []) throws {
        let obj = try JSONSerialization.jsonObject(with: data, options: options.union(.allowFragments))
        self = .object(obj)
    }
    
    public init(jsonString: String, options: JSONSerialization.ReadingOptions = []) throws {
        let data = jsonString.data(using: .utf8) ?? .init()
        try self.init(jsonData: data, options: options)
    }

    public func _at(_ key: String) -> DynamicInstance {
        if let value = _rawDictionary?[key] {
            return .object(value)
        } else {
            return .empty
        }
    }

    public mutating func _set(_ value: Any?, forKey key: String) {
        guard (value is DynamicInstance) == false else {
            assertionFailure("Use ._raw on the instance before setting")
            return
        }
        if var dict = _rawDictionary {
            dict[key] = value
            self = .object(dict)
        } else if case .empty = self {
            var newDict: [String: Any] = [:]
            newDict[key] = value
            self = .object(newDict)
        }
    }

    public subscript(dynamicMember member: String) -> DynamicInstance {
        get {
            _at(member)
        }
        set {
            _set(newValue._raw, forKey: member)
        }
    }
    
    public subscript(key: String) -> DynamicInstance {
        get {
            _at(key)
        }
        set {
            _set(newValue._raw, forKey: key)
        }
    }

    public subscript(index: Int) -> DynamicInstance {
        get {
            if let array = _raw as? [Any], index < array.count {
                return .object(array[index])
            } else {
                return .empty
            }
        }
        set {
            guard let object = newValue._raw else {
                return
            }
            guard var array = _rawArray else {
                return
            }
            let count = array.count
            if index < count {
                array[index] = object
                self = .object(array)
            } else if index == count {
                array.append(object)
                self = .object(array)
            } else {
                return
            }
        }
    }

    public func _as<T>(_ type: T.Type = T.self) -> T? {
        switch self {
        case .object(let obj):
            return obj as? T
        case .empty:
            return nil
        }
    }
    
    public func _as<T>(_ type: T.Type = T.self, default defaultValue: T) -> T {
        return _as(type) ?? defaultValue
    }
    
    public func _represent<T: RawRepresentable>(to: T.Type = T.self) -> T? {
        return _as(T.RawValue.self).flatMap(T.init(rawValue:))
    }
    
    public func _represent<T: RawRepresentable>(to: T.Type = T.self, fallback: T) -> T {
        return _represent() ?? fallback
    }

    public func _equals<T: Equatable>(_ value: T) -> Bool {
        if let this = _as(T.self) {
            return this == value
        }
        return false
    }

    public static var jsonDecoder = JSONDecoder()
    public static var jsonEncoder = JSONEncoder()

    public enum EncodingError: Error {
        case jsonObjectNil
    }

    public func _jsonEncoded(options: JSONSerialization.WritingOptions = []) throws -> Data {
        guard let jsonObject = _raw else {
            throw EncodingError.jsonObjectNil
        }
        return try JSONSerialization.data(withJSONObject: jsonObject, options: options.union(.fragmentsAllowed))
    }

    public func _decode<Object: Decodable>(_ jsonObject: Object.Type = Object.self) throws -> Object {
        let data = try _jsonEncoded()
        return try DynamicInstance.jsonDecoder.decode(Object.self, from: data)
    }

    public func _decodeDynamic<Object: Decodable>(_ jsonObject: Object.Type = Object.self) throws -> Dynamic<Object> {
        return try Dynamic<Object>(decoding: self)
    }
}

public extension DynamicInstance {
    var _string: String? {
        _as()
    }

    var _alwaysString: String {
        _as(default: "")
    }
}

public extension DynamicInstance {
    var _isNil: Bool {
        switch self {
        case .empty:
            return true
        default:
            return false
        }
    }
}

public extension DynamicInstance {
    static func make(_ dict: [WritableKeyPath<DynamicInstance, DynamicInstance>: Any]) -> DynamicInstance {
        var new = DynamicInstance.object([:])
        for (key, value) in dict {
            new[keyPath: key] = DynamicInstance(value)
        }
        return new
    }
}

public extension DynamicInstance {
    var _isArray: Bool {
        _rawArray != nil
    }
    
    var _isDictionary: Bool {
        _rawDictionary != nil
    }
}

public extension DynamicInstance {
    func _prettyPrinted() -> String {
        do {
            let jsonData = try _jsonEncoded(options: [.fragmentsAllowed, .prettyPrinted])
            let jsonString = String(data: jsonData, encoding: .utf8) ?? ""
            return jsonString
        } catch {
            return ""
        }
    }
    
    func _print() {
        print(_prettyPrinted())
    }
}

extension DynamicInstance {
    public func _map(_ transform: @escaping (DynamicInstance) -> DynamicInstance) -> DynamicInstance {
        if let array = _array {
            return array.map(transform).pack()
        } else if let dictionary = _dictionary {
            return dictionary.mapValues(transform).pack()
        } else {
            return transform(self)
        }
    }
}

extension Array where Element == DynamicInstance {
    public func pack() -> DynamicInstance {
        return .object(self.compactMap(\._raw))
    }
}

extension Dictionary where Key == String, Value == DynamicInstance {
    public func pack() -> DynamicInstance {
        return .object(self.compactMapValues(\._raw))
    }
}
