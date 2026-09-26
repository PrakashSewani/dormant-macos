import AppKit

// Regenerates every icon size from the Dormant mark (D-013). Run: swift Scripts/render-icons.swift

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

let paper = NSColor(srgbRed: 0.9569, green: 0.9451, blue: 0.9098, alpha: 1)
let plateTop = NSColor(srgbRed: 0.2353, green: 0.3529, blue: 0.2627, alpha: 1)
let plateBottom = NSColor(srgbRed: 0.1294, green: 0.2039, blue: 0.1529, alpha: 1)

// Mark geometry in unit space (y measured from the top), before centering.
let moonRadius = 0.36
let terminatorSemi = (x: 0.28, y: 0.37)
var moonCenter = (x: 0.46, y: 0.50)
var terminatorCenter = (x: 0.61, y: 0.50)

func inMoon(_ x: Double, _ y: Double) -> Bool {
  let dc = (x - moonCenter.x) * (x - moonCenter.x) + (y - moonCenter.y) * (y - moonCenter.y)
  guard dc <= moonRadius * moonRadius else { return false }
  let de = pow((x - terminatorCenter.x) / terminatorSemi.x, 2)
    + pow((y - terminatorCenter.y) / terminatorSemi.y, 2)
  return de > 1
}

// Shift the mark so its bounding box sits dead center of the plate.
var minX = 1.0, maxX = 0.0, minY = 1.0, maxY = 0.0
let steps = 200
for i in 0..<steps {
  for j in 0..<steps {
    let x = (Double(i) + 0.5) / Double(steps)
    let y = (Double(j) + 0.5) / Double(steps)
    if inMoon(x, y) {
      minX = min(minX, x)
      maxX = max(maxX, x)
      minY = min(minY, y)
      maxY = max(maxY, y)
    }
  }
}
let shift = (x: 0.5 - (minX + maxX) / 2, y: 0.5 - (minY + maxY) / 2)
moonCenter = (moonCenter.x + shift.x, moonCenter.y + shift.y)
terminatorCenter = (terminatorCenter.x + shift.x, terminatorCenter.y + shift.y)
print(String(format: "centering shift: %+.4f, %+.4f", shift.x, shift.y))

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

  // Crescent moon: paper circle with the elliptical terminator cleared out
  // in a transparency layer, so edges stay clean over the plate gradient.
  NSGraphicsContext.saveGraphicsState()
  plate.addClip()
  ctx.cgContext.beginTransparencyLayer(auxiliaryInfo: nil)

  let c = p(moonCenter.x, moonCenter.y)
  let moon = NSBezierPath(
    ovalIn: NSRect(
      x: c.x - moonRadius * side, y: c.y - moonRadius * side,
      width: 2 * moonRadius * side, height: 2 * moonRadius * side
    )
  )
  paper.setFill()
  moon.fill()

  let terminatorRect = NSRect(
    x: origin + CGFloat(terminatorCenter.x - terminatorSemi.x) * side,
    y: origin + (1 - CGFloat(terminatorCenter.y + terminatorSemi.y)) * side,
    width: CGFloat(2 * terminatorSemi.x) * side,
    height: CGFloat(2 * terminatorSemi.y) * side
  )
  ctx.cgContext.setBlendMode(.clear)
  ctx.cgContext.addEllipse(in: terminatorRect)
  ctx.cgContext.fillPath()
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

let svg = """
  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64">
    <defs>
      <linearGradient id="plate" x1="0" y1="0" x2="0" y2="1">
        <stop offset="0" stop-color="#3c5a43"/>
        <stop offset="1" stop-color="#213427"/>
      </linearGradient>
      <mask id="moon">
        <rect width="64" height="64" fill="black"/>
        <circle cx="\(f(moonCenter.x))" cy="\(f(moonCenter.y))" r="\(f(moonRadius))" fill="white"/>
        <ellipse cx="\(f(terminatorCenter.x))" cy="\(f(terminatorCenter.y))" rx="\(f(terminatorSemi.x))" ry="\(f(terminatorSemi.y))" fill="black"/>
      </mask>
    </defs>
    <rect width="64" height="64" rx="14.08" fill="url(#plate)"/>
    <rect width="64" height="64" fill="#f4f1e8" mask="url(#moon)"/>
  </svg>
  """
try! svg.write(to: root.appendingPathComponent("site/src/favicon.svg"), atomically: true, encoding: .utf8)
print("wrote site/src/favicon.svg")
