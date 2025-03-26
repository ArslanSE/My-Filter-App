//
//  StickersManager.swift
//  myzesty
//
//  Created by Arslan Saleem on 21/03/2025.
//  Copyright © 2025 MyZesty, inc. All rights reserved.
//

import Foundation

class StickersManager: ObservableObject, StickerVideoAttachmentViewDelegate {

    // Dependencies
    private let subBarResourcesManager: SubBarResourcesManager
    private let playerVM: PlayerViewModel
    private let navigator: MainScreenNavigator
    var lastSelectedStickerModel: StickerModel?
    var lastSelectedStickerAttachment: StickerVideoAttachment?


    // StickerModel and selectedStickerAttachment, both hold state of attachment
    // which is being edited. Their content is saved when editing of a sticker is completed.
    // They are assigned new sticker if user switch between 2 stickers.
    @Published var selectedStickerModel: StickerModel?
    @Published var selectedStickerAttachment: StickerVideoAttachment?
    @Published var newlyAddedStickerAttachment: StickerVideoAttachment?

    init(subBarResourcesManager: SubBarResourcesManager, playerVM: PlayerViewModel, navigator: MainScreenNavigator, lastSelectedStickerModel: StickerModel? = nil, lastSelectedStickerAttachment: StickerVideoAttachment? = nil, selectedStickerModel: StickerModel? = nil, selectedStickerAttachment: StickerVideoAttachment? = nil, newlyAddedStickerAttachment: StickerVideoAttachment? = nil) {
        self.subBarResourcesManager = subBarResourcesManager
        self.playerVM = playerVM
        self.navigator = navigator
        self.lastSelectedStickerModel = lastSelectedStickerModel
        self.lastSelectedStickerAttachment = lastSelectedStickerAttachment
        self.selectedStickerModel = selectedStickerModel
        self.selectedStickerAttachment = selectedStickerAttachment
        self.newlyAddedStickerAttachment = newlyAddedStickerAttachment
    }

    func addSticker(localStickerURL: String, stickerResourceEntity: ResourceEntity) {
        guard let previewVC = playerVM.mtkView?.attachmentsPreviewVC else { return }
        handlePremiumStickerIfNeeded(stickerResourceEntity)
        removeExistingSticker()
        let centerOfPreview = previewVC.view.frame.center
        let (size, rotation, center) = getReplacedStickerProperties(centerOfPreview: centerOfPreview)
        guard let stickerAttachmentView = createNewStickerAttachment(localStickerURL: localStickerURL,
                                                                     size: size,
                                                                     rotation: rotation)
        else { return }
        guard let sdImage = StickerHelpers.createImage(localStickerURL: localStickerURL) else {
            print("Failed to create SDAnimatedImage with url '\(localStickerURL)'.")
            return
        }
        let animatedStickerConverter = configureStickerImage(stickerAttachmentView, localStickerURL, sdImage)
        setupStickerAttachmentView(stickerAttachmentView, center, stickerResourceEntity)
        let newStickerModel = addStickerToPreview(stickerAttachmentView, localStickerURL, animatedStickerConverter)
        finalizeStickerAddition(newStickerModel, stickerAttachmentView)
    }

    // MARK: - Helper Functions
    private func handlePremiumStickerIfNeeded(_ stickerResourceEntity: ResourceEntity) {
        if stickerResourceEntity.premium == true, PremiumFlowManager.shared.shouldShowBanner() {
            playerVM.showPremiumBanner(with: &PremiumFlowManager.shared.shouldShowBannerOnStickersForVideoEditor)
        }
    }

    private func removeExistingSticker() {
        selectedStickerAttachment?.removeFromSuperview()
        removeStickerOperation(for: selectedStickerModel)

        if let modelId = selectedStickerAttachment?.modelID {
            subBarResourcesManager.deleteResource(type: .sticker, id: modelId)
        }
    }

    private func getReplacedStickerProperties(centerOfPreview: CGPoint) -> (CGSize, Float, CGPoint) {
        let size = selectedStickerAttachment?.contentViewSize ?? StickerHelpers.defaultSizeForStickerAttachment
        let rotation = selectedStickerAttachment?.rotation ?? 0.0
        let center = selectedStickerAttachment?.center ?? centerOfPreview
        return (size, rotation, center)
    }

    private func createNewStickerAttachment(localStickerURL: String, size: CGSize, rotation: Float) -> StickerVideoAttachment? {
        guard let stickerAttachmentView = createNewStickerAttachmentView(localStickerURL: localStickerURL,
                                                                         contentViewSize: size,
                                                                         rotation: rotation) else {
            print("Failed to create sticker attachment view")
            return nil
        }
        return stickerAttachmentView
    }

    private func configureStickerImage(_ stickerAttachmentView: StickerVideoAttachment, _ localStickerURL: String, _ sdImage: SDAnimatedImage) -> AnimatedStickerConverter? {
        let isAnimated = StickerHelpers.doesStickerUrlContainWebP(stickerURl: localStickerURL)
        var animatedStickerConverter: AnimatedStickerConverter?

        if isAnimated {
            animatedStickerConverter = AnimatedStickerConverter(animatedImage: sdImage)
            if let firstImage = animatedStickerConverter?.getImageAtTime(time: .zero) {
                stickerAttachmentView.setContentViewImage(firstImage)
                animatedStickerConverter?.preloadAllFrames()
            } else {
                print("Sticker converter returned nil image, failed to add sticker")
                return nil
            }
        } else {
            stickerAttachmentView.setContentViewImage(sdImage)
        }

        return animatedStickerConverter
    }

