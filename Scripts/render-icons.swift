import AppKit

// Regenerates every icon size from the Dormant mark (D-013 system, D-014 mark).
// Run: swift Scripts/render-icons.swift

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

let paper = NSColor(srgbRed: 0.9569, green: 0.9451, blue: 0.9098, alpha: 1)
let plateTop = NSColor(srgbRed: 0.2353, green: 0.3529, blue: 0.2627, alpha: 1)
let plateBottom = NSColor(srgbRed: 0.1294, green: 0.2039, blue: 0.1529, alpha: 1)

// Mark geometry in unit space (y measured from the top): a cocoon hanging from a
// thread — tapered pod with two wrap chords. Drawn bbox-centered.
let threadTop = 0.14
let threadBottom = 0.32
let threadWidth = 0.022
let podStart = (x: 0.50, y: 0.28)
let podSegs: [((Double, Double), (Double, Double), (Double, Double))] = [
  ((0.62, 0.34), (0.70, 0.46), (0.70, 0.58)),
  ((0.70, 0.76), (0.61, 0.86), (0.50, 0.86)),
  ((0.39, 0.86), (0.30, 0.76), (0.30, 0.58)),
  ((0.30, 0.46), (0.38, 0.34), (0.50, 0.28)),
]
let podStroke = 0.02
let chords = [0.54, 0.67]
let chordSpan = (x0: 0.26, x1: 0.74)
let chordLift = 0.03
let chordSag = 0.05
let chordWidth = 0.02

enum Variant {
  case appIcon
  case favicon
  case touch
}

func render(size: Int, variant: Variant) -> NSBitmapImageRep {
  let s = CGFloat(size)
  guard
    let rep = NSBitmapImageRep(
      bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
      bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
      colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    ),
    let ctx = NSGraphicsContext(bitmapImageRep: rep)
  else { fatalError("could not create bitmap context") }
  rep.size = NSSize(width: s, height: s)
  NSGraphicsContext.saveGraphicsState()
  NSGraphicsContext.current = ctx

  let margin: CGFloat = variant == .appIcon ? 0.0975 : 0
  let side = s * (1 - 2 * margin)
  let origin = s * margin
  let radius: CGFloat
  switch variant {
  case .appIcon: radius = side * 0.2237
  case .favicon: radius = side * 0.22
  case .touch: radius = 0
  }
  let squircle = NSRect(x: origin, y: origin, width: side, height: side)
  let plate = NSBezierPath(roundedRect: squircle, xRadius: radius, yRadius: radius)
  let plateGradient = NSGradient(starting: plateTop, ending: plateBottom)
  NSGraphicsContext.saveGraphicsState()
  plate.addClip()
  plateGradient?.draw(in: squircle, angle: -90)
  NSGraphicsContext.restoreGraphicsState()

  func p(_ x: Double, _ y: Double) -> NSPoint {
    NSPoint(x: origin + CGFloat(x) * side, y: origin + (1 - CGFloat(y)) * side)
  }

  // Cocoon: paper thread, paper pod, wrap chords cut out — all in one
  // transparency layer, so edges stay clean over the plate gradient.
  NSGraphicsContext.saveGraphicsState()
  plate.addClip()
  ctx.cgContext.beginTransparencyLayer(auxiliaryInfo: nil)

  let thread = NSBezierPath()
  thread.move(to: p(0.5, threadTop))
  thread.line(to: p(0.5, threadBottom))
  thread.lineCapStyle = .round
  thread.lineWidth = threadWidth * side
  paper.setStroke()
  thread.stroke()

  let pod = NSBezierPath()
  pod.move(to: p(podStart.x, podStart.y))
  for (c1, c2, end) in podSegs {
    pod.curve(to: p(end.0, end.1), controlPoint1: p(c1.0, c1.1), controlPoint2: p(c2.0, c2.1))
  }
  pod.close()
  pod.lineJoinStyle = .round
  pod.lineWidth = podStroke * side
  paper.setStroke()
  pod.stroke()
  paper.setFill()
  pod.fill()

  ctx.cgContext.setBlendMode(.clear)
  for y in chords {
    let chord = NSBezierPath()
    chord.move(to: p(chordSpan.x0, y - chordLift))
    chord.curve(
      to: p(chordSpan.x1, y - chordLift),
      controlPoint1: p(0.39, y + chordSag), controlPoint2: p(0.61, y + chordSag)
    )
    chord.lineCapStyle = .round
    chord.lineWidth = chordWidth * side
    chord.stroke()
  }
  ctx.cgContext.setBlendMode(.normal)

  ctx.cgContext.endTransparencyLayer()
  NSGraphicsContext.restoreGraphicsState()

  NSGraphicsContext.restoreGraphicsState()
  return rep
}

