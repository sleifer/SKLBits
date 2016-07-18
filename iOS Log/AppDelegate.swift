//
//  AppDelegate.swift
//  iOS Log
//
//  Created by Simeon Leifer on 7/16/16.
//  Copyright © 2016 droolingcat.com. All rights reserved.
//

import UIKit

let log = XCGLogger.defaultInstance()

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

	var window: UIWindow?


	func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {

		log.setup(.verbose, showThreadName: true)
		
		let logger: XCGNSLoggerDestination = XCGNSLoggerDestination(owner: log)
		logger.outputLogLevel = .verbose
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
		let image = UIImage(named: "test")
		log.info(image)
		let data = NSMutableData()
		let small: [UInt8] = [1,2,3,4,5,6,7,8,9]
		data.append(UnsafePointer<Void>(small), length: small.count)
		log.info(data)
		
		logger.startBonjourBrowsing()

		return true
	}

	func applicationWillResignActive(_ application: UIApplication) {
		// Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
		// Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
	}

	func applicationDidEnterBackground(_ application: UIApplication) {
		// Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
		// If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
	}

	func applicationWillEnterForeground(_ application: UIApplication) {
		// Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
	}

	func applicationDidBecomeActive(_ application: UIApplication) {
		// Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
	}

	func applicationWillTerminate(_ application: UIApplication) {
		// Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
	}


}

