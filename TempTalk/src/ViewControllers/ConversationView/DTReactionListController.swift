//
//  DTReactionListController.swift
//  Wea
//
//  Created by Ethan on 2022/5/24.
//  Copyright © 2022 Difft. All rights reserved.
//

import UIKit
import JXCategoryView

class DTReactionListController: OWSTableViewController {
    
    private var tableSources: [DTReactionSource]!
    
    var reactionSources: [DTReactionSource] {
        get {
            self.tableSources
        }
        set {
            tableSources = newValue
            updateTableContents()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.backgroundColor
    }
    
    override func applyTheme() {
        super.applyTheme()
        
        updateTableContents()
    }
    
    func updateTableContents() {
        
        let contents = OWSTableContents()
        let section = OWSTableSection()
        
        for reactionSource in reactionSources {
            let item = OWSTableItem(customCellBlock: {
                let cell = ContactTableViewCell()
                cell.cellView.type = .realAvater
                cell.configure(withRecipientId: reactionSource.source, contactsManager: Environment.shared.contactsManager)
                return cell
            }, customRowHeight: 70) { [weak self] in
                guard let _ = self else {
                    return
                }
                
                DTPersonalCardController.preConfigure(withRecipientId: reactionSource.source) { [weak self] signalAccount in
                    guard let self else { return }
                    
                    let personalCardVC = DTPersonalCardController(type: .other, 
                                                                  recipientId: reactionSource.source,
                                                                  account: signalAccount)
                    
                    self.navigationController?.modalPresentationStyle = .fullScreen
                    self.navigationController?.pushViewController(personalCardVC, animated: true)
                }
            }
            
            section.add(item)
        }
        contents.addSection(section)

        self.contents = contents
    }
    
    override func userTakeScreenshotEvent(_ notify: Notification) {
        
    }
}

extension DTReactionListController: JXCategoryListContentViewDelegate {
    
    func listView() -> UIView! {
        self.view
    }
    
    func listWillAppear() {
        applyTheme()
    }
    
}
