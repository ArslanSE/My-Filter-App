//
//  StickersManager.swift
//  myzesty
//
//  Created by Arslan Saleem on 28/03/2025.
//  Copyright © 2025 MyZesty, inc. All rights reserved.
//

import Foundation

// This class orchestrates and absatracts stickers related operations
class StickersManager: PremiumBannerViewModelProtocol {

    let playerVM: PlayerViewModel
    let navigator: MainScreenNavigator
    let subBarResourcesManager: SubBarResourcesManager
    let stickersSharedData: StickersSharedData
    let stickerOperationsManager: StickerVideoOperationsManager
    lazy var stickersEditor: StickersEditor = {
        return StickersEditor(playerVM: playerVM,
                              subbarResourcesManager: subBarResourcesManager,
                              navigator: navigator,
                              stickersManager: self)
    }()

    init(playerVM: PlayerViewModel, navigator: MainScreenNavigator, subBarsManager: SubBarResourcesManager, sharedData: StickersSharedData) {
        self.playerVM = playerVM
        self.navigator = navigator
        self.subBarResourcesManager = subBarsManager
        self.stickersSharedData = sharedData
        self.stickerOperationsManager = StickerVideoOperationsManager(playerVM: playerVM, sharedData: sharedData)
    }

    func addSticker(localStickerURL: String, stickerResourceEntity: ResourceEntity) {
        guard let previewVC = self.playerVM.mtkView?.attachmentsPreviewVC
        else { return }
        // 1. Check if sticker is premium and show the premium banner
        if stickerResourceEntity.premium == true && PremiumFlowManager.shared.shouldShowBanner() {
            self.showPremiumBanner(with: &PremiumFlowManager.shared.shouldShowBannerOnStickersForVideoEditor)
        }

        // 2. Remove existing attachment from preview
        stickersSharedData.selectedStickerAttachment?.removeFromSuperview()
        // 3. Remove the existing sticker video operation

        if let stickerModel = stickersSharedData.selectedStickerModel {
            removeStickerOperation(stickerModel: stickerModel)
        }

        // 4. Also REMOVE EDITING RESOURCE corresponding to sticker attachment being removed.
        if let modelId = stickersSharedData.selectedStickerAttachment?.modelID {
            subBarResourcesManager.deleteResource(type: .sticker,
                                                  id: modelId)
        }

        // 5. GET PROPERTIES OF ATTACHMENT
        // In following line, view.centre is not used as view.centre represents
        // centre of view in its parents coordinate system whereas
        // view.frame.centre(A calculated property in extension of view) represents
        // centre of view in its own coordinate system. We need centre of PREVIEW
        // within its own coordinates.
        let centerOfPreview = previewVC.view.frame.center
        let sizeOfReplacedSticker = stickersSharedData.selectedStickerAttachment?.contentViewSize
        let rotationOfReplacedSticker = stickersSharedData.selectedStickerAttachment?.rotation
        let centreOfReplacedSticker = stickersSharedData.selectedStickerAttachment?.center ?? centerOfPreview

        // Save current stickers extend to full to be used when updating model
        let previousStickersExtendToFull = stickersSharedData.selectedStickerModel?.extendToFull ?? false


        // 6. Create attachment view using stickerURL,size and rotation of selected sticker or default values.
        guard let stickerAttachmentView = createNewStickerAttachmentView(localStickerURL: localStickerURL,
                                                                         contentViewSize: sizeOfReplacedSticker ?? StickerHelpers.defaultSizeForStickerAttachment,
                                                                         rotation: rotationOfReplacedSticker ?? 0.0)
        else {
            print("Failed to create sticker attachment view")
            return
        }

        // 7. Create Image object of type SDAnimatedImage
        guard let sdImage = StickerHelpers.createImage(localStickerURL: localStickerURL) else {
            print("Failed to create SDAnimatedImage with url '\(localStickerURL)' in addSticker().")
            return
        }

        // 8. Set image property of sticker attachmentview. If it is an animated image, create converter, set a first image, and later store converter in the model for further uses.
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
            // Static image
            stickerAttachmentView.setContentViewImage(sdImage)
        }

        // Other settings for attachment view
        stickerAttachmentView.isHideContentView(true)
        stickerAttachmentView.showEditingHandlers = true
        stickerAttachmentView.delegate = stickersEditor
        stickerAttachmentView.center = centreOfReplacedSticker
        stickerAttachmentView.extendToFullProjectImageView.image = previousStickersExtendToFull ? UIImage.init(named: "extendToFullVideoIcon")! : UIImage.init(named: "extendToClipIcon")!

        // 9. Add sticker attachment to preview and get NEW model object after adding it.
        let newStickerModel = playerVM.mtkView?.attachmentsPreviewVC?.addStickerAttachment(stickerAttachment:stickerAttachmentView,
                                                                                           stickerURL: localStickerURL )
        // Important: set converter in the sticker model
        newStickerModel?.animatedStickerConverter = animatedStickerConverter
        newStickerModel?.isPremium = stickerResourceEntity.premium

        /*
         Update new sticker model's extendToFull with the previous sticker's extendToFull. This is done for the case
         if user is adding sticker for the first time, and then selected extendToFull then selected another sticker
         this would have created a new model with extendToFull being default False. Hence we read previous
         stickers extendToFull state and apply that to the new sticker
         */
        newStickerModel?.extendToFull = previousStickersExtendToFull
        stickerAttachmentView.stickerResource = stickerResourceEntity

