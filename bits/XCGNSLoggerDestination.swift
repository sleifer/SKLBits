//
//  XCGNSLoggerDestination.swift
//  NSLoggerSrc
//
//  Created by Simeon Leifer on 7/15/16.
//  Copyright © 2016 droolingcat.com. All rights reserved.
//

import Foundation

#if !os(watchOS)

// constants from NSLogger

// Constants for the "part key" field
let	partKeyMessageType: UInt8 = 0
let	partKeyTimestampS: UInt8 = 1			// "seconds" component of timestamp
let partKeyTimestampMS: UInt8 = 2			// milliseconds component of timestamp (optional, mutually exclusive with partKeyTimestampUS)
let partKeyTimestampUS: UInt8 = 3			// microseconds component of timestamp (optional, mutually exclusive with partKeyTimestampMS)
let partKeyThreadID: UInt8 = 4
let	partKeyTag: UInt8 = 5
let	partKeyLevel: UInt8 = 6
let	partKeyMessage: UInt8 = 7
let partKeyImagWidth: UInt8 = 8			// messages containing an image should also contain a part with the image size
let partKeyImageHeight: UInt8 = 9			// (this is mainly for the desktop viewer to compute the cell size without having to immediately decode the image)
let partKeyMessageSeq: UInt8 = 10			// the sequential number of this message which indicates the order in which messages are generated
let partKeyFilename: UInt8 = 11			// when logging, message can contain a file name
let partKeyLinenumber: UInt8 = 12			// as well as a line number
let partKeyFunctionname: UInt8 = 13			// and a function or method name

// Constants for parts in logMsgTypeClientInfo
let partKeyClientName: UInt8 = 20
let partKeyClientVersion: UInt8 = 21
let partKeyOSName: UInt8 = 22
let partKeyOSVersion: UInt8 = 23
let partKeyClientModel: UInt8 = 24			// For iPhone, device model (i.e 'iPhone', 'iPad', etc)
let partKeyUniqueID: UInt8 = 25			// for remote device identification, part of logMsgTypeClientInfo

// Area starting at which you may define your own constants
let partKeyUserDefined: UInt8 = 100

// Constants for the "partType" field
let	partTypeString: UInt8 = 0			// Strings are stored as UTF-8 data
let partTypeBinary: UInt8 = 1			// A block of binary data
let partTypeInt16: UInt8 = 2
let partTypeInt32: UInt8 = 3
let	partTypeInt64: UInt8 = 4
let partTypeImage: UInt8 = 5			// An image, stored in PNG format

// Data values for the partKeyMessageType parts
let logMsgTypeLog: UInt8 = 0			// A standard log message
let	logMsgTypeBlockStart: UInt8 = 1			// The start of a "block" (a group of log entries)
let	logMsgTypeBlockEnd: UInt8 = 2			// The end of the last started "block"
let logMsgTypeClientInfo: UInt8 = 3			// Information about the client app
let logMsgTypeDisconnect: UInt8 = 4			// Pseudo-message on the desktop side to identify client disconnects
let logMsgTypeMark: UInt8 = 5			// Pseudo-message that defines a "mark" that users can place in the log flow

let loggerServiceTypeSSL	= "_nslogger-ssl._tcp"
let loggerServiceType = "_nslogger._tcp"
let loggerServiceDomain = "local."

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

public struct XGNSLoggerNotification {
	public static let ConnectChanged = NSNotification.Name("XGNSLoggerNotification_ConnectChanged")
}

