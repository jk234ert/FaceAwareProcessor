//
//  FaceAwareProcessor.swift
//  PandaQA
//
//  Created by jk234ert on 04/07/2017.
//  Copyright © 2017 SujiTech. All rights reserved.
//

import Foundation
import UIKit
import CoreGraphics
import CoreImage
import Kingfisher

struct FaceAwareProcessor: ImageProcessor {
    
    var detector: CIDetector?
    
    var viewSize: CGSize?
    
    public let identifier: String
    
    init(viewSize: CGSize, fast: Bool = false) {
        
        self.identifier = "com.pandaqa.faceawareprocessor(\(viewSize))"
        self.viewSize = viewSize
        let opts = [(fast ? CIDetectorAccuracyLow : CIDetectorAccuracyHigh): CIDetectorAccuracy]
        detector = CIDetector(ofType: CIDetectorTypeFace, context: nil, options: opts)
    }
    
    func process(item: ImageProcessItem, options: KingfisherOptionsInfo) -> Image? {
        switch item {
        case .image(let image):
            var ciimage = image.ciImage
            if ciimage == nil {
                ciimage = CIImage(cgImage: image.cgImage!)
            }
            let features: [CIFeature] = self.detector!.features(in: ciimage!)
            if features.count == 0 {
                return image
            } else {
                let detectedRect = pickFaceAwareRect(features: features, image: image)
                guard detectedRect != .zero else { return image }
                let finalImage = cropImage(image: image, to: detectedRect)
                return finalImage
            }
        case .data(_):
            return (DefaultImageProcessor.default >> self).process(item: item, options: options)
        }
    }
    
    func pickFaceAwareRect(features: [CIFeature], image: UIImage) -> CGRect {
        guard let cgImage = image.cgImage else { return .zero }
        guard let viewSize = self.viewSize else { return .zero }
        let imgSize = CGSize(width: Double(cgImage.width), height: (Double(cgImage.height)))
        
        var fixedRect = CGRect(x: Double(MAXFLOAT), y: Double(MAXFLOAT), width: 0, height: 0)
        var rightBorder:Double = 0, bottomBorder: Double = 0
        for f: CIFeature in features {
            var oneRect = CGRect(x: f.bounds.origin.x, y: f.bounds.origin.y, width: f.bounds.size.width, height: f.bounds.size.height)
            oneRect.origin.y = imgSize.height - oneRect.origin.y - oneRect.size.height
            
            fixedRect.origin.x = min(oneRect.origin.x, fixedRect.origin.x)
            fixedRect.origin.y = min(oneRect.origin.y, fixedRect.origin.y)
            
            rightBorder = max(Double(oneRect.origin.x) + Double(oneRect.size.width), rightBorder)
            bottomBorder = max(Double(oneRect.origin.y) + Double(oneRect.size.height), bottomBorder)
        }
        
        fixedRect.size.width = CGFloat(Int(rightBorder) - Int(fixedRect.origin.x))
        fixedRect.size.height = CGFloat(Int(bottomBorder) - Int(fixedRect.origin.y))
        
        let fixedCenter: CGPoint = CGPoint(x: fixedRect.origin.x + fixedRect.size.width / 2.0,
                                           y: fixedRect.origin.y + fixedRect.size.height / 2.0)
        var offset: CGPoint = .zero
        var finalSize: CGSize = imgSize
        
        if imgSize.width / imgSize.height > viewSize.width / viewSize.height {
            finalSize.width = imgSize.height / viewSize.height * viewSize.width
            offset.x = max(fixedCenter.x - finalSize.width / 2.0, 0)
            offset.y = 0
        } else {
            finalSize.height = imgSize.width / viewSize.width * viewSize.height
            offset.x = 0
            offset.y = max(fixedCenter.y - finalSize.height / 2.0, 0)
        }
        
        return CGRect(x: offset.x, y: offset.y, width: finalSize.width, height: finalSize.height)
    }
    
    func cropImage(image: UIImage, to rect: CGRect) -> UIImage {
        guard rect.size.height < image.size.height && rect.size.height < image.size.height else {
            return image
        }
        guard let cgImage: CGImage = image.cgImage?.cropping(to: rect) else {
            return image
        }
        return UIImage(cgImage: cgImage)
    }
}
