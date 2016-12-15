//
//  DeferredAction.swift
//  SKLBits
//
//  Created by Simeon Leifer on 12/15/16.
//  Copyright © 2016 droolingcat.com. All rights reserved.
//

import Foundation

public typealias DeferredActionBlock = (DeferredAction) -> (Void)

public class DeferredAction {

	private(set) var timer: Timer?

	private var actionBlock: DeferredActionBlock

	public init(after: TimeInterval, block: @escaping DeferredActionBlock) {
		actionBlock = block
		timer = Timer.scheduledTimer(timeInterval: after, target: self, selector: #selector(doAction), userInfo: nil, repeats: false)
	}

	public func cancel() {
		timer?.invalidate()
	}

	public func reset(delay: TimeInterval) {
		if timer?.isValid ?? false {
			timer?.fireDate = Date(timeIntervalSinceNow: delay)
		} else {
			timer = Timer.scheduledTimer(timeInterval: delay, target: self, selector: #selector(doAction), userInfo: nil, repeats: false)
		}
	}

	public func fire() {
		timer?.fire()
	}

	@objc private func doAction() {
		actionBlock(self)
	}
}
