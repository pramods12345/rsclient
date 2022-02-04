//
//  JSONDecoder+Extension.swift
//  Realm+Codable
//
//  Created by YML on 05/07/18.
//  Copyright © 2018 YML. All rights reserved.
//

import Foundation

// MARK: - JSON Decoder with keypath
public extension JSONDecoder {
    func decode<T: Decodable>(_ type: T.Type, from data: Data, skipKeyPath keypath: String?) throws -> T? {
        if let key = keypath {
            // Pass the top level key to the decoder.
            userInfo[.jsonDecoderRootKeyName] = key
            
            let root = try decode(MultiLevelDecode<T>.self, from: data)
            return root.value
        } else {
            return try decode(type, from: data)
        }
    }
    
}

public extension JSONEncoder {
    func encode<T: Encodable>(_ objcet: T, addKeyPath keypath: String?) throws -> Data? {
        if let key = keypath {
            // Pass the top level key to the decoder.
            userInfo[.jsonDecoderRootKeyName] = key
            let encodedObj =  EncodableRoot<T>(data : objcet)
            let root = try encode(encodedObj)
            return root
        } else {
            return try encode(objcet)
        }
    }
    
    func encodeWithJson<T:Encodable>(_ objcet: T, addKeyPath keypath: String?) throws -> Any? {
        guard let encodedData = try encode(objcet, addKeyPath: keypath) else {
            return nil
        }
        guard let jsonObject = try? JSONSerialization.jsonObject(with: encodedData, options: .allowFragments) else {
            return nil
        }
        return jsonObject
    }
}


// MARK: - Plist Decoder with keypath
public extension PropertyListDecoder {
    
    public func decode<T: Decodable>(_ type: T.Type, from data: Data, skipKeyPath keypath: String?) throws -> T? {
        if let key = keypath {
            // Pass the top level key to the decoder.
            userInfo[.jsonDecoderRootKeyName] = key
            
            let root = try decode(MultiLevelDecode<T>.self, from: data)
            return root.value
        } else {
            return try decode(type, from: data)
        }
    }
}

public extension PropertyListEncoder {
    func encode<T: Encodable>(_ objcet: T, addKeyPath keypath: String?) throws -> Data? {
        if let key = keypath {
            // Pass the top level key to the decoder.
            userInfo[.jsonDecoderRootKeyName] = key
            let encodedObj =  EncodableRoot<T>(data : objcet)
            let root = try encode(encodedObj)
            return root
        } else {
            return try encode(objcet)
        }
    }
    
    func encodeWithJson<T:Encodable>(_ objcet: T, addKeyPath keypath: String?) throws -> Any? {
       
        guard let encodedData = try encode(objcet, addKeyPath: keypath) else {
            return nil
        }
        outputFormat = .xml
        guard let jsonObject = try? PropertyListSerialization.propertyList(from: encodedData, options: .mutableContainers, format: nil) else {
            return nil
        }
        return jsonObject
    }
}

// MARK: - Coding user info key
public extension CodingUserInfoKey {
    
    static let jsonDecoderRootKeyName = CodingUserInfoKey(rawValue: "rootKeyName")!
    
}

/// Custom Decodable object to skip th keyPath
struct MultiLevelDecode<T>: Decodable where T: Decodable {
    
    private struct CodingKeys: CodingKey {
        
        var stringValue: String
        var intValue: Int?
        
        init?(stringValue: String) {
            self.stringValue = stringValue
        }
        
        init?(intValue: Int) {
            self.intValue = intValue
            stringValue = "\(intValue)"
        }
        
        static func key(named name: String) -> CodingKeys? {
            return CodingKeys(stringValue: name)
        }
        
    }
    
    var value: T?
    
    init(from decoder: Decoder) throws {
        
        var container = try decoder.container(keyedBy: CodingKeys.self)
        
        if let keyList =  decoder.userInfo[.jsonDecoderRootKeyName] as? String{
            let splitKeyList = keyList.components(separatedBy: ".")
            for (index,splitKey) in splitKeyList.enumerated(){
                guard let key = CodingKeys.key(named: splitKey) else {
                    throw DecodingError.valueNotFound(
                        T.self,
                        DecodingError.Context(codingPath: [], debugDescription: "Value not found at root level.")
                    )
                }
                /// Extracting data from  updated last container to extact the value.
                if index == (splitKeyList.count - 1) {
                    value = try container.decode(T.self, forKey: key)
                }
                else{
                    //Update container by going inside of container
                    container = try container.nestedContainer(keyedBy: CodingKeys.self, forKey: key)
                }
                
            }
        }
        
    }
    
}

public class EncodableRoot<T> : Encodable where T:Encodable {
    
    private struct CodingKeys: CodingKey {
        
        var stringValue: String
        var intValue: Int?
        
        init?(stringValue: String) {
            self.stringValue = stringValue
        }
        
        init?(intValue: Int) {
            self.intValue = intValue
            stringValue = "\(intValue)"
        }
        
        static func key(named name: String) -> CodingKeys? {
            return CodingKeys(stringValue: name)
        }
        
    }
    
    init(data : T) {
        self.value = data
    }
    
    var value : T?
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        if let keyList =  encoder.userInfo[.jsonDecoderRootKeyName] as? String{
            let splitKeyList = keyList.components(separatedBy: ".")
            for (index,splitKey) in splitKeyList.enumerated(){
                guard let key = CodingKeys.key(named: splitKey) else {
                    throw EncodingError.invalidValue(T.self, EncodingError.Context(codingPath:encoder.codingPath, debugDescription: "Not able to add this key"))
                }
                /// Encoding value at lower level
                if index == (splitKeyList.count - 1) {
                    try container.encode(value, forKey: key)
                }
                else{
                    //Update container by going inside of container
                    container = container.nestedContainer(keyedBy: CodingKeys.self, forKey: key)
                }
                
            }
        }
    }
}
