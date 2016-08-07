//
//  DebugActionSheet.swift
//  SKLBits
//
//  Created by Simeon Leifer on 8/7/16.
//  Copyright © 2016 droolingcat.com. All rights reserved.
//

import UIKit

public typealias DebugActionSheetHandler = (Void) -> (Void)

struct DebugActionSheetAction {
	var title: String
	var action: DebugActionSheetHandler
}

public class DebugActionSheet {
	
	private var actions: [DebugActionSheetAction] = [DebugActionSheetAction]()
	
	public var gesture: UIGestureRecognizer
	
	private(set) public var view: UIView?
	
	public init() {
		let tap = UITapGestureRecognizer()
		self.gesture = tap
		tap.addTarget(self, action: #selector(gestureAction(_:)))
		tap.numberOfTouchesRequired = 2
		tap.numberOfTapsRequired = 1
	}
	
	public func attach(to view: UIView) {
		detachFromView()
		self.view = view
		view.addGestureRecognizer(gesture)
	}
	
	public func detachFromView() {
		if let oldView = self.view {
			oldView.removeGestureRecognizer(gesture)
			self.view = nil
		}
	}
	
	@objc func gestureAction(_ gesture: UIGestureRecognizer) {
		if gesture.state == .ended {
			show()
		}
	}
	
	public func addAction(_ name: String, handler: DebugActionSheetHandler) {
		let action = DebugActionSheetAction(title: name, action: handler)
		actions.append(action)
	}
	
	public func removeAllActions() {
		actions.removeAll()
	}
	
	public func show() {
		let alert = UIAlertController(title: "Debug", message: nil, preferredStyle: .actionSheet)
		
		for item in actions {
			let action = UIAlertAction(title: item.title, style: .default, handler: { (action) in
				item.action()
			})
			alert.addAction(action)
		}

		let action = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
		alert.addAction(action)

		UIApplication.shared.keyWindow?.rootViewController?.present(alert, animated: true, completion: nil)
	}
}
