//
//  Filters.swift
//  My Filter App
//
//  Created by Arsal on 09/04/2023.
//

import Foundation
import UIKit
import GPUImage

struct Filter {

    let name: String
    let image: UIImage
    let filter: GPUImageFilter
    
    func apply(to inputImage: UIImage) -> UIImage? {
            let picture = GPUImagePicture(image: inputImage)
            picture?.addTarget(filter)
            filter.useNextFrameForImageCapture()
            picture?.processImage()
            return filter.imageFromCurrentFramebuffer()
        }
}