    private func setupStickerAttachmentView(_ stickerAttachmentView: StickerVideoAttachment, _ center: CGPoint, _ stickerResourceEntity: ResourceEntity) {
        stickerAttachmentView.isHideContentView(true)
        stickerAttachmentView.showEditingHandlers = true
        stickerAttachmentView.delegate = self
        stickerAttachmentView.center = center
        stickerAttachmentView.stickerResource = stickerResourceEntity
        let previousStickersExtendToFull = selectedStickerModel?.extendToFull ?? false
        stickerAttachmentView.extendToFullProjectImageView.image = previousStickersExtendToFull ? UIImage.init(named: "extendToFullVideoIcon")! : UIImage.init(named: "extendToClipIcon")!

    }

    private func addStickerToPreview(_ stickerAttachmentView: StickerVideoAttachment, _ localStickerURL: String, _ animatedStickerConverter: AnimatedStickerConverter?) -> StickerModel? {
        guard let newStickerModel = playerVM.mtkView?.attachmentsPreviewVC?.addStickerAttachment(stickerAttachment: stickerAttachmentView,
                                                                                                 stickerURL: localStickerURL) else { return nil }

        newStickerModel.animatedStickerConverter = animatedStickerConverter
        newStickerModel.extendToFull = selectedStickerModel?.extendToFull ?? false
        return newStickerModel
    }

    private func finalizeStickerAddition(_ newStickerModel: StickerModel?, _ stickerAttachmentView: StickerVideoAttachment) {
        selectedStickerModel = newStickerModel
        selectedStickerAttachment = stickerAttachmentView
        newlyAddedStickerAttachment = stickerAttachmentView

        let computedTimeRange = playerVM.getTimeRangeForOperation(startTime: playerVM.currentPlayTime, duration: Constants.defaultImageDuration)

        if subBarResourcesManager.getResourcesOf(type: .sticker).contains(where: { $0.stickerModel?.getModelID() == newStickerModel?.getModelID() }) {
            return
        }

        _ = subBarResourcesManager.addResource(type: .sticker, startTime: playerVM.currentPlayTime, duration: computedTimeRange.duration, stickerModel: newStickerModel)

        self.addUpdateStickerOperation(timeRange: computedTimeRange, stickerStart: computedTimeRange.start, stickerModel: newStickerModel)
    }

    /// Removes the sticker  operation associated with the specified sticker model.
    func removeStickerOperation(for stickerModel: StickerModel?) {
        guard let stickerModel = stickerModel else { return }

        if let operation = stickerModel.videoOperation?.first(where: {$0.0 == .none}) {
            self.removeStickerOperationById(by: operation.1.videoOperationId)
        }
    }

    // IMPORTANT: Don't use self in this method, we will move this method out somewhere.
    func createNewStickerAttachmentView(localStickerURL: String,
                                        contentViewSize: CGSize,
                                        rotation: Float) -> StickerVideoAttachment? {

        let animatedImageView = StickerHelpers.createStickerImageView(imageViewSize: contentViewSize)
        let isWizardMode = navigator.editorMode == .wizard
        guard let stickerAttachmentView = StickerHelpers.createStickerVideoAttachment(stickerImageView: animatedImageView, isWizardMode: isWizardMode) else {
            print("Failed to create sticker attachment view.")
            return nil
        }

        // Set tag
        let isAnimated = StickerHelpers.doesStickerUrlContainWebP(stickerURl: localStickerURL)
        stickerAttachmentView.tag = isAnimated ? 888 : 999
        stickerAttachmentView.setDegreesRotation(angleDegrees: rotation)

        return stickerAttachmentView
    }

    func removeStickerOperationById(by id: UUID) {
        playerVM.textureProvider?.texturePostProcessor.removeStickerOperationById(id: id)
        playerVM.updateCurrentFrame()
    }

    // MARK: - Sticker Operation
    /// Adds or updates a sticker operation with the specified time range and sticker model.
    func addUpdateStickerOperation(timeRange: CMTimeRange, stickerStart: CMTime, stickerModel: StickerModel?) {
        guard let stickerModel = stickerModel else { return }

        // Check if the sticker model has no existing video operation
        if stickerModel.videoOperation == nil {
            self.addStickerOperation(timeRange: timeRange, stickerStart: stickerStart, model: stickerModel) { operation in
                self.selectedStickerModel?.videoOperation = [(.none, operation)]
            } onFailure: { error in
                print("Resource updater: adding sticker operation failed with error: \(error.localizedDescription)")
            }
        } else {
            // If a none operation exists, remove it and add a new one
            if let operation = stickerModel.videoOperation?.first(where: {$0.0 == .none}) {
                self.removeStickerOperationById(by: operation.1.videoOperationId)
                self.addStickerOperation(timeRange: timeRange, stickerStart: stickerStart, model: stickerModel) { operation in
                    self.selectedStickerModel?.videoOperation = [(.none, operation)]
                } onFailure: { error in
                    print("Resource updater: adding sticker operation failed with error: \(error.localizedDescription)")
                }
            }
        }
        playerVM.updateCurrentFrame() // Update the current frame after adding the sticker view
    }

