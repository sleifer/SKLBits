//
//  PrivacyAuthorization.swift
//  SKLBits
//
//  Created by Simeon Leifer on 7/29/16.
//  Copyright © 2016 droolingcat.com. All rights reserved.
//

import Foundation
import EventKit
import Photos

public class PrivacyAuthorization: NSObject, CLLocationManagerDelegate {
	
	typealias QueueAction = (Void) -> (Void)
	
	public var wantEvent: Bool = false
	
	public var wantReminder: Bool = false
	
	public var wantPhotos: Bool = false
	
	public var wantLocationAlways: Bool = false
	
	public var wantLocationWhenInUse: Bool = false
	
	private var _eventStore: EKEventStore?
	
	private var _locationManager: CLLocationManager?
	
	var requestQueue: [QueueAction] = []
	
	public override init() {
		
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
			if wantPhotos {
				requestQueue.append({
					self.requestPhotos()
				})
			}
			if wantLocationAlways {
				requestQueue.append({
					self.requestLocationAlways()
				})
			}
			if wantLocationWhenInUse {
				requestQueue.append({
					self.requestLocationWhenInUse()
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
	
	/*
		Requires plist string CFBundleDisplayName
	*/
	
	func requestPhotos() {
		if photosStatus() == .notDetermined {
			PHPhotoLibrary.requestAuthorization({ (status: PHAuthorizationStatus) in
				self.startNextRequest()
			})
		} else {
			startNextRequest()
		}
	}
	
	/*
		Requires plist string NSLocationAlwaysUsageDescription
	*/
	
	func requestLocationAlways() {
		if locationStatus() == .notDetermined {
			let mgr = locationManager()
			mgr.delegate = self
			mgr.requestAlwaysAuthorization()
		} else {
			startNextRequest()
		}
	}
	
	/*
		Requires plist string NSLocationWhenInUseUsageDescription
	*/
	
	func requestLocationWhenInUse() {
		if locationStatus() == .notDetermined {
			let mgr = locationManager()
			mgr.delegate = self
			mgr.requestWhenInUseAuthorization()
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
	
	public func locationManager() -> CLLocationManager {
		if _locationManager == nil {
			_locationManager = CLLocationManager()
		}
		return _locationManager!
	}
	
	public func eventStatus() -> EKAuthorizationStatus {
		return EKEventStore.authorizationStatus(for: .event)
	}
	
	public func reminderStatus() -> EKAuthorizationStatus {
		return EKEventStore.authorizationStatus(for: .reminder)
	}
	
	public func photosStatus() -> PHAuthorizationStatus {
		return PHPhotoLibrary.authorizationStatus()
	}
	
	public func locationStatus() -> CLAuthorizationStatus {
		return CLLocationManager.authorizationStatus()
	}

	// MARK: CLLocationManagerDelegate
	
	public func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
		startNextRequest()
	}

}
