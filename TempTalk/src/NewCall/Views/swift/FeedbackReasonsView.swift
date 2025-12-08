import UIKit
import PureLayout

final class FeedbackReasonsView: UIView, UITableViewDelegate, UITableViewDataSource, UIScrollViewDelegate {

    private let titles = [
        Localized("CALL_RATING_REASON_TAB_AUDIO"),
        Localized("CALL_RATING_REASON_TAB_VIDEO"),
        Localized("CALL_RATING_REASON_TAB_OTHER")
    ]
    
    private var selectedIndex = 0
    private let tabStack = UIStackView()
    private let indicatorView = UIView()
    private let separatorView = UIView()
    private let scrollView = UIScrollView()
    private var tables: [UITableView] = []
    
    private var indicatorLeadingConstraint: NSLayoutConstraint?
    private var indicatorWidthConstraint: NSLayoutConstraint?
    private var didSetupIndicator = false
    
    // MARK: - 新增：选中变化回调
    var onSelectionChanged: ((_ hasSelection: Bool) -> Void)?

    private let reasons: [[String]] = [
        [Localized("CALL_RATING_REASON_AUDIO_0"),
         Localized("CALL_RATING_REASON_AUDIO_1"),
         Localized("CALL_RATING_REASON_AUDIO_2"),
         Localized("CALL_RATING_REASON_AUDIO_3"),
         Localized("CALL_RATING_REASON_AUDIO_4"),
         Localized("CALL_RATING_REASON_AUDIO_5"),
         Localized("CALL_RATING_REASON_AUDIO_6")],
        [Localized("CALL_RATING_REASON_VIDEO_0"),
         Localized("CALL_RATING_REASON_VIDEO_1"),
         Localized("CALL_RATING_REASON_VIDEO_2"),
         Localized("CALL_RATING_REASON_VIDEO_3"),
         Localized("CALL_RATING_REASON_VIDEO_4"),
         Localized("CALL_RATING_REASON_VIDEO_5")],
        [Localized("CALL_RATING_REASON_OTHER_0"),
         Localized("CALL_RATING_REASON_OTHER_1"),
         Localized("CALL_RATING_REASON_OTHER_2")]
    ]
    
    private var selectedStates: [[Bool]]
    