let ringBufferCapacity: UInt32 = 5000000 // 5 MB

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
	private(set) var seq: Int32
	private(set) var timestamp: CFAbsoluteTime
	private var buffer: [UInt8]

	init(_ leader: Bool = false) {
		if leader == true {
			self.seq = 0
		} else {
			self.seq = 1
		}
		self.timestamp = CFAbsoluteTimeGetCurrent()
		self.buffer = [UInt8]()

		if seq == 0 {
			append(toByteArray(CFSwapInt32HostToBig(UInt32(2))))
			append(toByteArray(CFSwapInt16HostToBig(UInt16(0))))
		} else {
			append(toByteArray(CFSwapInt32HostToBig(UInt32(8))))
			append(toByteArray(CFSwapInt16HostToBig(UInt16(1))))
			append(partKeyMessageSeq)
			append(partTypeInt32)
			append(toByteArray(CFSwapInt32HostToBig(UInt32(seq))))
		}

		addTimestamp()
		addThreadID()
	}

	init?(_ fp: FileHandle?) {
		if let fp = fp {
			let atomSize = MemoryLayout<UInt32>.size
			let seqData = fp.readData(ofLength: atomSize)
			if seqData.count != atomSize {
				return nil
			}
			let seqValue = seqData.withUnsafeBytes { (bytes: UnsafePointer<UInt32>) -> Int32 in
				return Int32(CFSwapInt32HostToBig(bytes.pointee))
			}
			self.seq = seqValue
			self.timestamp = 0
			self.buffer = [UInt8]()

			let lenData = fp.readData(ofLength: atomSize)
			if lenData.count != atomSize {
				return nil
			}
			let lenValue = lenData.withUnsafeBytes { (bytes: UnsafePointer<UInt32>) -> Int32 in
				return Int32(CFSwapInt32HostToBig(bytes.pointee))
			}

			let packetData = fp.readData(ofLength: Int(lenValue))
			if packetData.count != Int(lenValue) {
				return nil
			}

			append(toByteArray(CFSwapInt32HostToBig(UInt32(lenValue))))

			packetData.withUnsafeBytes { (bytes: UnsafePointer<UInt8>) -> Void in
				append(UnsafeBufferPointer(start: bytes, count: Int(lenValue)))
			}

			extractTimestamp()
		} else {
			return nil
		}
	}

	init(_ raw: [UInt8]) {
		let seqExtract: UInt32 = UnsafePointer(raw).withMemoryRebound(to: UInt32.self, capacity: 1) {
			return $0[0]
		}
		self.seq = Int32(CFSwapInt32HostToBig(seqExtract))
		self.timestamp = 0
		let data = raw[4..<raw.count]
		self.buffer = [UInt8]()
		self.buffer.append(contentsOf: data)

		extractTimestamp()
	}

	private func extractTimestamp() {
		var bytePtr = ptr()
		bytePtr = bytePtr.advanced(by: 4)
		var partCount: UInt16 = 0
		UnsafeMutablePointer(bytePtr).withMemoryRebound(to: UInt16.self, capacity: 1) {
			partCount = CFSwapInt16HostToBig($0[0])
		}
		if partCount >= 3 {
			bytePtr = bytePtr.advanced(by: 2)

			if bytePtr[0] == partKeyMessageSeq && bytePtr[1] == partTypeInt32 {
				bytePtr = bytePtr.advanced(by: 6)
			}

			var s: Double = 0
			var us: Double = 0

#if __LP64__
			if bytePtr[0] == partKeyTimestampS && bytePtr[1] == partTypeInt64 {
				bytePtr = bytePtr.advanced(by: 2)
				var high: UInt32 = 0
				var low: UInt32 = 0
				UnsafeMutablePointer(bytePtr).withMemoryRebound(to: UInt32.self, capacity: 1) {
					high = CFSwapInt32HostToBig($0[0])
				}
				bytePtr = bytePtr.advanced(by: 4)
				UnsafeMutablePointer(bytePtr).withMemoryRebound(to: UInt32.self, capacity: 1) {
					low = CFSwapInt32HostToBig($0[0])
				}
				bytePtr = bytePtr.advanced(by: 4)
				let u64: UInt64 = (UInt64(high) << 32) + UInt64(low)
				s = Double(u64)
			}
#else
			if bytePtr[0] == partKeyTimestampS && bytePtr[1] == partTypeInt32 {
				bytePtr = bytePtr.advanced(by: 2)
				UnsafeMutablePointer(bytePtr).withMemoryRebound(to: UInt32.self, capacity: 1) {
					s = Double(CFSwapInt32HostToBig($0[0]))
				}
				bytePtr = bytePtr.advanced(by: 4)
			}
#endif

#if __LP64__
			if bytePtr[0] == partKeyTimestampUS && bytePtr[1] == partTypeInt64 {
				bytePtr = bytePtr.advanced(by: 2)
				var high: UInt32 = 0
				var low: UInt32 = 0
				UnsafeMutablePointer(bytePtr).withMemoryRebound(to: UInt32.self, capacity: 1) {
					high = CFSwapInt32HostToBig($0[0])
				}
				bytePtr = bytePtr.advanced(by: 4)
				UnsafeMutablePointer(bytePtr).withMemoryRebound(to: UInt32.self, capacity: 1) {
					low = CFSwapInt32HostToBig($0[0])
				}
				bytePtr = bytePtr.advanced(by: 4)
				let u64: UInt64 = (UInt64(high) << 32) + UInt64(low)
				us = Double(u64)
			}
#else
			if bytePtr[0] == partKeyTimestampUS && bytePtr[1] == partTypeInt32 {
				bytePtr = bytePtr.advanced(by: 2)
				UnsafeMutablePointer(bytePtr).withMemoryRebound(to: UInt32.self, capacity: 1) {
					us = Double(CFSwapInt32HostToBig($0[0])) / 1000000.0
				}
				bytePtr = bytePtr.advanced(by: 4)
			}
#endif

			self.timestamp = s + us
		}
	}

	func updateSeq(_ seq: Int32) {
		self.seq = seq

		var bytePtr = ptr()
		bytePtr = bytePtr.advanced(by: 4)
		var partCount: UInt16 = 0
		UnsafeMutablePointer(bytePtr).withMemoryRebound(to: UInt16.self, capacity: 1) {
			partCount = CFSwapInt16HostToBig($0[0])
		}
		if partCount >= 2 {
			bytePtr = bytePtr.advanced(by: 2)

			if bytePtr[0] == partKeyMessageSeq && bytePtr[1] == partTypeInt32 {
				bytePtr = bytePtr.advanced(by: 2)

				UnsafeMutablePointer(bytePtr).withMemoryRebound(to: UInt32.self, capacity: 1) {
					let newValue = UInt32(seq)
					$0[0] = CFSwapInt32HostToBig(newValue)
				}
			}
		}
	}

	func raw() -> [UInt8] {
		var rawArray: [UInt8] = toByteArray(CFSwapInt32HostToBig(UInt32(self.seq)))
		rawArray.append(contentsOf: buffer)
		return rawArray
	}

	private func toByteArray<T>(_ value: T) -> [UInt8] {
		var data = [UInt8](repeating: 0, count: MemoryLayout<T>.size)
		data.withUnsafeMutableBufferPointer {
			UnsafeMutableRawPointer($0.baseAddress!).storeBytes(of: value, as: T.self)
		}
		return data
	}

	private func append(_ value: UInt8) {
		buffer.append(value)
	}

	private func append<C: Collection>(_ newElements: C) where C.Iterator.Element == UInt8 {
		buffer.append(contentsOf: newElements)
	}

	private func append<S: Sequence>(_ newElements: S) where S.Iterator.Element == UInt8 {
		buffer.append(contentsOf: newElements)
	}

	func ptr() -> UnsafeMutablePointer<UInt8> {
		return UnsafeMutablePointer<UInt8>(mutating: buffer)
	}

	func count() -> Int {
		return buffer.count
	}

	private func prepareForPart(ofSize byteCount: Int) {
		var bytePtr = ptr()
		UnsafeMutablePointer(bytePtr).withMemoryRebound(to: UInt32.self, capacity: 1) {
			let currentValue = CFSwapInt32HostToBig($0[0])
			let newValue = currentValue + UInt32(byteCount)
			$0[0] = CFSwapInt32HostToBig(newValue)
		}

		bytePtr = bytePtr.advanced(by: 4)
		UnsafeMutablePointer(bytePtr).withMemoryRebound(to: UInt16.self, capacity: 1) {
			let currentValue = CFSwapInt16HostToBig($0[0])
			let newValue = currentValue + 1
			$0[0] = CFSwapInt16HostToBig(newValue)
		}
	}

	func addInt16(_ value: UInt16, key: UInt8) {
		prepareForPart(ofSize: 4)
		append(key)
		append(partTypeInt16)
		append(toByteArray(CFSwapInt16HostToBig(value)))
	}

	func addInt32(_ value: UInt32, key: UInt8) {
		prepareForPart(ofSize: 6)
		append(key)
		append(partTypeInt32)
		append(toByteArray(CFSwapInt32HostToBig(value)))
	}

