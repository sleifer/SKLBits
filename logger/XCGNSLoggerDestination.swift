//
//  XCGNSLoggerDestination.swift
//  NSLoggerSrc
//
//  Created by Simeon Leifer on 7/15/16.
//  Copyright © 2016 droolingcat.com. All rights reserved.
//

import Foundation

// constants from NSLogger

// Constants for the "part key" field
let	PART_KEY_MESSAGE_TYPE:UInt8 = 0
let	PART_KEY_TIMESTAMP_S:UInt8 = 1			// "seconds" component of timestamp
let PART_KEY_TIMESTAMP_MS:UInt8 = 2			// milliseconds component of timestamp (optional, mutually exclusive with PART_KEY_TIMESTAMP_US)
let PART_KEY_TIMESTAMP_US:UInt8 = 3			// microseconds component of timestamp (optional, mutually exclusive with PART_KEY_TIMESTAMP_MS)
let PART_KEY_THREAD_ID:UInt8 = 4
let	PART_KEY_TAG:UInt8 = 5
let	PART_KEY_LEVEL:UInt8 = 6
let	PART_KEY_MESSAGE:UInt8 = 7
let PART_KEY_IMAGE_WIDTH:UInt8 = 8			// messages containing an image should also contain a part with the image size
let PART_KEY_IMAGE_HEIGHT:UInt8 = 9			// (this is mainly for the desktop viewer to compute the cell size without having to immediately decode the image)
let PART_KEY_MESSAGE_SEQ:UInt8 = 10			// the sequential number of this message which indicates the order in which messages are generated
let PART_KEY_FILENAME:UInt8 = 11			// when logging, message can contain a file name
let PART_KEY_LINENUMBER:UInt8 = 12			// as well as a line number
let PART_KEY_FUNCTIONNAME:UInt8 = 13			// and a function or method name

// Constants for parts in LOGMSG_TYPE_CLIENTINFO
let PART_KEY_CLIENT_NAME:UInt8 = 20
let PART_KEY_CLIENT_VERSION:UInt8 = 21
let PART_KEY_OS_NAME:UInt8 = 22
let PART_KEY_OS_VERSION:UInt8 = 23
let PART_KEY_CLIENT_MODEL:UInt8 = 24			// For iPhone, device model (i.e 'iPhone', 'iPad', etc)
let PART_KEY_UNIQUEID:UInt8 = 25			// for remote device identification, part of LOGMSG_TYPE_CLIENTINFO

// Area starting at which you may define your own constants
let PART_KEY_USER_DEFINED:UInt8 = 100

// Constants for the "partType" field
let	PART_TYPE_STRING:UInt8 = 0			// Strings are stored as UTF-8 data
let PART_TYPE_BINARY:UInt8 = 1			// A block of binary data
let PART_TYPE_INT16:UInt8 = 2
let PART_TYPE_INT32:UInt8 = 3
let	PART_TYPE_INT64:UInt8 = 4
let PART_TYPE_IMAGE:UInt8 = 5			// An image, stored in PNG format

// Data values for the PART_KEY_MESSAGE_TYPE parts
let LOGMSG_TYPE_LOG:UInt8 = 0			// A standard log message
let	LOGMSG_TYPE_BLOCKSTART:UInt8 = 1			// The start of a "block" (a group of log entries)
let	LOGMSG_TYPE_BLOCKEND:UInt8 = 2			// The end of the last started "block"
let LOGMSG_TYPE_CLIENTINFO:UInt8 = 3			// Information about the client app
let LOGMSG_TYPE_DISCONNECT:UInt8 = 4			// Pseudo-message on the desktop side to identify client disconnects
let LOGMSG_TYPE_MARK:UInt8 = 5			// Pseudo-message that defines a "mark" that users can place in the log flow

let LOGGER_SERVICE_TYPE_SSL	= "_nslogger-ssl._tcp"
let LOGGER_SERVICE_TYPE = "_nslogger._tcp"
let LOGGER_SERVICE_DOMAIN = "local."

/*
	NSLogger packet format

	4b total packet length not including this length value
	2b part count
	part(s)
		1b part key
		1b part type
		nb part data
*/

// ---

let RING_BUFFER_CAPACITY: UInt32 = 5000000 // 5 MB

extension Array {
	
	mutating func orderedInsert(_ elem: Element, isOrderedBefore: (Element, Element) -> Bool) {
		var lo = 0
		var hi = self.count - 1
		while lo <= hi {
			let mid = (lo + hi)/2
			if isOrderedBefore(self[mid], elem) {
				lo = mid + 1
			} else if isOrderedBefore(elem, self[mid]) {
				hi = mid - 1
			} else {
				self.insert(elem, at:mid) // found at position mid
				return
			}
		}
		self.insert(elem, at:lo) // not found, would be inserted at position lo
	}
	
}

class MessageBuffer: CustomStringConvertible, Equatable {
	let seq: Int32
	private var buffer: [UInt8]
	
	init(_ seq: Int32) {
		self.seq = seq
		self.buffer = [UInt8]()
		
		if seq == 0 {
			append(toByteArray(CFSwapInt32HostToBig(UInt32(2))))
			append(toByteArray(CFSwapInt16HostToBig(UInt16(0))))
		} else {
			append(toByteArray(CFSwapInt32HostToBig(UInt32(8))))
			append(toByteArray(CFSwapInt16HostToBig(UInt16(1))))
			append(PART_KEY_MESSAGE_SEQ)
			append(PART_TYPE_INT32)
			append(toByteArray(CFSwapInt32HostToBig(UInt32(seq))))
		}
		
		addTimestamp()
		addThreadID()
	}
	
	init(_ fp: FileHandle?) {
		// TODO: (SKL) whole method needs good failure handling
		let seqData = fp?.readData(ofLength: sizeof(UInt32.self))
		let seqValue = seqData?.withUnsafeBytes { (bytes: UnsafePointer<UInt32>) -> Int32 in
			return Int32(CFSwapInt32HostToBig(bytes.pointee))
		}
		self.seq = seqValue!
		self.buffer = [UInt8]()

		let lenData = fp?.readData(ofLength: sizeof(UInt32.self))
		let lenValue = lenData?.withUnsafeBytes { (bytes: UnsafePointer<UInt32>) -> Int32 in
			return Int32(CFSwapInt32HostToBig(bytes.pointee))
		}

		let packetData = fp?.readData(ofLength: Int(lenValue!))

		if let count = lenValue, let data = packetData {
			append(toByteArray(CFSwapInt32HostToBig(UInt32(count))))
			
			data.withUnsafeBytes { (bytes: UnsafePointer<UInt8>) -> Void in
				append(UnsafeBufferPointer(start: bytes, count: Int(count)))
			}
		}
	}
	
	init(_ raw: [UInt8]) {
		self.seq = Int32(CFSwapInt32HostToBig(UnsafePointer<UInt32>(raw).pointee))
		let data = raw[4..<raw.count]
		self.buffer = [UInt8]()
		self.buffer.append(contentsOf: data)
	}
	
	func raw() -> [UInt8] {
		var rawArray: [UInt8] = toByteArray(CFSwapInt32HostToBig(UInt32(self.seq)))
		rawArray.append(contentsOf: buffer)
		return rawArray
	}
	
