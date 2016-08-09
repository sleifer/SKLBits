//
//  CGPoint+SKLBits.swift
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

public extension CGPoint {
	
	public func move(to: CGPoint, percentage: CGFloat) -> CGPoint {
		let x = self.x + ((to.x - self.x) * percentage)
		let y = self.y + ((to.y - self.y) * percentage)
		return CGPoint(x: x, y: y)
	}
	
}

