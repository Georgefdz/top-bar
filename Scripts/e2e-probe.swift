// Prints the text Vision reads in an image, one string per line.
// Usage: e2e-probe <png>. Scripts/e2e.sh uses it on menu bar screenshots: on macOS 27 neither AX
// nor the item's own window reports hiding, so the pixels are the only reliable signal.
import Foundation
import Vision

let request = VNRecognizeTextRequest()
request.usesLanguageCorrection = false
request.recognitionLanguages = ["en-US"]
request.automaticallyDetectsLanguage = false
try VNImageRequestHandler(url: URL(fileURLWithPath: CommandLine.arguments[1])).perform([request])
for observation in request.results ?? [] {
    if let text = observation.topCandidates(1).first?.string { print(text) }
}