	private func toByteArray<T>(_ value: T) -> [UInt8] {
		var value = value
		return withUnsafePointer(&value) {
			Array(UnsafeBufferPointer(start: UnsafePointer<UInt8>($0), count: sizeof(T.self)))
		}
	}
	
	private func append(_ value: UInt8) {
		buffer.append(value)
	}
	
	private func append<C : Collection where C.Iterator.Element == UInt8>(_ newElements: C) {
		buffer.append(contentsOf: newElements)
	}
	
	private func append<S : Sequence where S.Iterator.Element == UInt8>(_ newElements: S) {
		buffer.append(contentsOf: newElements)
	}
	
	func ptr() -> UnsafeMutablePointer<UInt8> {
		return UnsafeMutablePointer<UInt8>(buffer)
	}
	
	func count() -> Int {
		return buffer.count
	}
	
	private func prepareForPart(ofSize byteCount: Int) {
		var bytePtr = ptr()
		let sizePtr = UnsafeMutablePointer<UInt32>(bytePtr)
		let sizeValue = CFSwapInt32HostToBig(sizePtr.pointee)
		
		sizePtr[0] = CFSwapInt32HostToBig(sizeValue + UInt32(byteCount))
		
		bytePtr = bytePtr.advanced(by: 4)
		let partPtr = UnsafeMutablePointer<UInt16>(bytePtr)
		let partValue = CFSwapInt16HostToBig(partPtr.pointee)
		
		partPtr[0] = CFSwapInt16HostToBig(partValue + 1)
	}

	func addInt16(_ value: UInt16, key: UInt8) {
		prepareForPart(ofSize: 4)
		append(key)
		append(PART_TYPE_INT16)
		append(toByteArray(CFSwapInt16HostToBig(value)))
	}
	
	func addInt32(_ value: UInt32, key: UInt8) {
		prepareForPart(ofSize: 6)
		append(key)
		append(PART_TYPE_INT32)
		append(toByteArray(CFSwapInt32HostToBig(value)))
	}

#if __LP64__
	func addInt64(_ value: UInt64, key: UInt8) {
		prepareForPart(ofSize: 10)
		append(key)
		append(PART_TYPE_INT64)
		append(toByteArray(CFSwapInt32HostToBig(UInt32(value >> 32))))
		append(toByteArray(CFSwapInt32HostToBig(UInt32(value))))
	}
#endif
	
	func addString(_ value: String, key: UInt8) {
		let bytes = value.utf8
		let len = bytes.count
		
		prepareForPart(ofSize: 6 + len)
		append(key)
		append(PART_TYPE_STRING)
		append(toByteArray(CFSwapInt32HostToBig(UInt32(len))))
		if len > 0 {
			append(bytes)
		}
	}
	
	func addData(_ value: NSData, key: UInt8, type: UInt8) {
		let len = value.length
		
		prepareForPart(ofSize: 6 + len)
		append(key)
		append(type)
		append(toByteArray(CFSwapInt32HostToBig(UInt32(len))))
		if len > 0 {
			append(UnsafeBufferPointer(start: UnsafePointer<UInt8>(value.bytes), count: len))
		}
	}
	
	func addTimestamp() {
		let t = CFAbsoluteTimeGetCurrent()
		let s = floor(t)
		let us = floor((t - s) * 1000000)
		
		#if __LP64__
			addInt64(s, key: PART_KEY_TIMESTAMP_S)
			addInt64(us, key: PART_KEY_TIMESTAMP_US)
		#else
			addInt32(UInt32(s), key: PART_KEY_TIMESTAMP_S)
			addInt32(UInt32(us), key: PART_KEY_TIMESTAMP_US)
		#endif
	}
	
	func addThreadID() {
		var name: String = "unknown"
		if Thread.isMainThread {
			name = "main"
		} else {
			if let threadName = Thread.current.name, !threadName.isEmpty {
				name = threadName
			} else if let queueName = String(validatingUTF8: __dispatch_queue_get_label(nil)), !queueName.isEmpty {
				name = queueName
			}
			else {
				name = String(format:"%p", Thread.current)
			}
		}
		addString(name, key: PART_KEY_THREAD_ID)
	}
	
	var description: String {
		return "\(self.dynamicType), seq #\(seq)"
	}
}

func ==(lhs: MessageBuffer, rhs: MessageBuffer) -> Bool {
	return lhs === rhs
}

#if os(iOS)
	import UIKit
	public typealias ImageType = UIImage
#elseif os(OSX)
	import AppKit
	public typealias ImageType = NSImage
#endif

enum XCGNSLoggerOfflineOption {
	case drop
	case inMemory
	case runFile
	case ringFile
}

class XCGNSLoggerDestination: NSObject, XCGLogDestinationProtocol, NetServiceBrowserDelegate {
	
	var owner: XCGLogger
	var identifier: String = ""
	var outputLogLevel: XCGLogger.LogLevel = .debug
	
	override var debugDescription: String {
		get {
			return "\(extractClassName(self)): \(identifier) - LogLevel: \(outputLogLevel)"
		}
	}
	
	init(owner: XCGLogger, identifier: String = "") {
		self.owner = owner
		self.identifier = identifier
	}
	
	func processLogDetails(_ logDetails: XCGLogDetails) {
		output(logDetails)
	}
	
	func processInternalLogDetails(_ logDetails: XCGLogDetails) {
		output(logDetails)
	}
	
	func isEnabledForLogLevel (_ logLevel: XCGLogger.LogLevel) -> Bool {
		return logLevel >= self.outputLogLevel
	}
	
	private func convertLogLevel(_ level:XCGLogger.LogLevel) -> Int {
		switch(level) {
		case .severe:
			return 0
		case .error:
			return 1
		case .warning:
			return 2
		case .info:
			return 3
		case .debug:
			return 4
		case .verbose:
			return 5
		case .none:
			return 3
		}
	}

	func output(_ logDetails: XCGLogDetails) {
		if logDetails.logLevel == .none {
			return
		}
		
		logMessage(logDetails.logMessage, filename: logDetails.fileName, lineNumber: logDetails.lineNumber, functionName: logDetails.functionName, domain: nil, level: convertLogLevel(logDetails.logLevel))
	}
	
	/**
	If set, will only connect to receiver with name 'hostName'
	*/
	var hostName: String?
	
	var offlineBehavior: XCGNSLoggerOfflineOption = .drop

	private var runFilePath: String?
	
	private var runFileIndex: UInt64 = 0
	
	private var runFileCount: Int = 0
	
	private var ringFile: RingBufferFile?
	
	private let queue = DispatchQueue(label: "message queue", attributes: .serial, target: nil)

	private var browser: NetServiceBrowser?
	
	private var service: NetService?
	
	private var logStream: CFWriteStream?
	
	private var connected: Bool = false
	
	private var messageSeq: Int32 = 1
	
	private var messageQueue: [MessageBuffer] = []
	
	private var messageBeingSent: MessageBuffer?
	
	private var sentCount: Int = 0
	
