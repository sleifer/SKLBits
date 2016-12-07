//
//  FocusedTouchWindow.swift
//  SKLBits
//
//  Created by Simeon Leifer on 10/18/16.
//  Copyright © 2016 droolingcat.com. All rights reserved.
//

#if os(iOS)

import UIKit

public class FocusedTouchWindow: UIWindow {

	private var touchableView: UIView?
	private var focusMissHandler: ((Void) -> (Void))?

	public func focusTouch(to view: UIView, missHandler: @escaping (Void) -> (Void)) {
		self.touchableView = view
		self.focusMissHandler = missHandler
	}

	public func unfocusTouch() {
		self.touchableView = nil
		self.focusMissHandler = nil
	}

	override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
		let nominalView = super.hitTest(point, with: event)

		if let touchableView = touchableView, let nominalView = nominalView {
			if touchableView.isParent(of: nominalView) {
				return nominalView
			} else {
				return self
			}
		}

		return nominalView
	}

	func haveLiveTouches(_ touches: Set<UITouch>) -> Bool {
		for oneTouch in touches {
			if oneTouch.view == nil || touchableView?.isParent(of: oneTouch.view!) == false {
				if oneTouch.phase != .ended && oneTouch.phase != .cancelled {
					return true
				}
			}
		}
		return false
	}

	func processTouches(_ touches: Set<UITouch>) {
		if let focusMissHandler = focusMissHandler, touchableView != nil, haveLiveTouches(touches) == true {
			focusMissHandler()
		}
	}

	override public func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
		if let ours = event?.touches(for: self) {
			processTouches(ours)
		}
	}

	override public func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
		if let ours = event?.touches(for: self) {
			processTouches(ours)
		}
	}

	override public func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
		if let ours = event?.touches(for: self) {
			processTouches(ours)
		}
	}

	override public func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
		if let ours = event?.touches(for: self) {
			processTouches(ours)
		}
	}

}

#endif
