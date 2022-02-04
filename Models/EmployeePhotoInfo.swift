//
//  EmployeePhotoInfo.swift
//  CodablePOC
//
//  Created by Sharanabasappa-Macmini on 06/07/18.
//  Copyright © 2018 com. All rights reserved.
//

import Foundation
import RealmSwift

/// API Model
@objcMembers
class EmployeePhoto: Object,Codable {
    
    dynamic var name: String?
    dynamic var email : String?
    dynamic var profileURL : String?
    
    private enum CodingKeys : String,CodingKey {
        case name
        case email
        case profileURL = "profileUrl"
    }
}

/// Plist Model
@objcMembers
class Employee: Object,Codable {
    
    dynamic var name: String?
    dynamic var id: String?
    dynamic var profileURL: String?
    
    private enum CodingKeys : String,CodingKey {
        case name = "name"
        case id
        case profileURL = "photoInfo"
    }
}