    // MARK: - Sticker Operations functions
    func addStickerOperation(shaderName: String = "",
                             timeRange: CMTimeRange,
                             stickerStart: CMTime,
                             model: StickerModel,
                             onSuccess: @escaping (StickerVideoOperation) -> Void,
                             onFailure: @escaping (StickerError) -> Void) {
        switch model.type {
        case .staticImage:
            guard let options = model.info, let image = model.image else {
                onFailure(StickerError.failedToLoadSticker)
                return
            }
            if let operation = playerVM.textureProvider?.texturePostProcessor.addStaticSticker(image: image,
                                                                                      at: timeRange,
                                                                                      stickerOptions: options,
                                                                                      animationData: model.stickerAnimation,
                                                                                      stickerStart: stickerStart) {
                onSuccess(operation)
            } else {
                onFailure(StickerError.failedToAddSticker)
            }

        case .animatedWebp:
            guard let animatedStickerConverter = model.animatedStickerConverter,
                  let options = model.info else {
                onFailure(StickerError.invalidStickerURL)
                return
            }

            if let operation = playerVM.textureProvider?.texturePostProcessor.addAnimatedStickers(shaderName: shaderName, animatedStickerConverter: animatedStickerConverter,
                                                                                         at: timeRange,
                                                                                         stickerOptions: options,
                                                                                         animationData: model.stickerAnimation,
                                                                                         stickerStart: stickerStart) {
                onSuccess(operation)
            } else {
                onFailure(StickerError.failedToAddSticker)
            }
        }
    }

    /// Replaces existing sticker with new chosen sticker.
    /// This function only replaces sticker image and does not
    /// make changes to size, rotation and translation.
    /// - Parameters:
    ///     - localStickerURL: URL of sticker in file system.
    ///     - stickerResourceEntity: Entity which holds meta data of sticker
    ///     - shouldSelectSticker: Caller can choose to show replaced sticker as selected or unselected by providing value of this parameter.
    func replaceSticker(localStickerURL: String?,
                        stickerResourceEntity: ResourceEntity?,
                        shouldSelectSticker: Bool = true) {
        guard let previewVC = playerVM.mtkView?.attachmentsPreviewVC,
              let localStickerURL = localStickerURL,
              let stickerResourceEntity = stickerResourceEntity
        else {
            print("Player view model, replace sticker failed as couldn't find one of attachmentsPreviewVC, localStickerURL, stickResoureEntity")
            return
        }

        // 1. Remove existing attachment from preview.
        selectedStickerAttachment?.removeFromSuperview()
        // 2. Remove the existing sticker video operation
        removeStickerOperation(for: selectedStickerModel)

        // 3. GET PROPERTIES OF ATTACHMENT
        // In following line, not using view.centre as view.centre represents
        // centre of view in its parents coordinate system whereas
        // view.frame.centre(A calculated property in extension of view) represents
        // centre of view in its own coordinate system. We need centre of PREVIEW
        // within its own coordinates.
        let centerOfPreview = previewVC.view.frame.center
        let sizeOfReplacedSticker = selectedStickerAttachment?.contentViewSize
        let rotationOfReplacedSticker = selectedStickerAttachment?.rotation
        let centreOfReplacedSticker = selectedStickerAttachment?.center ?? centerOfPreview

        // 4. Create attachment view using stickerURL,size and rotation of selected sticker or default values.
        guard let stickerAttachmentView = createNewStickerAttachmentView(localStickerURL: localStickerURL,
                                                                         contentViewSize: sizeOfReplacedSticker ?? StickerHelpers.defaultSizeForStickerAttachment,
                                                                         rotation: rotationOfReplacedSticker ?? 0.0)
        else {
            print("Failed to create sticker attachment view")
            return
        }

        // 5. Create Image object of type SDAnimatedImage
        guard let sdImage = StickerHelpers.createImage(localStickerURL: localStickerURL) else {
            print("Failed to create SDAnimatedImage with url '\(localStickerURL)' in addSticker().")
            return
        }

        // 6. Set Image of sticker attachmentview. If animated sticker, create converter, set a first image, and later store converter in the model for further uses.
        let isAnimated = StickerHelpers.doesStickerUrlContainWebP(stickerURl: localStickerURL)
        var animatedStickerConverter: AnimatedStickerConverter?

        if isAnimated {
            // we preload after initiating StickerVideoAttachment which needs first image from converter.
            // If it is busy preloading, it takes time to give image to StickerVideoAttachment.
            animatedStickerConverter = AnimatedStickerConverter(animatedImage: sdImage)
            guard let firstImage = animatedStickerConverter?.getImageAtTime(time: .zero) else {
                print("sticker converter returned nil image, failed to add sticker")
                return
            }
            stickerAttachmentView.setContentViewImage(firstImage)
            animatedStickerConverter?.preloadAllFrames()
        } else {
            // static image
            stickerAttachmentView.setContentViewImage(sdImage)
        }

        // Other settings for attachment view
        if shouldSelectSticker {
            stickerAttachmentView.showEditingHandlers = true
        }

        stickerAttachmentView.delegate = self
        stickerAttachmentView.center = centreOfReplacedSticker
        stickerAttachmentView.isHideContentView(true)

        // 7. Add sticker attachment to preview and get NEW model object after adding it.
        let newStickerModel = playerVM.mtkView?.attachmentsPreviewVC?.addStickerAttachment(stickerAttachment:stickerAttachmentView,
                                                                            stickerURL: localStickerURL )
        // Important: set converter in the sticker model
        newStickerModel?.animatedStickerConverter = animatedStickerConverter

        /*
         Update new sticker model's extendToFull with the previous sticker's extendToFull. This is done for the case
         if user is adding sticker for the first time, and then selected extendToFull then selected another sticker
         this would have created a new model with extendToFull being default False. Hence we read previous
         stickers extendToFull state and apply that to the new sticker
         */
        // Save current stickers extend to full to be used when updating model
        let previousStickersExtendToFull = selectedStickerModel?.extendToFull ?? false
        newStickerModel?.extendToFull = previousStickersExtendToFull
        stickerAttachmentView.extendToFullProjectImageView.image = previousStickersExtendToFull ? UIImage.init(named: "extendToFullVideoIcon")! : UIImage.init(named: "extendToClipIcon")!

        // When sticker is replaced with new sticker on wizard screen
        // keep model id of sticker same
        newStickerModel?.setModelID(id: selectedStickerModel?.getModelID() ?? UUID())
        stickerAttachmentView.modelID = selectedStickerModel?.getModelID() ?? UUID()
        stickerAttachmentView.stickerResource = stickerResourceEntity
        newStickerModel?.isPremium = stickerResourceEntity.premium

        var startTime: CMTime = .zero
        var duration: CMTime = .zero

        // 8. Update selected sticker resource
        let stickerResourcess = subBarResourcesManager.getResourcesOf(type: .sticker)
        if let oldModelID = selectedStickerModel?.getModelID(),
           let previousStickerResource = stickerResourcess.first(where: { $0.stickerModel?.id == oldModelID }),
           let index = subBarResourcesManager.getIndexOf(type: .sticker, modelID: oldModelID),
            let updatedModel = newStickerModel {
            /*
             if old sticker was not extend to full but it was edited and user selected extend to full on new sticker
             we will not use the old stickers time,
             rather we will use the time from 0s to totalVideoSourcesTime in this case
            */
            let didExtendToFull = updatedModel.extendToFull
            startTime = didExtendToFull ? .zero : previousStickerResource.startTime
            duration = didExtendToFull ? playerVM.totalVideoSourcesTime : previousStickerResource.duration

            subBarResourcesManager.editResource (
              index: index,
              effectModel: nil,
              text: nil,
              startTime: startTime,
              duration: duration,
              textModel: nil,
              stickerModel: updatedModel,
              audioModel: nil
            )
            if let subbar = subBarResourcesManager.getCurrentSelectedResource() {
                PremiumFlowManager.shared.saveSubbarResource(subbar, type: .sticker)
            }
        }

        // 9. Make newly created sticker attachment and sticker model as selected
        selectedStickerModel = newStickerModel
        selectedStickerAttachment = stickerAttachmentView

        // 10. Add sticker operation in video operations
        self.addUpdateStickerOperation(timeRange: CMTimeRange(start: startTime, duration: duration), stickerStart: startTime, stickerModel: selectedStickerModel)

        // 11. Update premium for new selected sticker
//        isPremiumSticker = selectedStickerAttachment?.stickerResource?.premium ?? false
    }

