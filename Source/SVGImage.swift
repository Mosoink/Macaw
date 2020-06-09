//
//  SVGImage.swift
//  Macaw
//
//  Created by Zhibin on 2020/6/8.
//  Copyright © 2020 Exyte. All rights reserved.
//

import Foundation
import CoreGraphics

#if !CARTHAGE
import SWXMLHash
#endif

class SVGImageParser {

    var styleParser: SVGImage.StyleParser?

    public static let `default`: SVGImageParser = {
        SVGImageParser()
    }()
}

open class SVGImage: NSObject {

    public typealias StyleParserResultKey = NSString

    @objc  static let StyleParserResultKeyFontFaces: StyleParserResultKey = "fontFaces"

    public typealias StyleParser = (String) -> [StyleParserResultKey: Any]

    @objc public static func setStyleParser(_ styleParser: @escaping StyleParser) {
        SVGImageParser.default.styleParser = styleParser
    }

    @objc public var image: MImage? {
        get {
            guard let nOK = node, var size = nOK.bounds?.size() else {
                return nil
            }
            let didSetScale = scale != 1.0

            if didSetScale {
                let scaleOK = Double(scale)
                size = Size(size.w * scaleOK, size.h * scaleOK)
            }
            var img = nOK.toNativeImage(size: size, layout: .of(contentMode: .scaleAspectFit))
            if didSetScale, let cgImg = img.cgImage {
                img = MImage(cgImage: cgImg, scale: scale, orientation: .up)
            }
            return img
        }
    }

    @objc public var size: CGSize {
        get {
            guard let nOK = node, let size = nOK.bounds?.size() else {
                return CGSize.zero
            }
            return CGSize(width: size.w, height: size.h)
        }
    }

    @objc public var scale: CGFloat = 1.0

    private var node: Node?

    @objc public init(svgString: String) {
        super.init()
        let parser = SVGParser(svgString)
        parser.fontFimalyModifier = { old in
            self.fontNameFor(fontFimaly: old)
        }
        let n = try? parser.parse { opts in
            self.configOptions(opts)
        }
        self.node = n
    }

    private var fontNames = [String: String]()

    private func configOptions(_ opts: SWXMLHashOptions) {
        opts.styleParser = { text in
            guard let result = SVGImageParser.default.styleParser?(text) else {
                return
            }

            guard let fontFaces = result[SVGImage.StyleParserResultKeyFontFaces] as? [[String: Any]] else {
                return
            }

            for fontFace in fontFaces {
                self.registFontFace(fontFace)
            }
        }
    }

    private func fontNameFor(fontFimaly: String) -> String? {
        return fontNames[fontFimaly]
    }

    private func registFontFace(_ item: [String: Any]) {
        guard let fontFamily = item["font-family"] as? String else {
            return
        }
        guard let fontDataURL = item["src"] as? String else {
            return
        }
        var data = fontDataURL.replacingOccurrences(of: " ", with: "")
        data = data.replacingOccurrences(of: "url(data:font/truetype;charset=utf-8;base64,",
                                         with: "")
        data = data.replacingOccurrences(of: ")format('truetype')",
                                         with: "")

        guard let fontData = Data(base64Encoded: data) as CFData? else {
            return
        }
        guard let dataProvider = CGDataProvider(data: fontData) else {
            return
        }
        guard let fontRef = CGFont(dataProvider) else {
            return
        }
        guard let postScriptName = fontRef.postScriptName as String? else {
            return
        }

        fontNames[fontFamily] = postScriptName
    }
}
