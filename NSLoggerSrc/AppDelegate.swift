//
//  AppDelegate.swift
//  NSLoggerSrc
//
//  Created by Simeon Leifer on 7/15/16.
//  Copyright © 2016 droolingcat.com. All rights reserved.
//

import Cocoa

var appDelegate: AppDelegate?

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

	var logger: NSLoggerDestination = NSLoggerDestination()
	
	func applicationDidFinishLaunching(_ aNotification: Notification) {
		appDelegate = self
		logger.startBonjourBrowsing()
	}

	func applicationWillTerminate(_ aNotification: Notification) {
		logger.stopBonjourBrowsing()
		logger.disconnect()
	}

}

