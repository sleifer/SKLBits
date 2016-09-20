//
//  UIImage-SKLBits.swift
//  SKLBits
//
//  Created by Simeon Leifer on 7/29/16.
//  Copyright © 2016 droolingcat.com. All rights reserved.
//

#if os(iOS)

import UIKit

public extension UIImage {

	public class func drawSimpleButton(_ frame: CGRect, radius: CGFloat = -1, strokeWidth: CGFloat = 1, strokeColor: UIColor? = UIColor.black, fillColor: UIColor? = nil) {
		let inset = strokeWidth
		let rectanglePath = UIBezierPath(roundedRect: CGRect(x: (frame.origin.x + inset), y: (frame.origin.y + inset), width: (frame.size.width - (inset * 2)), height: (frame.size.height - (inset * 2))), cornerRadius: radius)
		if let fillColor = fillColor {
			fillColor.setFill()
			rectanglePath.fill()
		}
		if let strokeColor = strokeColor {
			strokeColor.setStroke()
			rectanglePath.lineWidth = strokeWidth
			rectanglePath.stroke()
		}
	}

	public class func imageOfSimpleButton(_ frame: CGRect, radius: CGFloat = -1, strokeWidth: CGFloat = 1, strokeColor: UIColor? = UIColor.black, fillColor: UIColor? = nil) -> UIImage {
		var r = radius
		if r == -1 {
			r = floor(frame.height / 2.0)
		}
		let width = ((r + 2) * 2) + 1
		let height = frame.height
		UIGraphicsBeginImageContextWithOptions(CGSize(width: width, height: height), false, 0)
		drawSimpleButton(CGRect(x: 0, y: 0, width: width, height: height), radius: r, strokeWidth: strokeWidth, strokeColor: strokeColor, fillColor: fillColor)

		let imageOfSimpleButton = UIGraphicsGetImageFromCurrentImageContext()?.resizableImage(withCapInsets: UIEdgeInsets(top: 0, left: r+2, bottom: 0, right: r+2), resizingMode: .stretch)
		UIGraphicsEndImageContext()

		return imageOfSimpleButton!
	}

	public func tinted(_ color: UIColor) -> UIImage? {
		let rect = CGRect(x: 0, y: 0, width: self.size.width, height: self.size.height)
		UIGraphicsBeginImageContextWithOptions(rect.size, false, self.scale)
		if let ctx = UIGraphicsGetCurrentContext() {
			self.draw(in: rect)

			ctx.setFillColor(color.cgColor)
			ctx.setBlendMode(.sourceAtop)
			ctx.fill(rect)
		}
		let image = UIGraphicsGetImageFromCurrentImageContext()
		UIGraphicsEndImageContext()
		return image
	}

}

#endif
