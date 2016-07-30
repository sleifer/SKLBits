//
//  PrivacyAuthorization.swift
//  SKLBits
//
//  Created by Simeon Leifer on 7/29/16.
//  Copyright © 2016 droolingcat.com. All rights reserved.
//

#if os(iOS)

import Foundation
import EventKit
import Photos
import MediaPlayer
import Speech
import AVFoundation
import Intents

public class PrivacyAuthorization: NSObject, CLLocationManagerDelegate {
	
	typealias QueueAction = (Void) -> (Void)
	
	public var wantEvent: Bool = false
	
	public var wantReminder: Bool = false
	
	public var wantPhotos: Bool = false
	
	public var wantMedia: Bool = false
	
	public var wantMicrophone: Bool = false
	
	public var wantSiri: Bool = false
	
	public var wantCamera: Bool = false
	
	public var wantSpeechRecognizer: Bool = false
	
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
			if wantMedia {
				requestQueue.append({
					self.requestMedia()
				})
			}
			if wantMicrophone {
				requestQueue.append({
					self.requestMicrophone()
				})
			}
			if wantSiri {
				requestQueue.append({
					self.requestSiri()
				})
			}
			if wantCamera {
				requestQueue.append({
					self.requestCamera()
				})
			}
			if wantSpeechRecognizer {
				requestQueue.append({
					self.requestSpeechRecognizer()
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
		Requires plist string NSPhotoLibraryUsageDescription
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
		Requires plist string NSAppleMusicUsageDescription
	*/
	
	func requestMedia() {
		if mediaStatus() == .notDetermined {
			MPMediaLibrary.requestAuthorization({ (status: MPMediaLibraryAuthorizationStatus) in
				self.startNextRequest()
			})
		} else {
			startNextRequest()
		}
	}
	
	/*
		Requires plist string NSMicrophoneUsageDescription
	*/
	
	func requestMicrophone() {
		if microphoneStatus() == .notDetermined {
			AVCaptureDevice.requestAccess(forMediaType: AVMediaTypeAudio, completionHandler: { (success: Bool) in
				self.startNextRequest()
			})
		} else {
			startNextRequest()
		}
	}
	
	/*
		Requires plist string NSSiriUsageDescription
		Requires Siri Capability (entitlement)
	*/

	func requestSiri() {
		if #available(iOS 10, *) {
			if siriStatus() == INSiriAuthorizationStatus.notDetermined.rawValue {
				INPreferences.requestSiriAuthorization({ (status: INSiriAuthorizationStatus) in
					self.startNextRequest()
				})
			} else {
				startNextRequest()
			}
		} else {
			startNextRequest()
		}
	}

	/*
		Requires plist string NSCameraUsageDescription
	*/
	
	func requestCamera() {
		if cameraStatus() == .notDetermined {
			AVCaptureDevice.requestAccess(forMediaType: AVMediaTypeVideo, completionHandler: { (success: Bool) in
				self.startNextRequest()
			})
		} else {
			startNextRequest()
		}
	}
	
	/*
		Requires plist string NSSpeechRecognitionUsageDescription. has microphone access prerequisite
	*/
	
	func requestSpeechRecognizer() {
		if #available(iOS 10, *) {
			if speechRecognizerStatus() == .notDetermined {
				SFSpeechRecognizer.requestAuthorization({ (status: SFSpeechRecognizerAuthorizationStatus) in
					self.startNextRequest()
				})
			} else {
				startNextRequest()
			}
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
	
	public func mediaStatus() -> MPMediaLibraryAuthorizationStatus {
		return MPMediaLibrary.authorizationStatus()
	}
	
	public func microphoneStatus() -> AVAuthorizationStatus {
		return AVCaptureDevice.authorizationStatus(forMediaType: AVMediaTypeAudio)
	}
	
	public func siriStatus() -> Int? {
		if #available(iOS 10, *) {
			return INPreferences.siriAuthorizationStatus().rawValue
		} else {
			return nil
		}
	}
	
	public func cameraStatus() -> AVAuthorizationStatus {
		return AVCaptureDevice.authorizationStatus(forMediaType: AVMediaTypeVideo)
	}
	
	public func speechRecognizerStatus() -> SFSpeechRecognizerAuthorizationStatus? {
		if #available(iOS 10, *) {
			return SFSpeechRecognizer.authorizationStatus()
		} else {
			return nil
		}
	}
	
	public func locationStatus() -> CLAuthorizationStatus {
		return CLLocationManager.authorizationStatus()
	}

	// MARK: CLLocationManagerDelegate
	
	public func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
		startNextRequest()
	}

}

#endif