func write(_ rep: NSBitmapImageRep, _ relativePath: String) {
  let url = root.appendingPathComponent(relativePath)
  try! FileManager.default.createDirectory(
    at: url.deletingLastPathComponent(), withIntermediateDirectories: true
  )
  try! rep.representation(using: .png, properties: [:])!.write(to: url)
  print("wrote \(relativePath)")
}

func renderMark(size: Int) -> NSBitmapImageRep {
  // Template silhouette of the mark (D-018): black shapes on transparent, chord
  // wraps cut out. Status items and other templates recolor it.
  let s = CGFloat(size)
  guard
    let rep = NSBitmapImageRep(
      bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
      bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
      colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    ),
    let ctx = NSGraphicsContext(bitmapImageRep: rep)
  else { fatalError("could not create bitmap context") }
  rep.size = NSSize(width: s, height: s)
  NSGraphicsContext.saveGraphicsState()
  NSGraphicsContext.current = ctx

  func p(_ x: Double, _ y: Double) -> NSPoint {
    NSPoint(x: CGFloat(x) * s, y: (1 - CGFloat(y)) * s)
  }

  ctx.cgContext.beginTransparencyLayer(auxiliaryInfo: nil)
  NSColor.black.setFill()
  NSColor.black.setStroke()

  let thread = NSBezierPath()
  thread.move(to: p(0.5, threadTop))
  thread.line(to: p(0.5, threadBottom))
  thread.lineCapStyle = .round
  thread.lineWidth = max(1, threadWidth * s)
  thread.stroke()

  let pod = NSBezierPath()
  pod.move(to: p(podStart.x, podStart.y))
  for (c1, c2, end) in podSegs {
    pod.curve(to: p(end.0, end.1), controlPoint1: p(c1.0, c1.1), controlPoint2: p(c2.0, c2.1))
  }
  pod.close()
  pod.lineJoinStyle = .round
  pod.lineWidth = podStroke * s
  pod.stroke()
  pod.fill()

  ctx.cgContext.setBlendMode(.clear)
  for y in chords {
    let chord = NSBezierPath()
    chord.move(to: p(chordSpan.x0, y - chordLift))
    chord.curve(
      to: p(chordSpan.x1, y - chordLift),
      controlPoint1: p(0.39, y + chordSag), controlPoint2: p(0.61, y + chordSag)
    )
    chord.lineCapStyle = .round
    chord.lineWidth = chordWidth * s
    chord.stroke()
  }
  ctx.cgContext.setBlendMode(.normal)
  ctx.cgContext.endTransparencyLayer()

  NSGraphicsContext.restoreGraphicsState()
  return rep
}

let markSet = "Sources/DormantApp/Assets.xcassets/Mark.imageset"
write(renderMark(size: 18), "\(markSet)/mark-18.png")
write(renderMark(size: 36), "\(markSet)/mark-18@2x.png")
let markContents = """
  {
    "images" : [
      { "filename" : "mark-18.png",    "idiom" : "universal", "scale" : "1x" },
      { "filename" : "mark-18@2x.png", "idiom" : "universal", "scale" : "2x" }
    ],
    "info" : { "author" : "xcode", "version" : 1 },
    "properties" : { "template-rendering-intent" : "template" }
  }
  """
try! markContents.write(
  to: root.appendingPathComponent("\(markSet)/Contents.json"),
  atomically: true, encoding: .utf8
)
print("wrote \(markSet)/Contents.json")

func f(_ v: Double) -> String { String(format: "%.2f", v * 64) }

let appSet = "Sources/DormantApp/Assets.xcassets/AppIcon.appiconset"
let macSet: [(Int, String)] = [
  (16, "AppIcon.16x16.png"), (32, "AppIcon.16x16@2x.png"),
  (32, "AppIcon.32x32.png"), (64, "AppIcon.32x32@2x.png"),
  (128, "AppIcon.128x128.png"), (256, "AppIcon.128x128@2x.png"),
  (256, "AppIcon.256x256.png"), (512, "AppIcon.256x256@2x.png"),
  (512, "AppIcon.512x512.png"), (1024, "AppIcon.512x512@2x.png"),
]
for (pixels, name) in macSet {
  write(render(size: pixels, variant: .appIcon), "\(appSet)/\(name)")
}