    override init(frame: CGRect) {
        selectedStates = reasons.map { Array(repeating: false, count: $0.count) }
        super.init(frame: frame)
        setupTabs()
        setupScrollView()
        setupPages()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Tabs
    private func setupTabs() {
        tabStack.axis = .horizontal
        tabStack.distribution = .fillEqually
        addSubview(tabStack)
        tabStack.autoPinEdge(toSuperviewEdge: .top)
        tabStack.autoPinEdge(toSuperviewEdge: .left)
        tabStack.autoPinEdge(toSuperviewEdge: .right)
        tabStack.autoSetDimension(.height, toSize: 44)

        for (index, title) in titles.enumerated() {
            let button = UIButton()
            button.setTitle(title, for: .normal)
            button.setTitleColor(UIColor.color(rgbHex: 0x848E9C), for: .normal)
            button.setTitleColor(Theme.isDarkThemeEnabled ? UIColor.color(rgbHex: 0xEAECEF) : UIColor.color(rgbHex: 0x1E2329), for: .selected)
            button.titleLabel?.font = UIFont.systemFont(ofSize: 16)
            button.tag = index
            button.addTarget(self, action: #selector(tabTapped(_:)), for: .touchUpInside)
            tabStack.addArrangedSubview(button)
        }
        
        separatorView.backgroundColor = Theme.isDarkThemeEnabled ? UIColor.color(rgbHex: 0x474D57) : UIColor.color(rgbHex: 0xEAECEF)
        addSubview(separatorView)
        separatorView.autoSetDimension(.height, toSize: 1)
        separatorView.autoSetDimension(.width, toSize: screenWidth)
        separatorView.autoPinEdge(.top, to: .bottom, of: tabStack, withOffset: 1)
        separatorView.autoPinEdge(toSuperviewEdge: .right, withInset: 0)
        separatorView.autoPinEdge(toSuperviewEdge: .left, withInset: 0)
        
        // Indicator
        indicatorView.backgroundColor = UIColor.color(rgbHex: 0x056FFA)
        addSubview(indicatorView)
        indicatorView.autoSetDimension(.height, toSize: 2)
        indicatorView.autoSetDimension(.width, toSize: screenWidth / 3)
        indicatorView.autoPinEdge(.top, to: .bottom, of: tabStack)
        // 先用临时约束
        indicatorWidthConstraint = indicatorView.autoSetDimension(.width, toSize: screenWidth / 3)
        indicatorLeadingConstraint = indicatorView.autoPinEdge(.left, to: .left, of: tabStack, withOffset: 0)

        // 默认选中第一个 tab
        updateTabSelection(for: 0)
    }

    // MARK: - ScrollView & Tables
    private func setupScrollView() {
        addSubview(scrollView)
        scrollView.delegate = self
        scrollView.isPagingEnabled = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.autoPinEdge(.top, to: .bottom, of: indicatorView)
        scrollView.autoPinEdgesToSuperviewEdges(with: .zero, excludingEdge: .top)
    }
    
    private func setupPages() {
        var previousPage: UIView? = nil
        for index in 0..<titles.count {
            let pageView = UIView()
            scrollView.addSubview(pageView)
            pageView.autoMatch(.width, to: .width, of: scrollView)
            pageView.autoMatch(.height, to: .height, of: scrollView)
            pageView.autoPinEdge(toSuperviewEdge: .top)
            if let prev = previousPage {
                pageView.autoPinEdge(.left, to: .right, of: prev)
            } else {
                pageView.autoPinEdge(toSuperviewEdge: .left)
            }
            previousPage = pageView

            let tableView = UITableView(frame: .zero, style: .plain)
            tableView.delegate = self
            tableView.dataSource = self
            tableView.tag = index
            tableView.tableFooterView = UIView()
            tableView.backgroundColor = Theme.isDarkThemeEnabled ? UIColor.color(rgbHex: 0x181A20) : UIColor.color(rgbHex: 0xFFFFFF)
            pageView.addSubview(tableView)
            tableView.isScrollEnabled = false
            tableView.separatorStyle = .none
            tableView.autoPinEdgesToSuperviewEdges()
            tableView.rowHeight = 40
            tables.append(tableView)
        }
        previousPage?.autoPinEdge(toSuperviewEdge: .right)
    }

    // MARK: - Indicator更新
    private func updateIndicator(for index: Int) {
        guard let button = tabStack.arrangedSubviews[index] as? UIButton else { return }
        let width = button.bounds.width
        let leading = (button.bounds.width - width) / 2
        indicatorWidthConstraint?.constant = width
        indicatorLeadingConstraint?.constant = button.frame.minX + leading
        UIView.animate(withDuration: 0.25) {
            self.layoutIfNeeded()
        }
    }

    // MARK: - Tab Tap
    @objc private func tabTapped(_ sender: UIButton) {
        selectedIndex = sender.tag
        updateTabSelection(for: sender.tag)
        let offset = CGPoint(x: CGFloat(sender.tag) * scrollView.bounds.width, y: 0)
        scrollView.setContentOffset(offset, animated: true)
        updateIndicator(for: sender.tag)
    }
    
    private func updateTabSelection(for index: Int) {
        for (i, view) in tabStack.arrangedSubviews.enumerated() {
            if let button = view as? UIButton {
                button.isSelected = (i == index)
            }
        }
    }

    // MARK: - ScrollViewDelegate
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        let page = Int(round(scrollView.contentOffset.x / scrollView.bounds.width))
        selectedIndex = page
        updateTabSelection(for: page)
        updateIndicator(for: page)
    }

    // MARK: - TableView
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return reasons[tableView.tag].count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cellId = "checkboxCell"
        let cell = tableView.dequeueReusableCell(withIdentifier: cellId) ?? UITableViewCell(style: .default, reuseIdentifier: cellId)
        cell.contentView.subviews.forEach { $0.removeFromSuperview() }
        cell.backgroundColor = Theme.isDarkThemeEnabled ? UIColor.color(rgbHex: 0x181A20) : UIColor.color(rgbHex: 0xFFFFFF)
        cell.contentView.backgroundColor = Theme.isDarkThemeEnabled ? UIColor.color(rgbHex: 0x181A20) : UIColor.color(rgbHex: 0xFFFFFF)

        let checkBox = UIButton(type: .custom)
        checkBox.isUserInteractionEnabled = false
        let isSelected = selectedStates[tableView.tag][indexPath.row]
        checkBox.setImage(UIImage(systemName: isSelected ? "checkmark.square.fill" : "square"), for: .normal)
        checkBox.tintColor = isSelected ? .systemBlue : .lightGray

        let label = UILabel()
        label.text = reasons[tableView.tag][indexPath.row]
        label.font = UIFont.systemFont(ofSize: 16)
        label.textColor = Theme.isDarkThemeEnabled ? UIColor.color(rgbHex: 0xEAECEF) : UIColor.color(rgbHex: 0x1E2329)

        cell.contentView.addSubview(checkBox)
        cell.contentView.addSubview(label)
        checkBox.autoSetDimensions(to: CGSize(width: 24, height: 24))
        checkBox.autoPinEdge(toSuperviewEdge: .left, withInset: 16)
        checkBox.autoAlignAxis(toSuperviewAxis: .horizontal)
        label.autoPinEdge(.left, to: .right, of: checkBox, withOffset: 12)
        label.autoPinEdge(toSuperviewEdge: .right, withInset: 16)
        label.autoAlignAxis(toSuperviewAxis: .horizontal)
        cell.selectionStyle = .none
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        selectedStates[tableView.tag][indexPath.row].toggle()
        tableView.reloadRows(at: [indexPath], with: .none)
        // 计算当前是否有至少一个选项被选中
        let hasAnySelected = selectedStates.flatMap { $0 }.contains(true)
        // 调用回调，通知外部更新按钮颜色
        onSelectionChanged?(hasAnySelected)
    }

    // MARK: - 提交接口
    public func submitSelectedItems() -> [Int: [Int]] {
        var result: [Int: [Int]] = [:]
        for (tabIndex, _) in titles.enumerated() {
            let selectedIndexes = selectedStates[tabIndex]
                .enumerated()
                .filter { $0.element } // 只保留被选中的
                .map { $0.offset }     // 转为对应索引
            result[tabIndex] = selectedIndexes
        }
        return result
    }
}
