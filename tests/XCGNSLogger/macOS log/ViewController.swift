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

	override func viewDidLoad() {
		super.viewDidLoad()
		
		self.view.translatesAutoresizingMaskIntoConstraints = false
		
		NSLayoutConstraint(item: self.view, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: 400).install()
		NSLayoutConstraint(item: self.view, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: 200).install()
		
		let connectBtn = NSButton()
		connectBtn.setButtonType(.momentaryChange)
		connectBtn.title = "Connect"
		connectBtn.target = self
		connectBtn.action = #selector(connectAction(_:))
		connectBtn.translatesAutoresizingMaskIntoConstraints = false
		connectBtn.sizeToFit()
		self.view.addSubview(connectBtn)
		
		NSLayoutConstraint(item: connectBtn, attribute: .left, relatedBy: .equal, toItem: self.view, attribute: .left, multiplier: 1.0, constant: 10.0).install()
		NSLayoutConstraint(item: connectBtn, attribute: .top, relatedBy: .equal, toItem: self.view, attribute: .top, multiplier: 1.0, constant: 10.0).install()
		
		let disconnectBtn = NSButton()
		disconnectBtn.setButtonType(.momentaryChange)
		disconnectBtn.title = "Disonnect"
		disconnectBtn.target = self
		disconnectBtn.action = #selector(disconnectAction(_:))
		disconnectBtn.translatesAutoresizingMaskIntoConstraints = false
		disconnectBtn.sizeToFit()
		self.view.addSubview(disconnectBtn)
		
		NSLayoutConstraint(item: disconnectBtn, attribute: .left, relatedBy: .equal, toItem: connectBtn, attribute: .right, multiplier: 1.0, constant: 10.0).install()
		NSLayoutConstraint(item: disconnectBtn, attribute: .top, relatedBy: .equal, toItem: self.view, attribute: .top, multiplier: 1.0, constant: 10.0).install()
		
		let logBtn = NSButton()
		logBtn.setButtonType(.momentaryChange)
		logBtn.title = "Log Message"
		logBtn.target = self
		logBtn.action = #selector(logAction(_:))
		logBtn.translatesAutoresizingMaskIntoConstraints = false
		logBtn.sizeToFit()
		self.view.addSubview(logBtn)
		
		NSLayoutConstraint(item: logBtn, attribute: .left, relatedBy: .equal, toItem: disconnectBtn, attribute: .right, multiplier: 1.0, constant: 10.0).install()
		NSLayoutConstraint(item: logBtn, attribute: .top, relatedBy: .equal, toItem: self.view, attribute: .top, multiplier: 1.0, constant: 10.0).install()
	}

	override var representedObject: AnyObject? {
		didSet {
		// Update the view, if already loaded.
		}
	}
	
	func connectAction(_ sender: AnyObject) {
	}
	
	func disconnectAction(_ sender: AnyObject) {
	}
	
	func logAction(_ sender: AnyObject) {
		log.debug("got something to say?")
	}

}

