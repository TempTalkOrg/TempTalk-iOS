//
//  DTSearchStateView.swift
//  Wea
//
//  Created by hornet on 2022/5/3.
//  Copyright © 2022 Difft. All rights reserved.
//

import UIKit

class DTSearchStateView : UIView {
    
    private var searchState :DTSearchViewState?
    private lazy var tipLabel :UILabel = {
        tipLabel = UILabel()
        tipLabel.font = UIFont.systemFont(ofSize: 18)
        tipLabel.textColor = Theme.primaryTextColor
        return tipLabel
    }()
    
    private override init (frame: CGRect) {
        super.init(frame : frame)
    }
    
    private convenience init () {
        self.init(frame:CGRect.zero)
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    convenience init(searchState : DTSearchViewState){
        self.init()
        self.searchState = searchState
        switch searchState {
        case .defaultState:
            initDefaultContent()
        case .noResults:
            initNoResultsContent()
        }
    }
    
    public func resetSearchState(searchState : DTSearchViewState) {
        self.searchState = searchState;
        switch searchState {
        case .defaultState:
            self.tipLabel.text = Localized("ENTER_KEYWORDS_TO_SEARCH", comment: "enter your keywords")
        case .noResults:
            self.tipLabel.text = Localized("ENTER_KEYWORDS_TO_SEARCH", comment: "enter your keywords")
        }
    }
    
    func addSubviewContents() {
        addSubview(tipLabel)
    }
    
    func layoutSubviewContents() {
        tipLabel.autoSetDimension(.height, toSize: 16)
        tipLabel.autoVCenterInSuperview()
        tipLabel.autoHCenterInSuperview()
    }
    
    func initDefaultContent(){
        self.tipLabel.text = Localized("ENTER_KEYWORDS_TO_SEARCH", comment: "enter your keywords")
    }
    
    func initNoResultsContent(){
        self.tipLabel.text = Localized("HOME_VIEW_SEARCH_NO_RESULTS_FORMAT", comment: "search no result")
    }
    
}