#if __LP64__
	func addInt64(_ value: UInt64, key: UInt8) {
		prepareForPart(ofSize: 10)
		append(key)
		append(partTypeInt64)
		append(toByteArray(CFSwapInt32HostToBig(UInt32(value >> 32))))
		append(toByteArray(CFSwapInt32HostToBig(UInt32(value))))
	}
#endif

	func addString(_ value: String, key: UInt8) {
		let bytes = value.utf8
		let len = bytes.count

		prepareForPart(ofSize: 6 + len)
		append(key)
		append(partTypeString)
		append(toByteArray(CFSwapInt32HostToBig(UInt32(len))))
		if len > 0 {
			append(bytes)
		}
	}

	func addData(_ value: Data, key: UInt8, type: UInt8) {
		let len = value.count

		prepareForPart(ofSize: 6 + len)
		append(key)
		append(type)
		append(toByteArray(CFSwapInt32HostToBig(UInt32(len))))
		if len > 0 {
			value.withUnsafeBytes({ (uptr: UnsafePointer<UInt8>) -> Void in
				append(UnsafeBufferPointer(start: uptr, count: len))
			})
		}
	}

	func addTimestamp() {
		let t = self.timestamp
		let s = floor(t)
		let us = floor((t - s) * 1000000)

		#if __LP64__
			addInt64(s, key: partKeyTimestampS)
			addInt64(us, key: partKeyTimestampUS)
		#else
			addInt32(UInt32(s), key: partKeyTimestampS)
			addInt32(UInt32(us), key: partKeyTimestampUS)
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
			} else {
				name = String(format:"%p", Thread.current)
			}
		}
		addString(name, key: partKeyThreadID)
	}

	var description: String {
		return "\(type(of: self)), seq #\(seq)"
	}
}