	func startBonjourBrowsing() {
		self.browser = NetServiceBrowser()
		if let browser = self.browser {
			browser.delegate = self
			browser.searchForServices(ofType: LOGGER_SERVICE_TYPE, inDomain: LOGGER_SERVICE_DOMAIN)
		}
	}
	
	func stopBonjourBrowsing() {
		if let browser = self.browser {
			browser.stop()
			self.browser = nil
		}
	}
	
	func connect(to service: NetService) {
		print("found service: \(service)")
		
		let serviceName = service.name
		if let hostName = self.hostName {
			if hostName.caseInsensitiveCompare(serviceName) != .orderedSame {
				print("service name: \(serviceName) does not match requested service name: \(hostName)")
				return
			}
		} else {
			if let txtData = service.txtRecordData() {
				if let txtDict = CFNetServiceCreateDictionaryWithTXTData(nil, txtData) as! CFDictionary? {
					var mismatch: Bool = true
					if let value = CFDictionaryGetValue(txtDict, "filterClients") as! CFTypeRef? {
						if CFGetTypeID(value) == CFStringGetTypeID() && CFStringCompare(value as! CFString, "1", CFStringCompareFlags(rawValue: CFOptionFlags(0))) == .compareEqualTo {
							mismatch = false
						}
					}
					if mismatch {
						print("service: \(serviceName) requested that only clients looking for it do connect")
						return
					}
				}
			}
		}
		
		self.service = service
		if tryConnect() == false {
			print("connection attempt failed")
		}
	}
	
	func disconnect(from service: NetService) {
		if self.service == service {
			print("NetService went away: \(service)")
			service.stop()
			self.service = nil
		}
	}
	
	func tryConnect() -> Bool {
		if self.logStream != nil {
			return true
		}
		
		if let service = self.service {
			var outputStream: NSOutputStream?
			service.getInputStream(nil, outputStream: &outputStream)
			self.logStream = outputStream
			
			let eventTypes: CFStreamEventType = [.openCompleted, .canAcceptBytes, .errorOccurred, .endEncountered]
			let options: CFOptionFlags = eventTypes.rawValue
			
			let info = Unmanaged.passUnretained(self).toOpaque()
			var context: CFStreamClientContext = CFStreamClientContext(version: 0, info: info, retain: nil, release: nil, copyDescription: nil)
			CFWriteStreamSetClient(self.logStream, options, { (ws: CFWriteStream?, event: CFStreamEventType, info: UnsafeMutablePointer<Void>?) in
				let me = Unmanaged<XCGNSLoggerDestination>.fromOpaque(info!).takeUnretainedValue()
				if let logStream = me.logStream, let ws = ws, ws == logStream {
					switch event {
					case CFStreamEventType.openCompleted:
						me.connected = true
						me.stopBonjourBrowsing()
						me.pushClientInfoToQueue()
						me.writeMoreData()
					case CFStreamEventType.canAcceptBytes:
						me.writeMoreData()
					case CFStreamEventType.errorOccurred:
						let error: CFError = CFWriteStreamCopyError(ws)
						print("Logger stream error: \(error)")
						me.streamTerminated()
					case CFStreamEventType.endEncountered:
						print("Logger stream end encountered")
						me.streamTerminated()
					default:
						break
					}
				}
				}, &context)
			
			CFWriteStreamScheduleWithRunLoop(self.logStream, CFRunLoopGetCurrent(), CFRunLoopMode.commonModes)

			if CFWriteStreamOpen(self.logStream) {
				print("stream open attempt, waiting for open completion")
				return true
			}

			print("stream open failed.")
			
			CFWriteStreamSetClient(self.logStream, 0, nil, nil)
			if CFWriteStreamGetStatus(self.logStream) == .open {
				CFWriteStreamClose(self.logStream)
			}
			CFWriteStreamUnscheduleFromRunLoop(self.logStream, CFRunLoopGetCurrent(), CFRunLoopMode.commonModes)
			
			stopBonjourBrowsing()
			startBonjourBrowsing()
		}
		
		return false
	}
	
	func disconnect() {
		if let logStream = self.logStream {
			CFWriteStreamSetClient(logStream, 0, nil, nil)
			CFWriteStreamClose(logStream)
			CFWriteStreamUnscheduleFromRunLoop(logStream, CFRunLoopGetCurrent(), CFRunLoopMode.commonModes)
			self.logStream = nil
		}
	}
	
	func writeMoreData() {
		queue.async {
			self.reconcileOfflineStatus()
			if let logStream = self.logStream {
				if CFWriteStreamCanAcceptBytes(logStream) == true {
					self.reconcileOnlineStatus()
					if self.messageBeingSent == nil && self.messageQueue.count > 0 {
						self.messageBeingSent = self.messageQueue.first
						self.sentCount = 0
					}
					if let msg = self.messageBeingSent {
						if self.sentCount < msg.count() {
							let ptr = msg.ptr().advanced(by: self.sentCount)
							let toWrite = msg.count() - self.sentCount
							let written = CFWriteStreamWrite(logStream, ptr, toWrite)
							if written < 0 {
								print("CFWriteStreamWrite returned error: \(written)")
								self.messageBeingSent = nil
							} else {
								self.sentCount = self.sentCount + written
								if self.sentCount == msg.count() {
									if let idx = self.messageQueue.index(where: { $0 == self.messageBeingSent }) {
										self.messageQueue.remove(at: idx)
									}
									self.messageBeingSent = nil
								}
							}
						}
					}
				}
			}
		}
	}
	
	func streamTerminated() {
		self.connected = false
		disconnect()
		if tryConnect() == false {
			print("connection attempt failed")
		}
	}
	
	func pushClientInfoToQueue() {
		let bundle = Bundle.main
		var encoder = MessageBuffer(0)
		encoder.addInt32(UInt32(LOGMSG_TYPE_CLIENTINFO), key: PART_KEY_MESSAGE_TYPE)
		if let version = bundle.infoDictionary?[kCFBundleVersionKey as String] as? String {
			encoder.addString(version, key: PART_KEY_CLIENT_VERSION)
		}
		if let name = bundle.infoDictionary?[kCFBundleNameKey as String] as? String {
			encoder.addString(name, key: PART_KEY_CLIENT_NAME)
		}
		
		#if os(iOS)
			if Thread.isMainThread || Thread.isMultiThreaded() {
				autoreleasepool {
					let device = UIDevice.current()
					encoder.addString(device.name, key: PART_KEY_UNIQUEID);
					encoder.addString(device.systemVersion, key: PART_KEY_OS_VERSION)
					encoder.addString(device.systemName, key: PART_KEY_OS_NAME)
					encoder.addString(device.model, key: PART_KEY_CLIENT_MODEL)
				}
			}
		#elseif os(OSX)
			var osName: String?
			var osVersion: String?
			autoreleasepool {
				if let versionString = NSDictionary(contentsOfFile: "/System/Library/CoreServices/SystemVersion.plist")?.object(forKey: "ProductVersion") as? String, !versionString.isEmpty {
					osName = "macOS"
					osVersion = versionString
				}
			}
			
			var u: utsname = utsname()
			if uname(&u) == 0 {
				osName = withUnsafePointer(&u.sysname, { (ptr) -> String? in
					let int8Ptr = unsafeBitCast(ptr, to: UnsafePointer<Int8>.self)
					return String(validatingUTF8: int8Ptr)
				})
				osVersion = withUnsafePointer(&u.release, { (ptr) -> String? in
					let int8Ptr = unsafeBitCast(ptr, to: UnsafePointer<Int8>.self)
					return String(validatingUTF8: int8Ptr)
				})
			} else {
				osName = "macOS"
				osVersion = ""
			}
			
			encoder.addString(osVersion!, key: PART_KEY_OS_VERSION)
			encoder.addString(osName!, key: PART_KEY_OS_NAME)
			encoder.addString("<unknown>", key: PART_KEY_CLIENT_MODEL)
		#endif
		
		pushMessageToQueue(encoder)
	}
	
