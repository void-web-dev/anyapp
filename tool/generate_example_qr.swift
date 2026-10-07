import AppKit
import CoreImage

let payload = "https://static.w3bsrv.app/dummy-app.json"
let filter = CIFilter(name: "CIQRCodeGenerator")!
filter.setValue(Data(payload.utf8), forKey: "inputMessage")
filter.setValue("M", forKey: "inputCorrectionLevel")
let code = filter.outputImage!
let scale = 16
let quiet = 4 * scale
let size = Int(code.extent.width) * scale + 2 * quiet
let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8,
                        bytesPerRow: size * 4, space: CGColorSpaceCreateDeviceRGB(),
                        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
context.setFillColor(CGColor(gray: 1, alpha: 1))
context.fill(CGRect(x: 0, y: 0, width: size, height: size))
context.interpolationQuality = .none
context.draw(CIContext().createCGImage(code, from: code.extent)!,
             in: CGRect(x: quiet, y: quiet, width: size - 2 * quiet, height: size - 2 * quiet))
let image = context.makeImage()!
let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])!
let url = URL(fileURLWithPath: "assets/testing/dummy-app-qr.png")
try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
try png.write(to: url)
let detector = CIDetector(ofType: CIDetectorTypeQRCode, context: nil, options: [CIDetectorAccuracy: CIDetectorAccuracyHigh])!
let decoded = detector.features(in: CIImage(cgImage: image)).compactMap { ($0 as? CIQRCodeFeature)?.messageString }
precondition(decoded == [payload], "QR round-trip failed")
print("QR verified: \(payload), \(size)x\(size)")
