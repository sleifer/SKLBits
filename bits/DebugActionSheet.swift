//
//  DebugActionSheet.swift
//  SKLBits
//
//  Created by Simeon Leifer on 8/7/16.
//  Copyright © 2016 droolingcat.com. All rights reserved.
//

#if os(iOS)

import UIKit

private var debugActionSheetsKey: UInt8 = 0

private extension UIView {

	var debugActionSheets: NSMutableArray {
		get {
			return associatedObject(self, key: &debugActionSheetsKey) {
				return NSMutableArray()
			}
		}
		set {
			associateObject(self, key: &debugActionSheetsKey, value: newValue)
		}
	}
}

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

	public class func from(_ view: UIView) -> [DebugActionSheet] {
		if let items = view.debugActionSheets as NSArray as? [DebugActionSheet] {
			return items
		}
		return [DebugActionSheet]()
	}

	public func attach(to view: UIView) {
		detachFromView()
		self.view = view
		view.debugActionSheets.add(self)
		view.addGestureRecognizer(gesture)
	}

	public func detachFromView() {
		if let oldView = self.view {
			oldView.removeGestureRecognizer(gesture)
			oldView.debugActionSheets.remove(self)
			self.view = nil
		}
	}

	@objc func gestureAction(_ gesture: UIGestureRecognizer) {
		if gesture.state == .ended {
			show()
		}
	}

	public func addAction(_ name: String, handler: @escaping DebugActionSheetHandler) {
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

		UIApplication.shared.keyWindow?.visibleViewController()?.present(alert, animated: true, completion: nil)
	}
}

extension UIAlertController {

	class func simpleInput(title: String?, message: String?, action: String, defaultText: String? = nil, placeholder: String, validator: ((_ text: String?) -> (Bool))? = nil, handler: @escaping (_ text: String?) -> (Void)) -> UIAlertController {
		let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)

		let loginAction = UIAlertAction(title: action, style: .default) { (_) in
			let valueTextField = alertController.textFields![0] as UITextField

			handler(valueTextField.text)
		}

		loginAction.isEnabled = false

		let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { (_) in
			handler(nil)
		}

		alertController.addTextField { (textField) in
			textField.placeholder = placeholder
			if let text = defaultText {
				textField.text = text

				if let validator = validator {
					loginAction.isEnabled = validator(textField.text)
				} else {
					loginAction.isEnabled = textField.text != ""
				}
			}

			NotificationCenter.default.addObserver(forName: NSNotification.Name.UITextFieldTextDidChange, object: textField, queue: OperationQueue.main) { (notification) in
				if let validator = validator {
					loginAction.isEnabled = validator(textField.text)
				} else {
					loginAction.isEnabled = textField.text != ""
				}
			}
		}

		alertController.addAction(loginAction)
		alertController.addAction(cancelAction)

		return alertController
	}

}

#endif