    /// Removes a sticker from the texture provider's post-processor.
    /// - Parameter stickerModel: The model representing the sticker to be removed.
    func removeSticker(stickerModel: StickerModel) {
        if let operations = stickerModel.videoOperation {
            operations.forEach({ operation in
                if let operation = operation.1 as? StickerVideoOperation {
                    playerVM.textureProvider?.texturePostProcessor.removeOperation(operation: operation)
                }
            })
        }
        playerVM.updateCurrentFrame() // Update the current frame after removing the sticker.
    }

    /// Updates the sticker with new options and time range.
    /// - Parameters:
    ///    -  stickerModel: The model representing the sticker to be updated.
    ///    - isManuallyDragged: A flag indicating whether the text sticker was manually dragged (default is `false`).
    func updateSticker(stickerModel: StickerModel?, isManuallyDragged: Bool = false) {
        if let stickerModel = stickerModel, let operations = stickerModel.videoOperation,
           let options = stickerModel.info {
            operations.forEach({ operation in
                if let operation = operation.1 as? StickerVideoOperation {
                    playerVM.textureProvider?.texturePostProcessor.updateSticker(videoOperation: operation,
                                                                             with: options,
                                                                             timeRange: operation.effectiveTimeRange ?? CMTimeRange.zero,
                                                                             isManuallyDragged: isManuallyDragged)
                }
            })
//            isPremiumSticker = selectedStickerAttachment?.stickerResource?.premium ?? false
        }
        playerVM.updateCurrentFrame() // Update the current frame after removing the sticker.
    }

