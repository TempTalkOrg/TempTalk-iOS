//
// Copyright 2019 Signal Messenger, LLC
// SPDX-License-Identifier: AGPL-3.0-only
//

import Photos
import TTServiceKit

protocol AttachmentKeyboardDelegate: AnyObject {
    func didTapPhotos()
    func didTapCamera()
    func didTapVoiceCall()
    func didTapVideoCall()
    func didTapContact()
    func didTapFile()
    func didTapConfidentialMode()
    func didTapMention()
    var isGroup: Bool { get }
}

class AttachmentKeyboard: CustomKeyboard {

    weak var delegate: AttachmentKeyboardDelegate?
    var inputToolbarState: InputToolbarState {
        didSet {
            guard oldValue != inputToolbarState else { return }
            moreAttachmentCollectionView.updateDataSource(inputToolbarState: inputToolbarState)
        }
    }
    
    var relationship: InputToolbarRelationship
    
    var threadType: InputToolbarThreadType

    private lazy var moreAttachmentCollectionView: AttachmentCollectionView = {
        let collectionView = AttachmentCollectionView(inputToolbarState: inputToolbarState, relationship: relationship, threadType: threadType)
        collectionView.moreAttachmentDelegate = self
        return collectionView
    }()

    // MARK: -

    init(inputToolbarState: InputToolbarState,
         relationship: InputToolbarRelationship,
         threadType: InputToolbarThreadType,
         delegate: AttachmentKeyboardDelegate?) {
        self.delegate = delegate
        self.inputToolbarState = inputToolbarState
        self.relationship = relationship
        self.threadType = threadType
        
        super.init()

        backgroundColor = Theme.backgroundColor

        let stackView = UIStackView(arrangedSubviews: [ moreAttachmentCollectionView ])
        stackView.axis = .vertical
        contentView.addSubview(stackView)
        stackView.autoPinWidthToSuperview()
        stackView.autoPinEdge(toSuperviewEdge: .top)
        stackView.autoPinEdge(toSuperviewEdge: .bottom)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: state
    
    
    // MARK: -

    override func willPresent() {
        super.willPresent()
//        checkPermissions()
        moreAttachmentCollectionView.prepareForPresentation()
    }

    override func wasPresented() {
        super.wasPresented()
        moreAttachmentCollectionView.performPresentationAnimation()
    }

//    private func checkPermissions() {
//        let authorizationStatus: PHAuthorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
//        guard authorizationStatus != .notDetermined else {
//            let handler: (PHAuthorizationStatus) -> Void = { status in
//                self.moreAttachmentCollectionView.mediaLibraryAuthorizationStatus = status
//            }
//            PHPhotoLibrary.requestAuthorization(for: .readWrite, handler: handler)
//            return
//        }
//        moreAttachmentCollectionView.mediaLibraryAuthorizationStatus = authorizationStatus
//    }
}

extension AttachmentKeyboard: MoreAttachmentDelegate {
    
    func didSelectAttachment(itemView: UICollectionViewCell?, attachment: DTInputToolBarMoreItem) {
        switch attachment.itemType {
        case DTToolBarMoreItemTypePhoto:
            delegate?.didTapPhotos()
        case DTToolBarMoreItemTypeCamera:
            delegate?.didTapCamera()
        case DTToolBarMoreItemTypeVoiceCall:
            delegate?.didTapVoiceCall()
        case DTToolBarMoreItemTypeVideoCall:
            delegate?.didTapVideoCall()
        case DTToolBarMoreItemTypeContact:
            delegate?.didTapContact()
        case DTToolBarMoreItemTypeFile:
            delegate?.didTapFile()
        case DTToolBarMoreItemTypeConfide:
            delegate?.didTapConfidentialMode()
        case DTToolBarMoreItemTypeMention:
            delegate?.didTapMention()
        default:
            break
        }
    }
}

//extension AttachmentKeyboard: AttachmentFormatPickerDelegate {
//    func didTapPhotos() {
//        delegate?.didTapPhotos()
//    }
//
//    func didTapGif() {
//        delegate?.didTapGif()
//    }
//
//    func didTapFile() {
//        delegate?.didTapFile()
//    }
//
//    func didTapContact() {
//        delegate?.didTapContact()
//    }
//}