	func appendToRunFile(_ encoder: MessageBuffer) {
		if runFilePath == nil {
			do {
				let fm = FileManager.default
				let urls = fm.urlsForDirectory(.cachesDirectory, inDomains: .userDomainMask)
				let identifier = Bundle.main.bundleIdentifier
				if let identifier = identifier, urls.count > 0 {
					let fileName = identifier + ".xcgnsrun"
					var url = urls[0]
					try url.appendPathComponent(fileName)
					runFilePath = url.path
					if let runFilePath = runFilePath {
						if fm.fileExists(atPath: runFilePath) {
							try fm.removeItem(atPath: runFilePath)
						}
						let created = fm.createFile(atPath: runFilePath, contents: nil, attributes: nil)
						if created == false {
							self.runFilePath = nil
						} else {
							self.runFileIndex = 0
							self.runFileCount = 0
						}
					}
				}
			} catch {
			}
		}
		if let runFilePath = runFilePath {
			let fp = FileHandle(forWritingAtPath: runFilePath)
			fp?.seekToEndOfFile()
			var seq = CFSwapInt32HostToBig(UInt32(encoder.seq))
			withUnsafeMutablePointer(&seq, {
				let data1 = Data(bytesNoCopy: UnsafeMutablePointer<UInt8>($0), count: sizeof(seq.dynamicType.self), deallocator: .none)
				fp?.write(data1)
			})
			let data2 = Data(bytesNoCopy: encoder.ptr(), count: encoder.count(), deallocator: .none)
			fp?.write(data2)
			fp?.closeFile()
			self.runFileCount = self.runFileCount + 1
		}
	}
	
	func readFromRunFile() -> MessageBuffer? {
		var encoder: MessageBuffer? = nil
		if let runFilePath = self.runFilePath, runFileCount > 0 {
			let fp = FileHandle(forUpdatingAtPath: runFilePath)
			fp?.seek(toFileOffset: runFileIndex)
			encoder = MessageBuffer(fp)
			if let encoder = encoder {
				self.runFileCount = self.runFileCount - 1
				self.runFileIndex = self.runFileIndex + UInt64(encoder.count() + sizeof(encoder.seq.dynamicType.self))
				if self.runFileCount == 0 {
					fp?.truncateFile(atOffset: 0)
				}
			}
			fp?.closeFile()
		}
		return encoder
	}
	
	func createRingFile() {
		do {
			let fm = FileManager.default
			let urls = fm.urlsForDirectory(.cachesDirectory, inDomains: .userDomainMask)
			let identifier = Bundle.main.bundleIdentifier
			if let identifier = identifier, urls.count > 0 {
				let fileName = identifier + ".xcgnsring"
				var url = urls[0]
				try url.appendPathComponent(fileName)
				self.ringFile = RingBufferFile(capacity: RING_BUFFER_CAPACITY, filePath: url.path!)
			}
		} catch {
		}
	}

	func appendToRingFile(_ encoder: MessageBuffer) {
		if ringFile == nil {
			createRingFile()
		}
		if let ringFile = self.ringFile {
			ringFile.push(encoder.raw())
		}
	}
	
	func readFromRingFile() -> MessageBuffer? {
		if ringFile == nil {
			createRingFile()
		}
		if let ringFile = self.ringFile {
			if let data: [UInt8] = ringFile.pop() {
				return MessageBuffer(data)
			}
		}
		return nil
	}
	
	func reconcileOfflineStatus() {
		if connected == false {
			switch offlineBehavior {
			case .drop:
				self.messageQueue.removeAll()
			case .inMemory:
				// nothing to do, MessageBuffer(s) are put in messageQueue by default
				break
			case .runFile:
				for msg in self.messageQueue {
					appendToRunFile(msg)
				}
				self.messageQueue.removeAll()
			case .ringFile:
				for msg in self.messageQueue {
					appendToRingFile(msg)
				}
				self.messageQueue.removeAll()
			}
		}
	}
	
	func reconcileOnlineStatus() {
		if connected == true {
			if self.messageBeingSent == nil {
				if offlineBehavior == .runFile, let encoder = readFromRunFile() {
					self.messageQueue.orderedInsert(encoder) { $0.seq < $1.seq }
				}
				if offlineBehavior == .ringFile, let encoder = readFromRingFile() {
					self.messageQueue.orderedInsert(encoder) { $0.seq < $1.seq }
				}
			}
		}
	}
	
	func pushMessageToQueue(_ encoder: MessageBuffer) {
		queue.async { 
			self.messageQueue.orderedInsert(encoder) { $0.seq < $1.seq }
			self.writeMoreData()
		}
	}

	func logMessage(_ message: String?, filename: String?, lineNumber: Int?, functionName: String?, domain: String?, level: Int?) {
		let seq = OSAtomicIncrement32Barrier(&messageSeq)
		var encoder = MessageBuffer(seq)
		encoder.addInt32(UInt32(LOGMSG_TYPE_LOG), key: PART_KEY_MESSAGE_TYPE)
		if let domain = domain, domain.characters.count > 0 {
			encoder.addString(domain, key: PART_KEY_TAG)
		}
		if let level = level, level != 0 {
			encoder.addInt16(UInt16(level), key: PART_KEY_LEVEL)
		}
		if let filename = filename, filename.characters.count > 0 {
			encoder.addString(filename, key: PART_KEY_FILENAME)
		}
		if let lineNumber = lineNumber, lineNumber != 0 {
			encoder.addInt32(UInt32(lineNumber), key: PART_KEY_LINENUMBER)
		}
		if let functionName = functionName, functionName.characters.count > 0 {
			encoder.addString(functionName, key: PART_KEY_FUNCTIONNAME)
		}
		if let message = message, message.characters.count > 0 {
			encoder.addString(message, key: PART_KEY_MESSAGE)
		} else {
			encoder.addString("", key: PART_KEY_MESSAGE)
		}
		pushMessageToQueue(encoder)
	}
	
	func logMark(_ message: String?) {
		let seq = OSAtomicIncrement32Barrier(&messageSeq)
		var encoder = MessageBuffer(seq)
		encoder.addInt32(UInt32(LOGMSG_TYPE_MARK), key: PART_KEY_MESSAGE_TYPE)
		if let message = message, message.characters.count > 0 {
			encoder.addString(message, key: PART_KEY_MESSAGE)
		} else {
			let df = CFDateFormatterCreate(nil, nil, .shortStyle, .mediumStyle)
			if let str = CFDateFormatterCreateStringWithAbsoluteTime(nil, df, CFAbsoluteTimeGetCurrent()) as String? {
				encoder.addString(str, key: PART_KEY_MESSAGE)
			}
		}
		pushMessageToQueue(encoder)
	}
	
