//
//  MediaDetailViewController.swift
//  TempTalk
//
//  Created by Kris.s on 2025/4/24.
//  Copyright © 2025 Difft. All rights reserved.
//

import Foundation

//AppLink
extension MediaDetailViewController  {
    @objc
    func handleInternalLink(url: URL) {
        _ = AppLinkManager.handle(url: url, fromExternal: false, sourceVC: self)
    }
}
