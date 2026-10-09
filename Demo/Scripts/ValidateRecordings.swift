import AppKit
import AVFoundation

@main struct ValidateRecordings {
    static func main() async throws {
        for path in CommandLine.arguments.dropFirst() {
            let url = URL(fileURLWithPath: path)
            let asset = AVURLAsset(url: url)
            let duration = try await asset.load(.duration).seconds
            guard duration > 0, let track = try await asset.loadTracks(withMediaType: .video).first else {
                throw NSError(domain: "RecordingValidation", code: 1)
            }
            let size = try await track.load(.naturalSize)
            let reader = try AVAssetReader(asset: asset)
            let output = AVAssetReaderTrackOutput(track: track, outputSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA])
            reader.add(output)
            guard reader.startReading() else { throw reader.error! }
            var frames = 0, previous = -1.0, maximumGap = 0.0
            while let sample = output.copyNextSampleBuffer() {
                let timestamp = CMSampleBufferGetPresentationTimeStamp(sample).seconds
                if previous >= 0 { maximumGap = max(maximumGap, timestamp - previous) }
                previous = timestamp; frames += 1
            }
            guard reader.status == .completed, frames > 0 else { throw reader.error ?? NSError(domain: "RecordingValidation", code: 2) }
            let folder = url.deletingPathExtension().appendingPathExtension("review")
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: 240, height: 522)
            var samples = Array(stride(from: 0.0, to: duration, by: 1.0)); samples.append(max(0, duration - 0.1))
            for (index, second) in samples.enumerated() {
                let result = try await generator.image(at: CMTime(seconds: second, preferredTimescale: 600))
                let bitmap = NSBitmapImageRep(cgImage: result.image)
                let data = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.85])!
                try data.write(to: folder.appendingPathComponent(String(format: "%03d-%.1fs.jpg", index, second)))
            }
            let metadata: [String: Any] = ["file":url.lastPathComponent, "duration":duration,"width":size.width,"height":size.height,"decodedFrames":frames,"decodedToEnd":true,"maximumFrameGap":maximumGap]
            let data = try JSONSerialization.data(withJSONObject: metadata, options: [.prettyPrinted,.sortedKeys])
            try data.write(to: folder.appendingPathComponent("metadata.json"))
            print(String(data: data, encoding: .utf8)!)
        }
    }
}