    func addSavedStickerToPreviewForRealm(localStickerURL: String, stickerModel: StickerModel) {
        guard let previewVC = playerVM.mtkView?.attachmentsPreviewVC
        else { return }
        // In following line, Not using view.center because
        // it has a different value
        let centerOfPreview = previewVC.view.frame.center
        let sizeOfReplacedSticker = stickerModel.stickerSize
        let rotationOfReplacedSticker = stickerModel.stickerRotation
        let centreOfReplacedSticker = stickerModel.stickerPosition?.denormalizePoint(inFrame: previewVC.view.frame) ?? centerOfPreview
        /// Save current stickers extend to full to be used when updating model
        let previousStickersExtendToFull = stickerModel.extendToFull

        // create SDImage
        guard let sdImage = StickerHelpers.createImage(localStickerURL: localStickerURL) else {
            print("Failed to create SDAnimatedImage with url '\(localStickerURL)' in addSticker().")
            return
        }

        let imageViewSize = stickerModel.stickerSize

        // Create attachment view
        guard let stickerAttachmentView = createNewStickerAttachmentView(localStickerURL: localStickerURL,
                                                                         contentViewSize: sizeOfReplacedSticker ?? CGSize(),
                                                                         rotation: rotationOfReplacedSticker ?? 0.0)
        else {
            print("Failed to addSticker")
            return
        }

        // If animated sticker, create converter, set a first image, and later store converter in the model for further uses.
        let isAnimated = StickerHelpers.doesStickerUrlContainWebP(stickerURl: localStickerURL)
        var animatedStickerConverter: AnimatedStickerConverter?

        if isAnimated {
            // we preload after initiating StickerVideoAttachment which needs first image from converter.
            // If it is busy preloading, it takes time to give image to StickerVideoAttachment.
            animatedStickerConverter = AnimatedStickerConverter(animatedImage: sdImage)
            guard let firstImage = animatedStickerConverter?.getImageAtTime(time: .zero) else {
                print("sticker converter returned nil image, failed to add sticker")
                return
            }
            stickerAttachmentView.setContentViewImage(firstImage)
            animatedStickerConverter?.preloadAllFrames()
        } else {
            // static image
            stickerAttachmentView.setContentViewImage(sdImage)
        }

        stickerAttachmentView.showEditingHandlers = false
        stickerAttachmentView.delegate = self
        stickerAttachmentView.center = centreOfReplacedSticker
        stickerAttachmentView.modelID = stickerModel.getModelID()
        if let opacity = stickerModel.info?.options.opacity {
            stickerAttachmentView.setOpacity(CGFloat(opacity))
        }
        if let extendDurationIcon = previousStickersExtendToFull ? UIImage.init(named: "extendToFullVideoIcon") : UIImage.init(named: "extendToClipIcon") {
            stickerAttachmentView.extendToFullProjectImageView.image = extendDurationIcon
        }
        stickerModel.animatedStickerConverter = animatedStickerConverter
        stickerModel.image = stickerAttachmentView.getContentViewImage()
        previewVC.view.addSubview(stickerAttachmentView)

        if let rotation = stickerModel.stickerRotation {
            stickerAttachmentView.setDegreesRotation(angleDegrees: rotation)
        }
        if let resource = stickerModel.videoAttachment?.stickerResource {
            stickerAttachmentView.stickerResource = resource
        }
        stickerModel.videoAttachment = stickerAttachmentView
        // Since we add all the attachments on project load, all attachments will appear at the start since we're
        // adding subviews. We need to show those at initial load which have start time of 0
        // when user seeks they would hide and appear at the appropriate time (start time)
        // hence to avoid seeing all attachments initially hide them after adding so when user seeks they would appear
        // at relevant place
        stickerAttachmentView.isHidden = true
    }


    /// Adds a duplicated sticker to preview and make its attachmentView and stickerModel selected.
    /// - Parameters:
    ///     - model: Duplicated sticker model
    ///     - stickerResourceEntity: Resource Entity of sticker being duplicated. As  duplicated sticker attachment needs
    ///      stickerResourceEntity to keep information about source of its content, it is passed to assign new duplicated
    ///      sticker attachment.
    func addDuplicateStickerWithModel(model: StickerModel?, stickerResourceEntity: ResourceEntity?, completion: @escaping (_ success: Bool) -> Void ) {
        // We always show first image in the duplicated sticker, so the model can have different sticker image
        // based on currentPlayTime change. So we first create hidden attachment view from model,
        // then update model image, then update & show the duplicated sticker attachment view.
        guard let model = model,
              let selectedStickerResource = stickerResourceEntity
        else {
            completion(false)
            return
        }

        // Create the hidden attachment view based on the model
        guard let stickerAttachmentView = createHiddenStickerAttachmentViewFromModel(
            model: model,
            stickerResourceEntity: selectedStickerResource
        ) else {
            print("Failed to create sticker attachment view from model")
            completion(false)
            return
        }

        // for animated sticker, we'll reset first image on the sticker attachment.
        if model.type == .animatedWebp {
            model.updateWithFirstStickerImage()
        }

        guard let image = model.image else {
            print("model doesn't have image, can't set image on duplicated attachment view")
            completion(false)
            return
        }

        // Important: Set image on stickerAttachmentView.contentView
        stickerAttachmentView.setContentViewImage(image)

        // Show duplicated sticker attachment view
        stickerAttachmentView.isHidden = false
        // Hide Content View of sticker attachment view
        stickerAttachmentView.isHideContentView(true)

        // These will keep model and attachment as editable
        self.selectedStickerModel = model
        self.selectedStickerAttachment = stickerAttachmentView
        // Adding duplicate sticker was successful
        completion(true)
    }

