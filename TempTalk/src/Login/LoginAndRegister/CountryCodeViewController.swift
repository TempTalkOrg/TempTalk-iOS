//
//  Copyright (c) 2021 Open Whisper Systems. All rights reserved.
//

import Foundation
import TTMessaging
import SignalCoreKit

@objc
public protocol CountryCodeViewControllerDelegate: AnyObject {
    func countryCodeViewController(_ vc: CountryCodeViewController,
                                   didSelectCountry: RegistrationCountryState)
}

// MARK: -

@objc
public class CountryCodeViewController: OWSTableViewController {
    @objc
    public weak var countryCodeDelegate: CountryCodeViewControllerDelegate?

    @objc
    public var interfaceOrientationMask: UIInterfaceOrientationMask = UIDevice.current.defaultSupportedOrientations

    public override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        interfaceOrientationMask
    }

    private let searchBar = OWSSearchBar()
    @objc
    open var topHeader = UIStackView()
    // MARK: -

    public override func loadView() {
        super.loadView()
        self.creatNav()
        self.navigationController?.isNavigationBarHidden = false;
    }
    
    func creatNav() {
        let backButton = UIButton();
        backButton.addTarget(self, action: #selector(backButtonPressed), for: .touchUpInside)
        backButton.setImage(UIImage(named: "nav_back_arrow_new"), for: .normal)
        let item = UIBarButtonItem.init(customView: backButton)
        self.navigationItem.leftBarButtonItem = item;
    }
    
    override public func viewDidLoad() {
        super.viewDidLoad()
        searchBar.delegate = self
        searchBar.placeholder = OWSLocalizedString("SEARCH_BYNAMEORNUMBER_PLACEHOLDER_TEXT", comment: "")
        searchBar.sizeToFit()

        topHeader.axis = .vertical
        topHeader.alignment = .fill
        topHeader.addArrangedSubview(searchBar)
        view.addSubview(topHeader)
        
        topHeader.autoPinEdge(toSuperviewSafeArea: ALEdge.top)
        topHeader.autoPinEdge(toSuperviewSafeArea: .leading)
        topHeader.autoPinEdge(toSuperviewSafeArea: .trailing)
        
        topHeader.autoSetDimension(ALDimension.height, toSize: 44)
        topHeader.setContentHuggingVerticalHigh()
        topHeader.setCompressionResistanceVerticalHigh()
        
        tableView.deactivateAllConstraints()
        tableView.autoPinEdge(.top, to: .bottom, of: topHeader)
        tableView.autoPinEdge(.left, to: .left, of: view)
        tableView.autoPinEdge(.right, to: .right, of: view)
        tableView.autoPinEdge(.bottom, to: .bottom, of: view)
        
        self.delegate = self
        self.title = OWSLocalizedString("COUNTRYCODE_SELECT_TITLE", comment: "")

//        self.navigationItem.leftBarButtonItem = UIBarButtonItem(
//            barButtonSystemItem: .stop,
//
//            target: self,
//            action: #selector(didPressCancel),
//            accessibilityIdentifier: "cancel")

        createViews()
    }
    
    @objc
    func backButtonPressed(sender: UIButton) {
        self.navigationController?.popViewController(animated: true)
    }
    private func createViews() {
        AssertIsOnMainThread()

        updateTableContents()
    }

    private func updateTableContents() {
        AssertIsOnMainThread()
        var countryStates = [RegistrationCountryState]()
        if let searchText = searchBar.text?.stripped, searchText.count > 0{
            countryStates = RegistrationCountryState.buildCountryStates(searchText: searchText)
        } else {
            countryStates = RegistrationCountryState.sortCountryStates(searchText: searchBar.text)
        }

        let contents = OWSTableContents()
        let section = OWSTableSection()
        for countryState in countryStates {
            let accessibilityIdentifier = "country.\(countryState.countryCode)"
            section.add(OWSTableItem.item(name: countryState.countryName,
                                          accessoryText: countryState.callingCode,
                                          accessibilityIdentifier: accessibilityIdentifier) { [weak self] in
                self?.countryWasSelected(countryState: countryState)
            })
        }
        contents.addSection(section)

        self.contents = contents
    }

    private func countryWasSelected(countryState: RegistrationCountryState) {
        AssertIsOnMainThread()
        countryCodeDelegate?.countryCodeViewController(self, didSelectCountry: countryState)
        searchBar.resignFirstResponder()
        self.navigationController?.popViewController(animated: true)
    }

    @objc
    private func didPressCancel() {
        
    }
}

// MARK: -

extension CountryCodeViewController: UISearchBarDelegate {

    public func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        AssertIsOnMainThread()

        searchTextDidChange()
    }

    public func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        AssertIsOnMainThread()

        searchTextDidChange()
    }

    public func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        AssertIsOnMainThread()

        searchTextDidChange()
    }

    public func searchBarResultsListButtonClicked(_ searchBar: UISearchBar) {
        AssertIsOnMainThread()

        searchTextDidChange()
    }

    public func searchBar(_ searchBar: UISearchBar, selectedScopeButtonIndexDidChange selectedScope: Int) {
        AssertIsOnMainThread()

        searchTextDidChange()
    }

    private func searchTextDidChange() {
        updateTableContents()
    }
}

// MARK: -

extension CountryCodeViewController: OWSTableViewControllerDelegate {

    public func tableViewWillBeginDragging() {
        searchBar.resignFirstResponder()
    }
}
