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

public class RingBufferFile: CustomStringConvertible {
	public private(set) var capacity: UInt32

	public let filePath: String

	public let atomSize: UInt32

	public let headerSize: UInt32

	private var bufferStartIndex: UInt32 = 0

	private var bufferEndIndex: UInt32 = 0

	private var maxBufferEndIndex: UInt32 = 0

	private var dataStartIndex: UInt32 = 0

	private var dataEndIndex: UInt32 = 0

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

	public func push(_ entry: [UInt8]) {
		let fp = FileHandle(forUpdatingAtPath: self.filePath)
		if let fp = fp {
			let entrySize = UInt32(entry.count)
			let totalSize = entrySize + atomSize

			var proposedItemCount = self.itemCount
			var proposedWriteStart = self.dataEndIndex + 1
			if self.dataStartIndex == self.dataEndIndex {
				proposedWriteStart = self.dataEndIndex
			}
			var proposedDataEndIndex = proposedWriteStart + totalSize - 1
			var proposedDataStartIndex = self.dataStartIndex
			var proposedBufferEndIndex = self.bufferEndIndex
			var needDropCheck = false
			if proposedDataEndIndex > self.maxBufferEndIndex {
				// push would exceed capacity, write at start
				proposedWriteStart = self.bufferStartIndex
				proposedDataEndIndex = proposedWriteStart + totalSize - 1
				needDropCheck = true
			}
			if self.dataEndIndex < self.dataStartIndex {
				needDropCheck = true
			}
			if needDropCheck == true {
				while proposedDataEndIndex >= proposedDataStartIndex {
					// push would run over first entry, need to drop until we do not collide
					fp.seek(toFileOffset: UInt64(proposedDataStartIndex))
					let peekEntrySize = readAtom(fp)
					proposedDataStartIndex = proposedDataStartIndex + (peekEntrySize + atomSize)
					proposedItemCount = proposedItemCount - 1
					if proposedDataStartIndex >= self.maxBufferEndIndex {
						proposedDataStartIndex = self.bufferStartIndex
					}
				}
			}
			if proposedDataEndIndex > proposedBufferEndIndex {
				proposedBufferEndIndex = proposedDataEndIndex
			}

			fp.seek(toFileOffset: UInt64(proposedWriteStart))
			writeEntry(fp, entry: entry)
			proposedItemCount = proposedItemCount + 1

			self.itemCount = proposedItemCount
			self.bufferEndIndex = proposedBufferEndIndex
			self.dataStartIndex = proposedDataStartIndex
			self.dataEndIndex = proposedDataEndIndex
			writeHeader(fp)
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
		var entry: [UInt8]?
		if itemCount > 0 {
			let fp = FileHandle(forReadingAtPath: self.filePath)
			if let fp = fp {
				fp.seek(toFileOffset: UInt64(self.dataStartIndex))
				entry = readEntry(fp)
				fp.closeFile()
			}
		}
		return entry
	}

	public func peekSize() -> UInt32? {
		var entrySize: UInt32?
		if itemCount > 0 {
			let fp = FileHandle(forReadingAtPath: self.filePath)
			if let fp = fp {
				fp.seek(toFileOffset: UInt64(self.dataStartIndex))
				entrySize = readAtom(fp)
				fp.closeFile()
			}
		}
		return entrySize
	}

	public func drop() {
		if itemCount > 0 {
			let fp = FileHandle(forUpdatingAtPath: self.filePath)
			if let fp = fp {
				fp.seek(toFileOffset: UInt64(self.dataStartIndex))
				let entrySize = readAtom(fp)
				self.itemCount = self.itemCount - 1
				self.dataStartIndex = self.dataStartIndex + (entrySize + self.atomSize)
				if self.dataStartIndex >= self.bufferEndIndex {
					self.dataStartIndex = self.bufferStartIndex

				}
				writeHeader(fp)
				fp.closeFile()
			}
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

	private func readAtom(_ fp: FileHandle) -> UInt32 {
		let atomData = fp.readData(ofLength: Int(atomSize))
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

	private func readEntry(_ fp: FileHandle) -> [UInt8]? {
		var entry: [UInt8]? = nil
		let lengthData = fp.readData(ofLength: Int(atomSize))
		let lengthValue = lengthData.withUnsafeBytes { (bytes: UnsafePointer<UInt32>) -> UInt32 in
			return CFSwapInt32HostToBig(bytes.pointee)
		}
		let entryData = fp.readData(ofLength: Int(lengthValue))
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
		if fm.fileExists(atPath: self.filePath) {
			let fp = FileHandle(forReadingAtPath: self.filePath)
			if let fp = fp {
				fp.seek(toFileOffset: 0)
				self.bufferStartIndex = readAtom(fp)
				self.bufferEndIndex = readAtom(fp)
				self.dataStartIndex = readAtom(fp)
				self.dataEndIndex = readAtom(fp)
				self.itemCount = readAtom(fp)
				self.capacity = readAtom(fp)
				self.maxBufferEndIndex = self.bufferStartIndex + self.capacity
				fp.closeFile()
			}
		} else {
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
}
