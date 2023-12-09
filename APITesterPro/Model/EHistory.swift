//
//  EHistory.swift
//  APITesterPro
//
//  Created by Jaseem V V on 20/05/20.
//  Copyright © 2020 Jaseem V V. All rights reserved.
//

import Foundation
import CoreData
import CloudKit

public class EHistory: NSManagedObject, Entity {
    static let db: CoreDataService = CoreDataService.shared
    static let ck: EACloudKit = EACloudKit.shared
    public var recordType: String { return "History" }
    private let secureTrans = SecureTransformerData()
    
    static func initFromResponseData(_ respData: ResponseData) -> EHistory {
        let history = EHistory(context: Self.db.mainMOC)
        let date = Date()
        history.created = date
        history.modified = date
        history.connection = respData.connectionInfo.connection
        history.connectionTime = respData.connectionInfo.connectionTime
        if let cookies = respData.cookiesData as NSObject? { history.cookies = cookies }
        history.dnsResolutionTime = respData.connectionInfo.dnsTime
        history.elapsed = respData.connectionInfo.elapsed
        history.fetchStartTime = respData.connectionInfo.fetchStart
        history.hasRequestBody = respData.hasRequestBody
        history.id = self.db.historyId()
        history.isCellular = respData.connectionInfo.isCellular
        history.isMultipath = respData.connectionInfo.isMultipath
        history.isProxyConnection = respData.connectionInfo.isProxyConnection
        history.isReusedConnection = respData.connectionInfo.isReusedConnection
        history.isSecure = respData.isSecure
        history.isSynced = false
        history.localAddress = respData.connectionInfo.localAddress
        history.localPort = respData.connectionInfo.localPort
        history.method = respData.method
        history.networkProtocolName = respData.connectionInfo.networkProtocolName
        history.remoteAddress = respData.connectionInfo.remoteAddress
        history.remotePort = respData.connectionInfo.remotePort
        history.request = respData.request
        history.requestBodyBytes = respData.connectionInfo.requestBodyBytesSent
        history.requestHeaderBytes = respData.connectionInfo.requestHeaderBytesSent
        history.requestTime = respData.connectionInfo.requestTime
        history.responseBodyBytes = respData.connectionInfo.responseBodyBytesReceived
        history.responseData = respData.responseData
        history.responseHeaderBytes = respData.connectionInfo.responseHeaderBytesReceived
        history.responseHeaders = URLRequest.headersToData(respData.getResponseHeaders())
        history.responseTime = respData.connectionInfo.responseTime
        history.secureConnectionTime = respData.connectionInfo.secureConnectionTime
        history.sessionName = respData.sessionName
        history.statusCode = respData.statusCode.toInt64()
        history.tlsCipherSuite = respData.connectionInfo.negotiatedTLSCipherSuite
        history.tlsProtocolVersion = respData.connectionInfo.negotiatedTLSProtocolVersion
        history.url = respData.url
        history.urlRequest = respData.urlRequest?.toString() ?? ""
        history.version = 0
        history.wsId = respData.wsId
        return history
    }
    
    public func getId() -> String {
        return self.id ?? ""
    }
    
    public func getWsId() -> String {
        return self.wsId ?? ""
    }
    
    public func setWsId(_ id: String) {
        self.wsId = id
    }
    
    public func getName() -> String {
        return ""
    }
    
    public func getCreated() -> Date {
        return self.created!.toLocalDate()
    }
    
    public func getCreatedUTC() -> Date {
        return self.created!
    }
    
    public func getModified() -> Date {
        return self.modified!.toLocalDate()
    }
    
    public func getModitiedUTC() -> Date {
        return self.modified!
    }
    
    public func setModified(_ date: Date) {
        self.modified = date.toUTC()
    }
    
    public func setModifiedUTC(_ date: Date) {
        self.modified = date
    }
    
    public func getVersion() -> Int64 {
        return self.version
    }
    
    public func setIsSynced(_ status: Bool) {
        self.isSynced = status
    }
    
    public func setMarkedForDelete(_ status: Bool) {
        self.markForDelete = status
    }
    
