import RealmSwift

extension LinkingObjects: Decodable where Element: Decodable {
    public convenience init(from decoder: Decoder) throws {
        try self.init(from: decoder)
        var container = try decoder.unkeyedContainer()
        if !container.isAtEnd {
            debugPrint(container)
            let element = try container.decode(Element.self)
            debugPrint(element)
        }
    }
}

//Since LinkingObjects is used for inverse relationship, there is no need need of encoding
//This is written to support codable
extension LinkingObjects: Encodable where Element: Encodable {
    public func encode(to encoder: Encoder) throws {
    }
}

extension RealmOptional : Encodable where Value: Encodable  {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let v = self.value {
            try v.encode(to: encoder)
        } else {
            try container.encodeNil()
        }
    }
}

extension RealmOptional : Decodable where Value: Decodable {
    public convenience init(from decoder: Decoder) throws {
        self.init()
        let container = try decoder.singleValueContainer()
        if !container.decodeNil() {
            self.value = try Value(from: decoder)
        }
    }
}

extension List : Decodable where Element : Decodable {
    public convenience init(from decoder: Decoder) throws {
        self.init()
        var container = try decoder.unkeyedContainer()
        while !container.isAtEnd {
            let element = try container.decode(Element.self)
            self.append(element)
        }
    }
}

extension List : Encodable where Element : Encodable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        for element in self {
            try element.encode(to: container.superEncoder())
        }
    }
}