	func logBlockStart(_ message: String?) {
		let seq = OSAtomicIncrement32Barrier(&messageSeq)
		var encoder = MessageBuffer(seq)
		encoder.addInt32(UInt32(LOGMSG_TYPE_BLOCKSTART), key: PART_KEY_MESSAGE_TYPE)
		if let message = message, message.characters.count > 0 {
			encoder.addString(message, key: PART_KEY_MESSAGE)
		}
		pushMessageToQueue(encoder)
	}
	
	func logBlockEnd() {
		let seq = OSAtomicIncrement32Barrier(&messageSeq)
		var encoder = MessageBuffer(seq)
		encoder.addInt32(UInt32(LOGMSG_TYPE_BLOCKEND), key: PART_KEY_MESSAGE_TYPE)
		pushMessageToQueue(encoder)
	}
	
	func logImage(_ image: ImageType?, filename: String?, lineNumber: Int?, functionName: String?, domain: String?, level: Int?) {
		let seq = OSAtomicIncrement32Barrier(&messageSeq)
		var encoder = MessageBuffer(seq)
		encoder.addInt32(UInt32(LOGMSG_TYPE_LOG), key: PART_KEY_MESSAGE_TYPE)
		if let domain = domain, domain.characters.count > 0 {
			encoder.addString(domain, key: PART_KEY_TAG)
		}
		if let level = level, level != 0 {
			encoder.addInt16(UInt16(level), key: PART_KEY_LEVEL)
		}
		if let filename = filename, filename.characters.count > 0 {
			encoder.addString(filename, key: PART_KEY_FILENAME)
		}
		if let lineNumber = lineNumber, lineNumber != 0 {
			encoder.addInt32(UInt32(lineNumber), key: PART_KEY_LINENUMBER)
		}
		if let functionName = functionName, functionName.characters.count > 0 {
			encoder.addString(functionName, key: PART_KEY_FUNCTIONNAME)
		}
		if let image = image {
			var data: Data?
			var width: UInt32 = 0
			var height: UInt32 = 0
			#if os(iOS)
				data = UIImagePNGRepresentation(image)
				width = UInt32(image.size.width)
				height = UInt32(image.size.height)
			#elseif os(OSX)
				image.lockFocus()
				let bitmap = NSBitmapImageRep(focusedViewRect: NSRect(x: 0, y: 0, width: image.size.width, height: image.size.height))
				image.unlockFocus()
				width = UInt32(image.size.width)
				height = UInt32(image.size.height)
				data = bitmap?.representation(using: .PNG, properties: [:])
			#endif
			
			if let data = data {
				encoder.addInt32(width, key: PART_KEY_IMAGE_WIDTH)
				encoder.addInt32(height, key: PART_KEY_IMAGE_HEIGHT)
				encoder.addData(data, key: PART_KEY_MESSAGE, type: PART_TYPE_IMAGE)
			}
		}
		pushMessageToQueue(encoder)
	}
	
	func logData(_ data: NSData?, filename: String?, lineNumber: Int?, functionName: String?, domain: String?, level: Int?) {
		let seq = OSAtomicIncrement32Barrier(&messageSeq)
		var encoder = MessageBuffer(seq)
		encoder.addInt32(UInt32(LOGMSG_TYPE_LOG), key: PART_KEY_MESSAGE_TYPE)
		if let domain = domain, domain.characters.count > 0 {
			encoder.addString(domain, key: PART_KEY_TAG)
		}
		if let level = level, level != 0 {
			encoder.addInt16(UInt16(level), key: PART_KEY_LEVEL)
		}
		if let filename = filename, filename.characters.count > 0 {
			encoder.addString(filename, key: PART_KEY_FILENAME)
		}
		if let lineNumber = lineNumber, lineNumber != 0 {
			encoder.addInt32(UInt32(lineNumber), key: PART_KEY_LINENUMBER)
		}
		if let functionName = functionName, functionName.characters.count > 0 {
			encoder.addString(functionName, key: PART_KEY_FUNCTIONNAME)
		}
		if let data = data {
			encoder.addData(data, key: PART_KEY_MESSAGE, type: PART_TYPE_BINARY)
		}
		pushMessageToQueue(encoder)
	}
	
	// MARK: NetServiceBrowserDelegate
	
	func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
		connect(to: service)
	}
	
	func netServiceBrowser(_ browser: NetServiceBrowser, didRemove service: NetService, moreComing: Bool) {
		disconnect(from: service)
	}

}

extension XCGLogger {

	class func convertLogLevel(_ level:XCGLogger.LogLevel) -> Int {
		switch(level) {
		case .severe:
			return 0
		case .error:
			return 1
		case .warning:
			return 2
		case .info:
			return 3
		case .debug:
			return 4
		case .verbose:
			return 5
		case .none:
			return 3
		}
	}
	
	func convertLogLevel(_ level:XCGLogger.LogLevel) -> Int {
		switch(level) {
		case .severe:
			return 0
		case .error:
			return 1
		case .warning:
			return 2
		case .info:
			return 3
		case .debug:
			return 4
		case .verbose:
			return 5
		case .none:
			return 3
		}
	}
	
	func onAllNSLogger(_ level: XCGLogger.LogLevel, closure: @noescape (XCGNSLoggerDestination) -> Void) {
		for logDestination in self.logDestinations {
			if logDestination.isEnabledForLogLevel(level) {
				if let logger = logDestination as? XCGNSLoggerDestination {
					closure(logger)
				}
			}
		}
	}
	
	func onAllNonNSLogger(_ level: XCGLogger.LogLevel, closure: @noescape (XCGLogDestinationProtocol) -> Void) {
		for logDestination in self.logDestinations {
			if logDestination.isEnabledForLogLevel(level) {
				if logDestination is XCGNSLoggerDestination == false {
					closure(logDestination)
				}
			}
		}
	}
	
	// MARK: mark
	
	public class func mark( _ closure: @autoclosure () -> String?) {
		self.defaultInstance().mark(closure)
	}
	
	public func mark( _ closure: @autoclosure () -> String?) {
		if let value = closure() {
			onAllNSLogger(.none) { logger in
				logger.logMark(value)
			}
			onAllNonNSLogger(.none) { logger in
				let logDetails = XCGLogDetails(logLevel: .none, date: Date(), logMessage: "<mark: \(value)>", functionName: "", fileName: "", lineNumber: 0)
				logger.processLogDetails(logDetails)
			}
		}
	}
	
	// MARK: block start
	
	public class func blockStart( _ closure: @autoclosure () -> String?) {
		self.defaultInstance().blockStart(closure)
	}
	
