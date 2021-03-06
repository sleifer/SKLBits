//
//  RingBufferFile.swift
//  XCGNSLogger
//
//  Created by Simeon Leifer on 7/19/16.
//  Copyright © 2016 droolingcat.com. All rights reserved.
//

import Foundation

/*
File Header:
bufferStartIndex: UInt32
bufferEndIndex: UInt32
dataStartIndex: UInt32
dataEndIndex: UInt32
itemCount: UInt32
capacity: UInt32

Entry:
dataSize: UInt32
data: UInt8[N]
*/

public enum RingBufferFileError: Error {
	case outOfDataWhileReading
}

public class RingBufferFile: CustomStringConvertible {
	public private(set) var capacity: UInt32

	public let filePath: String

	public let atomSize: UInt32

	public let headerSize: UInt32

	public private(set) var bufferStartIndex: UInt32 = 0

	public private(set) var bufferEndIndex: UInt32 = 0

	public private(set) var maxBufferEndIndex: UInt32 = 0

	public private(set) var dataStartIndex: UInt32 = 0

	public private(set) var dataEndIndex: UInt32 = 0

	public private(set) var itemCount: UInt32 = 0

	public init(capacity: UInt32, filePath: String) {
		self.capacity = capacity
		self.filePath = filePath
		self.atomSize = UInt32(MemoryLayout<UInt32>.size)
		self.headerSize = self.atomSize * 6

		loadOrCreate()
	}

	public var description: String {
		return "\(type(of: self))\n  filePath: \(filePath)\n  capacity: \(capacity)\n  atomSize: \(atomSize)\n  headerSize: \(headerSize)\n  bufferStartIndex: \(bufferStartIndex)\n  bufferEndIndex: \(bufferEndIndex)\n  dataStartIndex: \(dataStartIndex)\n  dataEndIndex: \(dataEndIndex)\n  maxBufferEndIndex: \(maxBufferEndIndex)\n  itemCount: \(itemCount)\n---"
	}

	public func debugLogAllEntries() {
		do {
			var entry: [UInt8]?
			if itemCount > 0 {
				print("Buffer contents (\(itemCount)):")
				let fp = FileHandle(forReadingAtPath: self.filePath)
				if let fp = fp {
					var start = self.dataStartIndex
					for idx in 0..<itemCount {
						fp.seek(toFileOffset: UInt64(start))
						entry = try readEntry(fp)
						if let entry = entry {
							print("\(idx): \(entry)")
							start += UInt32(entry.count) + atomSize
							if start >= bufferEndIndex {
								start = bufferStartIndex
							}
						}
					}
					fp.closeFile()
				}
			} else {
				print("Buffer empty")
			}
		} catch {
			print("Error: \(error)")
		}

	}

	public func push(_ entry: [UInt8]) {
		do {
			let fp = FileHandle(forUpdatingAtPath: self.filePath)
			if let fp = fp {
				let entrySize = UInt32(entry.count) + atomSize

				var newItemCount = self.itemCount
				var newWriteStart = self.dataEndIndex + 1
				if self.dataStartIndex == self.dataEndIndex {
					newWriteStart = self.dataEndIndex
				}
				var newDataEndIndex = newWriteStart + entrySize - 1
				var newDataStartIndex = self.dataStartIndex
				var newBufferEndIndex = self.bufferEndIndex
				var needDropCheck = false
				if newDataEndIndex > self.maxBufferEndIndex {
					// push would exceed capacity, write at start
					newWriteStart = self.bufferStartIndex
					newDataEndIndex = newWriteStart + entrySize - 1
					needDropCheck = true
					if self.dataStartIndex > self.dataEndIndex {
						newDataStartIndex = self.bufferStartIndex
						newBufferEndIndex = self.dataEndIndex
					}
				}
				if self.dataEndIndex < self.dataStartIndex && newDataEndIndex >= self.dataStartIndex {
					needDropCheck = true
				}
				if needDropCheck == true {
					while newDataStartIndex <= newDataEndIndex {
						// push would run over first entry, need to drop until we do not collide
						fp.seek(toFileOffset: UInt64(newDataStartIndex))
						let peekEntrySize = try readAtom(fp)
						newDataStartIndex += (peekEntrySize + atomSize)
						newItemCount -= 1
						if newDataStartIndex >= self.maxBufferEndIndex || newDataStartIndex >= self.bufferEndIndex {
							newDataStartIndex = self.bufferStartIndex
							newBufferEndIndex = max(self.dataEndIndex, newDataEndIndex)
							break
						}
					}
				}
				if newDataEndIndex > newBufferEndIndex {
					newBufferEndIndex = newDataEndIndex
				}

				fp.seek(toFileOffset: UInt64(newWriteStart))
				writeEntry(fp, entry: entry)
				newItemCount += 1

				self.itemCount = newItemCount
				self.bufferEndIndex = newBufferEndIndex
				self.dataStartIndex = newDataStartIndex
				self.dataEndIndex = newDataEndIndex
				writeHeader(fp)
				fp.closeFile()
			}
		} catch {
			print("Error: \(error)")
		}
	}

	public func pop() -> [UInt8]? {
		if itemCount > 0 {
			let entry = peek()
			drop()
			return entry
		}
		return nil
	}

	public func peek() -> [UInt8]? {
		do {
			var entry: [UInt8]?
			if itemCount > 0 {
				let fp = FileHandle(forReadingAtPath: self.filePath)
				if let fp = fp {
					fp.seek(toFileOffset: UInt64(self.dataStartIndex))
					entry = try readEntry(fp)
					fp.closeFile()
				}
			}
			return entry
		} catch {
			print("Error: \(error)")
		}
		return nil
	}

