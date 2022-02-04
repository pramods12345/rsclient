//
//  ViewController.swift
//  CodablePOC
//
//  Created by Sharanabasappa-Macmini on 06/07/18.
//  Copyright © 2018 com. All rights reserved.
//
import Foundation
import UIKit
import RealmSwift
import RSClient

class ViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        getEmployeePhotoInfo()
        getEmployeePhotoWithCodable()
        loadSslUrl()
        loadFromPilst(fileName:"Employee")
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func loadSslUrl() {
        let url = "https://www.objc.io"
        if let request = NetworkManager.requestForURL(url, method: .Get, params: nil, headers:nil, encoding: .Raw) {
            _ = NetworkManager.request(request) { (response, error, task) in
                debugPrint("Hello", response as Any)
            }
        }
    }
    
    /// With Codable 
    func getEmployeePhotoWithCodable() {
        let url = "https://asset-management-backend.ymedia.in/api/read/getUserList"
        var header : [String:String] = [:]
        header["token"] = "asset_box_token_xyz987"
        if let request = NetworkManager.requestForURL(url, method: .Get, params: nil, headers:header, encoding: .Raw) {
            NetworkManager.requestWithDataModel(request , model: [EmployeePhoto].self, skipKeyPath: "users") { (employeesList, error, task) in
                guard let employees =  employeesList else {
                    return
                }
                do {
                    let realm  = try Realm()
                    try realm.write {
                        realm.add(employees)
                    }
                } catch {
                    
                }
                
                debugPrint(employees)
                let encoder = JSONEncoder()
                if let json = try! encoder.encodeWithJson(employees, addKeyPath: "users.user1.user2.user3") {
                    debugPrint(json)
                }
            }
        }
    }
    
    /// Without codable
    func getEmployeePhotoInfo() {
        let url = "https://asset-management-backend.ymedia.in/api/read/getUserList"
        var header : [String:String] = [:]
        header["token"] = "asset_box_token_xyz987"
        if let request = NetworkManager.requestForURL(url, method: .Get, params: nil, headers:header, encoding: .Raw) {
            _ =  NetworkManager.request(request, completionHandler: { (response, error, task) in
                if error == nil {
                    guard let response = response else {
                        return
                    }
                    
                    if let employees = response["users"].array {
                        debugPrint(employees)
                    }
                }
            })
            
        }
    }
}

// MARK: - Plist Decoder and Encoder
extension ViewController {
    fileprivate func encodePlistDataToJson(_ employee: Employee?) throws {
        let encoder = PropertyListEncoder()
        let employeeJson = try encoder.encodeWithJson(employee, addKeyPath: "Employee")
        print(employeeJson as Any)
    }
    
    func loadFromPilst(fileName:String) {
        guard  let plistFilepath = Bundle.main.path(forResource: fileName, ofType: "plist"), let plistData = FileManager.default.contents(atPath: plistFilepath) else {
            return
        }
        
        let decoder = PropertyListDecoder()
        do {
            let employee = try decoder.decode(Employee.self, from: plistData, skipKeyPath: "Employee")
            print(employee as Any)
            try encodePlistDataToJson(employee)
        } catch {
            print(error)
        }
    }
}

extension NetworkTask: NetworkTasksDelegate {
    public func isSSLNeeded(for request: URLRequest?) -> Bool {
        // Handle action
        return false
    }
    
    public func performSSLFailedAction() {
        // Handle action
    }
    
    public func getSSLFilePath() -> URL {
        let url = Bundle.main.url(forResource: "objcio", withExtension: "cer")
        return url!
    }
}
