//
//  NSLayoutConstraint-SKLBits.swift
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

#if os(iOS) || os(tvOS)
private var barKey: UInt8 = 0

public class LayoutConstraintSizeClass {
	public var horizontalSizeClass: UIUserInterfaceSizeClass = .unspecified

	public var verticalSizeClass: UIUserInterfaceSizeClass = .unspecified
}
#endif

public extension NSLayoutConstraint {

#if os(iOS) || os(tvOS)
	var sizeClass: LayoutConstraintSizeClass {
		get {
			return associatedObject(self, key: &barKey) {
				return LayoutConstraintSizeClass()
			}
		}
		set {
			associateObject(self, key: &barKey, value: newValue)
		}
	}
#endif

	public func referes(_ toView: ViewType) -> Bool {
		if let view = self.firstItem as? ViewType, view == toView {
			return true
		}
		if self.secondItem == nil {
			return false
		}
		if let view = self.secondItem as? ViewType, view == toView {
			return true
		}
		return false
	}

	@discardableResult public func install() -> NSLayoutConstraint {
		let first = self.firstItem as? ViewType
		let second = self.secondItem as? ViewType
		let target = first?.nearestCommonAncestor(second)
		if target != nil && target?.constraints.contains(self) == false {
			if target != first {
				first?.translatesAutoresizingMaskIntoConstraints = false
			}
			if target != second {
				second?.translatesAutoresizingMaskIntoConstraints = false
			}

			target?.addConstraint(self)
		}
		return self
	}

	@discardableResult public func installWith(priority: Float) -> NSLayoutConstraint {
		self.priority = priority
		self.install()
		return self
	}

	@discardableResult public func remove() -> NSLayoutConstraint {
		if let owner = owner() {
			owner.removeConstraint(self)
		}
		return self
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
		while view != nil {
			views.append(view!)
			view = view?.superview
		}

		return views
	}

	public func isParent(of view: ViewType) -> Bool {
		if self == view {
			return true
		}
		if view.allSuperviews().contains(self) {
			return true
		}
		return false
	}

	public func allSubviews(_ includeSelf: Bool = true) -> [ViewType] {
		var views: [ViewType] = []

		for view in self.subviews {
			views.append(view)
			views.append(contentsOf: view.allSubviews())
		}

		if includeSelf {
			views.append(self)
		}

		return views
	}

	public func referencingConstraintsInSuperviews() -> [NSLayoutConstraint] {
		var constraints = [NSLayoutConstraint]()
		for view in allSuperviews() {
			for constraint in view.constraints {
				if type(of: constraint) != NSLayoutConstraint.self && constraint.shouldBeArchived == false {
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
			if type(of: constraint) != NSLayoutConstraint.self && constraint.shouldBeArchived == false {
				continue
			}
			if constraint.referes(self) {
				constraints.append(constraint)
			}
		}
		return constraints
	}

	public func referencingConstraint(withIdentifier identifier: String) -> NSLayoutConstraint? {
		let constraints = self.referencingConstraints()
		let slidables = constraints.filter { (item) -> Bool in
			if item.identifier == identifier {
				return true
			}
			return false
		}
		if slidables.count > 0 {
			return slidables[0]
		}
		return nil
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

#if os(iOS) || os(tvOS)
	public func installConstraintsFor(_ traits: UITraitCollection) {
		let hSizeClass = traits.horizontalSizeClass
		let vSizeClass = traits.verticalSizeClass
		var install = [NSLayoutConstraint]()
		var remove = [NSLayoutConstraint]()

		for constraint in self {
			let sizeClass = constraint.sizeClass
			var add: Bool = false

			if hSizeClass == .unspecified || sizeClass.horizontalSizeClass == .unspecified || hSizeClass == sizeClass.horizontalSizeClass {
				if vSizeClass == .unspecified || sizeClass.verticalSizeClass == .unspecified || vSizeClass == sizeClass.verticalSizeClass {
					add = true
				}
			}
			if add == true {
				if constraint.isActive == false {
					install.append(constraint)
				}
			} else {
				if constraint.isActive == true {
					remove.append(constraint)
				}
			}
		}

		NSLayoutConstraint.deactivate(remove)
		NSLayoutConstraint.activate(install)
	}
#endif

}

#endif
