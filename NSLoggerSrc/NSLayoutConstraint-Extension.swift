//
//  NSLayoutConstraint-Extension.swift
//  slidekey
//
//  Created by Simeon Leifer on 7/10/16.
//  Copyright © 2016 droolingcat.com. All rights reserved.
//

#if os(iOS)
	import UIKit
	typealias ViewType = UIView
#elseif os(OSX)
	import AppKit
	typealias ViewType = NSView
#endif

extension NSLayoutConstraint {

	func referes(toView: ViewType) -> Bool {
		if self.firstItem as! NSObject == toView {
			return true
		}
		if self.secondItem == nil {
			return false
		}
		if self.secondItem as! NSObject == toView {
			return true
		}
		return false
	}
	
	func install() {
		let first = self.firstItem as? ViewType
		let second = self.secondItem as? ViewType
		let target = first?.nearestCommonAncestor(view: second)
		if target != nil {
			if target != first {
				first?.translatesAutoresizingMaskIntoConstraints = false
			}
			if target != second {
				second?.translatesAutoresizingMaskIntoConstraints = false
			}
			
			target?.addConstraint(self)
		}
	}

}

extension ViewType {
	
	func allSuperviews() -> [ViewType] {
		var views = [ViewType]()
		var view = self.superview
		while (view != nil) {
			views.append(view!)
			view = view?.superview
		}
		
		return views
	}
	
	func referencingConstraintsInSuperviews() -> [NSLayoutConstraint] {
		var constraints = [NSLayoutConstraint]()
		for view in allSuperviews() {
			for constraint in view.constraints {
				if constraint.isMember(of:object_getClass(NSLayoutConstraint.self)) == false && constraint.shouldBeArchived == false {
					continue
				}
				if constraint.referes(toView: self) {
					constraints.append(constraint)
				}
			}
		}
		return constraints
	}
	
	func referencingConstraints() -> [NSLayoutConstraint] {
		var constraints = referencingConstraintsInSuperviews()
		for constraint in self.constraints {
			if constraint.isMember(of:object_getClass(NSLayoutConstraint.self)) == false && constraint.shouldBeArchived == false {
				continue
			}
			if constraint.referes(toView: self) {
				constraints.append(constraint)
			}
		}
		return constraints
	}
	
	func isAncestorOf(view: ViewType?) -> Bool {
		if let view = view {
			return view.allSuperviews().contains(self)
		}
		return false
	}
	
	func nearestCommonAncestor(view: ViewType?) -> ViewType? {
		if let view = view {
			if self == view {
				return self
			}
			if self.isAncestorOf(view: view) {
				return self
			}
			if view.isAncestorOf(view: self) {
				return view
			}
			
			let ancestors = self.allSuperviews()
			for aView in view.allSuperviews() {
				if ancestors.contains(aView) {
					return aView
				}
			}
			return nil
		}
		return self
	}

}