        // 10. Assign newly created sticker attachment and sticker model to selected properties of playerVM.
        stickersSharedData.selectedStickerModel = newStickerModel
        stickersSharedData.selectedStickerAttachment = stickerAttachmentView
        // reference of the newly added sticker
        stickersSharedData.newlyAddedStickerAttachment = stickerAttachmentView
        // Get time range and add editing resource corresponding to new sticker and model
        let computedTimeRange = playerVM.getTimeRangeForOperation(startTime: playerVM.currentPlayTime,
                                                                  duration: Constants.defaultImageDuration)

        // If resource is already added for model, don't add it again.
        if subBarResourcesManager
            .getResourcesOf(type: .sticker)
            .first(where: { $0.stickerModel?.getModelID() == stickersSharedData.selectedStickerModel?.getModelID() }) != nil
        { return }

        // 11. Add sticker resource if not already added. We need to add sticker resource while adding sticker on preview
        // as we need it for seeking to start and end of sticker.
        _ = subBarResourcesManager.addResource(type: .sticker,
                                               startTime: playerVM.currentPlayTime,
                                               duration: computedTimeRange.duration,
                                               stickerModel: stickersSharedData.selectedStickerModel)

        // 12. Add sticker operation in video operations
        stickerOperationsManager.addUpdateStickerOperation(timeRange: computedTimeRange,
                                                           stickerStart: computedTimeRange.start,
                                                           stickerModel: stickersSharedData.selectedStickerModel)
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
        stickersSharedData.selectedStickerAttachment?.removeFromSuperview()
        // 2. Remove the existing sticker video operation
        removeStickerOperation(stickerModel: stickersSharedData.selectedStickerModel)

        // 3. GET PROPERTIES OF ATTACHMENT
        // In following line, not using view.centre as view.centre represents
        // centre of view in its parents coordinate system whereas
        // view.frame.centre(A calculated property in extension of view) represents
        // centre of view in its own coordinate system. We need centre of PREVIEW
        // within its own coordinates.
        let centerOfPreview = previewVC.view.frame.center
        let sizeOfReplacedSticker = stickersSharedData.selectedStickerAttachment?.contentViewSize
        let rotationOfReplacedSticker = stickersSharedData.selectedStickerAttachment?.rotation
        let centreOfReplacedSticker = stickersSharedData.selectedStickerAttachment?.center ?? centerOfPreview

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

        stickerAttachmentView.delegate = stickersEditor
        stickerAttachmentView.center = centreOfReplacedSticker
        stickerAttachmentView.isHideContentView(true)

        // 7. Add sticker attachment to preview and get NEW model object after adding it.
        let newStickerModel = playerVM.mtkView?.attachmentsPreviewVC?.addStickerAttachment(stickerAttachment:stickerAttachmentView,
                                                                            stickerURL: localStickerURL )
        // Important: set converter in the sticker model
        newStickerModel?.animatedStickerConverter = animatedStickerConverter
        newStickerModel?.isPremium = stickerResourceEntity.premium

        /*
         Update new sticker model's extendToFull with the previous sticker's extendToFull. This is done for the case
         if user is adding sticker for the first time, and then selected extendToFull then selected another sticker
         this would have created a new model with extendToFull being default False. Hence we read previous
         stickers extendToFull state and apply that to the new sticker
         */
        // Save current stickers extend to full to be used when updating model
        let previousStickersExtendToFull = stickersSharedData.selectedStickerModel?.extendToFull ?? false
        newStickerModel?.extendToFull = previousStickersExtendToFull
        stickerAttachmentView.extendToFullProjectImageView.image = previousStickersExtendToFull ? UIImage.init(named: "extendToFullVideoIcon")! : UIImage.init(named: "extendToClipIcon")!

        // When sticker is replaced with new sticker on wizard screen
        // keep model id of sticker same
        newStickerModel?.setModelID(id: stickersSharedData.selectedStickerModel?.getModelID() ?? UUID())
        stickerAttachmentView.modelID = stickersSharedData.selectedStickerModel?.getModelID() ?? UUID()
        stickerAttachmentView.stickerResource = stickerResourceEntity
        newStickerModel?.isPremium = stickerResourceEntity.premium

        var startTime: CMTime = .zero
        var duration: CMTime = .zero

        // 8. Update selected sticker resource
        let stickerResourcess = subBarResourcesManager.getResourcesOf(type: .sticker)
        if let oldModelID = stickersSharedData.selectedStickerModel?.getModelID(),
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
        stickersSharedData.selectedStickerModel = newStickerModel
        stickersSharedData.selectedStickerAttachment = stickerAttachmentView

        // 10. Add sticker operation in video operations
        stickerOperationsManager.addUpdateStickerOperation(timeRange: CMTimeRange(start: startTime, duration: duration), stickerStart: startTime, stickerModel: stickersSharedData.selectedStickerModel)
    }


    // Wrapper function
    func updateStickerVideoOperation(stickerModel: StickerModel, isManuallyDragged: Bool = false) {
        stickerOperationsManager.updateOperationWithModel(stickerModel: stickerModel, isManuallyDragged: isManuallyDragged)
    }

    // Wrapper function
    func removeStickerOperation(stickerModel: StickerModel?) {
        guard let selectedModel = stickerModel else {
            print("StickersManager: removeStickerOperation: selectedModel is nil")
            return
        }
        stickerOperationsManager.removeOperationWithModel(stickerModel: selectedModel)
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
        stickerAttachmentView.delegate = stickersEditor
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
        stickersSharedData.selectedStickerModel = model
        stickersSharedData.selectedStickerAttachment = stickerAttachmentView
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

        stickerAttachmentView.delegate = stickersEditor
        model.videoAttachment = stickerAttachmentView

        previewVC.view.addSubview(stickerAttachmentView)

        return stickerAttachmentView
    }
}
