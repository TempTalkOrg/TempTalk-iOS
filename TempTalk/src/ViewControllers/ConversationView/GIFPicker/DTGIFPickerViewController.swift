//
//  DTGIFPickerViewController.swift
//  TempTalk
//
//  Inline GIF panel: icon tab bar (search / favorites / trending / happy / sad)
//  + waterfall grid. Data source in +Search, favorites hosting in +Favorites.
//

import Foundation
import UIKit
import SnapKit
import TTServiceKit
import TTMessaging

protocol DTGIFPickerViewControllerDelegate: AnyObject {
    func gifPickerViewController(
        _ viewController: DTGIFPickerViewController,
        didSelect attachment: SignalAttachment
    )
    func gifPickerViewControllerDidSelectCancel(_ viewController: DTGIFPickerViewController)
    /// Keyboard-hosted picker asks the host to present search modally (an
    /// inputView panel can't host the system keyboard needed for typing).
    func gifPickerViewControllerDidRequestSearch(_ viewController: DTGIFPickerViewController)
    /// Close the panel immediately on tap (WeChat-style); the send then runs in
    /// the background and the conversation bubble shows sending/sent.
    func gifPickerViewControllerRequestDismiss(_ viewController: DTGIFPickerViewController)
}

class DTGIFPickerViewController: OWSViewController {

    // Content tabs. Search is a mode (see isSearching), not a tab.
    enum Tab {
        case favorites, trending, happy, sad
    }

    enum ViewMode {
        case idle, searching, results, noResults, error
    }

    weak var delegate: DTGIFPickerViewControllerDelegate?

    /// True when hosted inside DTGifKeyboard; tapping search hands off to a modal.
    var isHostedInKeyboard = false
    /// Start directly in search mode (used by the modal search presentation).
    var startInSearch = false
    /// Host to present sheets from when embedded in a keyboard (picker isn't in
    /// the VC hierarchy then); falls back to self when presented modally.
    weak var presentationHost: UIViewController?
    var presenter: UIViewController { presentationHost ?? self }

    var currentTab: Tab = .trending {
        didSet {
            guard oldValue != currentTab else { return }
            updateTabSelection()
            switchTab()
        }
    }

    // Search mode swaps the tab bar row for a search field + close button.
    var isSearching = false {
        didSet {
            guard oldValue != isSearching else { return }
            updateTopRow()
        }
    }

    var lastQuery: String?
    var nextPage: DTGIFSearchOperation.Page? = .first

    var viewMode = ViewMode.idle {
        didSet { updateContents() }
    }

    var isShowLoading = false {
        didSet {
            guard oldValue != isShowLoading else { return }
            if isShowLoading {
                collectionView.isHidden = true
                activityIndicator.startAnimating()
            } else {
                activityIndicator.stopAnimating()
            }
        }
    }

    // Refreshed explicitly by callers (reloadResults for a replace, appendResults for paging) —
    // no didSet reload, so appending a page doesn't rebuild every visible cell (whole-grid flash).
    var searchResults = [DTGIFSearchAssetInfo]()

    /// Query driving the waterfall: typed text while searching, fixed keyword
    /// for the mood tabs, nil for trending.
    var activeQuery: String? {
        if isSearching {
            let query = searchField.text?.trimmingCharacters(in: .whitespacesAndNewlines)
            return (query?.isEmpty ?? true) ? nil : query
        }
        switch currentTab {
        case .happy: return "happy"
        case .sad: return "sad"
        default: return nil
        }
    }

