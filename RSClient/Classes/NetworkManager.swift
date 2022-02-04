//
//  NetworkManager.swift
//  RSClient
//
//  Created by YML on 02/03/16.
//  Copyright © 2016 YML. All rights reserved.
//

import Foundation
import UIKit

@objc public protocol NetworkTasksDelegate {
    @objc optional func isSSLNeeded(for request: URLRequest?) -> Bool
    @objc optional func performSSLFailedAction()
    @objc optional func getSSLFilePath() -> URL
}

private let timeoutInterval = 60.0
private let domainName = "com.networkmanager.error"
private let concurrrentQueueIndentifier = "com.networkmanager.queue"

public typealias NetworkManagerCompletion = (_ response: JSON?, _ error: NetworkError?, _ success: Bool) -> ()
public typealias CodableNetworkManagerCompletion<T:Codable> = (_ model: T.Type?,_ error: NetworkError?, _ task: NetworkTask) -> ()
public typealias ResponseHandler = (_ data:Data?,_ response:URLResponse?,_ error:NetworkError?) -> ()

var noNetworkError: NSError {
    let userInfo: [AnyHashable: Any] =
        [NSLocalizedDescriptionKey: NSLocalizedString("No Network",
                                                      value: "The Internet connection appears to be offline.",
                                                      comment: "")]
    
    return NSError(domain: "com.connectionManager.error", code: -1009, userInfo: (userInfo as? [String : Any]))
}

public enum HTTPMethod: String {
    case Get = "GET"
    case Put = "PUT"
    case Post = "POST"
    case Delete = "DELETE"
}

public enum NetworkManagerEncodingType: String {
    case URL = "multipart/form-data"
    case URLEncoded = "application/x-www-form-urlencoded"
    case Raw = "application/json"
}

public enum NetworkError: Error {
    // Can't connect to the server (maybe offline?)
    case connectionError(connectionError: NSError)
    // The server responded with a non 200 status code
    case serverError(statusCode: Int, message: String)
    // We got no data (0 bytes) back from the server
    case noDataError(statusCode: Int)
    // The server response can't be converted from JSON to a Dictionary
    case jsonSerializationError(statusCode: Int)
    case decodeError(error: NSError)
    case noNetworkError(error: NSError)
    
    public var errorMessage: String {
        var message = ""
        
        switch self {
        case .connectionError(let connectionError):
            message = connectionError.localizedDescription
        case .serverError(_, let messageString):
            message = messageString
        case .noDataError:
            message = "Sorry, server didn't respond with sufficient data."
        case .jsonSerializationError(_):
            message = "Sorry, we couldn't interpret server's response."
        case .decodeError(let error):
            message = error.localizedDescription
        case .noNetworkError:
            message = "The Internet connection appears to be offline."
        }
        
        if message.count == 0 { message = "Unknown error occured." }
        return message
    }
    
    public var errorDomain: String {
        var domain = domainName
        
        switch self {
        case .connectionError(_):
            domain = "Connection Error"
        case .serverError(_,_):
            domain = "Server Error"
        case .noDataError:
            domain = "No Data"
        case .jsonSerializationError(_):
            domain = "Parse Error"
        case .decodeError(_):
            domain = "Decode Error"
        case .noNetworkError(_):
            domain = "No Network Error"
        }
        
        return domain
    }
    
    public var code: Int {
        var errorCode: Int = 0
        
        switch self {
        case .connectionError(let connectionError):
            errorCode = connectionError.code
        case .serverError(let statusCode, _):
            errorCode = statusCode
        case .noDataError(let statusCode):
            errorCode = statusCode
        case .jsonSerializationError(let statusCode):
            errorCode = statusCode
        case .decodeError(_):
            errorCode = 0
        case .noNetworkError(let error):
            errorCode = error.code
        }
        
        return errorCode
    }
    
    public var error: NSError {
        switch self {
        case .serverError(_,_):
            return NSError(domain: domainName, code: code)
        case .connectionError(_), .jsonSerializationError(_), .noDataError,.decodeError(_), .noNetworkError(_):
            return NSError(domain: domainName, code: code, userInfo: [NSLocalizedDescriptionKey: errorMessage])
        }
    }
}

