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
		log.info("An info message, probably useful to power users looking in console.app")
		log.warning("A warning message, may indicate a possible error")
		log.error("An error occurred, but it's recoverable, just info about what happened")
		log.severe("A severe error occurred, we are likely about to crash now")

		logger.startBonjourBrowsing()
	}

	func applicationWillTerminate(_ aNotification: Notification) {
	}

}

