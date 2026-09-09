import CoreGraphics
import ImageIO
import Foundation
let size = 1024
let space = CGColorSpaceCreateDeviceRGB()
let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: size * 4, space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
let colors = [CGColor(red: 0.10, green: 0.22, blue: 0.19, alpha: 1), CGColor(red: 0.28, green: 0.46, blue: 0.37, alpha: 1)] as CFArray
let gradient = CGGradient(colorsSpace: space, colors: colors, locations: [0,1])!
context.drawLinearGradient(gradient, start: CGPoint(x: 900,y: 0), end: CGPoint(x: 100,y: 1024), options: [.drawsBeforeStartLocation,.drawsAfterEndLocation])
context.setFillColor(CGColor(red: 0.94, green: 0.96, blue: 0.89, alpha: 1))
context.addPath(CGPath(roundedRect: CGRect(x:194,y:286,width:636,height:474), cornerWidth:142, cornerHeight:142, transform:nil)); context.fillPath()
context.move(to: CGPoint(x:282,y:355)); context.addLine(to: CGPoint(x:270,y:190)); context.addLine(to: CGPoint(x:470,y:322)); context.closePath(); context.fillPath()
context.setFillColor(CGColor(red:0.21,green:0.37,blue:0.31,alpha:1))
for x in [354,512,670] { context.fillEllipse(in: CGRect(x:x-36,y:487,width:72,height:72)) }
let output = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "ios/Chatty/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
let destination = CGImageDestinationCreateWithURL(URL(fileURLWithPath:output) as CFURL, "public.png" as CFString, 1, nil)!
CGImageDestinationAddImage(destination, context.makeImage()!, nil)
guard CGImageDestinationFinalize(destination) else { fatalError("PNG export failed") }
print(output)
