//
//  DTImageRecognizationEngine.swift
//  Difft
//
//  Created by Jaymin on 2024/5/30.
//  Copyright © 2024 Difft. All rights reserved.
//

import Foundation
import Vision
import SignalCoreKit

class DTImageRecognizationEngine {
    
    enum RecognizationError: Error {
        case invalidImage
        case recognizeFailed
    }
    
    static func recognize(image: UIImage) -> Promise<[DTImageRecognizedContent]> {
        guard let cgImage = image.cgImage else {
            return Promise(error: RecognizationError.invalidImage)
        }
        
        return Promise { future in
            
            DispatchQueue.global().async {
                
                var qrcodeResults: [DTImageRecognizedContent]? = nil
                var textResults: [DTImageRecognizedContent]? = nil
                
                let completion = {
                    guard let qrcodeResults, let textResults else {
                        return
                    }
                    guard !qrcodeResults.isEmpty || !textResults.isEmpty else {
                        future.reject(RecognizationError.recognizeFailed)
                        return
                    }
                    let results: [DTImageRecognizedContent] = qrcodeResults + textResults
                    future.resolve(results)
                }
                
                let barcodeRequest = VNDetectBarcodesRequest { request, error in
                    qrcodeResults = request.results?.compactMap { DTImageRecognizedContent(observation: $0) } ?? []
                    completion()
                }
                barcodeRequest.preferBackgroundProcessing = true
                
                let textRequest = VNRecognizeTextRequest { request, error in
                    textResults = request.results?.compactMap { DTImageRecognizedContent(observation: $0) } ?? []
                    completion()
                }
                textRequest.preferBackgroundProcessing = true
                textRequest.usesLanguageCorrection = true
                // Note: 默认无法识别简体中文和繁体中文
                textRequest.recognitionLanguages = ["zh-Hans", "zh-Hant"]
                
                let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                do {
                    try handler.perform([barcodeRequest, textRequest])
                } catch {
                    qrcodeResults = []
                    textResults = []
                    completion()
                }
                
            }
        }
    }
}
