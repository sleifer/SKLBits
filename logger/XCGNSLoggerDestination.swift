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

// ---

typealias MessageBuffer = [UInt8]

#if os(iOS)
	import UIKit
	public typealias ImageType = UIImage
#elseif os(OSX)
	import AppKit
	public typealias ImageType = NSImage
#endif

func toByteArray<T>(_ value: T) -> [UInt8] {
	var value = value
	return withUnsafePointer(&value) {
		Array(UnsafeBufferPointer(start: UnsafePointer<UInt8>($0), count: sizeof(T.self)))
	}
}

class XCGNSLoggerDestination: NSObject, XCGLogDestinationProtocol, NetServiceBrowserDelegate {
	
	var owner: XCGLogger
	var identifier: String = ""
	var outputLogLevel: XCGLogger.LogLevel = .debug
	
	var showLogIdentifier: Bool = false
	var showFunctionName: Bool = true
	var showThreadName: Bool = false
	var showFileName: Bool = true
	var showLineNumber: Bool = true
	var showLogLevel: Bool = true
	var showDate: Bool = true
	
	override var debugDescription: String {
		get {
			return "\(extractClassName(self)): \(identifier) - LogLevel: \(outputLogLevel) showLogIdentifier: \(showLogIdentifier) showFunctionName: \(showFunctionName) showThreadName: \(showThreadName) showLogLevel: \(showLogLevel) showFileName: \(showFileName) showLineNumber: \(showLineNumber) showDate: \(showDate)"
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
	
	private var browser: NetServiceBrowser?
	
	private var service: NetService?
	
	private var logStream: CFWriteStream?
	
	private var messageSeq: Int32 = 1
	
	private var sendQueue: MessageBuffer = MessageBuffer()
	
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
		let success = tryConnect()
		if success == false {
			print("connection attempt failed")
		}
	}
	
	func disconnect(from service: NetService) {
		if self.service == service {
			service.stop()
			self.service = nil
		}
	}
	
	func tryConnect() -> Bool {
		if self.logStream != nil {
			return true
		}
		
		stopBonjourBrowsing()
		
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
				if let logStream = me.logStream, ws = ws where ws == logStream {
					switch event {
					case CFStreamEventType.openCompleted:
						me.pushClientInfoToQueue()
						me.writeMoreData()
					case CFStreamEventType.canAcceptBytes:
						me.writeMoreData()
					case CFStreamEventType.errorOccurred:
						let error: CFError = CFWriteStreamCopyError(ws)
						print("Logger stream error: \(error)")
						me.streamTerminated()
					case CFStreamEventType.endEncountered:
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
		if let logStream = self.logStream {
			if CFWriteStreamCanAcceptBytes(logStream) == true && sendQueue.count > 0 {
				let written = CFWriteStreamWrite(logStream, sendQueue, sendQueue.count)
				if written < 0 {
					print("CFWriteStreamWrite returned error: \(written)")
				} else {
					sendQueue.removeSubrange(0..<written)
				}
			}
		}
	}
	
	func streamTerminated() {
		disconnect()
	}
	
	func messageCreate(_ seq: Int32) -> MessageBuffer {
		var encoder = MessageBuffer()
		if seq == 0 {
			encoder.append(contentsOf: toByteArray(CFSwapInt32HostToBig(UInt32(2))))
			encoder.append(contentsOf: toByteArray(CFSwapInt16HostToBig(UInt16(0))))
		} else {
			encoder.append(contentsOf: toByteArray(CFSwapInt32HostToBig(UInt32(8))))
			encoder.append(contentsOf: toByteArray(CFSwapInt16HostToBig(UInt16(1))))
			encoder.append(PART_KEY_MESSAGE_SEQ)
			encoder.append(PART_TYPE_INT32)
			encoder.append(contentsOf: toByteArray(CFSwapInt32HostToBig(UInt32(seq))))
		}
		
		messageAddTimestamp(&encoder)
		messageAddThreadID(&encoder)
		
		return encoder
	}
	
	func messagePrepareForPart(_ encoder: inout MessageBuffer, byteCount: Int) {
		var bytePtr = UnsafeMutablePointer<UInt8>(encoder)
		let sizePtr = UnsafeMutablePointer<UInt32>(bytePtr)
		let sizeValue = CFSwapInt32HostToBig(sizePtr.pointee)
		
		sizePtr[0] = CFSwapInt32HostToBig(sizeValue + UInt32(byteCount))
		
		bytePtr = bytePtr.advanced(by: 4)
		let partPtr = UnsafeMutablePointer<UInt16>(bytePtr)
		let partValue = CFSwapInt16HostToBig(partPtr.pointee)
		
		partPtr[0] = CFSwapInt16HostToBig(partValue + 1)
	}
	
	func messageAddInt16(_ encoder: inout MessageBuffer, value: UInt16, key: UInt8) {
		messagePrepareForPart(&encoder, byteCount: 4)
		encoder.append(key)
		encoder.append(PART_TYPE_INT16)
		encoder.append(contentsOf: toByteArray(CFSwapInt16HostToBig(value)))
	}
	
	func messageAddInt32(_ encoder: inout MessageBuffer, value: UInt32, key: UInt8) {
		messagePrepareForPart(&encoder, byteCount: 6)
		encoder.append(key)
		encoder.append(PART_TYPE_INT32)
		encoder.append(contentsOf: toByteArray(CFSwapInt32HostToBig(value)))
	}
	
#if __LP64__
	func messageAddInt64(_ encoder: inout MessageBuffer, value: UInt64, key: UInt8) {
		messagePrepareForPart(&encoder, byteCount: 10)
		encoder.append(key)
		encoder.append(PART_TYPE_INT64)
		encoder.append(contentsOf: toByteArray(CFSwapInt32HostToBig(UInt32(value >> 32))))
		encoder.append(contentsOf: toByteArray(CFSwapInt32HostToBig(UInt32(value))))
	}
#endif

	func messageAddString(_ encoder: inout MessageBuffer, value: String, key: UInt8) {
		let bytes = value.utf8
		let len = bytes.count
		
		messagePrepareForPart(&encoder, byteCount: 6 + len)
		encoder.append(key)
		encoder.append(PART_TYPE_STRING)
		encoder.append(contentsOf: toByteArray(CFSwapInt32HostToBig(UInt32(len))))
		if len > 0 {
			encoder.append(contentsOf: bytes)
		}
	}
	
	func messageAddData(_ encoder: inout MessageBuffer, value: NSData, key: UInt8, type: UInt8) {
		let len = value.length
		
		messagePrepareForPart(&encoder, byteCount: 6 + len)
		encoder.append(key)
		encoder.append(type)
		encoder.append(contentsOf: toByteArray(CFSwapInt32HostToBig(UInt32(len))))
		if len > 0 {
			encoder.append(contentsOf: UnsafeBufferPointer(start: UnsafePointer<UInt8>(value.bytes), count: len))
		}
	}
	
	func messageAddTimestamp(_ encoder: inout MessageBuffer) {
		let t = CFAbsoluteTimeGetCurrent()
		let s = floor(t)
		let us = floor((t - s) * 1000000)
		
	#if __LP64__
		messageAddInt64(&encoder, value: s, key: PART_KEY_TIMESTAMP_S)
		messageAddInt64(&encoder, value: us, key: PART_KEY_TIMESTAMP_US)
	#else
		messageAddInt32(&encoder, value: UInt32(s), key: PART_KEY_TIMESTAMP_S)
		messageAddInt32(&encoder, value: UInt32(us), key: PART_KEY_TIMESTAMP_US)
	#endif
	}
	
	func messageAddThreadID(_ encoder: inout MessageBuffer) {
		var name: String = "unknown"
		if Thread.isMainThread {
			name = "main"
		} else {
			if let threadName = Thread.current.name where !threadName.isEmpty {
				name = threadName
			} else if let queueName = String(validatingUTF8: __dispatch_queue_get_label(nil)) where !queueName.isEmpty {
				name = queueName
			}
			else {
				name = String(format:"%p", Thread.current)
			}
		}
		messageAddString(&encoder, value: name, key: PART_KEY_THREAD_ID)
	}

	func pushClientInfoToQueue() {
		let bundle = Bundle.main
		var encoder = messageCreate(0)
		messageAddInt32(&encoder, value: UInt32(LOGMSG_TYPE_CLIENTINFO), key: PART_KEY_MESSAGE_TYPE)
		if let version = bundle.infoDictionary?[kCFBundleVersionKey as String] as? String {
			messageAddString(&encoder, value: version, key: PART_KEY_CLIENT_VERSION)
		}
		if let name = bundle.infoDictionary?[kCFBundleNameKey as String] as? String {
			messageAddString(&encoder, value: name, key: PART_KEY_CLIENT_NAME)
		}
		
		#if os(iOS)
			if Thread.isMainThread || Thread.isMultiThreaded() {
				autoreleasepool {
					let device = UIDevice.current()
					messageAddString(&encoder, value: device.name, key: PART_KEY_UNIQUEID);
					messageAddString(&encoder, value: device.systemVersion, key: PART_KEY_OS_VERSION)
					messageAddString(&encoder, value: device.systemName, key: PART_KEY_OS_NAME)
					messageAddString(&encoder, value: device.model, key: PART_KEY_CLIENT_MODEL)
				}
			}
		#elseif os(OSX)
			var osName: String?
			var osVersion: String?
			autoreleasepool {
				if let versionString = NSDictionary(contentsOfFile: "/System/Library/CoreServices/SystemVersion.plist")?.object(forKey: "ProductVersion") as? String where !versionString.isEmpty {
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
			
			messageAddString(&encoder, value: osVersion!, key: PART_KEY_OS_VERSION)
			messageAddString(&encoder, value: osName!, key: PART_KEY_OS_NAME)
			messageAddString(&encoder, value: "<unknown>", key: PART_KEY_CLIENT_MODEL)
		#endif
		
		pushMessageToQueue(encoder)
		
	}
	
	func pushMessageToQueue(_ encoder: MessageBuffer) {
		sendQueue.append(contentsOf: encoder)
		writeMoreData()
	}

	func logMessage(_ message: String?, filename: String?, lineNumber: Int?, functionName: String?, domain: String?, level: Int?) {
		let seq = OSAtomicIncrement32Barrier(&messageSeq)
		var encoder = messageCreate(seq)
		messageAddInt32(&encoder, value: UInt32(LOGMSG_TYPE_LOG), key: PART_KEY_MESSAGE_TYPE)
		if let domain = domain where domain.characters.count > 0 {
			messageAddString(&encoder, value: domain, key: PART_KEY_TAG)
		}
		if let level = level where level != 0 {
			messageAddInt16(&encoder, value: UInt16(level), key: PART_KEY_LEVEL)
		}
		if let filename = filename where filename.characters.count > 0 {
			messageAddString(&encoder, value: filename, key: PART_KEY_FILENAME)
		}
		if let lineNumber = lineNumber where lineNumber != 0 {
			messageAddInt32(&encoder, value: UInt32(lineNumber), key: PART_KEY_LINENUMBER)
		}
		if let functionName = functionName where functionName.characters.count > 0 {
			messageAddString(&encoder, value: functionName, key: PART_KEY_FUNCTIONNAME)
		}
		if let message = message where message.characters.count > 0 {
			messageAddString(&encoder, value: message, key: PART_KEY_MESSAGE)
		} else {
			messageAddString(&encoder, value: "", key: PART_KEY_MESSAGE)
		}
		pushMessageToQueue(encoder)
	}
	
	func logMark(_ message: String?) {
		let seq = OSAtomicIncrement32Barrier(&messageSeq)
		var encoder = messageCreate(seq)
		messageAddInt32(&encoder, value: UInt32(LOGMSG_TYPE_MARK), key: PART_KEY_MESSAGE_TYPE)
		if let message = message where message.characters.count > 0 {
			messageAddString(&encoder, value: message, key: PART_KEY_MESSAGE)
		} else {
			let df = CFDateFormatterCreate(nil, nil, .shortStyle, .mediumStyle)
			if let str = CFDateFormatterCreateStringWithAbsoluteTime(nil, df, CFAbsoluteTimeGetCurrent()) as String? {
				messageAddString(&encoder, value: str, key: PART_KEY_MESSAGE)
			}
		}
		pushMessageToQueue(encoder)
	}
	
	func logBlockStart(_ message: String?) {
		let seq = OSAtomicIncrement32Barrier(&messageSeq)
		var encoder = messageCreate(seq)
		messageAddInt32(&encoder, value: UInt32(LOGMSG_TYPE_BLOCKSTART), key: PART_KEY_MESSAGE_TYPE)
		if let message = message where message.characters.count > 0 {
			messageAddString(&encoder, value: message, key: PART_KEY_MESSAGE)
		}
		pushMessageToQueue(encoder)
	}
	
	func logBlockEnd() {
		let seq = OSAtomicIncrement32Barrier(&messageSeq)
		var encoder = messageCreate(seq)
		messageAddInt32(&encoder, value: UInt32(LOGMSG_TYPE_BLOCKEND), key: PART_KEY_MESSAGE_TYPE)
		pushMessageToQueue(encoder)
	}
	
	func logImage(_ image: ImageType?, filename: String?, lineNumber: Int?, functionName: String?, domain: String?, level: Int?) {
		let seq = OSAtomicIncrement32Barrier(&messageSeq)
		var encoder = messageCreate(seq)
		messageAddInt32(&encoder, value: UInt32(LOGMSG_TYPE_LOG), key: PART_KEY_MESSAGE_TYPE)
		if let domain = domain where domain.characters.count > 0 {
			messageAddString(&encoder, value: domain, key: PART_KEY_TAG)
		}
		if let level = level where level != 0 {
			messageAddInt16(&encoder, value: UInt16(level), key: PART_KEY_LEVEL)
		}
		if let filename = filename where filename.characters.count > 0 {
			messageAddString(&encoder, value: filename, key: PART_KEY_FILENAME)
		}
		if let lineNumber = lineNumber where lineNumber != 0 {
			messageAddInt32(&encoder, value: UInt32(lineNumber), key: PART_KEY_LINENUMBER)
		}
		if let functionName = functionName where functionName.characters.count > 0 {
			messageAddString(&encoder, value: functionName, key: PART_KEY_FUNCTIONNAME)
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
				messageAddInt32(&encoder, value: width, key: PART_KEY_IMAGE_WIDTH)
				messageAddInt32(&encoder, value: height, key: PART_KEY_IMAGE_HEIGHT)
				messageAddData(&encoder, value: data, key: PART_KEY_MESSAGE, type: PART_TYPE_IMAGE)
			}
		}
		pushMessageToQueue(encoder)
	}
	
	func logData(_ data: NSData?, filename: String?, lineNumber: Int?, functionName: String?, domain: String?, level: Int?) {
		let seq = OSAtomicIncrement32Barrier(&messageSeq)
		var encoder = messageCreate(seq)
		messageAddInt32(&encoder, value: UInt32(LOGMSG_TYPE_LOG), key: PART_KEY_MESSAGE_TYPE)
		if let domain = domain where domain.characters.count > 0 {
			messageAddString(&encoder, value: domain, key: PART_KEY_TAG)
		}
		if let level = level where level != 0 {
			messageAddInt16(&encoder, value: UInt16(level), key: PART_KEY_LEVEL)
		}
		if let filename = filename where filename.characters.count > 0 {
			messageAddString(&encoder, value: filename, key: PART_KEY_FILENAME)
		}
		if let lineNumber = lineNumber where lineNumber != 0 {
			messageAddInt32(&encoder, value: UInt32(lineNumber), key: PART_KEY_LINENUMBER)
		}
		if let functionName = functionName where functionName.characters.count > 0 {
			messageAddString(&encoder, value: functionName, key: PART_KEY_FUNCTIONNAME)
		}
		if let data = data {
			messageAddData(&encoder, value: data, key: PART_KEY_MESSAGE, type: PART_TYPE_BINARY)
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
	
	func onAllNSLogger(closure: @noescape (XCGNSLoggerDestination) -> Void) {
		for logDestination in self.logDestinations {
			if let logger = logDestination as? XCGNSLoggerDestination {
				closure(logger)
			}
		}
	}
	
	// MARK: mark
	
	public class func mark( _ closure: @autoclosure () -> String?) {
		self.defaultInstance().onAllNSLogger { logger in
			logger.logMark(closure())
		}
	}
	
	public func mark( _ closure: @autoclosure () -> String?) {
		onAllNSLogger { logger in
			logger.logMark(closure())
		}
	}
	
	// MARK: block start
	
	public class func blockStart( _ closure: @autoclosure () -> String?) {
		self.defaultInstance().onAllNSLogger { logger in
			logger.logBlockStart(closure())
		}
	}
	
	public func blockStart( _ closure: @autoclosure () -> String?) {
		onAllNSLogger { logger in
			logger.logBlockStart(closure())
		}
	}
	
	// MARK: block end
	
	public class func blockEnd() {
		self.defaultInstance().onAllNSLogger { logger in
			logger.logBlockEnd()
		}
	}
	
	public func blockEnd() {
		onAllNSLogger { logger in
			logger.logBlockEnd()
		}
	}
	
	// MARK: verbose
	
	public class func verbose( _ closure: @autoclosure () -> ImageType?, functionName: String = #function, fileName: String = #file, lineNumber: Int = #line) {
		self.defaultInstance().onAllNSLogger { logger in
			logger.logImage(closure(), filename: fileName, lineNumber: lineNumber, functionName: functionName, domain: nil, level: convertLogLevel(.verbose))
		}
	}
	
	public class func verbose(_ functionName: String = #function, fileName: String = #file, lineNumber: Int = #line, closure: @noescape () -> ImageType?) {
		self.defaultInstance().onAllNSLogger { logger in
			logger.logImage(closure(), filename: fileName, lineNumber: lineNumber, functionName: functionName, domain: nil, level: convertLogLevel(.verbose))
		}
	}
	
	public func verbose( _ closure: @autoclosure () -> ImageType?, functionName: String = #function, fileName: String = #file, lineNumber: Int = #line) {
		onAllNSLogger { logger in
			logger.logImage(closure(), filename: fileName, lineNumber: lineNumber, functionName: functionName, domain: nil, level: convertLogLevel(.verbose))
		}
	}
	
	public func verbose(_ functionName: String = #function, fileName: String = #file, lineNumber: Int = #line, closure: @noescape () -> ImageType?) {
		onAllNSLogger { logger in
			logger.logImage(closure(), filename: fileName, lineNumber: lineNumber, functionName: functionName, domain: nil, level: convertLogLevel(.verbose))
		}
	}
	
	public class func verbose( _ closure: @autoclosure () -> NSData?, functionName: String = #function, fileName: String = #file, lineNumber: Int = #line) {
		self.defaultInstance().onAllNSLogger { logger in
			logger.logData(closure(), filename: fileName, lineNumber: lineNumber, functionName: functionName, domain: nil, level: convertLogLevel(.verbose))
		}
	}
	
	public class func verbose(_ functionName: String = #function, fileName: String = #file, lineNumber: Int = #line, closure: @noescape () -> NSData?) {
		self.defaultInstance().onAllNSLogger { logger in
			logger.logData(closure(), filename: fileName, lineNumber: lineNumber, functionName: functionName, domain: nil, level: convertLogLevel(.verbose))
		}
	}
	
	public func verbose( _ closure: @autoclosure () -> NSData?, functionName: String = #function, fileName: String = #file, lineNumber: Int = #line) {
		onAllNSLogger { logger in
			logger.logData(closure(), filename: fileName, lineNumber: lineNumber, functionName: functionName, domain: nil, level: convertLogLevel(.verbose))
		}
	}
	
	public func verbose(_ functionName: String = #function, fileName: String = #file, lineNumber: Int = #line, closure: @noescape () -> NSData?) {
		onAllNSLogger { logger in
			logger.logData(closure(), filename: fileName, lineNumber: lineNumber, functionName: functionName, domain: nil, level: convertLogLevel(.verbose))
		}
	}
	
	// MARK: debug
	
	public class func debug( _ closure: @autoclosure () -> ImageType?, functionName: String = #function, fileName: String = #file, lineNumber: Int = #line) {
		self.defaultInstance().onAllNSLogger { logger in
			logger.logImage(closure(), filename: fileName, lineNumber: lineNumber, functionName: functionName, domain: nil, level: convertLogLevel(.debug))
		}
	}
	
	public class func debug(_ functionName: String = #function, fileName: String = #file, lineNumber: Int = #line, closure: @noescape () -> ImageType?) {
		self.defaultInstance().onAllNSLogger { logger in
			logger.logImage(closure(), filename: fileName, lineNumber: lineNumber, functionName: functionName, domain: nil, level: convertLogLevel(.debug))
		}
	}
	
	public func debug( _ closure: @autoclosure () -> ImageType?, functionName: String = #function, fileName: String = #file, lineNumber: Int = #line) {
		onAllNSLogger { logger in
			logger.logImage(closure(), filename: fileName, lineNumber: lineNumber, functionName: functionName, domain: nil, level: convertLogLevel(.debug))
		}
	}
	
	public func debug(_ functionName: String = #function, fileName: String = #file, lineNumber: Int = #line, closure: @noescape () -> ImageType?) {
		onAllNSLogger { logger in
			logger.logImage(closure(), filename: fileName, lineNumber: lineNumber, functionName: functionName, domain: nil, level: convertLogLevel(.debug))
		}
	}
	
	public class func debug( _ closure: @autoclosure () -> NSData?, functionName: String = #function, fileName: String = #file, lineNumber: Int = #line) {
		self.defaultInstance().onAllNSLogger { logger in
			logger.logData(closure(), filename: fileName, lineNumber: lineNumber, functionName: functionName, domain: nil, level: convertLogLevel(.debug))
		}
	}
	
	public class func debug(_ functionName: String = #function, fileName: String = #file, lineNumber: Int = #line, closure: @noescape () -> NSData?) {
		self.defaultInstance().onAllNSLogger { logger in
			logger.logData(closure(), filename: fileName, lineNumber: lineNumber, functionName: functionName, domain: nil, level: convertLogLevel(.debug))
		}
	}
	
	public func debug( _ closure: @autoclosure () -> NSData?, functionName: String = #function, fileName: String = #file, lineNumber: Int = #line) {
		onAllNSLogger { logger in
			logger.logData(closure(), filename: fileName, lineNumber: lineNumber, functionName: functionName, domain: nil, level: convertLogLevel(.debug))
		}
	}
	
	public func debug(_ functionName: String = #function, fileName: String = #file, lineNumber: Int = #line, closure: @noescape () -> NSData?) {
		onAllNSLogger { logger in
			logger.logData(closure(), filename: fileName, lineNumber: lineNumber, functionName: functionName, domain: nil, level: convertLogLevel(.debug))
		}
	}
	
	// MARK: info
	
	public class func info( _ closure: @autoclosure () -> ImageType?, functionName: String = #function, fileName: String = #file, lineNumber: Int = #line) {
		self.defaultInstance().onAllNSLogger { logger in
			logger.logImage(closure(), filename: fileName, lineNumber: lineNumber, functionName: functionName, domain: nil, level: convertLogLevel(.info))
		}
	}
	
	public class func info(_ functionName: String = #function, fileName: String = #file, lineNumber: Int = #line, closure: @noescape () -> ImageType?) {
		self.defaultInstance().onAllNSLogger { logger in
			logger.logImage(closure(), filename: fileName, lineNumber: lineNumber, functionName: functionName, domain: nil, level: convertLogLevel(.info))
		}
	}
	
	public func info( _ closure: @autoclosure () -> ImageType?, functionName: String = #function, fileName: String = #file, lineNumber: Int = #line) {
		onAllNSLogger { logger in
			logger.logImage(closure(), filename: fileName, lineNumber: lineNumber, functionName: functionName, domain: nil, level: convertLogLevel(.info))
		}
	}
	
	public func info(_ functionName: String = #function, fileName: String = #file, lineNumber: Int = #line, closure: @noescape () -> ImageType?) {
		onAllNSLogger { logger in
			logger.logImage(closure(), filename: fileName, lineNumber: lineNumber, functionName: functionName, domain: nil, level: convertLogLevel(.info))
		}
	}
	
	public class func info( _ closure: @autoclosure () -> NSData?, functionName: String = #function, fileName: String = #file, lineNumber: Int = #line) {
		self.defaultInstance().onAllNSLogger { logger in
			logger.logData(closure(), filename: fileName, lineNumber: lineNumber, functionName: functionName, domain: nil, level: convertLogLevel(.info))
		}
	}
	
	public class func info(_ functionName: String = #function, fileName: String = #file, lineNumber: Int = #line, closure: @noescape () -> NSData?) {
		self.defaultInstance().onAllNSLogger { logger in
			logger.logData(closure(), filename: fileName, lineNumber: lineNumber, functionName: functionName, domain: nil, level: convertLogLevel(.info))
		}
	}
	
	public func info( _ closure: @autoclosure () -> NSData?, functionName: String = #function, fileName: String = #file, lineNumber: Int = #line) {
		onAllNSLogger { logger in
			logger.logData(closure(), filename: fileName, lineNumber: lineNumber, functionName: functionName, domain: nil, level: convertLogLevel(.info))
		}
	}
	
	public func info(_ functionName: String = #function, fileName: String = #file, lineNumber: Int = #line, closure: @noescape () -> NSData?) {
		onAllNSLogger { logger in
			logger.logData(closure(), filename: fileName, lineNumber: lineNumber, functionName: functionName, domain: nil, level: convertLogLevel(.info))
		}
	}
	
	// MARK: warning
	
	public class func warning( _ closure: @autoclosure () -> ImageType?, functionName: String = #function, fileName: String = #file, lineNumber: Int = #line) {
		self.defaultInstance().onAllNSLogger { logger in
			logger.logImage(closure(), filename: fileName, lineNumber: lineNumber, functionName: functionName, domain: nil, level: convertLogLevel(.warning))
		}
	}
	
	public class func warning(_ functionName: String = #function, fileName: String = #file, lineNumber: Int = #line, closure: @noescape () -> ImageType?) {
		self.defaultInstance().onAllNSLogger { logger in
			logger.logImage(closure(), filename: fileName, lineNumber: lineNumber, functionName: functionName, domain: nil, level: convertLogLevel(.warning))
		}
	}
	
	public func warning( _ closure: @autoclosure () -> ImageType?, functionName: String = #function, fileName: String = #file, lineNumber: Int = #line) {
		onAllNSLogger { logger in
			logger.logImage(closure(), filename: fileName, lineNumber: lineNumber, functionName: functionName, domain: nil, level: convertLogLevel(.warning))
		}
	}
	
	public func warning(_ functionName: String = #function, fileName: String = #file, lineNumber: Int = #line, closure: @noescape () -> ImageType?) {
		onAllNSLogger { logger in
			logger.logImage(closure(), filename: fileName, lineNumber: lineNumber, functionName: functionName, domain: nil, level: convertLogLevel(.warning))
		}
	}
	
	public class func warning( _ closure: @autoclosure () -> NSData?, functionName: String = #function, fileName: String = #file, lineNumber: Int = #line) {
		self.defaultInstance().onAllNSLogger { logger in
			logger.logData(closure(), filename: fileName, lineNumber: lineNumber, functionName: functionName, domain: nil, level: convertLogLevel(.warning))
		}
	}
	
	public class func warning(_ functionName: String = #function, fileName: String = #file, lineNumber: Int = #line, closure: @noescape () -> NSData?) {
		self.defaultInstance().onAllNSLogger { logger in
			logger.logData(closure(), filename: fileName, lineNumber: lineNumber, functionName: functionName, domain: nil, level: convertLogLevel(.warning))
		}
	}
	
	public func warning( _ closure: @autoclosure () -> NSData?, functionName: String = #function, fileName: String = #file, lineNumber: Int = #line) {
		onAllNSLogger { logger in
			logger.logData(closure(), filename: fileName, lineNumber: lineNumber, functionName: functionName, domain: nil, level: convertLogLevel(.warning))
		}
	}
	
	public func warning(_ functionName: String = #function, fileName: String = #file, lineNumber: Int = #line, closure: @noescape () -> NSData?) {
		onAllNSLogger { logger in
			logger.logData(closure(), filename: fileName, lineNumber: lineNumber, functionName: functionName, domain: nil, level: convertLogLevel(.warning))
		}
	}
	
	// MARK: error
	
	public class func error( _ closure: @autoclosure () -> ImageType?, functionName: String = #function, fileName: String = #file, lineNumber: Int = #line) {
		self.defaultInstance().onAllNSLogger { logger in
			logger.logImage(closure(), filename: fileName, lineNumber: lineNumber, functionName: functionName, domain: nil, level: convertLogLevel(.error))
		}
	}
	
	public class func error(_ functionName: String = #function, fileName: String = #file, lineNumber: Int = #line, closure: @noescape () -> ImageType?) {
		self.defaultInstance().onAllNSLogger { logger in
			logger.logImage(closure(), filename: fileName, lineNumber: lineNumber, functionName: functionName, domain: nil, level: convertLogLevel(.error))
		}
	}
	
	public func error( _ closure: @autoclosure () -> ImageType?, functionName: String = #function, fileName: String = #file, lineNumber: Int = #line) {
		onAllNSLogger { logger in
			logger.logImage(closure(), filename: fileName, lineNumber: lineNumber, functionName: functionName, domain: nil, level: convertLogLevel(.error))
		}
	}
	
	public func error(_ functionName: String = #function, fileName: String = #file, lineNumber: Int = #line, closure: @noescape () -> ImageType?) {
		onAllNSLogger { logger in
			logger.logImage(closure(), filename: fileName, lineNumber: lineNumber, functionName: functionName, domain: nil, level: convertLogLevel(.error))
		}
	}
	
	public class func error( _ closure: @autoclosure () -> NSData?, functionName: String = #function, fileName: String = #file, lineNumber: Int = #line) {
		self.defaultInstance().onAllNSLogger { logger in
			logger.logData(closure(), filename: fileName, lineNumber: lineNumber, functionName: functionName, domain: nil, level: convertLogLevel(.error))
		}
	}
	
	public class func error(_ functionName: String = #function, fileName: String = #file, lineNumber: Int = #line, closure: @noescape () -> NSData?) {
		self.defaultInstance().onAllNSLogger { logger in
			logger.logData(closure(), filename: fileName, lineNumber: lineNumber, functionName: functionName, domain: nil, level: convertLogLevel(.error))
		}
	}
	
	public func error( _ closure: @autoclosure () -> NSData?, functionName: String = #function, fileName: String = #file, lineNumber: Int = #line) {
		onAllNSLogger { logger in
			logger.logData(closure(), filename: fileName, lineNumber: lineNumber, functionName: functionName, domain: nil, level: convertLogLevel(.error))
		}
	}
	
	public func error(_ functionName: String = #function, fileName: String = #file, lineNumber: Int = #line, closure: @noescape () -> NSData?) {
		onAllNSLogger { logger in
			logger.logData(closure(), filename: fileName, lineNumber: lineNumber, functionName: functionName, domain: nil, level: convertLogLevel(.error))
		}
	}
	
	// MARK: severe
	
	public class func severe( _ closure: @autoclosure () -> ImageType?, functionName: String = #function, fileName: String = #file, lineNumber: Int = #line) {
		self.defaultInstance().onAllNSLogger { logger in
			logger.logImage(closure(), filename: fileName, lineNumber: lineNumber, functionName: functionName, domain: nil, level: convertLogLevel(.severe))
		}
	}
	
	public class func severe(_ functionName: String = #function, fileName: String = #file, lineNumber: Int = #line, closure: @noescape () -> ImageType?) {
		self.defaultInstance().onAllNSLogger { logger in
			logger.logImage(closure(), filename: fileName, lineNumber: lineNumber, functionName: functionName, domain: nil, level: convertLogLevel(.severe))
		}
	}
	
	public func severe( _ closure: @autoclosure () -> ImageType?, functionName: String = #function, fileName: String = #file, lineNumber: Int = #line) {
		onAllNSLogger { logger in
			logger.logImage(closure(), filename: fileName, lineNumber: lineNumber, functionName: functionName, domain: nil, level: convertLogLevel(.severe))
		}
	}
	
	public func severe(_ functionName: String = #function, fileName: String = #file, lineNumber: Int = #line, closure: @noescape () -> ImageType?) {
		onAllNSLogger { logger in
			logger.logImage(closure(), filename: fileName, lineNumber: lineNumber, functionName: functionName, domain: nil, level: convertLogLevel(.severe))
		}
	}
	
	public class func severe( _ closure: @autoclosure () -> NSData?, functionName: String = #function, fileName: String = #file, lineNumber: Int = #line) {
		self.defaultInstance().onAllNSLogger { logger in
			logger.logData(closure(), filename: fileName, lineNumber: lineNumber, functionName: functionName, domain: nil, level: convertLogLevel(.severe))
		}
	}
	
	public class func severe(_ functionName: String = #function, fileName: String = #file, lineNumber: Int = #line, closure: @noescape () -> NSData?) {
		self.defaultInstance().onAllNSLogger { logger in
			logger.logData(closure(), filename: fileName, lineNumber: lineNumber, functionName: functionName, domain: nil, level: convertLogLevel(.severe))
		}
	}
	
	public func severe( _ closure: @autoclosure () -> NSData?, functionName: String = #function, fileName: String = #file, lineNumber: Int = #line) {
		onAllNSLogger { logger in
			logger.logData(closure(), filename: fileName, lineNumber: lineNumber, functionName: functionName, domain: nil, level: convertLogLevel(.severe))
		}
	}
	
	public func severe(_ functionName: String = #function, fileName: String = #file, lineNumber: Int = #line, closure: @noescape () -> NSData?) {
		onAllNSLogger { logger in
			logger.logData(closure(), filename: fileName, lineNumber: lineNumber, functionName: functionName, domain: nil, level: convertLogLevel(.severe))
		}
	}
	
}