let contents = """
  {
    "images" : [
      { "filename" : "AppIcon.16x16.png",   "idiom" : "mac", "scale" : "1x", "size" : "16x16" },
      { "filename" : "AppIcon.16x16@2x.png","idiom" : "mac", "scale" : "2x", "size" : "16x16" },
      { "filename" : "AppIcon.32x32.png",   "idiom" : "mac", "scale" : "1x", "size" : "32x32" },
      { "filename" : "AppIcon.32x32@2x.png","idiom" : "mac", "scale" : "2x", "size" : "32x32" },
      { "filename" : "AppIcon.128x128.png", "idiom" : "mac", "scale" : "1x", "size" : "128x128" },
      { "filename" : "AppIcon.128x128@2x.png","idiom" : "mac", "scale" : "2x", "size" : "128x128" },
      { "filename" : "AppIcon.256x256.png", "idiom" : "mac", "scale" : "1x", "size" : "256x256" },
      { "filename" : "AppIcon.256x256@2x.png","idiom" : "mac", "scale" : "2x", "size" : "256x256" },
      { "filename" : "AppIcon.512x512.png", "idiom" : "mac", "scale" : "1x", "size" : "512x512" },
      { "filename" : "AppIcon.512x512@2x.png","idiom" : "mac", "scale" : "2x", "size" : "512x512" }
    ],
    "info" : { "author" : "xcode", "version" : 1 }
  }
  """
try! contents.write(
  to: root.appendingPathComponent("\(appSet)/Contents.json"),
  atomically: true, encoding: .utf8
)
print("wrote \(appSet)/Contents.json")

for pixels in [16, 32, 48] {
  write(render(size: pixels, variant: .favicon), "site/src/favicon-\(pixels).png")
}
write(render(size: 180, variant: .touch), "site/src/apple-touch-icon.png")
write(render(size: 512, variant: .appIcon), "site/src/icon-512.png")
write(render(size: 1024, variant: .appIcon), "site/src/icon-1024.png")

let podPath = """
  M \(f(podStart.x)) \(f(podStart.y)) \
  C \(f(podSegs[0].0.0)) \(f(podSegs[0].0.1)), \(f(podSegs[0].1.0)) \(f(podSegs[0].1.1)), \(f(podSegs[0].2.0)) \(f(podSegs[0].2.1)) \
  C \(f(podSegs[1].0.0)) \(f(podSegs[1].0.1)), \(f(podSegs[1].1.0)) \(f(podSegs[1].1.1)), \(f(podSegs[1].2.0)) \(f(podSegs[1].2.1)) \
  C \(f(podSegs[2].0.0)) \(f(podSegs[2].0.1)), \(f(podSegs[2].1.0)) \(f(podSegs[2].1.1)), \(f(podSegs[2].2.0)) \(f(podSegs[2].2.1)) \
  C \(f(podSegs[3].0.0)) \(f(podSegs[3].0.1)), \(f(podSegs[3].1.0)) \(f(podSegs[3].1.1)), \(f(podSegs[3].2.0)) \(f(podSegs[3].2.1)) \
  Z
  """
let chordLines = chords.map { y in
  """
    <path d="M \(f(chordSpan.x0)) \(f(y - chordLift)) C \(f(0.39)) \(f(y + chordSag)), \(f(0.61)) \(f(y + chordSag)), \(f(chordSpan.x1)) \(f(y - chordLift))" fill="none" stroke="black" stroke-width="\(f(chordWidth))" stroke-linecap="round"/>
  """
}.joined(separator: "\n")

let svg = """
  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64">
    <defs>
      <linearGradient id="plate" x1="0" y1="0" x2="0" y2="1">
        <stop offset="0" stop-color="#3c5a43"/>
        <stop offset="1" stop-color="#213427"/>
      </linearGradient>
      <mask id="mark">
        <rect width="64" height="64" fill="black"/>
        <line x1="\(f(0.5))" y1="\(f(threadTop))" x2="\(f(0.5))" y2="\(f(threadBottom))" stroke="white" stroke-width="\(f(threadWidth))" stroke-linecap="round"/>
        <path d="\(podPath)" fill="white" stroke="white" stroke-width="\(f(podStroke))" stroke-linejoin="round"/>
  \(chordLines)
      </mask>
    </defs>
    <rect width="64" height="64" rx="14.08" fill="url(#plate)"/>
    <rect width="64" height="64" fill="#f4f1e8" mask="url(#mark)"/>
  </svg>
  """
try! svg.write(to: root.appendingPathComponent("site/src/favicon.svg"), atomically: true, encoding: .utf8)
print("wrote site/src/favicon.svg")
