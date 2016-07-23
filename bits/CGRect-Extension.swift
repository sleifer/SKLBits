//
//  CGRect-Extension.swift
//  slidekey
//
//  Created by Simeon Leifer on 7/11/16.
//  Copyright © 2016 droolingcat.com. All rights reserved.
//

#if os(OSX)
	import AppKit
#elseif os(iOS) || os(tvOS) || os(watchOS)
	import UIKit
#endif

extension CGRect {
	
	func floored() -> CGRect {
		var r: CGRect = self
		r.origin.x = ceil(r.origin.x)
		r.origin.y = ceil(r.origin.y)
		r.size.width = floor(r.size.width)
		r.size.height = floor(r.size.height)
		if r.maxX > self.maxX {
			r.size.width = r.size.width - 1
		}
		if r.maxY > self.maxY {
			r.size.height = r.size.height - 1
		}
		return r
	}
	
	mutating func center(in rect: CGRect) {
		self.position(in: rect, px: 0.5, py: 0.5)
	}
	
	mutating func position(in rect: CGRect, px: CGFloat, py: CGFloat) {
		let offset = offsetToPosition(in: rect, px: px, py: py)
		self = self.offsetBy(dx: offset.x, dy: offset.y)
	}
	
	func offsetToPosition(in rect: CGRect, px: CGFloat, py: CGFloat) -> CGPoint {
		let xoff = floor((rect.width - self.width) * px)
		let yoff = floor((rect.height - self.height) * py)
		return CGPoint(x: xoff, y: yoff)
	}
}