public final class NetworkManager {
    
    static let queue = DispatchQueue(label:concurrrentQueueIndentifier, attributes: [])
    
    class public func requestForURL(_ urlString: String, method: HTTPMethod, params: [String: Any]?, headers: [String: String]?, encoding: NetworkManagerEncodingType = .Raw) -> URLRequest? {
        
        guard let url = URL(string: urlString) else {
            return nil
        }
        
//        guard let escapedURLString = urlString.addingPercentEncoding(withAllowedCharacters:.urlQueryAllowed), let url = URL(string:escapedURLString) else {
//            return nil
//        }
        
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: timeoutInterval)
        URLCache.shared.removeCachedResponse(for: request)
        request.httpMethod = method.rawValue
        if let headers = headers {
            for (field, value) in headers {
                request.setValue(value, forHTTPHeaderField: field)
            }
        }
        switch (encoding) {
        case .URLEncoded:
            request.setValue(NetworkManagerEncodingType.URLEncoded.rawValue, forHTTPHeaderField: "Content-Type")
        case .Raw:
            if let params = params, params.count > 0 {
                request.httpBody = try? JSONSerialization.data(withJSONObject: params, options: JSONSerialization.WritingOptions())
            }
            
        case .URL:
            var image = UIImage()
            var name = String()
            var key = String()
            if let params = params, params.count > 0 {
                if let imageFile = params["image"] as? UIImage, let imageName = params["imageName"] as? String, let imgKey = params["keyName"] as? String {
                    image = imageFile
                    name = imageName
                    key = imgKey
                }
                
            }
            let boundary = "---------------------------14737809831466499882746641449"
            let contentType = "multipart/form-data; boundary=\(boundary)"
            request.setValue(contentType, forHTTPHeaderField: "Content-Type")
            request.addValue("application/json", forHTTPHeaderField: "Accept")
            request.addValue("filename=\(name)", forHTTPHeaderField: "Content-Disposition")
            var body = Data()
            guard let data = image.jpegData(compressionQuality: 0.5) else {
                return  nil
            }
            // print("size of images in byte \(data!.count)")
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(key)\"; filename=\"\(name)\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
            body.append(data)
            body.append("\r\n".data(using: .utf8)!)
            body.append("--\(boundary)--\r\n".data(using: .utf8)!)
            request.httpBody = body
            
        }
        
        return request
    }
    
    class func convertStringToData(string: String) -> Data? {
        guard let data = string.data(using: .utf8) else {
            return nil
        }
        return data
    }
    
    class public func request(_ request: URLRequest,completionHandler: @escaping NetworkManagerCompletion) -> NetworkTask {
        let networkTask = NetworkTask(request: request, queue: queue, completionHandler: completionHandler)
        networkTask.networkTaskDelegate = networkTask
        return networkTask
    }
    
    ///   - model  : Data model that user want to extract from response
    ///   - keyPath: keys that user should skip to extract model from response
    /**
     An example of using a skipKeyPath
     
     ````
     let data = """
     {
     "ok": true,
     "warning": "something_problematic",
     "user": {
     "user1": {
     "user2": [
     {
     "name": "Htin Linn",
     "userName": "Litt"
     },
     {
     "name": "Baadshah Linn",
     "userName": "Litt"
     }
     ]
     }
     }
     }
     """.data(using: .utf8)!
     
     /// User Model Class
     struct user: Decodable {
     let name: String
     let userName: String
     }
     
     /// MultiLevelDecoding
     func decoder(){
     let jsonDecoder = JSONDecoder()
     
     do {
     let usermodel = try jsonDecoder.decode([user].self, from: data, skipKeyPath: "user.user1.user2")
     print(usermodel)
     } catch {
     print(error)
     }
     
     ````
     */
    class public func requestWithDataModel<T:Codable>(_ request: URLRequest,model:T.Type,skipKeyPath:String?=nil,completionHandelr completion :@escaping (_ model: T?,_ error: NetworkError?, _ success: Bool) -> ()) {
        let networkTask = NetworkTask(request: request, model: model, skipKeyPath: skipKeyPath, completionHandelr: completion)
        networkTask.networkTaskDelegate = networkTask
    }
}