	public func peekSize() -> UInt32? {
		do {
			var entrySize: UInt32?
			if itemCount > 0 {
				let fp = FileHandle(forReadingAtPath: self.filePath)
				if let fp = fp {
					fp.seek(toFileOffset: UInt64(self.dataStartIndex))
					entrySize = try readAtom(fp)
					fp.closeFile()
				}
			}
			return entrySize
		} catch {
			print("Error: \(error)")
		}
		return nil
	}

	public func drop() {
		do {
			if itemCount > 0 {
				let fp = FileHandle(forUpdatingAtPath: self.filePath)
				if let fp = fp {
					fp.seek(toFileOffset: UInt64(self.dataStartIndex))
					let entrySize = try readAtom(fp)
					self.itemCount -= 1
					self.dataStartIndex += (entrySize + self.atomSize)
					if self.dataStartIndex >= self.bufferEndIndex {
						self.dataStartIndex = self.bufferStartIndex
					}
					if self.itemCount == 0 {
						self.dataEndIndex = self.dataStartIndex
					}
					writeHeader(fp)
					fp.closeFile()
				}
			}
		} catch {
			print("Error: \(error)")
		}
	}

	public func clear() {
		let fp = FileHandle(forUpdatingAtPath: self.filePath)
		if let fp = fp {
			self.itemCount = 0
			self.bufferStartIndex = self.headerSize
			self.bufferEndIndex = self.headerSize
			self.dataStartIndex = self.headerSize
			self.dataEndIndex = self.headerSize
			self.maxBufferEndIndex = self.bufferStartIndex + self.capacity
			writeHeader(fp)
			fp.truncateFile(atOffset: UInt64(self.headerSize))
			fp.closeFile()
		}
	}

	private func writeHeader(_ fp: FileHandle) {
		fp.seek(toFileOffset: 0)
		writeAtom(fp, atom: self.bufferStartIndex)
		writeAtom(fp, atom: self.bufferEndIndex)
		writeAtom(fp, atom: self.dataStartIndex)
		writeAtom(fp, atom: self.dataEndIndex)
		writeAtom(fp, atom: self.itemCount)
		writeAtom(fp, atom: self.capacity)
	}

	private func readAtom(_ fp: FileHandle) throws -> UInt32 {
		let atomData = fp.readData(ofLength: Int(atomSize))
		if atomData.count != Int(atomSize) {
			throw RingBufferFileError.outOfDataWhileReading
		}
		let atomValue = atomData.withUnsafeBytes { (bytes: UnsafePointer<UInt32>) -> UInt32 in
			return CFSwapInt32HostToBig(bytes.pointee)
		}
		return atomValue
	}

	private func writeAtom(_ fp: FileHandle, atom: UInt32) {
		var value = CFSwapInt32HostToBig(atom)
		let data = Data(buffer: UnsafeBufferPointer<UInt32>(start: &value, count: 1))
		fp.write(data)
	}

	private func readEntry(_ fp: FileHandle) throws -> [UInt8]? {
		var entry: [UInt8]? = nil
		let lengthData = fp.readData(ofLength: Int(atomSize))
		if lengthData.count != Int(atomSize) {
			throw RingBufferFileError.outOfDataWhileReading
		}
		let lengthValue = lengthData.withUnsafeBytes { (bytes: UnsafePointer<UInt32>) -> UInt32 in
			return CFSwapInt32HostToBig(bytes.pointee)
		}
		let entryData = fp.readData(ofLength: Int(lengthValue))
		if entryData.count != Int(lengthValue) {
			throw RingBufferFileError.outOfDataWhileReading
		}
		entryData.withUnsafeBytes { (bytes: UnsafePointer<UInt8>) -> Void in
			entry = [UInt8]()
			entry?.append(contentsOf: UnsafeBufferPointer(start: bytes, count: Int(lengthValue)))
		}
		return entry
	}

	private func writeEntry(_ fp: FileHandle, entry: [UInt8]) {
		var value = CFSwapInt32HostToBig(UInt32(entry.count))
		let data1 = Data(buffer: UnsafeBufferPointer<UInt32>(start: &value, count: 1))
		fp.write(data1)
		let data = Data(bytesNoCopy: UnsafeMutablePointer<UInt8>(mutating: entry), count: entry.count, deallocator: .none)
		fp.write(data)
	}

	private func loadOrCreate() {
		let fm = FileManager.default

		do {
			if fm.fileExists(atPath: self.filePath) {
				let fp = FileHandle(forReadingAtPath: self.filePath)
				if let fp = fp {
					fp.seek(toFileOffset: 0)
					self.bufferStartIndex = try readAtom(fp)
					self.bufferEndIndex = try readAtom(fp)
					self.dataStartIndex = try readAtom(fp)
					self.dataEndIndex = try readAtom(fp)
					self.itemCount = try readAtom(fp)
					self.capacity = try readAtom(fp)
					self.maxBufferEndIndex = self.bufferStartIndex + self.capacity
					fp.closeFile()
					return
				}
			}
		} catch {
			print("Error: \(error)")
		}

		let created = fm.createFile(atPath: self.filePath, contents: nil, attributes: nil)
		if created {
			self.itemCount = 0
			self.bufferStartIndex = self.headerSize
			self.bufferEndIndex = self.headerSize
			self.dataStartIndex = self.headerSize
			self.dataEndIndex = self.headerSize
			self.maxBufferEndIndex = self.bufferStartIndex + self.capacity

			let fp = FileHandle(forWritingAtPath: self.filePath)
			if let fp = fp {
				writeHeader(fp)
				fp.closeFile()
			}

		}
	}
}
