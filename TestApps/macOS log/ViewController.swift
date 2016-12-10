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

}