    /// It hides created attachment view, caller should set the image in created attachment view and can show by setting isHidden = false.
    func createHiddenStickerAttachmentViewFromModel(model: StickerModel, stickerResourceEntity: ResourceEntity) -> StickerVideoAttachment? {
        guard let stickerURL = model.stickerUrl else {
            print("model.stickerUrl is nil")
            return nil
        }

        // Get size from model
        let imageViewSize = model.stickerImageFrame?.size ?? StickerHelpers.defaultSizeForStickerAttachment
        let attachmentRotation = model.stickerRotation ?? 0.0

        guard let stickerAttachmentView = self.createNewStickerAttachmentView(localStickerURL: stickerURL,
                                                                              contentViewSize: imageViewSize,
                                                                              rotation: attachmentRotation)
        else {
            print("Failed to create stickerAttachmentView with url \(stickerURL)")
            return nil
        }

        // Although model has the image, but we don't set that image to created attachment view here.
        // Caller of this function would set the desired image.

        // Hide initially, caller should update appearance
        stickerAttachmentView.isHidden = true
        stickerAttachmentView.enableAllEditingGestures(areEnabled: true)
        stickerAttachmentView.enableCloseAndRotateButtons(areEnabled: false)
        stickerAttachmentView.modelID = model.id
        stickerAttachmentView.stickerResource = stickerResourceEntity

        stickerAttachmentView.setOpacity(CGFloat(model.info?.options.opacity ?? 1))
        stickerAttachmentView.setDegreesRotation(angleDegrees: Float(model.stickerImageRotation ?? 0))

        // Place the attachment view at correct position inside the previewVC
        guard let stickerPosition = model.stickerPosition else {
            print("model.stickerPosition is nil. Can't create hidden StickerAttachmentView")
            return nil
        }

        guard let previewVC = playerVM.mtkView?.attachmentsPreviewVC else {
            print("self.mtkView?.attachmentsPreviewVC?.view is nil. Can't create hidden StickerAttachmentView")
            return nil
        }
        stickerAttachmentView.center = stickerPosition.denormalizePoint(inFrame: previewVC.view.frame)
        stickerAttachmentView.delegate = self
        model.videoAttachment = stickerAttachmentView

        previewVC.view.addSubview(stickerAttachmentView)

        return stickerAttachmentView
    }



    /// Duplicates sticker operations for the specified sticker model.
    func duplicateStickerOperations(stickerStart: CMTime, stickerModel: StickerModel?) {
        guard let stickerModel = stickerModel else { return }
        stickerModel.videoOperation?.forEach({ operation in
            self.addStickerOperation(shaderName: operation.1.shaderFunctionName, timeRange: operation.1.effectiveTimeRange ?? CMTimeRange.zero, stickerStart: stickerStart, model: stickerModel) { newOperation in
                if let index = stickerModel.videoOperation?.firstIndex(where: {$0.0 == operation.0}) {
                    stickerModel.videoOperation?.remove(at: index)
                    stickerModel.videoOperation?.insert((operation.0, newOperation), at: index)
                }
            } onFailure: { error in
                print("Resource updater: adding sticker operation failed with error: \(error.localizedDescription)")
            }
        })
        playerVM.updateCurrentFrame() // Update the current frame after adding the sticker view
    }

    func updateStickerOperation(shaderName: String, timeRange: CMTimeRange, stickerOperationId: UUID) {
        playerVM.textureProvider?.texturePostProcessor.updateStickerOperation(
            shaderName: shaderName,
            timeRange: timeRange,
            stickerOperationId: stickerOperationId
        )
        playerVM.updateCurrentFrame()
    }

    func updateStickerAnimationData(animationData: AnimationData?, stickerStart: CMTime, operation: StickerVideoOperation) {
        playerVM.textureProvider?.texturePostProcessor.updateStickerAnimationData(videoOperation: operation, animationData: animationData, stickerStart: stickerStart)
    }

    func addDuplicateStickerOpeartion(timeRange: CMTimeRange, model: StickerModel?) {
        guard let model else {
            return
        }
        switch model.type {
        case .staticImage:
            guard let options = model.info,
                  let image = model.image else {
                return // @TODO: throw error to the user that sticker can't be loaded
            }

            guard let operation = (playerVM.textureProvider?.texturePostProcessor.addStaticSticker(
                image: image,
                at: timeRange,
                stickerOptions: options,
                animationData: model.stickerAnimation,
                stickerStart: timeRange.start
            )) else { return }
            model.videoOperation?.append((.none, operation))

        case .animatedWebp:
            guard
                let animatedStickerConverter = model.animatedStickerConverter,
                let options = model.info
            else {
                print("add duplicate sticker operation failed")
                return // @TODO: throw error to the user that sticker can't be loaded
            }

            guard let operation = playerVM.textureProvider?.texturePostProcessor.addAnimatedStickers(
                animatedStickerConverter: animatedStickerConverter,
                at: timeRange,
                stickerOptions: options,
                animationData: model.stickerAnimation,
                stickerStart: timeRange.start
            ) else { return }
            model.videoOperation?.append((.none, operation))
        }
    }