	public func blockStart( _ closure: @autoclosure () -> String?) {
		if let value = closure() {
			onAllNSLogger(.none) { logger in
				logger.logBlockStart(value)
			}
			onAllNonNSLogger(.none) { logger in
				let logDetails = XCGLogDetails(logLevel: .none, date: Date(), logMessage: "<block start: \(value)>", functionName: "", fileName: "", lineNumber: 0)
				logger.processLogDetails(logDetails)
			}
		}
	}
	
	// MARK: block end
	
	public class func blockEnd() {
		self.defaultInstance().blockEnd()
	}
	
	public func blockEnd() {
		onAllNSLogger(.none) { logger in
			logger.logBlockEnd()
		}
		onAllNonNSLogger(.none) { logger in
			let logDetails = XCGLogDetails(logLevel: .none, date: Date(), logMessage: "<block end>", functionName: "", fileName: "", lineNumber: 0)
			logger.processLogDetails(logDetails)
		}
	}
	
	// MARK: verbose
	
	public class func verbose( _ closure: @autoclosure () -> ImageType?, functionName: String = #function, fileName: String = #file, lineNumber: Int = #line) {
		self.defaultInstance().verbose(closure())
	}
	
	public class func verbose(_ functionName: String = #function, fileName: String = #file, lineNumber: Int = #line, closure: @noescape () -> ImageType?) {
		self.defaultInstance().verbose(closure())
	}
	
	public func verbose( _ closure: @autoclosure () -> ImageType?, functionName: String = #function, fileName: String = #file, lineNumber: Int = #line) {
		if let value = closure() {
			onAllNSLogger(.verbose) { logger in
				logger.logImage(value, filename: fileName, lineNumber: lineNumber, functionName: functionName, domain: nil, level: convertLogLevel(.verbose))
			}
			onAllNonNSLogger(.verbose) { logger in
				let logDetails = XCGLogDetails(logLevel: .verbose, date: Date(), logMessage: "<image>", functionName: functionName, fileName: fileName, lineNumber: lineNumber)
				logger.processLogDetails(logDetails)
			}
		}
	}
	
	public func verbose(_ functionName: String = #function, fileName: String = #file, lineNumber: Int = #line, closure: @noescape () -> ImageType?) {
		if let value = closure() {
			onAllNSLogger(.verbose) { logger in
				logger.logImage(value, filename: fileName, lineNumber: lineNumber, functionName: functionName, domain: nil, level: convertLogLevel(.verbose))
			}
			onAllNonNSLogger(.verbose) { logger in
				let logDetails = XCGLogDetails(logLevel: .verbose, date: Date(), logMessage: "<image>", functionName: functionName, fileName: fileName, lineNumber: lineNumber)
				logger.processLogDetails(logDetails)
			}
		}
	}
	
	public class func verbose( _ closure: @autoclosure () -> NSData?, functionName: String = #function, fileName: String = #file, lineNumber: Int = #line) {
		self.defaultInstance().verbose(closure())
	}
	
	public class func verbose(_ functionName: String = #function, fileName: String = #file, lineNumber: Int = #line, closure: @noescape () -> NSData?) {
		self.defaultInstance().verbose(closure())
	}
	
	public func verbose( _ closure: @autoclosure () -> NSData?, functionName: String = #function, fileName: String = #file, lineNumber: Int = #line) {
		if let value = closure() {
			onAllNSLogger(.verbose) { logger in
				logger.logData(value, filename: fileName, lineNumber: lineNumber, functionName: functionName, domain: nil, level: convertLogLevel(.verbose))
			}
			onAllNonNSLogger(.verbose) { logger in
				let logDetails = XCGLogDetails(logLevel: .verbose, date: Date(), logMessage: "<data>", functionName: functionName, fileName: fileName, lineNumber: lineNumber)
				logger.processLogDetails(logDetails)
			}
		}
	}
	
	public func verbose(_ functionName: String = #function, fileName: String = #file, lineNumber: Int = #line, closure: @noescape () -> NSData?) {
		if let value = closure() {
			onAllNSLogger(.verbose) { logger in
				logger.logData(value, filename: fileName, lineNumber: lineNumber, functionName: functionName, domain: nil, level: convertLogLevel(.verbose))
			}
			onAllNonNSLogger(.verbose) { logger in
				let logDetails = XCGLogDetails(logLevel: .verbose, date: Date(), logMessage: "<data>", functionName: functionName, fileName: fileName, lineNumber: lineNumber)
				logger.processLogDetails(logDetails)
			}
		}
	}
	
	// MARK: debug

	public class func debug( _ closure: @autoclosure () -> ImageType?, functionName: String = #function, fileName: String = #file, lineNumber: Int = #line) {
		self.defaultInstance().debug(closure())
	}
	
	public class func debug(_ functionName: String = #function, fileName: String = #file, lineNumber: Int = #line, closure: @noescape () -> ImageType?) {
		self.defaultInstance().debug(closure())
	}
	
	public func debug( _ closure: @autoclosure () -> ImageType?, functionName: String = #function, fileName: String = #file, lineNumber: Int = #line) {
		if let value = closure() {
			onAllNSLogger(.debug) { logger in
				logger.logImage(value, filename: fileName, lineNumber: lineNumber, functionName: functionName, domain: nil, level: convertLogLevel(.debug))
			}
			onAllNonNSLogger(.debug) { logger in
				let logDetails = XCGLogDetails(logLevel: .debug, date: Date(), logMessage: "<image>", functionName: functionName, fileName: fileName, lineNumber: lineNumber)
				logger.processLogDetails(logDetails)
			}
		}
	}
	
	public func debug(_ functionName: String = #function, fileName: String = #file, lineNumber: Int = #line, closure: @noescape () -> ImageType?) {
		if let value = closure() {
			onAllNSLogger(.debug) { logger in
				logger.logImage(value, filename: fileName, lineNumber: lineNumber, functionName: functionName, domain: nil, level: convertLogLevel(.debug))
			}
			onAllNonNSLogger(.debug) { logger in
				let logDetails = XCGLogDetails(logLevel: .debug, date: Date(), logMessage: "<image>", functionName: functionName, fileName: fileName, lineNumber: lineNumber)
				logger.processLogDetails(logDetails)
			}
		}
	}
	
	public class func debug( _ closure: @autoclosure () -> NSData?, functionName: String = #function, fileName: String = #file, lineNumber: Int = #line) {
		self.defaultInstance().debug(closure())
	}
	
	public class func debug(_ functionName: String = #function, fileName: String = #file, lineNumber: Int = #line, closure: @noescape () -> NSData?) {
		self.defaultInstance().debug(closure())
	}
	
	public func debug( _ closure: @autoclosure () -> NSData?, functionName: String = #function, fileName: String = #file, lineNumber: Int = #line) {
		if let value = closure() {
			onAllNSLogger(.debug) { logger in
				logger.logData(value, filename: fileName, lineNumber: lineNumber, functionName: functionName, domain: nil, level: convertLogLevel(.debug))
			}
			onAllNonNSLogger(.debug) { logger in
				let logDetails = XCGLogDetails(logLevel: .debug, date: Date(), logMessage: "<data>", functionName: functionName, fileName: fileName, lineNumber: lineNumber)
				logger.processLogDetails(logDetails)
			}
		}
	}
	
