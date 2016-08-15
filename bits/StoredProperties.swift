//
//  StoredProperties.swift
//  SKLBits
//
//  Created by Simeon Leifer on 7/26/16.
//  Copyright © 2016 droolingcat.com. All rights reserved.
//

import Foundation

/*
	Based on a post by Tikitu de Jager
	https://medium.com/@ttikitu/swift-extensions-can-add-stored-properties-92db66bce6cd#.gj41qt4a8
*/

func associatedObject<ValueType: AnyObject>(_ base: AnyObject, key: UnsafePointer<UInt8>, initialiser: () -> ValueType) -> ValueType {
	if let associated = objc_getAssociatedObject(base, key) as? ValueType {
		return associated
	}
	let associated = initialiser()
	objc_setAssociatedObject(base, key, associated, .OBJC_ASSOCIATION_RETAIN)
	return associated
}

func associateObject<ValueType: AnyObject>(_ base: AnyObject, key: UnsafePointer<UInt8>, value: ValueType) {
	objc_setAssociatedObject(base, key, value, .OBJC_ASSOCIATION_RETAIN)
}

/*
	e.g.
*/

#if false

class Foo {
}
class Bar {
	var name = "Alpha"
}

private var barKey: UInt8 = 0
extension Foo {
	var bar: Bar {
		get {
			return associatedObject(self, key: &barKey) {
				return Bar()
			}
		}
		set {
			associateObject(self, key: &barKey, value: newValue)
		}
	}
}

#endif