    /// Makes chosen sticker editable
    func beginEditingStickerAttachment(_ videoAttachmentView: StickerVideoAttachment) {
        playerVM.pause()
        if navigator.primaryTool == .text {
            playerVM.mainScreenVM?.updateCurrentTextAttachmentModel()
            playerVM.textElementSharedData?.selectedTextAttachment?.showEditingHandlers = false
            playerVM.resetTextElementsSharedData()
            // In Full editor, user will be shown subbars list
            // on selection of sticker in preview.
            if navigator.editorMode == .fullEditor {
                navigator.navigate(to: .stickers, secondaryTool: SecondaryTool.list.rawValue)
            } else if navigator.editorMode == .wizard {
                // In wizard stickers editing only replaces sticker
                navigator.navigate(to: .stickers, secondaryTool: SecondaryTool.replace.rawValue)
            }
        }

        // Check if user switched from current selected sticker attachment
        // to another sticker attachment
        if videoAttachmentView != self.selectedStickerAttachment {
            self.selectedStickerAttachment?.showEditingHandlers = false
            videoAttachmentView.showEditingHandlers = true
            self.selectedStickerAttachment = videoAttachmentView
            playerVM.stickerElementSharedData.selectedStickerEntity = videoAttachmentView.stickerResource

            if let modelID = selectedStickerAttachment?.modelID,
               let index = subBarResourcesManager.getIndexOf(type: .sticker, modelID: modelID) {
                subBarResourcesManager.selectResource(index: index)
            }
        }

        // If video editor is in wizard mode
        // show seek arrows when sticker attachment begins editing
        // TODO: After discussion with product team, we have found that we don't need seek buttons
        // Related code is being commented here, if this decision persists in upcoming releases
        // remove this code
//        if navigator.editorMode == .wizard {
//            mtkView?.attachmentsPreviewVC?.showSeekButtonsForSelectedEditingResource()
//        }
    }

    /// Checks if some sticker is already selected and then make chosen sticker editable
    func checkSelectionAndBeginEditingStickerAttachment(_ videoAttachmentView: StickerVideoAttachment) {
        playerVM.pause()
        guard self.selectedStickerAttachment != videoAttachmentView else { return }
        playerVM.mainScreenVM?.updateCurrentStickerModel()
        beginEditingStickerAttachment(videoAttachmentView)
    }

    func getStickerModelForStickerAttachment (videoAttachment: StickerVideoAttachment) -> StickerModel? {

        guard let stickerResource = subBarResourcesManager.getResourcesOf(type: .sticker).first(where: { $0.stickerModel?.id == videoAttachment.modelID }) else {
            print("Did not get sticker resource of given stickerAttachment")
            return nil
        }
        // Get model of given stickerAttachment
        if let stickerModel = stickerResource.stickerModel {
            return stickerModel
        } else {
            print("Did not get sticker model of given stickerAttachment")
            return nil
        }
    }


    // MARK: - StickerVideoAttachmentViewDelegate functions

    func stickerVideoAttachmentViewDidBeginMoving(_ videoAttachmentView: StickerVideoAttachment) {
        // Check if user is switching from one sticker to another.
        if (videoAttachmentView.modelID != selectedStickerModel?.getModelID()
            && selectedStickerModel != nil) {
            handleStickerAttachmentEditingForWizard(videoAttachmentView: videoAttachmentView)
        }

        checkSelectionAndBeginEditingStickerAttachment(videoAttachmentView)
    }

    func stickerVideoAttachmentViewDidChangePosition(_ videoAttachmentView: StickerVideoAttachment) {
    }

    func stickerVideoAttachmentViewDidEndMoving(_ videoAttachmentView: StickerVideoAttachment) {
        // Update sticker operations position
        guard let selectedStickerModel = selectedStickerModel else { return }
        let frame = playerVM.mtkView?.attachmentsPreviewVC?.view.frame
        if let frame {
            selectedStickerModel.stickerPosition = videoAttachmentView.center.normalizePoint(inFrame: frame)
        }
        // Mark sticker as being manually dragged false to allow uniform progress
        self.updateSticker(stickerModel: selectedStickerModel)
        updateModelInDbFrom(videoAttachmentView: videoAttachmentView)
    }

    /// Update model in realm after user changes the scale, rotation etc in full editor, as those can be changed without cross and tick buttons
    func updateModelInDbFrom(videoAttachmentView: StickerVideoAttachment) {
        // get index of current resource
        let currentResourceIndex = subBarResourcesManager.editingResources.firstIndex(where: {$0.stickerModel?.id == videoAttachmentView.modelID})
        // ensure we index is not nil, if it exists then we also know its added in subbars (valid resource)
        // this is a case of full editor as wizard is having cross and tick for actions such as movement, scale etc
        guard let index = currentResourceIndex,
              navigator.editorMode == .fullEditor else { return }
        // manullay update db to get updated values of the scale, rotation etc
        let currentEditableResource = subBarResourcesManager.editingResources[index]

        if let attachment = selectedStickerAttachment {
            playerVM.mainScreenVM?.updateStickerAndTextModelInDbFrom(resource: currentEditableResource,
                                                                                                attachment: videoAttachmentView,
                                                                     stickerModel: playerVM.mainScreenVM?.getUpdatedModelFromAttachment(attachment))
        }
    }

    func stickerVideoAttachmentViewDidBeginRotating(_ videoAttachmentView: StickerVideoAttachment) {
        checkSelectionAndBeginEditingStickerAttachment(videoAttachmentView)
    }

    func stickerVideoAttachmentViewDidChangeRotating(_ videoAttachmentView: StickerVideoAttachment) {
        selectedStickerModel?.stickerRotation = videoAttachmentView.rotation
        selectedStickerModel?.info?.options.rotation = videoAttachmentView.rotation
        // Mark sticker as being manually dragged true to avoid uniform progress
        self.updateSticker(stickerModel: selectedStickerModel, isManuallyDragged: true)
    }

