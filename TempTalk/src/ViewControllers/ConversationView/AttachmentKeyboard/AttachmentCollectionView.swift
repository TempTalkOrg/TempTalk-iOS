//
// Copyright 2019 Signal Messenger, LLC
// SPDX-License-Identifier: AGPL-3.0-only
//

import TTServiceKit

protocol MoreAttachmentDelegate: AnyObject {
    func didSelectAttachment(itemView: UICollectionViewCell?, attachment: DTInputToolBarMoreItem)
}

class AttachmentCollectionView: UICollectionView {

    static let itemSpacing: CGFloat = 13

    weak var moreAttachmentDelegate: MoreAttachmentDelegate?

    private lazy var collectionContents: [DTInputToolBarMoreItem] = [DTInputToolBarMoreItem]()

    // Cell Sizing

    private static let initialCellSize: CGSize = CGSizeMake(72, 88)

    private var cellSize: CGSize = initialCellSize {
        didSet {
            guard oldValue != cellSize else { return }

            Logger.debug("[Keyboard] \(cellSize)")
            
            // Replacing the collection view layout is the only reliable way
            // to change cell size when `collectionView(_:layout:sizeForItemAt:)` is implemented.
            // That delegate method is necessary to allow custom size for "manage access" helper UI.
            setCollectionViewLayout(AttachmentCollectionView.collectionViewLayout(itemSize: cellSize), animated: false)
            reloadData() // Needed in order to reload photos with better quality on size change.
        }
    }

    private var lastKnownHeight: CGFloat = 0

    override var bounds: CGRect {
        didSet {
            let height = frame.height
            guard height != lastKnownHeight, height > 0 else { return }

            lastKnownHeight = height
            recalculateCellSize()
        }
    }
    
    fileprivate let defaultHOuterMargin: CGFloat = 11.0
    fileprivate var itemWidth: CGFloat {
        (UIScreen.main.bounds.width - defaultHOuterMargin*2) / 4;
    }

    private func recalculateCellSize() {
        guard lastKnownHeight > 0 else { return }

//        if lastKnownHeight > 250 {
//            cellSize = CGSize(square: 0.5 * (lastKnownHeight - RecentPhotosCollectionView.itemSpacing))
//        // Otherwise, assume the recent photos take up the full height of the collection view.
//        } else {
//            cellSize = CGSize(square: lastKnownHeight)
//        }
        
        let itemHeight = 113.0 // 128
        cellSize = CGSize(width: itemWidth, height: itemHeight)
    }

    private static func collectionViewLayout(itemSize: CGSize) -> UICollectionViewFlowLayout {
        let layout = DTInputToolbarFlowLayout()
        layout.itemSize = itemSize
        return layout
    }
    
    init(inputToolbarState: InputToolbarState, relationship: InputToolbarRelationship, threadType: InputToolbarThreadType) {
        let layout = AttachmentCollectionView.collectionViewLayout(itemSize: AttachmentCollectionView.initialCellSize)
        super.init(frame: .zero, collectionViewLayout: layout)

        dataSource = self
        delegate = self

        backgroundColor = Theme.defaultBackgroundColor
        showsHorizontalScrollIndicator = false
        isPagingEnabled = true
        bounces = false
        let horizontalInset = defaultHOuterMargin
        contentInset = UIEdgeInsets(top: horizontalInset, leading: horizontalInset, bottom: 0, trailing: -horizontalInset)
        register(RecentPhotoCell.self, forCellWithReuseIdentifier: RecentPhotoCell.reuseIdentifier)
        
        configDataSource(inputToolbarState: inputToolbarState, relationship: relationship, threadType: threadType)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func updateDataSource(inputToolbarState: InputToolbarState) {
        if let index = collectionContents.firstIndex(where: { DTToolBarMoreItemTypeConfide == $0.itemType }) {
            let confidImageName = InputToolbarState.confidential == inputToolbarState ? "input_attachment_confide_select" : "input_attachment_confide"
            let confide = DTInputToolBarMoreItem(title: OWSLocalizedString("INPUTTOOL_ATTACHMENT_CONFIDENTIAL_BUTTON",
                                                                           comment: "Input bar action button title when open confidential mode"),
                                                 imageName:confidImageName,
                                                 itemType: DTToolBarMoreItemTypeConfide)
            collectionContents[index] = confide
            reloadData()
        }
    }
    
    private func configDataSource(inputToolbarState: InputToolbarState,
                                  relationship: InputToolbarRelationship,
                                  threadType: InputToolbarThreadType) {
        
        let photo = DTInputToolBarMoreItem(title: OWSLocalizedString("INPUTTOOL_ATTACHMENT_PHOTO_BUTTON",
                                                                     comment: "Input bar action button title when choosing Photos"),
                                           imageName:"input_attachment_picture",
                                           itemType: DTToolBarMoreItemTypePhoto)
        let camera = DTInputToolBarMoreItem(title: OWSLocalizedString("INPUTTOOL_ATTACHMENT_CAMERA_BUTTON",
                                                                      comment: "Input bar action button title when open Camera"),
                                            imageName:"input_attachment_camera",
                                            itemType: DTToolBarMoreItemTypeCamera)
        let contact = DTInputToolBarMoreItem(title: OWSLocalizedString("INPUTTOOL_ATTACHMENT_CONTACT_BUTTON",
                                                                       comment: "Input bar action button title when start Vidio Call"),
                                             imageName:"input_attachment_contact",
                                             itemType: DTToolBarMoreItemTypeContact)
        let file = DTInputToolBarMoreItem(title: OWSLocalizedString("INPUTTOOL_ATTACHMENT_FILE_BUTTON",
                                                                    comment: "Input bar action button title when open file"),
                                          imageName:"input_attachment_file",
                                          itemType: DTToolBarMoreItemTypeFile)
        
        let at = DTInputToolBarMoreItem(title: OWSLocalizedString("INPUTTOOL_ATTACHMENT_MENTION",
                                                                  comment: "Input bar action button title when start mention"),
                                        imageName:"input_attachment_at",
                                        itemType: DTToolBarMoreItemTypeMention)
                    
        
        if threadType == .group {
            collectionContents.append(contentsOf: [
                photo,
                camera,
                contact,
                file,
                at
            ])
        } else {
            collectionContents.append(contentsOf: [
                photo,
                camera,
                contact,
                file
            ])
        }

    }

    // Presentation Animations

    func prepareForPresentation() {
        UIView.performWithoutAnimation {
            self.alpha = 0
        }
    }

    func performPresentationAnimation() {
        UIView.animate(withDuration: 0.2) {
            self.alpha = 1
        }
    }
}

// MARK: - UICollectionViewDelegate

extension AttachmentCollectionView: UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {

        guard indexPath.row < collectionContents.count else {
            owsFailDebug("Item at index path \(indexPath) does not exist.")
            return
        }

        let item = collectionContents[indexPath.row]
        self.moreAttachmentDelegate?.didSelectAttachment(itemView: nil, attachment: item)

    }

//    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
//        Logger.debug("[keyboard] 1 \(cellSize)")
//        return cellSize
//    }
}

// MARK: - UICollectionViewDataSource

extension AttachmentCollectionView: UICollectionViewDataSource {

    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection sectionIdx: Int) -> Int {

        let cellCount = collectionContents.count

        return cellCount
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {

        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: RecentPhotoCell.reuseIdentifier, for: indexPath) as? RecentPhotoCell else {
            Logger.error("cell was unexpectedly nil")
            
            return UICollectionViewCell()
        }

        let item = collectionContents[indexPath.row]
        cell.configure(item: item)
        
        return cell
    }
}

private class RecentPhotoCell: UICollectionViewCell {

    static let reuseIdentifier = "RecentPhotoCell"

    private let imageContainer =  {
        let view = UIView()
        view.backgroundColor = Theme.defaultTableCellBackgroundColor
        view.layer.cornerRadius = 8
        view.layer.masksToBounds = true
        
        return view
    }()
    private let imageView = UIImageView()
    private let titleLabel = {
        let name = UILabel()
        name.font = .systemFont(ofSize: 12)
        name.numberOfLines = 2
        name.textAlignment = .center
        
        return name
    }()

    private var item: DTInputToolBarMoreItem?

    override init(frame: CGRect) {

        super.init(frame: frame)

        clipsToBounds = true
        
        contentView.addSubview(imageContainer)
        imageContainer.autoSetDimensions(to: CGSize(square: 64))
        imageContainer.autoPinTopToSuperviewMargin()
        imageContainer.autoHCenterInSuperview()
        
        imageView.contentMode = .scaleAspectFill
        imageContainer.addSubview(imageView)
        imageView.autoSetDimensions(to: CGSize(square: 32))
        imageView.autoCenterInSuperview()

        contentView.addSubview(titleLabel)
        titleLabel.autoPinEdge(.top, to: .bottom, of: imageContainer, withOffset: 8)
        titleLabel.autoPinWidthToSuperview()
    }

    @available(*, unavailable, message: "Unimplemented")
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

//    override var frame: CGRect {
//        didSet {
//            updateCornerRadius()
//        }
//    }
//
//    override var bounds: CGRect {
//        didSet {
//            updateCornerRadius()
//        }
//    }
//
//    private func updateCornerRadius() {
//        let cellSize = min(bounds.width, bounds.height)
//        guard cellSize > 0 else { return }
//        layer.cornerRadius = (cellSize * 13 / 84).rounded()
//    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
    }

    private var image: UIImage? {
        get { return imageView.image }
        set {
            imageView.image = newValue
            imageView.backgroundColor = newValue == nil ? Theme.washColor : .clear
        }
    }

    func configure(item: DTInputToolBarMoreItem) {
        self.item = item

        imageView.image = UIImage(named: item.imageName)
        titleLabel.text = item.title
    }

    override func prepareForReuse() {
        super.prepareForReuse()

        item = nil
        imageView.image = nil
        titleLabel.text = nil
    }

}