//MARK:- JSON and Codable
public final class NetworkTask: NSObject {
    
    /// JSON Completion Handler
    fileprivate var completionHandler: NetworkManagerCompletion?
    fileprivate var request: URLRequest?
    
    /// netowrk task delegate is used to handle SSL Connection and Other Features
    weak var networkTaskDelegate: NetworkTasksDelegate?
    
    /// This initalizer is used for JSON parsing
    ///
    /// - Parameters:
    ///   - request: Network request
    convenience init(request: URLRequest, queue: DispatchQueue? = nil,completionHandler: @escaping NetworkManagerCompletion) {
        self.init()
        self.request = request
        let concurrentQueue = DispatchQueue(label: concurrrentQueueIndentifier, attributes: .concurrent)
        concurrentQueue.async {
            self.loadRequest(request, completionHandler: completionHandler)
        }
    }
    
    /// This initalizer is used for Codable Parsing
    ///
    /// - Parameters:
    ///   - request: Network request
    ///   - model  : Type of model to parse
    ///   - keypath : keyPath that user want to skip to extract model content from response
    convenience init<T:Codable>(request: URLRequest, queue: DispatchQueue? = nil,model:T.Type,skipKeyPath:String?,completionHandelr completion:@escaping (_ model: T?,_ error: NetworkError?, _ success: Bool) -> ()) {
        self.init()
        self.request = request
        let concurrentQueue = DispatchQueue(label: concurrrentQueueIndentifier, attributes: .concurrent)
        concurrentQueue.async {
            self.loadRequestWithModel(model: model, skipKeyPath: skipKeyPath, request, completionHandler: completion)
        }
    }
    // MARK: - Request Methods
    
    /// Network and handle error and response Parsing using Swifty JSON
    ///
    /// - Parameter request: APi Request URL with Header and body information
    func loadRequest(_ request: URLRequest,completionHandler:@escaping NetworkManagerCompletion) {
        
        dataTaskWithUrl(request) { (data, response, error) in
            if error != nil {
                completionHandler(nil, error, false)
                return
            }
            
            guard let responseData = data else {
                completionHandler(nil, error, false)
                return
            }
            
            let responseObject = JSON(data: responseData)
            completionHandler(responseObject,error,true)
        }
    }
    
    /// returns Model with response data is  mapped to model
    ///
    /// - Parameters:
    ///   - model: Data model
    ///   - skipKeyPath: keys that user should skip to extract model from response
    /**
     An example of using a skipKeyPath
     
     ````
     let data = """
     {
     "ok": true,
     "warning": "something_problematic",
     "user": {
     "user1":{
     "user2":[
     {
     "name": "Htin Linn",
     "userName": "Litt"
     },{
     "name": "Baadshah Linn",
     "userName": "Litt"
     }
     ]
     }
     }
     }
     """.data(using: .utf8)!
     
     /// User Model Class
     struct user: Decodable {
     let name: String
     let userName: String
     }
     
     /// MultiLevelDecoding
     func decoder(){
     let jsonDecoder = JSONDecoder()
     
     do {
     let usermodel = try jsonDecoder.decode([user].self, from: data, skipKeyPath: "user.user1.user2")
     print(usermodel)
     } catch {
     print(error)
     }
     
     ````
     */
    func dataTaskWithUrl(_ request: URLRequest,completionHandler:@escaping ResponseHandler) {
        // Check for internet connection
        guard let connection = Reachability()?.connection, connection != .none else {
            let noNetworkErrorType = NetworkError.noNetworkError(error: noNetworkError)
            return completionHandler(nil,nil, noNetworkErrorType)
        }
        let configuration = URLSessionConfiguration.default
        let session = Foundation.URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
        
        let task = session.dataTask(with: request) { (data, response, error) in
            // Check for server error
            if let error = error {
                completionHandler(nil, nil, NetworkError.connectionError(connectionError: error as NSError))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completionHandler(nil, nil, NetworkError.serverError(statusCode: 0, message: "Something went wrong"))
                return
            }
            guard httpResponse.statusCode == 200 else {
                
                var networkErrorMsg = error?.localizedDescription ?? "Something went wrong"
                var networkErrorCode = httpResponse.statusCode
                
                if let data = data,
                    let errorMsg = JSON(data: data)["message"].rawString(),
                    let errorCodeStr = JSON(data: data)["statusCode"].rawString(),
                    let errorCode = Int(errorCodeStr)  {
                    networkErrorMsg = errorMsg
                    networkErrorCode = errorCode
                }
                if networkErrorCode == 601 {
                    networkErrorMsg = "Something went wrong"
                }
                completionHandler(nil, nil, NetworkError.serverError(statusCode: networkErrorCode, message: networkErrorMsg))
                return
            }
            
            // Parse Data to JSON Object
            guard let responseData = data, responseData.count > 0 else {
                completionHandler(nil, nil, NetworkError.noDataError(statusCode: httpResponse.statusCode))
                return
            }
            completionHandler(data,response,nil)
        }
        task.resume()
        
    }
    