    public override func willSave() {
        
    }
    
    static func getCKRecord(id: String, reqId: String, projId: String, wsId: String, ctx: NSManagedObjectContext) -> CKRecord? {
        var history: EHistory!
        var ckHistory: CKRecord!
        guard let ckReq = ERequest.getCKRecord(id: reqId, projId: projId, wsId: wsId, ctx: ctx) else { return ckHistory }
        ctx.performAndWait {
            history = db.getHistory(id: id, ctx: ctx)
            let zoneID = history.getZoneID()
            let ckHistoryID = self.ck.recordID(entityId: id, zoneID: zoneID)
            ckHistory = self.ck.createRecord(recordID: ckHistoryID, recordType: history.recordType)
            history.updateCKRecord(ckHistory, request: ckReq)
        }
        return ckHistory
    }
    
    public func updateCKRecord(_ record: CKRecord, request: CKRecord) {
        self.managedObjectContext?.performAndWait {
            record["created"] = self.created! as CKRecordValue
            record["modified"] = self.modified! as CKRecordValue
            record["connection"] = (self.connection ?? "") as CKRecordValue
            record["connectionTime"] = self.connectionTime as CKRecordValue
            if let id = self.id, let _cookies = self.cookies, let data = self.secureTrans.transformedValue(_cookies) as? Data {
                let url = EAFileManager.getTemporaryURL(id)
                do {
                    try data.write(to: url)
                    record["value"] = CKAsset(fileURL: url)
                } catch let error {
                    Log.error("Error: \(error)")
                }
            }
            record["dnsResolutionTime"] = self.dnsResolutionTime as CKRecordValue
            record["elapsed"] = self.elapsed as CKRecordValue
            record["fetchStartTime"] = self.fetchStartTime as CKRecordValue
            record["hasRequestBody"] = self.hasRequestBody as CKRecordValue
            record["id"] = self.getId() as CKRecordValue
            record["isCellular"] = self.isCellular as CKRecordValue
            record["isMultipath"] = self.isMultipath as CKRecordValue
            record["isProxyConnection"] = self.isProxyConnection as CKRecordValue
            record["isReusedConnection"] = self.isReusedConnection as CKRecordValue
            record["isSecure"] = self.isSecure as CKRecordValue
            record["localAddress"] = (self.localAddress ?? "") as CKRecordValue
            record["localPort"] = self.localPort as CKRecordValue
            record["method"] = (self.method ?? "") as CKRecordValue
            record["networkProtocolName"] = (self.networkProtocolName ?? "") as CKRecordValue
            record["remoteAddress"] = (self.remoteAddress ?? "") as CKRecordValue
            record["remotePort"] = self.remotePort as CKRecordValue
            record["responseTime"] = self.responseTime as CKRecordValue
            record["responseBodyBytes"] = self.responseBodyBytes as CKRecordValue
            if let id = self.id, let data = self.responseData {
                let url = EAFileManager.getTemporaryURL(id)
                do {
                    try data.write(to: url)
                    record["responseData"] = CKAsset(fileURL: url)
                } catch let error {
                    Log.error("Error: \(error)")
                }
            }
            record["responseHeaderBytes"] = self.responseHeaderBytes as CKRecordValue
            if let id = self.id, let data = self.responseHeaders {
                let url = EAFileManager.getTemporaryURL(id)
                do {
                    try data.write(to: url)
                    record["responseHeaders"] = CKAsset(fileURL: url)
                } catch let error {
                    Log.error("Error: \(error)")
                }
            }
            record["responseTime"] = self.responseTime as CKRecordValue
            record["secureConnectionTime"] = self.secureConnectionTime as CKRecordValue
            record["sessionName"] = (self.sessionName ?? "") as CKRecordValue
            record["statusCode"] = self.statusCode as CKRecordValue
            record["tlsCipherSuite"] = (self.tlsCipherSuite ?? "") as CKRecordValue
            record["tlsProtocolVersion"] = (self.tlsProtocolVersion ?? "") as CKRecordValue
            record["url"] = (self.url ?? "") as CKRecordValue
            record["urlRequest"] = (self.urlRequest ?? "") as CKRecordValue  // urlRequestString
            record["method"] = (self.method ?? "") as CKRecordValue
            record["version"] = self.version as CKRecordValue
            record["wsId"] = self.getWsId() as CKRecordValue
            let ref = CKRecord.Reference(record: request, action: .deleteSelf)
            record["request"] = ref
        }
    }
    
