//
//  DTRenderViewManager.swift
//  Signal
//
//  Created by Ethan on 2022/8/2.
//  Copyright © 2022 Difft. All rights reserved.
//

import UIKit
import TTServiceKit

@objcMembers
class DTRenderViewManager: NSObject {
    
    var renderViewMap: AtomicDictionary<String, DTRenderView>!
    
    static let shareManager = DTRenderViewManager()
    
    private override init() {
        super.init()
        renderViewMap = AtomicDictionary<String, DTRenderView>(lock: .init())
    }
    
    func insertRenderView(_ renderView: DTRenderView, account: String) {
//        guard renderViewMap[account] == nil else {
//            return
//        }
        renderViewMap[account] = renderView
    }
    
    func removeRenderView(for account: String) {
        guard let renderView = renderViewMap[account] else {
            return
        }
        if renderView.superview != nil {
            renderView.removeFromSuperview()
        }
        renderViewMap[account] = nil
    }
    
    func renderView(account: String) -> DTRenderView? {
        guard let renderView = renderViewMap[account] else {
            return nil
        }
        return renderView
    }
    
    func allRenderViews() -> [DTRenderView] {
        renderViewMap.allValues
    }
    
    func removeAllObjects() {
        renderViewMap.removeAllValues()
    }
    
}

@objcMembers
class DTRenderView: UIView {

    override init (frame: CGRect) {
        super.init(frame : frame)
        backgroundColor = .clear
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    class func renderView() -> DTRenderView {
        return DTRenderView()
    }
    
}
