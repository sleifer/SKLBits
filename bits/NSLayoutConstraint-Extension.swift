//
//  NSLayoutConstraint-Extension.swift
//  slidekey
//
//  Created by Simeon Leifer on 7/10/16.
//  Copyright © 2016 droolingcat.com. All rights reserved.
//

#if os(iOS) || os(tvOS)
	import UIKit
	public typealias ViewType = UIView
#elseif os(OSX)
	import AppKit
	public typealias ViewType = NSView
#endif

#if !os(watchOS)
	
public extension NSLayoutConstraint {

	public func referes(_ toView: ViewType) -> Bool {
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
	
	public func install() {
		let first = self.firstItem as? ViewType
		let second = self.secondItem as? ViewType
		let target = first?.nearestCommonAncestor(second)
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
	
	public func installWith(priority: Float) {
		self.priority = priority
		self.install()
	}

	public func remove() {
		if let owner = owner() {
			owner.removeConstraint(self)
		}
	}
	
	public func likelyOwner() -> ViewType? {
		let first = self.firstItem as? ViewType
		let second = self.secondItem as? ViewType
		let target = first?.nearestCommonAncestor(second)
		return target
	}
	
	public func owner() -> ViewType? {
		let first = self.firstItem as? ViewType
		if first != nil && first?.constraints.contains(self) == true {
			return first
		}
		let second = self.secondItem as? ViewType
		if second != nil && second?.constraints.contains(self) == true {
			return second
		}
		let target = first?.nearestCommonAncestor(second)
		if target != nil && target != first && target != second && target?.constraints.contains(self) == true {
			return target
		}
		if first != nil, let supers = first?.allSuperviews() {
			for view in supers {
				if view.constraints.contains(self) {
					return view
				}
			}
		}
		if second != nil, let supers = second?.allSuperviews() {
			for view in supers {
				if view.constraints.contains(self) {
					return view
				}
			}
		}
		return nil
	}
	
}

public extension ViewType {
	
	public func allSuperviews() -> [ViewType] {
		var views = [ViewType]()
		var view = self.superview
		while (view != nil) {
			views.append(view!)
			view = view?.superview
		}
		
		return views
	}
	
	public func referencingConstraintsInSuperviews() -> [NSLayoutConstraint] {
		var constraints = [NSLayoutConstraint]()
		for view in allSuperviews() {
			for constraint in view.constraints {
				if constraint.isMember(of:object_getClass(NSLayoutConstraint.self)) == false && constraint.shouldBeArchived == false {
					continue
				}
				if constraint.referes(self) {
					constraints.append(constraint)
				}
			}
		}
		return constraints
	}
	
	public func referencingConstraints() -> [NSLayoutConstraint] {
		var constraints = referencingConstraintsInSuperviews()
		for constraint in self.constraints {
			if constraint.isMember(of:object_getClass(NSLayoutConstraint.self)) == false && constraint.shouldBeArchived == false {
				continue
			}
			if constraint.referes(self) {
				constraints.append(constraint)
			}
		}
		return constraints
	}
	
	public func isAncestorOf(_ view: ViewType?) -> Bool {
		if let view = view {
			return view.allSuperviews().contains(self)
		}
		return false
	}
	
	public func nearestCommonAncestor(_ view: ViewType?) -> ViewType? {
		if let view = view {
			if self == view {
				return self
			}
			if self.isAncestorOf(view) {
				return self
			}
			if view.isAncestorOf(self) {
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

public extension Array where Element: NSLayoutConstraint {
	
	public func installConstraints() {
		for constraint in self {
			constraint.install()
		}
	}
	
	public func removeConstraints() {
		for constraint in self {
			constraint.remove()
		}
	}
	
}
	
	
#endif
