//
//  AppDelegate.swift
//  NSLoggerSrc
//
//  Created by Simeon Leifer on 7/15/16.
//  Copyright © 2016 droolingcat.com. All rights reserved.
//

import Cocoa
import SKLBits

let log = XCGLogger.defaultInstance()

var appDelegate: AppDelegate?

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

	func applicationDidFinishLaunching(_ aNotification: Notification) {
		appDelegate = self

//		testRing()

		setupLogger()
		testLogger()
	}

	func applicationWillTerminate(_ aNotification: Notification) {
	}

	func setupLogger() {
		log.setup(.verbose, showThreadName: true)

		let logger: XCGNSLoggerDestination = XCGNSLoggerDestination(owner: log)
		logger.outputLogLevel = .verbose
		logger.offlineBehavior = .ringFile
		if log.addLogDestination(logger) {
		}

		logger.startBonjourBrowsing()
	}

	func testLogger() {
		log.verbose("A verbose message, usually useful when working on a specific problem")
		log.debug("A debug message")
		log.blockStart("a block start")
		log.info("An info message, probably useful to power users looking in console.app")
		log.warning("A warning message, may indicate a possible error")
		log.blockEnd()
		log.error("An error occurred, but it's recoverable, just info about what happened")
		log.mark("a mark")
		log.severe("A severe error occurred, we are likely about to crash now")
		let image = NSImage(named: "test")
		log.info(image)
		let data = NSMutableData()
		let small: [UInt8] = [1, 2, 3, 4, 5, 6, 7, 8, 9]
		data.append(UnsafePointer<Void>(small), length: small.count)
		log.info(data)
	}

	func testRing() {
		let capacity: UInt32 = 80
		let fm = FileManager.default
		let urls = fm.urlsForDirectory(.desktopDirectory, inDomains: .userDomainMask)
		let fileName = "ring.xcgnsring"
		var url = urls[0]
		url.appendPathComponent(fileName)
		let testFilePath = url.path!

		let buffer = RingBufferFile(capacity: capacity, filePath: testFilePath)
		buffer.clear()
		print(buffer)
		buffer.push([1, 2, 3, 4])
		print(buffer)
		buffer.push([5, 6, 7])
		print(buffer)
		buffer.push([8, 9])
		print(buffer)
		buffer.push([10])
		print(buffer)
		buffer.push([11, 12, 13, 14, 15])
		print(buffer)
		buffer.push([16, 17, 18, 19])
		print(buffer)
		buffer.push([20, 21, 22])
		print(buffer)
		buffer.push([23, 24])
		print(buffer)
		buffer.push([25])
		print(buffer)
		buffer.push([26, 27, 29, 29, 30])
		print(buffer)
		buffer.push([31, 32, 33, 34])
		print(buffer)
		// will wrap and drop oldest starting with next push
		buffer.push([35, 36, 37])
		print(buffer)
		buffer.push([38, 39])
		print(buffer)
		buffer.push([40])
		print(buffer)
		print("peekSize: ", buffer.peekSize())
		print("peek: ", buffer.peek())
		buffer.drop()
		while buffer.itemCount > 0 {
			print("pop: ", buffer.pop())
			print(buffer)
		}
	}
}
