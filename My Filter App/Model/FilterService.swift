//
//  FilterService.swift
//  My Filter App
//
//  Created by Arsal on 09/04/2023.
//

import Foundation
import GPUImage

class FilterService {
    func getFilterCategories() -> [FilterCategory] {
        let colorAdjustmentFilters = [
            Filter(name: "Brightness", image: applyFilter(GPUImageBrightnessFilter()), filter: GPUImageBrightnessFilter()),
            Filter(name: "Contrast", image: applyFilter(GPUImageContrastFilter()), filter: GPUImageContrastFilter()),
            Filter(name: "Saturation", image: applyFilter(GPUImageSaturationFilter()), filter: GPUImageSaturationFilter()),
            Filter(name: "Hue", image: applyFilter(GPUImageHueFilter()), filter: GPUImageHueFilter()),
            Filter(name: "Exposure", image: applyFilter(GPUImageExposureFilter()), filter: GPUImageExposureFilter())
        ]
        let blurAndSharpenFilters = [
            Filter(name: "Gaussian Blur", image: applyFilter(GPUImageGaussianBlurFilter()), filter: GPUImageGaussianBlurFilter()),
            Filter(name: "Box Blur", image: applyFilter(GPUImageBoxBlurFilter()), filter: GPUImageBoxBlurFilter()),
            Filter(name: "Sharpen", image: applyFilter(GPUImageSharpenFilter()), filter: GPUImageSharpenFilter())
        ]
        let edgeDetectionFilters = [
            Filter(name: "Sobel Edge Detection", image: applyFilter(GPUImageSobelEdgeDetectionFilter()), filter: GPUImageSobelEdgeDetectionFilter()),
            Filter(name: "Prewitt Edge Detection", image: applyFilter(GPUImagePrewittEdgeDetectionFilter()), filter: GPUImagePrewittEdgeDetectionFilter())
        ]
        let morphologyFilters = [
            Filter(name: "Erosion", image: applyFilter(GPUImageErosionFilter()), filter: GPUImageErosionFilter()),
            Filter(name: "Dilation", image: applyFilter(GPUImageDilationFilter()), filter: GPUImageDilationFilter()),
        ]
        let specialEffectsFilters = [
            Filter(name: "Sepia", image: applyFilter(GPUImageSepiaFilter()), filter: GPUImageSepiaFilter()),
            Filter(name: "Vignette", image: applyFilter(GPUImageVignetteFilter()), filter: GPUImageVignetteFilter()),
            Filter(name: "Grayscale", image: applyFilter(GPUImageGrayscaleFilter()), filter: GPUImageGrayscaleFilter()),
            Filter(name: "Toon", image: applyFilter(GPUImageToonFilter()), filter: GPUImageToonFilter())
        ]
        return [
            FilterCategory(name: "Blur and Sharpen", filters: blurAndSharpenFilters),
            FilterCategory(name: "Edge Detection", filters: edgeDetectionFilters),
            FilterCategory(name: "Morphology", filters: morphologyFilters),
            FilterCategory(name: "Special Effects", filters: specialEffectsFilters),
            FilterCategory(name: "Color Adjustment", filters: colorAdjustmentFilters)
        ]
    }
    
    private func applyFilter(_ filter: GPUImageFilter) -> UIImage {
        let inputImage = UIImage(named: "DefaultImage")!
        let picture = GPUImagePicture(image: inputImage)
        picture?.addTarget(filter)
        filter.useNextFrameForImageCapture()
        picture?.processImage()
        return filter.imageFromCurrentFramebuffer()!
    }
}
