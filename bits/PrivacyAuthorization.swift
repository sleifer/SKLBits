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

public enum PrivacyAuthorizationType: Int {
	case none
	case event
	case reminder
	case photos
	case media
	case microphone
	case siri
	case camera
	case speechRecognizer
	case location
}

public enum PrivacyAuthorizationSimpleStatus {
	case notAvailable
	case notDetermined
	case authorized
	case unauthorized
}

public struct PrivacyAuthorizationStatus {
	let eventStatus: PrivacyAuthorizationSimpleStatus
	let reminderStatus: PrivacyAuthorizationSimpleStatus
	let photosStatus: PrivacyAuthorizationSimpleStatus
	let mediaStatus: PrivacyAuthorizationSimpleStatus
	let microphoneStatus: PrivacyAuthorizationSimpleStatus
	let siriStatus: PrivacyAuthorizationSimpleStatus
	let cameraStatus: PrivacyAuthorizationSimpleStatus
	let speechRecognizerStatus: PrivacyAuthorizationSimpleStatus
	let locationStatus: PrivacyAuthorizationSimpleStatus
}

public struct PrivacyAuthorizationNotification {
	public static let AuthorizationChanged = NSNotification.Name("PrivacyAuthorizationNotification_AuthorizationChanged")
}

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

	// swiftlint:disable cyclomatic_complexity
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
	// swiftlint:enable cyclomatic_complexity

	func startNextRequest() {
		if requestQueue.count > 0 {
			DispatchQueue.main.async {
				let action = self.requestQueue.remove(at: 0)
				action()
			}
		}
	}

	func notify(_ type: PrivacyAuthorizationType) {
		NotificationCenter.default.post(name: PrivacyAuthorizationNotification.AuthorizationChanged, object: type)
	}

	// MARK: requestors

	/*
		Requires plist string NSCalendarsUsageDescription
	*/

	func requestEvent() {
		if eventStatus() == .notDetermined {
			eventStore().requestAccess(to: .event, completion: { (success: Bool, error: Error?) in
				self.notify(.event)
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
			eventStore().requestAccess(to: .reminder, completion: { (success: Bool, error: Error?) in
				self.notify(.reminder)
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
				self.notify(.photos)
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
				self.notify(.media)
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
				self.notify(.microphone)
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
					self.notify(.siri)
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
				self.notify(.camera)
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
					self.notify(.speechRecognizer)
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

	// MARK: managers

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

	// MARK: authorization status

	public func simpleStatus() -> PrivacyAuthorizationStatus {
		let eventStatus = simpleEventStatus()
		let reminderStatus = simpleReminderStatus()
		let photoStatus = simplePhotosStatus()
		let mediaStatus = simpleMediaStatus()
		let microphoneStatus = simpleMicrophoneStatus()
		let siriStatus = simpleSiriStatus()
		let cameraStatus = simpleCameraStatus()
		let speechStatus = simpleSpeechRecognizerStatus()
		let locationStatus = simpleLocationStatus()

		return PrivacyAuthorizationStatus(eventStatus: eventStatus, reminderStatus: reminderStatus, photosStatus: photoStatus, mediaStatus: mediaStatus, microphoneStatus: microphoneStatus, siriStatus: siriStatus, cameraStatus: cameraStatus, speechRecognizerStatus: speechStatus, locationStatus: locationStatus)
	}

	public func eventStatus() -> EKAuthorizationStatus {
		return EKEventStore.authorizationStatus(for: .event)
	}

	public func simpleEventStatus() -> PrivacyAuthorizationSimpleStatus {
		switch EKEventStore.authorizationStatus(for: .event) {
		case .notDetermined:
			return .notDetermined
		case .restricted, .denied:
			return .unauthorized
		case .authorized:
			return .authorized
		}
	}

	public func reminderStatus() -> EKAuthorizationStatus {
		return EKEventStore.authorizationStatus(for: .reminder)
	}

	public func simpleReminderStatus() -> PrivacyAuthorizationSimpleStatus {
		switch EKEventStore.authorizationStatus(for: .reminder) {
		case .notDetermined:
			return .notDetermined
		case .restricted, .denied:
			return .unauthorized
		case .authorized:
			return .authorized
		}
	}

	public func photosStatus() -> PHAuthorizationStatus {
		return PHPhotoLibrary.authorizationStatus()
	}

	public func simplePhotosStatus() -> PrivacyAuthorizationSimpleStatus {
		switch PHPhotoLibrary.authorizationStatus() {
		case .notDetermined:
			return .notDetermined
		case .restricted, .denied:
			return .unauthorized
		case .authorized:
			return .authorized
		}
	}

	public func mediaStatus() -> MPMediaLibraryAuthorizationStatus {
		return MPMediaLibrary.authorizationStatus()
	}

	public func simpleMediaStatus() -> PrivacyAuthorizationSimpleStatus {
		switch MPMediaLibrary.authorizationStatus() {
		case .notDetermined:
			return .notDetermined
		case .restricted, .denied:
			return .unauthorized
		case .authorized:
			return .authorized
		}
	}

	public func microphoneStatus() -> AVAuthorizationStatus {
		return AVCaptureDevice.authorizationStatus(forMediaType: AVMediaTypeAudio)
	}

	public func simpleMicrophoneStatus() -> PrivacyAuthorizationSimpleStatus {
		switch AVCaptureDevice.authorizationStatus(forMediaType: AVMediaTypeAudio) {
		case .notDetermined:
			return .notDetermined
		case .restricted, .denied:
			return .unauthorized
		case .authorized:
			return .authorized
		}
	}

	public func siriStatus() -> Int? {
		if #available(iOS 10, *) {
			return INPreferences.siriAuthorizationStatus().rawValue
		} else {
			return nil
		}
	}

	public func simpleSiriStatus() -> PrivacyAuthorizationSimpleStatus {
		if #available(iOS 10, *) {
			switch INPreferences.siriAuthorizationStatus() {
			case .notDetermined:
				return .notDetermined
			case .restricted, .denied:
				return .unauthorized
			case .authorized:
				return .authorized
			}
		} else {
			return .notAvailable
		}
	}

	public func cameraStatus() -> AVAuthorizationStatus {
		return AVCaptureDevice.authorizationStatus(forMediaType: AVMediaTypeVideo)
	}

	public func simpleCameraStatus() -> PrivacyAuthorizationSimpleStatus {
		switch AVCaptureDevice.authorizationStatus(forMediaType: AVMediaTypeVideo) {
		case .notDetermined:
			return .notDetermined
		case .restricted, .denied:
			return .unauthorized
		case .authorized:
			return .authorized
		}
	}

	public func speechRecognizerStatus() -> PrivacyAuthorizationSimpleStatus {
		if #available(iOS 10, *) {
			switch SFSpeechRecognizer.authorizationStatus() {
			case .notDetermined:
				return .notDetermined
			case .denied, .restricted:
				return .unauthorized
			case .authorized:
				return .authorized
			}
		} else {
			return .notAvailable
		}
	}

	public func simpleSpeechRecognizerStatus() -> PrivacyAuthorizationSimpleStatus {
		if #available(iOS 10, *) {
			switch SFSpeechRecognizer.authorizationStatus() {
			case .notDetermined:
				return .notDetermined
			case .restricted, .denied:
				return .unauthorized
			case .authorized:
				return .authorized
			}
		} else {
			return .notAvailable
		}
	}

	public func locationStatus() -> CLAuthorizationStatus {
		return CLLocationManager.authorizationStatus()
	}

	public func simpleLocationStatus() -> PrivacyAuthorizationSimpleStatus {
		switch CLLocationManager.authorizationStatus() {
		case .notDetermined:
			return .notDetermined
		case .restricted, .denied:
			return .unauthorized
		case .authorizedAlways, .authorizedWhenInUse:
			return .authorized
		}
	}

	// MARK: CLLocationManagerDelegate

	public func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
		self.notify(.location)
		startNextRequest()
	}

}

#endif
