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
	@IBOutlet weak var testLoggerRingIssueButton: UIButton!

	@IBOutlet weak var imageTint1: UIImageView!
	@IBOutlet weak var imageTint2: UIImageView!

	@IBOutlet weak var feedbackLabel: UILabel!

	@IBOutlet weak var layoutAndHiddenView1: UIView!
	@IBOutlet weak var layoutAndHiddenView2: UIView!

	@IBOutlet weak var focusTestView: UIView!

//	var auth: PrivacyAuthorization?

	let semaphore = DispatchSemaphore(value: 0)

	var visibleCollection: [NSLayoutConstraint] = []

	var hiddenCollection: [NSLayoutConstraint] = []

	override func viewDidLoad() {
		super.viewDidLoad()

		testLoggerButton.contentEdgeInsets = UIEdgeInsets(top: 0, left: 8, bottom: 0, right: 8)
		testRingFileButton.contentEdgeInsets = UIEdgeInsets(top: 0, left: 8, bottom: 0, right: 8)
		testPrivacyButton.contentEdgeInsets = UIEdgeInsets(top: 0, left: 8, bottom: 0, right: 8)
		testLoggerRingIssueButton.contentEdgeInsets = UIEdgeInsets(top: 0, left: 8, bottom: 0, right: 8)

		let debug = DebugActionSheet()
		debug.attach(to: self.view)
		debug.addAction("Alpha", handler: {
			print("GOT Alpha")
		})
		debug.addAction("Bravo", handler: {
			print("GOT Bravo")
		})

		let tap = UITapGestureRecognizer(target: self, action: #selector(toggleHidden))
		layoutAndHiddenView1.addGestureRecognizer(tap)

		let visibleCon = NSLayoutConstraint(item: layoutAndHiddenView1, attribute: .right, relatedBy: .equal, toItem: layoutAndHiddenView2, attribute: .left, multiplier: 1.0, constant: -8.0)
		visibleCollection = [visibleCon]

		let hiddenCon = NSLayoutConstraint(item: layoutAndHiddenView1, attribute: .trailing, relatedBy: .equal, toItem: self.view, attribute: .trailingMargin, multiplier: 1.0, constant: 0.0)
		hiddenCollection = [hiddenCon]

		visibleCollection.installConstraints()

		imageTint1.image = UIImage(named: "cancel")?.tinted(UIColor.red)
		imageTint2.image = UIImage(named: "group")?.tinted(UIColor.red)
	}

	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)

		if let curcon = UIApplication.shared.keyWindow?.visibleViewController() {
			log.debug("\(curcon)")
		} else {
			log.debug("Can't find visibleViewController")
		}

		NotificationCenter.default.addObserver(self, selector: #selector(connectChanged(_:)), name: XGNSLoggerNotification.ConnectChanged, object: nil)
//		NotificationCenter.default.addObserver(self, selector: #selector(authorizationChanged(_:)), name: PrivacyAuthorizationNotification.AuthorizationChanged, object: nil)
	}

	override func viewWillDisappear(_ animated: Bool) {
		super.viewWillDisappear(animated)

		NotificationCenter.default.removeObserver(self)
	}

