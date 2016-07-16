//
//  AppDelegate.swift
//  NSLoggerSrc
//
//  Created by Simeon Leifer on 7/15/16.
//  Copyright © 2016 droolingcat.com. All rights reserved.
//

import Cocoa

let log = XCGLogger.defaultInstance()

var appDelegate: AppDelegate?

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

	func applicationDidFinishLaunching(_ aNotification: Notification) {
		appDelegate = self
		
		log.setup(.verbose, showThreadName: true)

		let logger: XCGNSLoggerDestination = XCGNSLoggerDestination(owner: log)
		logger.outputLogLevel = .verbose
		logger.showLogIdentifier = true
		logger.showFunctionName = true
		logger.showThreadName = true
		logger.showLogLevel = true
		logger.showFileName = true
		logger.showLineNumber = true
		logger.showDate = true
		if log.addLogDestination(logger) {
		}

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
		let small: [UInt8] = [1,2,3,4,5,6,7,8,9]
		data.append(UnsafePointer<Void>(small), length: small.count)
		log.info(data)

		logger.startBonjourBrowsing()
	}

	func applicationWillTerminate(_ aNotification: Notification) {
	}

}

