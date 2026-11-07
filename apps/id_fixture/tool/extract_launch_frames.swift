import Foundation
import AVFoundation
import AppKit

let args = CommandLine.arguments
guard args.count == 3 else { fatalError("Expected video and output directory") }
let asset = AVURLAsset(url: URL(fileURLWithPath: args[1]))
let generator = AVAssetImageGenerator(asset: asset)
generator.appliesPreferredTrackTransform = true
generator.requestedTimeToleranceBefore = .zero
generator.requestedTimeToleranceAfter = .zero
let directory = URL(fileURLWithPath: args[2], isDirectory: true)
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
let frameCount = min(300, max(1, Int(CMTimeGetSeconds(asset.duration) * 5)))
for index in 0..<frameCount {
    let seconds = Double(index) * 0.2
    do {
        let image = try generator.copyCGImage(at: CMTime(seconds: seconds, preferredTimescale: 600), actualTime: nil)
        let rep = NSBitmapImageRep(cgImage: image)
        if let data = rep.representation(using: .png, properties: [:]) {
            try data.write(to: directory.appendingPathComponent(String(format: "frame-%02d.png", index)))
        }
    } catch { break }
}
print("Launch frames extracted for visual inspection.")