    lazy var operationQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        return queue
    }()

    // MARK: - Lifecycle

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        createViews()
        if startInSearch {
            isSearching = true
        }
        updateTabSelection()
        loadData()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if startInSearch {
            searchField.becomeFirstResponder()
        }
    }

    override func applyTheme() {
        super.applyTheme()
        view.backgroundColor = Theme.bg1Color
        collectionView.backgroundColor = Theme.bg1Color
        tabBar.backgroundColor = Theme.bg1Color
        searchRow.backgroundColor = Theme.bg1Color
        searchFieldContainer.backgroundColor = Theme.bg2Color
        searchField.textColor = Theme.tprimaryColor
        searchField.attributedPlaceholder = NSAttributedString(
            string: Localized("GIF_SEARCH_PLACEHOLDER"),
            attributes: [.foregroundColor: Theme.tdisableColor, .font: UIFont.systemFont(ofSize: 14)])
        tabButtons.forEach { $0.tintColor = Theme.iconColor }
        searchIconView.tintColor = Theme.tdisableColor
        closeSearchButton.tintColor = Theme.iconColor
        searchErrorLabel.textColor = Theme.tprimaryColor
        noResultsLabel.textColor = Theme.tprimaryColor
        attributionLabel.textColor = Theme.tsecondaryColor
        favoritesView.applyTheme()
        updateTabSelection()
    }

    // MARK: - Views

    private func createViews() {
        // In a keyboard panel the view IS the inputView; its safe-area guide is
        // unreliable, so anchor to the real edges. Modal search uses the guide.
        let topAnchor = isHostedInKeyboard ? view.snp.top : view.safeAreaLayoutGuide.snp.top
        let bottomAnchor = isHostedInKeyboard ? view.snp.bottom : view.safeAreaLayoutGuide.snp.bottom

        view.addSubview(tabBar)
        tabBar.snp.makeConstraints { make in
            make.top.equalTo(topAnchor)
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(56)
        }

        view.addSubview(searchRow)
        searchRow.snp.makeConstraints { make in
            make.edges.equalTo(tabBar)
        }

        view.addSubview(collectionView)
        collectionView.snp.makeConstraints { make in
            make.top.equalTo(tabBar.snp.bottom)
            make.leading.trailing.equalToSuperview()
        }

        view.addSubview(attributionLabel)
        attributionLabel.snp.makeConstraints { make in
            make.top.equalTo(collectionView.snp.bottom)
            make.centerX.equalToSuperview()
            make.bottom.equalTo(bottomAnchor).offset(-8)
            make.height.equalTo(20)
        }

        view.addSubview(noResultsLabel)
        noResultsLabel.snp.makeConstraints { make in
            make.center.equalTo(collectionView)
            make.leading.trailing.equalTo(collectionView).inset(24)
        }

        view.addSubview(searchErrorLabel)
        searchErrorLabel.snp.makeConstraints { make in
            make.center.equalTo(collectionView)
            make.leading.trailing.equalTo(collectionView).inset(24)
        }

        view.addSubview(favoritesView)
        favoritesView.snp.makeConstraints { make in
            make.top.equalTo(tabBar.snp.bottom)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(bottomAnchor).offset(-8)
        }

        view.addSubview(activityIndicator)
        activityIndicator.snp.makeConstraints { make in
            make.center.equalTo(collectionView)
        }

        applyTheme()
        updateContents()
    }

    private func updateContents() {
        let showFavorites = (currentTab == .favorites) && !isSearching
        favoritesView.isHidden = !showFavorites
        attributionLabel.isHidden = showFavorites
        if showFavorites {
            collectionView.isHidden = true
            noResultsLabel.isHidden = true
            searchErrorLabel.isHidden = true
            return
        }
        switch viewMode {
        case .idle, .searching, .results:
            collectionView.isHidden = false
            noResultsLabel.isHidden = true
            searchErrorLabel.isHidden = true
        case .noResults:
            collectionView.isHidden = true
            noResultsLabel.isHidden = false
            searchErrorLabel.isHidden = true
        case .error:
            collectionView.isHidden = true
            noResultsLabel.isHidden = true
            searchErrorLabel.isHidden = false
        }
    }

    private func updateTopRow() {
        tabBar.isHidden = isSearching
        searchRow.isHidden = !isSearching
        updateContents()
    }

    private func updateTabSelection() {
        favoritesTabButton.backgroundColor = currentTab == .favorites ? Theme.bg3Color : .clear
        trendingTabButton.backgroundColor = currentTab == .trending ? Theme.bg3Color : .clear
        happyTabButton.backgroundColor = currentTab == .happy ? Theme.bg3Color : .clear
        sadTabButton.backgroundColor = currentTab == .sad ? Theme.bg3Color : .clear
    }

    private func switchTab() {
        switch currentTab {
        case .favorites:
            operationQueue.cancelAllOperations()
            favoritesView.reload()   // refresh each time so favorites added elsewhere show up
            updateContents()
        case .trending, .happy, .sad:
            updateContents()
            loadData()
        }
    }

    // MARK: - Event Handlers

    @objc
    private func searchTabTapped() {
        if isHostedInKeyboard {
            // Can't type inside a keyboard panel; hand search off to a modal.
            delegate?.gifPickerViewControllerDidRequestSearch(self)
            return
        }
        isSearching = true
        searchField.becomeFirstResponder()
        loadData()
    }

    @objc
    func exitSearch() {
        searchField.text = nil
        searchField.resignFirstResponder()
        // Search is presented modally (from the keyboard panel); ✕ closes it.
        if presentingViewController != nil {
            delegate?.gifPickerViewControllerDidSelectCancel(self)
            return
        }
        isSearching = false
        // Fall back to trending; force a reload when already on trending.
        if currentTab == .trending {
            loadData()
        } else {
            currentTab = .trending
        }
    }

    @objc private func favoritesTabTapped() { currentTab = .favorites }
    @objc private func trendingTabTapped() { currentTab = .trending }
    @objc private func happyTabTapped() { currentTab = .happy }
    @objc private func sadTabTapped() { currentTab = .sad }

    @objc
    func retryTapped(sender: UIGestureRecognizer) {
        guard sender.state == .recognized, viewMode == .error else { return }
        loadData()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        layout.invalidateLayout()
    }

    // MARK: - Tab bar

    private lazy var searchTabButton = makeIconTab(imageName: "gif_tab_search", action: #selector(searchTabTapped))
    private lazy var favoritesTabButton = makeIconTab(imageName: "gif_tab_star", action: #selector(favoritesTabTapped))
    private lazy var trendingTabButton = makeIconTab(imageName: "gif_tab_trending", action: #selector(trendingTabTapped))
    private lazy var happyTabButton = makeIconTab(imageName: "gif_tab_happy", action: #selector(happyTabTapped))
    private lazy var sadTabButton = makeIconTab(imageName: "gif_tab_sad", action: #selector(sadTabTapped))

    private var tabButtons: [UIButton] {
        [searchTabButton, favoritesTabButton, trendingTabButton, happyTabButton, sadTabButton]
    }

    private lazy var tabBar: UIView = {
        let container = UIView()
        let stack = UIStackView(arrangedSubviews: tabButtons)
        stack.axis = .horizontal
        stack.spacing = 10
        stack.alignment = .center
        container.addSubview(stack)
        stack.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
        return container
    }()

    private func makeIconTab(imageName: String, action: Selector) -> UIButton {
        let button = UIButton(type: .custom)
        button.setImage(UIImage(named: imageName)?.withRenderingMode(.alwaysTemplate), for: .normal)
        button.layer.cornerRadius = 8
        button.layer.masksToBounds = true
        button.addTarget(self, action: action, for: .touchUpInside)
        button.snp.makeConstraints { make in make.size.equalTo(38) }
        return button
    }

    // MARK: - Search row

    private lazy var searchIconView: UIImageView = {
        let imageView = UIImageView(image: UIImage(named: "gif_tab_search")?.withRenderingMode(.alwaysTemplate))
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    lazy var searchField: UITextField = {
        let textField = UITextField()
        textField.font = .systemFont(ofSize: 14)
        textField.returnKeyType = .search
        textField.clearButtonMode = .whileEditing
        textField.delegate = self
        textField.addTarget(self, action: #selector(searchTextChanged), for: .editingChanged)
        return textField
    }()

    private lazy var searchFieldContainer: UIView = {
        let container = UIView()
        container.layer.cornerRadius = 8
        container.layer.masksToBounds = true
        container.addSubview(searchIconView)
        searchIconView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.centerY.equalToSuperview()
            make.size.equalTo(16)
        }
        container.addSubview(searchField)
        searchField.snp.makeConstraints { make in
            make.leading.equalTo(searchIconView.snp.trailing).offset(9)
            make.trailing.equalToSuperview().offset(-16)
            make.centerY.equalToSuperview()
        }
        return container
    }()

    private lazy var closeSearchButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setImage(UIImage(named: "gif_search_close")?.withRenderingMode(.alwaysTemplate), for: .normal)
        button.addTarget(self, action: #selector(exitSearch), for: .touchUpInside)
        return button
    }()

    private lazy var searchRow: UIView = {
        let container = UIView()
        container.isHidden = true
        container.addSubview(searchFieldContainer)
        container.addSubview(closeSearchButton)
        closeSearchButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-16)
            make.centerY.equalToSuperview()
            make.size.equalTo(24)
        }
        searchFieldContainer.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.centerY.equalToSuperview()
            make.height.equalTo(40)
            make.trailing.equalTo(closeSearchButton.snp.leading).offset(-24)
        }
        return container
    }()

    // MARK: - Content views

    private lazy var layout: DTGIFPickerCollectionViewLayout = {
        let layout = DTGIFPickerCollectionViewLayout()
        layout.dataSource = self
        return layout
    }()

    lazy var collectionView: UICollectionView = {
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.contentInsetAdjustmentBehavior = .never
        collectionView.alwaysBounceVertical = true
        collectionView.showsVerticalScrollIndicator = false
        collectionView.register(
            DTGIFPickerCell.self,
            forCellWithReuseIdentifier: DTGIFPickerCell.reuseIdentifier)
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handlePanelLongPress))
        collectionView.addGestureRecognizer(longPress)
        return collectionView
    }()

    lazy var favoritesView: DTGIFFavoritesView = {
        let view = DTGIFFavoritesView()
        view.delegate = self
        view.isHidden = true
        return view
    }()

    private lazy var noResultsLabel = makeCenteredLabel(text: Localized("GIF_SEARCH_NO_RESULTS"))

    private lazy var searchErrorLabel: UILabel = {
        let label = makeCenteredLabel(text: Localized("GIF_SEARCH_ERROR"))
        label.isUserInteractionEnabled = true
        label.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(retryTapped)))
        return label
    }()

    private func makeCenteredLabel(text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .semiboldFont(ofSize: 16)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        return label
    }

    private lazy var activityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.hidesWhenStopped = true
        return indicator
    }()

    // GIPHY ToS requires visible attribution.
    private lazy var attributionLabel: UILabel = {
        let label = UILabel()
        label.text = "Powered by GIPHY"
        label.font = .systemFont(ofSize: 11)
        label.textAlignment = .center
        return label
    }()
}