    public func updateFromCKRecord(_ record: CKRecord, ctx: NSManagedObjectContext) {
        if let moc = self.managedObjectContext {
            moc.performAndWait {
                if let x = record["created"] as? Date { self.created = x }
                if let x = record["modified"] as? Date { self.modified = x }
                if let x = record["connection"] as? String { self.connection = x }
                if let x = record["connectionTime"] as? Double { self.connectionTime = x }
                if let x = record["cookies"] as? CKAsset, let url = x.fileURL {
                    do {
                        let data = try Data(contentsOf: url)
                        if let _cookies = self.secureTrans.reverseTransformedValue(data) as? String {
                            self.cookies = _cookies as NSObject
                        }
                        
                    } catch let error { Log.error("Error getting data from file url: \(error)") }
                }
                if let x = record["dnsResolutionTime"] as? Double { self.dnsResolutionTime = x }
                if let x = record["elapsed"] as? Int64 { self.elapsed = x }
                if let x = record["fetchStartTime"] as? Int64 { self.fetchStartTime = x }
                if let x = record["hasRequestBody"] as? Bool { self.hasRequestBody = x }
                if let x = record["id"] as? String { self.id = x }
                if let x = record["isCellular"] as? Bool { self.isCellular = x }
                if let x = record["isMultipath"] as? Bool { self.isMultipath = x }
                if let x = record["isProxyConnection"] as? Bool { self.isProxyConnection = x }
                if let x = record["isSecure"] as? Bool { self.isSecure = x }
                if let x = record["localAddress"] as? String { self.localAddress = x }
                if let x = record["localPort"] as? Int64 { self.localPort = x }
                if let x = record["method"] as? String { self.method = x }
                if let x = record["networkProtocolName"] as? String { self.networkProtocolName = x }
                if let x = record["remoteAddress"] as? String { self.remoteAddress = x }
                if let x = record["remotePort"] as? Int64 { self.remotePort = x }
                if let x = record["requestHeaderBytes"] as? Int64 { self.requestHeaderBytes = x }
                if let x = record["requestBodyBytes"] as? Int64 { self.requestBodyBytes = x }
                if let x = record["requestTime"] as? Double { self.requestTime = x }
                if let x = record["responseBodyBytes"] as? Int64 { self.responseBodyBytes = x }
                if let x = record["responseData"] as? CKAsset, let url = x.fileURL {
                    do { self.responseData = try Data(contentsOf: url) } catch let error { Log.error("Error getting data from file url: \(error)") }
                }
                if let x = record["responseHeaderBytes"] as? Int64 { self.responseHeaderBytes = x }
                if let x = record["responseHeaders"] as? CKAsset, let url = x.fileURL {
                    do { self.responseHeaders = try Data(contentsOf: url) } catch let error { Log.error("Error getting data from file url: \(error)") }
                }
                if let x = record["responseTime"] as? Double { self.responseTime = x }
                if let x = record["secureConnectionTime"] as? Double { self.secureConnectionTime = x }
                if let x = record["sessionName"] as? String { self.sessionName = x }
                if let x = record["statusCode"] as? Int64 { self.statusCode = x }
                if let x = record["tlsCipherSuite"] as? String { self.tlsCipherSuite = x }
                if let x = record["tlsProtoclVersion"] as? String { self.tlsProtocolVersion = x }
                if let x = record["url"] as? String { self.url = x }
                if let x = record["urlRequest"] as? String { self.urlRequest = x }
                if let x = record["version"] as? Int64 { self.version = x }
                if let x = record["wsId"] as? String { self.wsId = x }
                if let ref = record["request"] as? CKRecord.Reference, let req = ERequest.getRequestFromReference(ref, record: record, ctx: moc) { self.request = req }
            }
        }
    }
}
