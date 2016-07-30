//
//  ViewController.swift
//  iOS Log
//
//  Created by Simeon Leifer on 7/16/16.
//  Copyright © 2016 droolingcat.com. All rights reserved.
//

import UIKit

import SKLBits

class ViewController: UIViewController {

	@IBOutlet weak var testLoggerButton: UIButton!
	@IBOutlet weak var testRingFileButton: UIButton!
	@IBOutlet weak var testPrivacyButton: UIButton!
	
	var auth: PrivacyAuthorization?
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		testLoggerButton.contentEdgeInsets = UIEdgeInsets(top: 0, left: 8, bottom: 0, right: 8)
		testRingFileButton.contentEdgeInsets = UIEdgeInsets(top: 0, left: 8, bottom: 0, right: 8)
		testPrivacyButton.contentEdgeInsets = UIEdgeInsets(top: 0, left: 8, bottom: 0, right: 8)
	}

	override func viewDidLayoutSubviews() {
		if testLoggerButton.backgroundImage(for: .normal) == nil {
			let img1 = UIImage.imageOfSimpleButton(testLoggerButton.bounds, radius: 6)
			testLoggerButton.setBackgroundImage(img1, for: [])
			
			let img2 = UIImage.imageOfSimpleButton(testRingFileButton.bounds, radius: 6)
			testRingFileButton.setBackgroundImage(img2, for: [])
			
			let img3 = UIImage.imageOfSimpleButton(testPrivacyButton.bounds, radius: 6)
			testPrivacyButton.setBackgroundImage(img3, for: [])
		}
	}

	override func didReceiveMemoryWarning() {
		super.didReceiveMemoryWarning()
		// Dispose of any resources that can be recreated.
	}

	@IBAction func testPrivacyAuth() {
		if auth == nil {
			auth = PrivacyAuthorization()
		}
		
		auth?.wantEvent = true
		auth?.wantReminder = true
		auth?.wantPhotos = true
		auth?.wantLocationWhenInUse = true
		auth?.wantMedia = true
		auth?.wantSpeechRecognizer = true
		auth?.wantMicrophone = true
		auth?.wantCamera = true
		auth?.wantSiri = true
		auth?.requestAccess()
	}

	@IBAction func testLogger() {
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
	
	@IBAction func testRing() {
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

}