    func loadRequestWithModel<T:Codable>(model:T.Type,skipKeyPath:String?=nil,_ request: URLRequest,completionHandler completion:@escaping (_ model: T?,_ error: NetworkError?, _ success: Bool) -> ()) {

        dataTaskWithUrl(request) { (data, response, error) in
            
            if error != nil {
                completion(nil, error, false)
                return
            }
            
            guard let responseData = data, !responseData.isEmpty else {
                completion(nil, error, false)
                return
            }
            let jsonDecoder = JSONDecoder()
            do {
                let modelData = try jsonDecoder.decode(model.self, from: responseData, skipKeyPath: skipKeyPath)
                return completion(modelData, nil, true)
            } catch let error {
                return completion(nil, NetworkError.decodeError(error: error as NSError), false)
            }
        }
    }
    
    // MARK: - Private Methods
    func URLSession(_ session: Foundation.URLSession, dataTask: URLSessionDataTask, willCacheResponse proposedResponse: CachedURLResponse, completionHandler: (CachedURLResponse?) -> Void) {
        completionHandler(nil)
    }
    
}

extension NetworkTask: URLSessionDelegate {
    
    /// SSL Pinning/ URLAuthenticationChallenge
    ///
    /// - Parameters:
    ///   - session: urlSession
    ///   - challenge: urlAuthenticationChallenge
    ///   - completionHandler: completion handler to check whether to allow the request.
    public func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        
        guard let isSslNeeded = networkTaskDelegate?.isSSLNeeded?(for: self.request), isSslNeeded else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        
        if let trust = challenge.protectionSpace.serverTrust, SecTrustGetCertificateCount(trust) > 0 {
            if let certificate = SecTrustGetCertificateAtIndex(trust, 0), let sslFilePath = networkTaskDelegate?.getSSLFilePath?() {
                let remotedata = SecCertificateCopyData(certificate) as Data
                do {
                    let localCertificateData = try Data(contentsOf: sslFilePath)
                    let isValidCert = remotedata == localCertificateData
                    
                    if !isValidCert {
                        sslFailed()
                    }
                    completionHandler( isValidCert ? .useCredential : .cancelAuthenticationChallenge, isValidCert ? URLCredential(trust: trust) : nil)
                } catch {
                    sslFailed()
                    completionHandler(.cancelAuthenticationChallenge, nil)
                }
                return
            }
        }
        sslFailed()
        completionHandler(.cancelAuthenticationChallenge, nil)
        
    }
    
    func sslFailed() {
        networkTaskDelegate?.performSSLFailedAction?()
    }
    
}

extension NetworkTask: NetworkTasksDelegate {
    
    
}

extension NetworkTask: URLSessionTaskDelegate {
    
    public func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping(URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,let serverTrust = challenge.protectionSpace.serverTrust {
            let credential = URLCredential(trust: serverTrust)
            completionHandler(Foundation.URLSession.AuthChallengeDisposition.useCredential, credential)
        }
    }
}