	public func debug(_ functionName: String = #function, fileName: String = #file, lineNumber: Int = #line, closure: @noescape () -> NSData?) {
		if let value = closure() {
			onAllNSLogger(.debug) { logger in
				logger.logData(value, filename: fileName, lineNumber: lineNumber, functionName: functionName, domain: nil, level: convertLogLevel(.debug))
			}
			onAllNonNSLogger(.debug) { logger in
				let logDetails = XCGLogDetails(logLevel: .debug, date: Date(), logMessage: "<data>", functionName: functionName, fileName: fileName, lineNumber: lineNumber)
				logger.processLogDetails(logDetails)
			}
		}
	}
	
	// MARK: info
	
	public class func info( _ closure: @autoclosure () -> ImageType?, functionName: String = #function, fileName: String = #file, lineNumber: Int = #line) {
		self.defaultInstance().info(closure())
	}
	
	public class func info(_ functionName: String = #function, fileName: String = #file, lineNumber: Int = #line, closure: @noescape () -> ImageType?) {
		self.defaultInstance().info(closure())
	}
	
	public func info( _ closure: @autoclosure () -> ImageType?, functionName: String = #function, fileName: String = #file, lineNumber: Int = #line) {
		if let value = closure() {
			onAllNSLogger(.info) { logger in
				logger.logImage(value, filename: fileName, lineNumber: lineNumber, functionName: functionName, domain: nil, level: convertLogLevel(.info))
			}
			onAllNonNSLogger(.info) { logger in
				let logDetails = XCGLogDetails(logLevel: .info, date: Date(), logMessage: "<image>", functionName: functionName, fileName: fileName, lineNumber: lineNumber)
				logger.processLogDetails(logDetails)
			}
		}
	}
	
	public func info(_ functionName: String = #function, fileName: String = #file, lineNumber: Int = #line, closure: @noescape () -> ImageType?) {
		if let value = closure() {
			onAllNSLogger(.info) { logger in
				logger.logImage(value, filename: fileName, lineNumber: lineNumber, functionName: functionName, domain: nil, level: convertLogLevel(.info))
			}
			onAllNonNSLogger(.info) { logger in
				let logDetails = XCGLogDetails(logLevel: .info, date: Date(), logMessage: "<image>", functionName: functionName, fileName: fileName, lineNumber: lineNumber)
				logger.processLogDetails(logDetails)
			}
		}
	}
	
	public class func info( _ closure: @autoclosure () -> NSData?, functionName: String = #function, fileName: String = #file, lineNumber: Int = #line) {
		self.defaultInstance().info(closure())
	}
	
	public class func info(_ functionName: String = #function, fileName: String = #file, lineNumber: Int = #line, closure: @noescape () -> NSData?) {
		self.defaultInstance().info(closure())
	}
	
	public func info( _ closure: @autoclosure () -> NSData?, functionName: String = #function, fileName: String = #file, lineNumber: Int = #line) {
		if let value = closure() {
			onAllNSLogger(.info) { logger in
				logger.logData(value, filename: fileName, lineNumber: lineNumber, functionName: functionName, domain: nil, level: convertLogLevel(.info))
			}
			onAllNonNSLogger(.info) { logger in
				let logDetails = XCGLogDetails(logLevel: .info, date: Date(), logMessage: "<data>", functionName: functionName, fileName: fileName, lineNumber: lineNumber)
				logger.processLogDetails(logDetails)
			}
		}
	}
	
	public func info(_ functionName: String = #function, fileName: String = #file, lineNumber: Int = #line, closure: @noescape () -> NSData?) {
		if let value = closure() {
			onAllNSLogger(.info) { logger in
				logger.logData(value, filename: fileName, lineNumber: lineNumber, functionName: functionName, domain: nil, level: convertLogLevel(.info))
			}
			onAllNonNSLogger(.info) { logger in
				let logDetails = XCGLogDetails(logLevel: .verbose, date: Date(), logMessage: "<data>", functionName: functionName, fileName: fileName, lineNumber: lineNumber)
				logger.processLogDetails(logDetails)
			}
		}
	}

	// MARK: warning
	
	public class func warning( _ closure: @autoclosure () -> ImageType?, functionName: String = #function, fileName: String = #file, lineNumber: Int = #line) {
		self.defaultInstance().warning(closure())
	}
	
	public class func warning(_ functionName: String = #function, fileName: String = #file, lineNumber: Int = #line, closure: @noescape () -> ImageType?) {
		self.defaultInstance().warning(closure())
	}
	
	public func warning( _ closure: @autoclosure () -> ImageType?, functionName: String = #function, fileName: String = #file, lineNumber: Int = #line) {
		if let value = closure() {
			onAllNSLogger(.warning) { logger in
				logger.logImage(value, filename: fileName, lineNumber: lineNumber, functionName: functionName, domain: nil, level: convertLogLevel(.warning))
			}
			onAllNonNSLogger(.warning) { logger in
				let logDetails = XCGLogDetails(logLevel: .warning, date: Date(), logMessage: "<image>", functionName: functionName, fileName: fileName, lineNumber: lineNumber)
				logger.processLogDetails(logDetails)
			}
		}
	}
	
	public func warning(_ functionName: String = #function, fileName: String = #file, lineNumber: Int = #line, closure: @noescape () -> ImageType?) {
		if let value = closure() {
			onAllNSLogger(.warning) { logger in
				logger.logImage(value, filename: fileName, lineNumber: lineNumber, functionName: functionName, domain: nil, level: convertLogLevel(.warning))
			}
			onAllNonNSLogger(.warning) { logger in
				let logDetails = XCGLogDetails(logLevel: .warning, date: Date(), logMessage: "<image>", functionName: functionName, fileName: fileName, lineNumber: lineNumber)
				logger.processLogDetails(logDetails)
			}
		}
	}
	
	public class func warning( _ closure: @autoclosure () -> NSData?, functionName: String = #function, fileName: String = #file, lineNumber: Int = #line) {
		self.defaultInstance().warning(closure())
	}
	
	public class func warning(_ functionName: String = #function, fileName: String = #file, lineNumber: Int = #line, closure: @noescape () -> NSData?) {
		self.defaultInstance().warning(closure())
	}
	
	public func warning( _ closure: @autoclosure () -> NSData?, functionName: String = #function, fileName: String = #file, lineNumber: Int = #line) {
		if let value = closure() {
			onAllNSLogger(.warning) { logger in
				logger.logData(value, filename: fileName, lineNumber: lineNumber, functionName: functionName, domain: nil, level: convertLogLevel(.warning))
			}
			onAllNonNSLogger(.warning) { logger in
				let logDetails = XCGLogDetails(logLevel: .warning, date: Date(), logMessage: "<data>", functionName: functionName, fileName: fileName, lineNumber: lineNumber)
				logger.processLogDetails(logDetails)
			}
		}
	}
	
	public func warning(_ functionName: String = #function, fileName: String = #file, lineNumber: Int = #line, closure: @noescape () -> NSData?) {
		if let value = closure() {
			onAllNSLogger(.warning) { logger in
				logger.logData(value, filename: fileName, lineNumber: lineNumber, functionName: functionName, domain: nil, level: convertLogLevel(.warning))
			}
			onAllNonNSLogger(.warning) { logger in
				let logDetails = XCGLogDetails(logLevel: .warning, date: Date(), logMessage: "<data>", functionName: functionName, fileName: fileName, lineNumber: lineNumber)
				logger.processLogDetails(logDetails)
			}
		}
	}

