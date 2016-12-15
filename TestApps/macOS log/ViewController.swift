//
//  ViewController.swift
//  NSLoggerSrc
//
//  Created by Simeon Leifer on 7/15/16.
//  Copyright © 2016 droolingcat.com. All rights reserved.
//

import Cocoa
import SKLBits

class ViewController: NSViewController {

	var deferred: DeferredAction?

	@IBAction func connectAction(_ sender: AnyObject) {
		if let logger = logger {
			if logger.isConnected == false {
				logger.startBonjourBrowsing()
			}
		}
	}

	@IBAction func disconnectAction(_ sender: AnyObject) {
		if let logger = logger {
			if logger.isConnected == true {
				logger.disconnect()
			}
		}
	}

	@IBAction func logAction(_ sender: AnyObject) {
		log.debug("got something to say?")
	}

	func logDeferMessage() {
		log.debug("Deferred action happened")
	}

	@IBAction func deferSet(_ sender: AnyObject) {
		deferred = DeferredAction(after: 5) { [weak self] (action: DeferredAction) in
			self?.logDeferMessage()
			self?.deferred = nil
		}
	}

	@IBAction func deferCancel(_ sender: AnyObject) {
		deferred?.cancel()
		deferred = nil
	}

	@IBAction func deferReset(_ sender: AnyObject) {
		deferred?.reset(delay: 5)
	}

	@IBAction func deferFire(_ sender: AnyObject) {
		deferred?.fire()
	}

}