func == (lhs: MessageBuffer, rhs: MessageBuffer) -> Bool {
	return lhs === rhs
}

#if os(iOS) || os(tvOS)
	import UIKit
	public typealias ImageType = UIImage
#elseif os(OSX)
	import AppKit
	public typealias ImageType = NSImage
#endif

public enum XCGNSLoggerOfflineOption {
	case drop
	case inMemory
	case runFile
	case ringFile
}

public class XCGNSLoggerDestination: NSObject, XCGLogDestinationProtocol, NetServiceBrowserDelegate {

	public var owner: XCGLogger
	public var identifier: String = ""
	public var outputLogLevel: XCGLogger.LogLevel = .debug

	public override var debugDescription: String {
		get {
			return "\(extractClassName(self)): \(identifier) - LogLevel: \(outputLogLevel)"
		}
	}

	public init(owner: XCGLogger, identifier: String = "") {
		self.owner = owner
		self.identifier = identifier
	}

	public func processLogDetails(_ logDetails: XCGLogDetails) {
		output(logDetails)
	}

	public func processInternalLogDetails(_ logDetails: XCGLogDetails) {
		output(logDetails)
	}

	public func isEnabledForLogLevel (_ logLevel: XCGLogger.LogLevel) -> Bool {
		return logLevel >= self.outputLogLevel
	}

