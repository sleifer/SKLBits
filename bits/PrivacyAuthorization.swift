//
//  PrivacyAuthorization.swift
//  SKLBits
//
//  Created by Simeon Leifer on 7/29/16.
//  Copyright © 2016 droolingcat.com. All rights reserved.
//

import Foundation
import EventKit

public class PrivacyAuthorization {
	
	typealias QueueAction = (Void) -> (Void)
	
	public var wantEvent: Bool = false
	
	public var wantReminder: Bool = false
	
	private var _eventStore: EKEventStore?
	
	var requestQueue: [QueueAction] = []
	
	public init() {
		
	}
	
	public func requestAccess() {
		if requestQueue.count == 0 {
			if wantEvent {
				requestQueue.append({
					self.requestEvent()
				})
			}
			if wantReminder {
				requestQueue.append({
					self.requestReminder()
				})
			}
		}
		startNextRequest()
	}
	
	func startNextRequest() {
		if requestQueue.count > 0 {
			DispatchQueue.main.async {
				let action = self.requestQueue.remove(at: 0)
				action()
			}
		}
	}
	
	/*
		Requires plist string NSCalendarsUsageDescription
	*/
	
	func requestEvent() {
		if eventStatus() == .notDetermined {
			eventStore().requestAccess(to: .event, completion: { (success: Bool, error: NSError?) in
				self.startNextRequest()
			})
		} else {
			startNextRequest()
		}
	}
	
	/*
	Requires plist string NSRemindersUsageDescription
	*/
	
	func requestReminder() {
		if reminderStatus() == .notDetermined {
			eventStore().requestAccess(to: .reminder, completion: { (success: Bool, error: NSError?) in
				self.startNextRequest()
			})
		} else {
			startNextRequest()
		}
	}
	
	public func eventStore() -> EKEventStore {
		if _eventStore == nil {
			_eventStore = EKEventStore()
		}
		return _eventStore!
	}
	
	public func eventStatus() -> EKAuthorizationStatus {
		return EKEventStore.authorizationStatus(for: .event)
	}
	
	public func reminderStatus() -> EKAuthorizationStatus {
		return EKEventStore.authorizationStatus(for: .reminder)
	}
	
}