//	func authorizationChanged(_ note: Notification) {
//		if let type = note.object as? PrivacyAuthorizationType {
//			log.debug("\(type)")
//		}
//	}

	func connectChanged(_ note: Notification) {
		semaphore.signal()
	}

	func toggleHidden() {
		if layoutAndHiddenView2.isHidden == false {
			layoutAndHiddenView2.isHidden = true
			visibleCollection.removeConstraints()
			hiddenCollection.installConstraints()
		} else {
			layoutAndHiddenView2.isHidden = false
			hiddenCollection.removeConstraints()
			visibleCollection.installConstraints()
		}
	}

	override func viewDidLayoutSubviews() {
		if testLoggerButton.backgroundImage(for: .normal) == nil {
			let img1 = UIImage.imageOfSimpleButton(testLoggerButton.bounds, radius: 6)
			testLoggerButton.setBackgroundImage(img1, for: [])

			let img2 = UIImage.imageOfSimpleButton(testRingFileButton.bounds, radius: 6)
			testRingFileButton.setBackgroundImage(img2, for: [])

			let img3 = UIImage.imageOfSimpleButton(testPrivacyButton.bounds, radius: 6)
			testPrivacyButton.setBackgroundImage(img3, for: [])

			let img4 = UIImage.imageOfSimpleButton(testLoggerRingIssueButton.bounds, radius: 6)
			testLoggerRingIssueButton.setBackgroundImage(img4, for: [])
		}
	}

	override func didReceiveMemoryWarning() {
		super.didReceiveMemoryWarning()
		// Dispose of any resources that can be recreated.
	}

	@IBAction func logSomethingAction() {
		print("LOG SOMETHING")
	}

	@IBAction func focusTestAction() {
		if let window = self.view.window as? FocusedTouchWindow {
			self.focusTestView.isHidden = false
			window.focusTouch(to: focusTestView, missHandler: {
				self.focusTestView.isHidden = true
				window.unfocusTouch()
			})
		}
	}

	@IBAction func testPrivacyAuth() {
//		if auth == nil {
//			auth = PrivacyAuthorization()
//		}
//
//		auth?.wantEvent = true
//		auth?.wantReminder = true
//		auth?.wantPhotos = true
//		auth?.wantLocationWhenInUse = true
//		auth?.wantMedia = true
//		auth?.wantSpeechRecognizer = true
//		auth?.wantMicrophone = true
//		auth?.wantCamera = true
//		auth?.wantSiri = true
//		auth?.requestAccess()
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
		var data = Data()
		let small: [UInt8] = [1, 2, 3, 4, 5, 6, 7, 8, 9]
		data.append(UnsafePointer(small), count: small.count)
		log.info(data)
	}

	@IBAction func testRing() {
		let capacity: UInt32 = 80
		let fm = FileManager.default
		let urls = fm.urls(for: .cachesDirectory, in: .userDomainMask)
		let fileName = "testring.xcgnsring"
		var url = urls[0]
		url.appendPathComponent(fileName)
		let testFilePath = url.path

		let buffer = RingBufferFile(capacity: capacity, filePath: testFilePath)
		buffer.clear()
		print(buffer)

		var testArrayValue: UInt8 = 0

		let make = { (_ count: Int) -> ([UInt8]) in
			testArrayValue += 1
			return [UInt8](repeating: testArrayValue, count: count)
		}

		let doPush = { (data: [UInt8]) in
			buffer.push(data)
			print("push: \(data) | Bd: \(buffer.dataStartIndex)/\(buffer.dataEndIndex) | Bb: \(buffer.bufferStartIndex)/\(buffer.bufferEndIndex)")
		}

		let doPeekSize = {
			let value = buffer.peekSize()
			print("peekSize: \(value) | Bd: \(buffer.dataStartIndex)/\(buffer.dataEndIndex) | Bb: \(buffer.bufferStartIndex)/\(buffer.bufferEndIndex)")
		}

		let doPeek = {
			let value = buffer.peek()
			print("peek: \(value) | Bd: \(buffer.dataStartIndex)/\(buffer.dataEndIndex) | Bb: \(buffer.bufferStartIndex)/\(buffer.bufferEndIndex)")
		}

		let doPop = {
			let value = buffer.pop()
			print("pop: \(value) | Bd: \(buffer.dataStartIndex)/\(buffer.dataEndIndex) | Bb: \(buffer.bufferStartIndex)/\(buffer.bufferEndIndex)")
		}

		print("Test 1 (\(testArrayValue))...")
		doPush(make(4))
		doPush(make(3))
		doPush(make(2))
		doPush(make(1))
		doPush(make(5))
		doPush(make(4))
		doPush(make(3))
		doPush(make(2))
		doPush(make(1))
		doPush(make(5))
		doPush(make(4))
		print("will wrap and drop oldest starting with next push")
		doPush(make(3))
		doPush(make(2))
		doPush(make(1))
		doPeekSize()
		doPeek()
		buffer.drop()
		while buffer.itemCount > 0 {
			doPop()
		}

		print("Test 2 (\(testArrayValue))...")
		// test full buffer where new push falls over to start and requires drop (of 2)
		buffer.clear()
		doPush(make(6))
		doPush(make(6))
		doPush(make(6))
		doPush(make(6))
		doPush(make(6))
		doPush(make(6))
		doPush(make(6))
		doPush(make(4))
		buffer.debugLogAllEntries()
		print("buffer should be full - 2, next should go at start of buffer removing 2 entries")
		doPush(make(7))
		buffer.debugLogAllEntries()

		print("Test 3 (\(testArrayValue))...")
		// test an already wrapped buffer where push requires drop of start items that are past data end in buffer
		buffer.clear()
		doPush(make(6))
		doPush(make(6))
		doPush(make(6))
		doPush(make(6))
		doPush(make(6))
		doPush(make(6))
		doPush(make(6))
		doPush(make(4))
		doPop()
		doPop()
		doPop()
		doPop()
		doPop()
		doPop()
		doPush(make(6))
		doPush(make(6))
		doPush(make(6))
		doPush(make(6))
		doPush(make(6))
		doPush(make(4))
		buffer.debugLogAllEntries()
		print("buffer should be wrapped with one entry after a gap after the data end, push should drop 1 leaving start at start of buffer")
		doPush(make(10))
		buffer.debugLogAllEntries()

		print("Done.")

	}

	func connect() {
		if let logger = logger {
			if logger.isConnected == false {
				logger.startBonjourBrowsing()
				semaphore.wait()
			}
		}
	}

	func disconnect() {
		if let logger = logger {
			if logger.isConnected == true {
				logger.disconnect()
				semaphore.wait()
			}
		}
	}

	func resetSeq() {
		if let logger = logger {
			logger.resetSeq()
		}
	}

	@IBAction func testLoggerWithRingIssue() {
		feedbackLabel.text = "Starting Ring Buffer Test"

		log.debug("alpha")
		usleep(10000)
		log.debug("bravo")
		usleep(10000)
		log.debug("charlie")
		usleep(10000)

		disconnect()

		resetSeq()
		log.debug("delta")
		usleep(10000)
		log.debug("echo")
		usleep(10000)
		log.debug("foxtrot")
		usleep(10000)

		resetSeq()
		log.debug("golf")
		usleep(10000)
		log.debug("hotel")
		usleep(10000)
		log.debug("india")
		usleep(10000)

		connect()
		log.debug("juliet")
		usleep(10000)
		log.debug("kilo")
		usleep(10000)
		log.debug("lima")

		feedbackLabel.text = "Ring Buffer Test Complete"
	}

}