    func stickerVideoAttachmentViewDidEndRotating(_ videoAttachmentView: StickerVideoAttachment) {
        selectedStickerModel?.stickerRotation = videoAttachmentView.rotation
        // Mark sticker as being manually dragged false to allow uniform progress
        self.updateSticker(stickerModel: selectedStickerModel)
        updateModelInDbFrom(videoAttachmentView: videoAttachmentView)
    }

    func stickerVideoAttachmentViewDidClose(_ videoAttachmentView: StickerVideoAttachment) {

    }

    func stickerVideoAttachmentViewDidChangeOpacity(_ videoAttachmentView: StickerVideoAttachment) {
        selectedStickerModel?.info?.options.opacity = videoAttachmentView.getOpacity()
        self.updateSticker(stickerModel: selectedStickerModel)
    }

    func stickerVideoAttachmentViewDidTap(_ videoAttachmentView: StickerVideoAttachment) {
        // Check if user is switching from one sticker to another.
        if (videoAttachmentView.modelID != selectedStickerModel?.getModelID() && selectedStickerModel != nil) {
            handleStickerAttachmentEditingForWizard(videoAttachmentView: videoAttachmentView)
        }

        beginEditingStickerAttachment(videoAttachmentView)
    }


    /// Check wizard mode and manages saving replacement changes, if sticker jumps from one to another.
    /// It also handles navigation, when user jumps from new sticker being added to already added sticker to
    /// replace it.
    func handleStickerAttachmentEditingForWizard(videoAttachmentView: StickerVideoAttachment) {

        // Check if program control is in wizard mode
        guard navigator.editorMode == .wizard else { return }

        // Replace sticker if not already replaced.
        // This scenario appears when user while replacing, jumps to another sticker.
        // In that case we assume approval of replacement and save changes.
        if navigator.secondaryTool == SecondaryTool.replace.rawValue {
                // If user changed the model and switched to another sticker
                // update the existing model
                playerVM.mainScreenVM?.confirmReplacingSticker()

                // Need to assign last sticker attachment and last sticker model
                // as if user is already on replace and switch stickers, on appear which
                // of StickersCard won't be called.
                // As life cycle of lastSelectedStickerAttachment, lastSelectedStickerModel is on
                // appear we need to assign them here as well.

            if let chosenStickerModel = getStickerModelForStickerAttachment(videoAttachment: videoAttachmentView) {
                lastSelectedStickerAttachment = videoAttachmentView.copy()
                lastSelectedStickerModel = chosenStickerModel.copy() as? StickerModel
            } else { return }
        }

        // This check handles case when user switch to already added sticker while
        // adding new sticker.
        if  navigator.secondaryTool == SecondaryTool.new.rawValue {
            // Update current sticker which is being added
            playerVM.mainScreenVM?.updateCurrentStickerModel()
            // Then navigate to replace
            navigator.navigate(to: .stickers, secondaryTool: SecondaryTool.replace.rawValue)
        }
    }

    func stickerVideoAttachmentViewScaledTo(_ videoAttachmentView: StickerVideoAttachment, scale: CGFloat, isFromStickerSettingCard: Bool) {
        playerVM.stickerElementSharedData.stickerScale = scale.roundedToTwoDecimalPlaces()
        if !isFromStickerSettingCard {
            // isFromStickerSettingCard represents if user is altering scale from stickerSettingCard where we have scale slider
            // if user is editing from there, we dont update db as there is a cross and tick button on which we'll update
            // also this prevents stutters in app due to constant to db from slider
            // similarly this function is also called on `.ended` of the scale gesture so prevent extra updates; resulting
            // in jitters in app. If its called from the gesture this param is false else it is true when called from card
            updateModelInDbFrom(videoAttachmentView: videoAttachmentView)
        }

        // Update sticker operations size
        guard let selectedStickerModel = selectedStickerModel else { return }
        selectedStickerModel.info?.options.size = videoAttachmentView.imageCurrentSize ?? videoAttachmentView.contentViewSize
        // Mark sticker as being manually dragged true to avoid uniform progress
        self.updateSticker(stickerModel: selectedStickerModel, isManuallyDragged: true)
    }

    func stickerVideoAttachmentViewDidEndScaled(_ videoAttachmentView: StickerVideoAttachment) {
        guard let selectedStickerModel = selectedStickerModel else { return }
        // Mark sticker as being manually dragged false to allow uniform progress
        self.updateSticker(stickerModel: selectedStickerModel)
    }

    func videoAttachmentViewDidChangePosition(position: CGPoint) {
    }

    func didReceivePinchGestureOnStickerVideoAttachment(_ videoAttachmentView: StickerVideoAttachment) {
        checkSelectionAndBeginEditingStickerAttachment(videoAttachmentView)
    }

    func stickerVideoAttachmentViewDidChangePosition(position: CGPoint) {
        // Update sticker operations position
        guard let selectedStickerModel = selectedStickerModel else { return }

        if let frame = playerVM.mtkView?.attachmentsPreviewVC?.view.frame {
            selectedStickerModel.info?.options.position = position.normalizePoint(inFrame: frame)
        }

        // Mark sticker as being manually dragged true to avoid uniform progress
        self.updateSticker(stickerModel: selectedStickerModel, isManuallyDragged: true)
    }
}
