//
//  UIWindow-SKLBits.swift
//  SKLBits
//
//  Created by Simeon Leifer on 8/20/16.
//  Copyright © 2016 droolingcat.com. All rights reserved.
//

#if os(iOS)

import UIKit

public extension UIWindow {

	public func visibleViewController() -> UIViewController? {
		if let rootViewController: UIViewController = self.rootViewController {
			return UIWindow.getVisibleViewControllerFrom(rootViewController)
		}
		return nil
	}

	class func getVisibleViewControllerFrom(_ vc: UIViewController) -> UIViewController? {
		if let navigationController = vc as? UINavigationController {
			if let visibleController = navigationController.visibleViewController {
				return UIWindow.getVisibleViewControllerFrom(visibleController)
			} else {
				return navigationController
			}
		} else if let tabBarController = vc as? UITabBarController {
			if let selectedController = tabBarController.selectedViewController {
				return UIWindow.getVisibleViewControllerFrom(selectedController)
			} else {
				return tabBarController
			}
		} else {
			if let presentedViewController = vc.presentedViewController {
				return UIWindow.getVisibleViewControllerFrom(presentedViewController)
			} else {
				return vc
			}
		}
	}

}

#endif