	// MARK: error
	
	public class func error( _ closure: @autoclosure () -> ImageType?, functionName: String = #function, fileName: String = #file, lineNumber: Int = #line) {
		self.defaultInstance().error(closure())
	}
	
	public class func error(_ functionName: String = #function, fileName: String = #file, lineNumber: Int = #line, closure: @noescape () -> ImageType?) {
		self.defaultInstance().error(closure())
	}
	
	public func error( _ closure: @autoclosure () -> ImageType?, functionName: String = #function, fileName: String = #file, lineNumber: Int = #line) {
		if let value = closure() {
			onAllNSLogger(.error) { logger in
				logger.logImage(value, filename: fileName, lineNumber: lineNumber, functionName: functionName, domain: nil, level: convertLogLevel(.error))
			}
			onAllNonNSLogger(.error) { logger in
				let logDetails = XCGLogDetails(logLevel: .error, date: Date(), logMessage: "<image>", functionName: functionName, fileName: fileName, lineNumber: lineNumber)
				logger.processLogDetails(logDetails)
			}
		}
	}
	
	public func error(_ functionName: String = #function, fileName: String = #file, lineNumber: Int = #line, closure: @noescape () -> ImageType?) {
		if let value = closure() {
			onAllNSLogger(.error) { logger in
				logger.logImage(value, filename: fileName, lineNumber: lineNumber, functionName: functionName, domain: nil, level: convertLogLevel(.error))
			}
			onAllNonNSLogger(.error) { logger in
				let logDetails = XCGLogDetails(logLevel: .error, date: Date(), logMessage: "<image>", functionName: functionName, fileName: fileName, lineNumber: lineNumber)
				logger.processLogDetails(logDetails)
			}
		}
	}
	
	public class func error( _ closure: @autoclosure () -> NSData?, functionName: String = #function, fileName: String = #file, lineNumber: Int = #line) {
		self.defaultInstance().error(closure())
	}
	
	public class func error(_ functionName: String = #function, fileName: String = #file, lineNumber: Int = #line, closure: @noescape () -> NSData?) {
		self.defaultInstance().error(closure())
	}
	
	public func error( _ closure: @autoclosure () -> NSData?, functionName: String = #function, fileName: String = #file, lineNumber: Int = #line) {
		if let value = closure() {
			onAllNSLogger(.error) { logger in
				logger.logData(value, filename: fileName, lineNumber: lineNumber, functionName: functionName, domain: nil, level: convertLogLevel(.error))
			}
			onAllNonNSLogger(.error) { logger in
				let logDetails = XCGLogDetails(logLevel: .error, date: Date(), logMessage: "<data>", functionName: functionName, fileName: fileName, lineNumber: lineNumber)
				logger.processLogDetails(logDetails)
			}
		}
	}
	
	public func error(_ functionName: String = #function, fileName: String = #file, lineNumber: Int = #line, closure: @noescape () -> NSData?) {
		if let value = closure() {
			onAllNSLogger(.error) { logger in
				logger.logData(value, filename: fileName, lineNumber: lineNumber, functionName: functionName, domain: nil, level: convertLogLevel(.error))
			}
			onAllNonNSLogger(.error) { logger in
				let logDetails = XCGLogDetails(logLevel: .error, date: Date(), logMessage: "<data>", functionName: functionName, fileName: fileName, lineNumber: lineNumber)
				logger.processLogDetails(logDetails)
			}
		}
	}

	// MARK: severe
	
	public class func severe( _ closure: @autoclosure () -> ImageType?, functionName: String = #function, fileName: String = #file, lineNumber: Int = #line) {
		self.defaultInstance().severe(closure())
	}
	
	public class func severe(_ functionName: String = #function, fileName: String = #file, lineNumber: Int = #line, closure: @noescape () -> ImageType?) {
		self.defaultInstance().severe(closure())
	}
	
	public func severe( _ closure: @autoclosure () -> ImageType?, functionName: String = #function, fileName: String = #file, lineNumber: Int = #line) {
		if let value = closure() {
			onAllNSLogger(.severe) { logger in
				logger.logImage(value, filename: fileName, lineNumber: lineNumber, functionName: functionName, domain: nil, level: convertLogLevel(.severe))
			}
			onAllNonNSLogger(.severe) { logger in
				let logDetails = XCGLogDetails(logLevel: .severe, date: Date(), logMessage: "<image>", functionName: functionName, fileName: fileName, lineNumber: lineNumber)
				logger.processLogDetails(logDetails)
			}
		}
	}
	
	public func severe(_ functionName: String = #function, fileName: String = #file, lineNumber: Int = #line, closure: @noescape () -> ImageType?) {
		if let value = closure() {
			onAllNSLogger(.severe) { logger in
				logger.logImage(value, filename: fileName, lineNumber: lineNumber, functionName: functionName, domain: nil, level: convertLogLevel(.severe))
			}
			onAllNonNSLogger(.severe) { logger in
				let logDetails = XCGLogDetails(logLevel: .severe, date: Date(), logMessage: "<image>", functionName: functionName, fileName: fileName, lineNumber: lineNumber)
				logger.processLogDetails(logDetails)
			}
		}
	}
	
	public class func severe( _ closure: @autoclosure () -> NSData?, functionName: String = #function, fileName: String = #file, lineNumber: Int = #line) {
		self.defaultInstance().severe(closure())
	}
	
	public class func severe(_ functionName: String = #function, fileName: String = #file, lineNumber: Int = #line, closure: @noescape () -> NSData?) {
		self.defaultInstance().severe(closure())
	}
	
	public func severe( _ closure: @autoclosure () -> NSData?, functionName: String = #function, fileName: String = #file, lineNumber: Int = #line) {
		if let value = closure() {
			onAllNSLogger(.severe) { logger in
				logger.logData(value, filename: fileName, lineNumber: lineNumber, functionName: functionName, domain: nil, level: convertLogLevel(.severe))
			}
			onAllNonNSLogger(.severe) { logger in
				let logDetails = XCGLogDetails(logLevel: .severe, date: Date(), logMessage: "<data>", functionName: functionName, fileName: fileName, lineNumber: lineNumber)
				logger.processLogDetails(logDetails)
			}
		}
	}
	
	public func severe(_ functionName: String = #function, fileName: String = #file, lineNumber: Int = #line, closure: @noescape () -> NSData?) {
		if let value = closure() {
			onAllNSLogger(.severe) { logger in
				logger.logData(value, filename: fileName, lineNumber: lineNumber, functionName: functionName, domain: nil, level: convertLogLevel(.severe))
			}
			onAllNonNSLogger(.severe) { logger in
				let logDetails = XCGLogDetails(logLevel: .severe, date: Date(), logMessage: "<data>", functionName: functionName, fileName: fileName, lineNumber: lineNumber)
				logger.processLogDetails(logDetails)
			}
		}
	}
	
}
