//
//  AppDelegate.swift
//  iOS Log
//
//  Created by Simeon Leifer on 7/16/16.
//  Copyright © 2016 droolingcat.com. All rights reserved.
//

import UIKit
import SKLBits

let log = XCGLogger.defaultInstance()

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

	var window: UIWindow?

	var auth: PrivacyAuthorization?

	func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {

//		testRing()
		
//		setupLogger()
//		testLogger()
		
		testPrivacyAuth()

		return true
	}

	func testPrivacyAuth() {
		if auth == nil {
			auth = PrivacyAuthorization()
		}
		
		auth?.wantEvent = true
		auth?.wantReminder = true
		auth?.wantPhotos = true
		auth?.wantLocationWhenInUse = true
		auth?.requestAccess()
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
		let image = UIImage(named: "test")
		log.info(image)
		let data = NSMutableData()
		let small: [UInt8] = [1,2,3,4,5,6,7,8,9]
		data.append(UnsafePointer<Void>(small), length: small.count)
		log.info(data)
	}
	
	func testRing() {
		let capacity: UInt32 = 80
		let fm = FileManager.default
		let urls = fm.urlsForDirectory(.desktopDirectory, inDomains: .userDomainMask)
		let fileName = "ring.xcgnsring"
		var url = urls[0]
		try! url.appendPathComponent(fileName)
		let testFilePath = url.path!
		
		let buffer = RingBufferFile(capacity: capacity, filePath: testFilePath)
		buffer.clear()
		print(buffer)
		buffer.push([1,2,3,4])
		print(buffer)
		buffer.push([5,6,7])
		print(buffer)
		buffer.push([8,9])
		print(buffer)
		buffer.push([10])
		print(buffer)
		buffer.push([11,12,13,14,15])
		print(buffer)
		buffer.push([16,17,18,19])
		print(buffer)
		buffer.push([20,21,22])
		print(buffer)
		buffer.push([23,24])
		print(buffer)
		buffer.push([25])
		print(buffer)
		buffer.push([26,27,29,29,30])
		print(buffer)
		buffer.push([31,32,33,34])
		print(buffer)
		// will wrap and drop oldest starting with next push
		buffer.push([35,36,37])
		print(buffer)
		buffer.push([38,39])
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

