//
//  DTPhotoBrowserHelper.swift
//  Signal
//
//  Created by gfly on 2021/9/5.
//

import Foundation
import Photos
import ZLPhotoBrowser
import TTMessaging

@objcMembers
public class DTPhotoBrowserHelper: NSObject {
    
    public typealias SelectedImageBlock = ([PHAsset], Bool) -> Void
    
    weak var viewController: UIViewController?
    var selectImageBlock: SelectedImageBlock?
    
    @objc public init(viewController: UIViewController, 
                      maxSelectCount: Int,
                      onlySelectImage: Bool = false,
                      selectImageBlock: @escaping SelectedImageBlock) {
        self.viewController = viewController
        self.selectImageBlock = selectImageBlock
        
        let config = ZLPhotoConfiguration.default()
        config.maxSelectCount = maxSelectCount
        config.allowTakePhotoInLibrary = false
        config.allowSelectOriginal = true
        if onlySelectImage {
            config.allowEditImage = false
            config.allowSelectImage = true
            config.allowSelectGif = false
        } else {
            config.allowMixSelect = true
            config.allowEditVideo = true
            config.maxEditVideoTime = 120
        }
        config.canSelectAsset = { asset -> Bool in
            true
        }

        let uiConfig = ZLPhotoUIConfiguration.default()
        uiConfig.indexLabelBgColor = .ows_themeBlue
        uiConfig.bottomToolViewBtnNormalBgColor = .ows_themeBlue;
        uiConfig.sheetBtnBgColor = .ows_themeBlue
        uiConfig.bottomToolViewBtnNormalBgColorOfPreviewVC = .ows_themeBlue
        uiConfig.selectedBorderColor = .ows_themeBlue
        
        super.init()
    }
    
    deinit {
        Logger.info("dealloc")
    }
    
    public func showLibrary() {
        
        guard let vc = viewController else {
            OWSLogger.error("no viewcontroller avaliable")
            return
        }
        
        let previewSheet = ZLPhotoPreviewSheet(selectedAssets: [])
        previewSheet.selectImageBlock = { [weak self] resultModels, isFullImage in
            
            guard let strongSelf = self else {
                return
            }
            guard let finiskBlock = strongSelf.selectImageBlock else {
                owsFailDebug("selectImageBlock was unexpectedly nil")
                return
            }
            let assets = resultModels.map { $0.asset }
            finiskBlock(assets, isFullImage)
        }
        previewSheet.cancelBlock = {
            Logger.debug("cancel select")
        }
        previewSheet.selectImageRequestErrorBlock = { (errorAssets, errorIndexs) in
            OWSLogger.debug("fetch error assets: \(errorAssets), error indexs: \(errorIndexs)")
        }
        OWSWindowManager.shared().setIsPhotoLibraryAuth(true)
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.2) {
            OWSWindowManager.shared().setIsPhotoLibraryAuth(false)
        }
        previewSheet.showPhotoLibrary(sender: vc)
    }
}
