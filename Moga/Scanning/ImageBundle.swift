import Foundation

// Collects raw chunk data for a single scan position.
// Once all chunks for all stack frames are received, assembles them into Data blobs.

final class ImageBundle {
    let positionIndex: Int
    let expectedStackSize: Int

    // [stackIndex: [chunkIndex: Data]]
    private var chunks: [Int: [Int: Data]] = [:]
    private var totalChunks: [Int: Int] = [:]

    var isComplete: Bool {
        guard chunks.count == expectedStackSize else { return false }
        return chunks.allSatisfy { stackIndex, chunkMap in
            guard let total = totalChunks[stackIndex] else { return false }
            return chunkMap.count == total
        }
    }

    init(positionIndex: Int, expectedStackSize: Int) {
        self.positionIndex = positionIndex
        self.expectedStackSize = expectedStackSize
    }

    func addChunk(_ chunk: ChunkPacket) {
        let si = Int(chunk.stackIndex)
        let ci = Int(chunk.chunkIndex)
        totalChunks[si] = Int(chunk.totalChunks)
        if chunks[si] == nil { chunks[si] = [:] }
        chunks[si]?[ci] = chunk.payload
    }

    // Returns assembled image data per stack frame, in order.
    func assembledImages() -> [Data] {
        (0..<expectedStackSize).compactMap { si in
            guard let chunkMap = chunks[si],
                  let total = totalChunks[si],
                  chunkMap.count == total else { return nil }
            return (0..<total).reduce(into: Data()) { result, ci in
                result.append(chunkMap[ci] ?? Data())
            }
        }
    }
}