	private func convertLogLevel(_ level: XCGLogger.LogLevel) -> Int {
		switch level {
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
	public var hostName: String?

	public var offlineBehavior: XCGNSLoggerOfflineOption = .drop

	private var runFilePath: String?

	private var runFileIndex: UInt64 = 0

	private var runFileCount: Int = 0

	private var ringFile: RingBufferFile?

	private let queue = DispatchQueue(label: "message queue")

	private var browser: NetServiceBrowser?

	private var service: NetService?

	private var logStream: CFWriteStream?

	private var connected: Bool = false

	private var messageSeq: Int32 = 1

	private var messageQueue: [MessageBuffer] = []

	private var messageBeingSent: MessageBuffer?

	private var sentCount: Int = 0

	public var isBrowsing: Bool {
		get {
			if self.browser == nil {
				return true
			}
			return false
		}
	}

	public var isConnected: Bool {
		get {
			return self.connected
		}
	}

	#if DEBUG

	public func resetSeq() {
		messageSeq = 1
	}

	#endif

	public func startBonjourBrowsing() {
		self.browser = NetServiceBrowser()
		if let browser = self.browser {
			browser.delegate = self
			browser.searchForServices(ofType: loggerServiceType, inDomain: loggerServiceDomain)
		}
	}

	public func stopBonjourBrowsing() {
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
				// swiftlint:disable:next force_cast
				if let txtDict = CFNetServiceCreateDictionaryWithTXTData(nil, txtData as CFData) as! CFDictionary? {
					var mismatch: Bool = true
					if let value = CFDictionaryGetValue(txtDict, "filterClients") as CFTypeRef? {
						// swiftlint:disable:next force_cast
						if CFGetTypeID(value) == CFStringGetTypeID() && CFStringCompare(value as! CFString, "1" as CFString!, CFStringCompareFlags(rawValue: CFOptionFlags(0))) == .compareEqualTo {
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
			var outputStream: OutputStream?
			service.getInputStream(nil, outputStream: &outputStream)
			self.logStream = outputStream

			let eventTypes: CFStreamEventType = [.openCompleted, .canAcceptBytes, .errorOccurred, .endEncountered]
			let options: CFOptionFlags = eventTypes.rawValue

			let info = Unmanaged.passUnretained(self).toOpaque()
			var context: CFStreamClientContext = CFStreamClientContext(version: 0, info: info, retain: nil, release: nil, copyDescription: nil)
			CFWriteStreamSetClient(self.logStream, options, { (_ ws: CFWriteStream?, _ event: CFStreamEventType, _ info: UnsafeMutableRawPointer?) in
				let me = Unmanaged<XCGNSLoggerDestination>.fromOpaque(info!).takeUnretainedValue()
				if let logStream = me.logStream, let ws = ws, ws == logStream {
					switch event {
					case CFStreamEventType.openCompleted:
						me.connected = true
						NotificationCenter.default.post(name: XGNSLoggerNotification.ConnectChanged, object: me)
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
						print("Logger should not be here")
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

	public func disconnect() {
		if let logStream = self.logStream {
			CFWriteStreamSetClient(logStream, 0, nil, nil)
			CFWriteStreamClose(logStream)
			CFWriteStreamUnscheduleFromRunLoop(logStream, CFRunLoopGetCurrent(), CFRunLoopMode.commonModes)
			self.logStream = nil
		}
		self.connected = false
		queue.async {
			self.reconcileOfflineStatus()
		}
		NotificationCenter.default.post(name: XGNSLoggerNotification.ConnectChanged, object: self)
	}

	func writeMoreData() {
		queue.async {
			self.reconcileOfflineStatus()
			if let logStream = self.logStream {
				if CFWriteStreamCanAcceptBytes(logStream) == true {
					self.reconcileOnlineStatus()
					if self.messageBeingSent == nil && self.messageQueue.count > 0 {
						self.messageBeingSent = self.messageQueue.first
						if let msg = self.messageBeingSent {
							msg.updateSeq(self.messageSeq)
							self.messageSeq = self.messageSeq + 1
						}
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

									self.queue.async {
										self.writeMoreData()
									}
								}
							}
						}
					}
				}
			}
		}
	}

	func streamTerminated() {
		disconnect()
		if tryConnect() == false {
			print("connection attempt failed")
		}
	}

	func pushClientInfoToQueue() {
		let bundle = Bundle.main
		var encoder = MessageBuffer(true)
		encoder.addInt32(UInt32(logMsgTypeClientInfo), key: partKeyMessageType)
		if let version = bundle.infoDictionary?[kCFBundleVersionKey as String] as? String {
			encoder.addString(version, key: partKeyClientVersion)
		}
		if let name = bundle.infoDictionary?[kCFBundleNameKey as String] as? String {
			encoder.addString(name, key: partKeyClientName)
		}

		#if os(iOS)
			if Thread.isMainThread || Thread.isMultiThreaded() {
				autoreleasepool {
					let device = UIDevice.current
					encoder.addString(device.name, key: partKeyUniqueID)
					encoder.addString(device.systemVersion, key: partKeyOSVersion)
					encoder.addString(device.systemName, key: partKeyOSName)
					encoder.addString(device.model, key: partKeyClientModel)
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
				osName = withUnsafePointer(to: &u.sysname, { (ptr) -> String? in
					let int8Ptr = unsafeBitCast(ptr, to: UnsafePointer<Int8>.self)
					return String(validatingUTF8: int8Ptr)
				})
				osVersion = withUnsafePointer(to: &u.release, { (ptr) -> String? in
					let int8Ptr = unsafeBitCast(ptr, to: UnsafePointer<Int8>.self)
					return String(validatingUTF8: int8Ptr)
				})
			} else {
				osName = "macOS"
				osVersion = ""
			}

			encoder.addString(osVersion!, key: partKeyOSVersion)
			encoder.addString(osName!, key: partKeyOSName)
			encoder.addString("<unknown>", key: partKeyClientModel)
		#endif

		pushMessageToQueue(encoder)
	}

	func appendToRunFile(_ encoder: MessageBuffer) {
		if runFilePath == nil {
			do {
				let fm = FileManager.default
				let urls = fm.urls(for: .cachesDirectory, in: .userDomainMask)
				let identifier = Bundle.main.bundleIdentifier
				if let identifier = identifier, urls.count > 0 {
					let fileName = identifier + ".xcgnsrun"
					var url = urls[0]
					url.appendPathComponent(fileName)
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
			let data1 = Data(buffer: UnsafeBufferPointer<UInt32>(start: &seq, count: 1))
			fp?.write(data1)
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
				self.runFileIndex = self.runFileIndex + UInt64(encoder.count() + MemoryLayout<Int32>.size)
				if self.runFileCount == 0 {
					fp?.truncateFile(atOffset: 0)
				}
			}
			fp?.closeFile()
		}
		return encoder
	}

	func createRingFile() {
		let fm = FileManager.default
		let urls = fm.urls(for: .cachesDirectory, in: .userDomainMask)
		let identifier = Bundle.main.bundleIdentifier
		if let identifier = identifier, urls.count > 0 {
			let fileName = identifier + ".xcgnsring"
			var url = urls[0]
			url.appendPathComponent(fileName)
			self.ringFile = RingBufferFile(capacity: ringBufferCapacity, filePath: url.path)
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
					self.messageQueue.orderedInsert(encoder) { $0.timestamp < $1.timestamp }
				}
				if offlineBehavior == .ringFile, let encoder = readFromRingFile() {
					self.messageQueue.orderedInsert(encoder) { $0.timestamp < $1.timestamp }
				}
			}
		}
	}

	func pushMessageToQueue(_ encoder: MessageBuffer) {
		queue.async {
			self.messageQueue.orderedInsert(encoder) { $0.timestamp < $1.timestamp }
			self.writeMoreData()
		}
	}

	func logMessage(_ message: String?, filename: String?, lineNumber: Int?, functionName: String?, domain: String?, level: Int?) {
		let encoder = MessageBuffer()
		encoder.addInt32(UInt32(logMsgTypeLog), key: partKeyMessageType)
		if let domain = domain, domain.characters.count > 0 {
			encoder.addString(domain, key: partKeyTag)
		}
		if let level = level, level != 0 {
			encoder.addInt16(UInt16(level), key: partKeyLevel)
		}
		if let filename = filename, filename.characters.count > 0 {
			encoder.addString(filename, key: partKeyFilename)
		}
		if let lineNumber = lineNumber, lineNumber != 0 {
			encoder.addInt32(UInt32(lineNumber), key: partKeyLinenumber)
		}
		if let functionName = functionName, functionName.characters.count > 0 {
			encoder.addString(functionName, key: partKeyFunctionname)
		}
		if let message = message, message.characters.count > 0 {
			encoder.addString(message, key: partKeyMessage)
		} else {
			encoder.addString("", key: partKeyMessage)
		}
		pushMessageToQueue(encoder)
	}

	func logMark(_ message: String?) {
		let encoder = MessageBuffer()
		encoder.addInt32(UInt32(logMsgTypeMark), key: partKeyMessageType)
		if let message = message, message.characters.count > 0 {
			encoder.addString(message, key: partKeyMessage)
		} else {
			let df = CFDateFormatterCreate(nil, nil, .shortStyle, .mediumStyle)
			if let str = CFDateFormatterCreateStringWithAbsoluteTime(nil, df, CFAbsoluteTimeGetCurrent()) as String? {
				encoder.addString(str, key: partKeyMessage)
			}
		}
		pushMessageToQueue(encoder)
	}

	func logBlockStart(_ message: String?) {
		let encoder = MessageBuffer()
		encoder.addInt32(UInt32(logMsgTypeBlockStart), key: partKeyMessageType)
		if let message = message, message.characters.count > 0 {
			encoder.addString(message, key: partKeyMessage)
		}
		pushMessageToQueue(encoder)
	}

	func logBlockEnd() {
		let encoder = MessageBuffer()
		encoder.addInt32(UInt32(logMsgTypeBlockEnd), key: partKeyMessageType)
		pushMessageToQueue(encoder)
	}

	func logImage(_ image: ImageType?, filename: String?, lineNumber: Int?, functionName: String?, domain: String?, level: Int?) {
		let encoder = MessageBuffer()
		encoder.addInt32(UInt32(logMsgTypeLog), key: partKeyMessageType)
		if let domain = domain, domain.characters.count > 0 {
			encoder.addString(domain, key: partKeyTag)
		}
		if let level = level, level != 0 {
			encoder.addInt16(UInt16(level), key: partKeyLevel)
		}
		if let filename = filename, filename.characters.count > 0 {
			encoder.addString(filename, key: partKeyFilename)
		}
		if let lineNumber = lineNumber, lineNumber != 0 {
			encoder.addInt32(UInt32(lineNumber), key: partKeyLinenumber)
		}
		if let functionName = functionName, functionName.characters.count > 0 {
			encoder.addString(functionName, key: partKeyFunctionname)
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
				encoder.addInt32(width, key: partKeyImagWidth)
				encoder.addInt32(height, key: partKeyImageHeight)
				encoder.addData(data, key: partKeyMessage, type: partTypeImage)
			}
		}
		pushMessageToQueue(encoder)
	}

	func logData(_ data: Data?, filename: String?, lineNumber: Int?, functionName: String?, domain: String?, level: Int?) {
		let encoder = MessageBuffer()
		encoder.addInt32(UInt32(logMsgTypeLog), key: partKeyMessageType)
		if let domain = domain, domain.characters.count > 0 {
			encoder.addString(domain, key: partKeyTag)
		}
		if let level = level, level != 0 {
			encoder.addInt16(UInt16(level), key: partKeyLevel)
		}
		if let filename = filename, filename.characters.count > 0 {
			encoder.addString(filename, key: partKeyFilename)
		}
		if let lineNumber = lineNumber, lineNumber != 0 {
			encoder.addInt32(UInt32(lineNumber), key: partKeyLinenumber)
		}
		if let functionName = functionName, functionName.characters.count > 0 {
			encoder.addString(functionName, key: partKeyFunctionname)
		}
		if let data = data {
			encoder.addData(data, key: partKeyMessage, type: partTypeBinary)
		}
		pushMessageToQueue(encoder)
	}

	// MARK: NetServiceBrowserDelegate

	public func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
		connect(to: service)
	}

	public func netServiceBrowser(_ browser: NetServiceBrowser, didRemove service: NetService, moreComing: Bool) {
		disconnect(from: service)
	}

}

extension XCGLogger {

	class func convertLogLevel(_ level: XCGLogger.LogLevel) -> Int {
		switch level {
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

	func convertLogLevel(_ level: XCGLogger.LogLevel) -> Int {
		switch level {
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

	func onAllNSLogger(_ level: XCGLogger.LogLevel, closure: (XCGNSLoggerDestination) -> Void) {
		for logDestination in self.logDestinations {
			if logDestination.isEnabledForLogLevel(level) {
				if let logger = logDestination as? XCGNSLoggerDestination {
					closure(logger)
				}
			}
		}
	}

	func onAllNonNSLogger(_ level: XCGLogger.LogLevel, closure: (XCGLogDestinationProtocol) -> Void) {
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

	public class func verbose(_ functionName: String = #function, fileName: String = #file, lineNumber: Int = #line, closure: () -> ImageType?) {
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

	public func verbose(_ functionName: String = #function, fileName: String = #file, lineNumber: Int = #line, closure: () -> ImageType?) {
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

	public class func verbose( _ closure: @autoclosure () -> Data?, functionName: String = #function, fileName: String = #file, lineNumber: Int = #line) {
		self.defaultInstance().verbose(closure())
	}

	public class func verbose(_ functionName: String = #function, fileName: String = #file, lineNumber: Int = #line, closure: () -> Data?) {
		self.defaultInstance().verbose(closure())
	}

	public func verbose( _ closure: @autoclosure () -> Data?, functionName: String = #function, fileName: String = #file, lineNumber: Int = #line) {
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

	public func verbose(_ functionName: String = #function, fileName: String = #file, lineNumber: Int = #line, closure: () -> Data?) {
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

	public class func debug(_ functionName: String = #function, fileName: String = #file, lineNumber: Int = #line, closure: () -> ImageType?) {
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

	public func debug(_ functionName: String = #function, fileName: String = #file, lineNumber: Int = #line, closure: () -> ImageType?) {
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

	public class func debug( _ closure: @autoclosure () -> Data?, functionName: String = #function, fileName: String = #file, lineNumber: Int = #line) {
		self.defaultInstance().debug(closure())
	}

	public class func debug(_ functionName: String = #function, fileName: String = #file, lineNumber: Int = #line, closure: () -> Data?) {
		self.defaultInstance().debug(closure())
	}

	public func debug( _ closure: @autoclosure () -> Data?, functionName: String = #function, fileName: String = #file, lineNumber: Int = #line) {
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

	public func debug(_ functionName: String = #function, fileName: String = #file, lineNumber: Int = #line, closure: () -> Data?) {
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

	public class func info(_ functionName: String = #function, fileName: String = #file, lineNumber: Int = #line, closure: () -> ImageType?) {
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

	public func info(_ functionName: String = #function, fileName: String = #file, lineNumber: Int = #line, closure: () -> ImageType?) {
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

	public class func info( _ closure: @autoclosure () -> Data?, functionName: String = #function, fileName: String = #file, lineNumber: Int = #line) {
		self.defaultInstance().info(closure())
	}

	public class func info(_ functionName: String = #function, fileName: String = #file, lineNumber: Int = #line, closure: () -> Data?) {
		self.defaultInstance().info(closure())
	}

	public func info( _ closure: @autoclosure () -> Data?, functionName: String = #function, fileName: String = #file, lineNumber: Int = #line) {
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

	public func info(_ functionName: String = #function, fileName: String = #file, lineNumber: Int = #line, closure: () -> Data?) {
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

	public class func warning(_ functionName: String = #function, fileName: String = #file, lineNumber: Int = #line, closure: () -> ImageType?) {
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

	public func warning(_ functionName: String = #function, fileName: String = #file, lineNumber: Int = #line, closure: () -> ImageType?) {
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

	public class func warning( _ closure: @autoclosure () -> Data?, functionName: String = #function, fileName: String = #file, lineNumber: Int = #line) {
		self.defaultInstance().warning(closure())
	}

	public class func warning(_ functionName: String = #function, fileName: String = #file, lineNumber: Int = #line, closure: () -> Data?) {
		self.defaultInstance().warning(closure())
	}

	public func warning( _ closure: @autoclosure () -> Data?, functionName: String = #function, fileName: String = #file, lineNumber: Int = #line) {
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

	public func warning(_ functionName: String = #function, fileName: String = #file, lineNumber: Int = #line, closure: () -> Data?) {
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

	public class func error(_ functionName: String = #function, fileName: String = #file, lineNumber: Int = #line, closure: () -> ImageType?) {
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

	public func error(_ functionName: String = #function, fileName: String = #file, lineNumber: Int = #line, closure: () -> ImageType?) {
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

	public class func error( _ closure: @autoclosure () -> Data?, functionName: String = #function, fileName: String = #file, lineNumber: Int = #line) {
		self.defaultInstance().error(closure())
	}

	public class func error(_ functionName: String = #function, fileName: String = #file, lineNumber: Int = #line, closure: () -> Data?) {
		self.defaultInstance().error(closure())
	}

	public func error( _ closure: @autoclosure () -> Data?, functionName: String = #function, fileName: String = #file, lineNumber: Int = #line) {
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

	public func error(_ functionName: String = #function, fileName: String = #file, lineNumber: Int = #line, closure: () -> Data?) {
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

	public class func severe(_ functionName: String = #function, fileName: String = #file, lineNumber: Int = #line, closure: () -> ImageType?) {
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

	public func severe(_ functionName: String = #function, fileName: String = #file, lineNumber: Int = #line, closure: () -> ImageType?) {
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

	public class func severe( _ closure: @autoclosure () -> Data?, functionName: String = #function, fileName: String = #file, lineNumber: Int = #line) {
		self.defaultInstance().severe(closure())
	}

	public class func severe(_ functionName: String = #function, fileName: String = #file, lineNumber: Int = #line, closure: () -> Data?) {
		self.defaultInstance().severe(closure())
	}

	public func severe( _ closure: @autoclosure () -> Data?, functionName: String = #function, fileName: String = #file, lineNumber: Int = #line) {
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

	public func severe(_ functionName: String = #function, fileName: String = #file, lineNumber: Int = #line, closure: () -> Data?) {
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

#endif
