//
//  EAFileManager.swift
//  APITesterPro
//
//  Created by Jaseem V V on 10/03/20.
//  Copyright © 2020 Jaseem V V. All rights reserved.
//

import Foundation

/// File open mode
public enum FileIOMode {
    case read
    case write
    case append
}

/// A result type of `Data`.
public typealias EADataResultCallback = ((Result<Data, Error>) -> Void)

public final class EAFileManager: NSObject {
    public let url: URL!
    private var callback: EADataResultCallback?
    private var data: Data?
    private let fm = FileManager.default
    private static let fm = FileManager.default
    private var fileHandle: FileHandle?
    private let queue = EACommon.userInitiatedQueue
    public var isFileOpened = false
    private let writeLock = NSLock()

    deinit {
        Log.debug("EAFileManager deinit")
        self.fileHandle?.closeFile()
    }
    
    public init(url: URL) {
        self.url = url
        super.init()
    }
    
    /// Checks if the file exists at the given URL.
    public static func isFileExists(at url: URL) -> Bool {
        return self.fm.fileExists(atPath: url.path)
    }
    
    /// Checks if the directory exists at the given URL.
    public static func isDirectoryExists(at url: URL) -> Bool {
        var isDir: ObjCBool = false
        if self.fm.fileExists(atPath: url.path, isDirectory: &isDir) {
            return isDir.boolValue
        }
        return false
    }
    
    /// Returns a file URL that's located in the temporary directory. Even if this is a temporary URL this needs cleanup.
    public static func getTemporaryURL(_ name: String) -> URL {
        return URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(name)
    }
    
    /// Returns a file URL that's located in the app's document directory
    public static func getDocumentDirectoryURL(_ name: String) -> URL? {
        if let docDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            return docDirectory.appendingPathComponent(name)
        }
        return nil
    }
    
    /// Create directory at the given path including intermediate directories as well.
    public static func createDirectory(at url: URL) -> Bool {
        do {
            try self.fm.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
            return true
        } catch let err {
            Log.error("Error creating directory: \(err)")
            return false
        }
    }
    
    /// Create a file at the given file url irrespective of whether the file exists or not. If the file exists at the file url, this will clear its contents.
    public static func createFile(_ url: URL) {
        self.fm.createFile(atPath: url.path, contents: nil, attributes: nil)
    }
    
    /// Creates a file at the given file URL if it does not exists already.
    public static func createFileIfNotExists(_ url: URL) {
        if !self.isFileExists(at: url) {
            let dirURL = url.deletingLastPathComponent()
            if !self.isDirectoryExists(at: dirURL) { _ = self.createDirectory(at: dirURL) }
            self.createFile(url)
        }
    }

    /// Copy file contents of the source to the destination
    public static func copy(source: URL, destination: URL) -> Bool {
        do {
            let content = try Data(contentsOf: source)
            try content.write(to: destination, options: .atomic)
        } catch {
            Log.error("Error copying file contents: \(error)")
            return false
        }
        return true
    }
    
    /// Delete a file at the given URL.
    public static func delete(url: URL?) -> Bool {
        guard let url = url else { return true }
        do {
            try FileManager.default.removeItem(at: url)
        } catch let error {
            Log.error("Error deleting file: \(error)")
            return false
        }
        return true
    }
    
    /// Open an existing file with the given mode, which can be for reading, writing or for appending.
    public func openFile(for mode: FileIOMode) {
        switch mode {
        case .read:
            self.fileHandle = FileHandle(forReadingAtPath: self.url.path)
        case .write:
            self.fileHandle = FileHandle(forWritingAtPath: self.url.path)
        case .append:
            self.fileHandle = FileHandle(forUpdatingAtPath: self.url.path)
        }
        self.isFileOpened = true
    }
    
    /// Reads the entire file and return the data object
    public func readToEOF(completion: EADataResultCallback? = nil) {
        self.queue.async {
            do {
                self.data = try Data(contentsOf: self.url)
                if let x = self.data, let cb = completion { cb(.success(x)) }
            } catch let error {
                Log.error("Error reading file: \(error)")
                if let cb = completion { cb(.failure(AppError.fileRead)) }
            }
        }
    }
    
    public func write(_ string: String) {
        self.write(string.data(using: .utf8))
    }
    
    public func write(_ data: Data?) {
        if let data = data, let fh = self.fileHandle {
            self.writeLock.lock()
            fh.write(data)
            self.writeLock.unlock()
        }
    }
    
    public func close() {
        if let fh = self.fileHandle {
            if #available(iOS 13.0, *) {
                do {
                    try fh.close()
                } catch let error {
                    Log.error(error)
                }
            } else {
                fh.closeFile()  // deprecated in iOS 13 above
            }
        }
    }
}

struct EATemporaryFile {
    let dirURL: URL
    let fileURL: URL
    
    init(fileName: String) throws {
        self.dirURL = try FileManager.default.urlForUniqueTemporaryDirectory()
        self.fileURL = dirURL.appendingPathComponent(fileName)
    }
    
    func delete() -> Bool {
        return EAFileManager.delete(url: self.dirURL)
    }
}

extension FileManager {
    func urlForUniqueTemporaryDirectory(_ name: String? = nil) throws -> URL {
        let rootName = name ?? UUID().uuidString
        var count = 0
        var createdDirURL: URL? = nil
        while (true) {
            do {
                let subDirName = count == 0 ? rootName : "\(rootName)-\(count)"
                let subDirURL = self.temporaryDirectory.appendingPathComponent(subDirName, isDirectory: true)
                try self.createDirectory(at: subDirURL, withIntermediateDirectories: false)
                createdDirURL = subDirURL
                break
            } catch CocoaError.fileWriteFileExists {
                Log.error("Error - file exists")
                count += 1
            }
        }
        return createdDirURL!
    }
}
