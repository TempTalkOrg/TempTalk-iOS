//
//  LoginPolicyWebController.swift
//  Difft
//
//  Created by Henry on 2025/7/9.
//  Copyright © 2025 Difft. All rights reserved.
//

import WebKit

class LoginPolicyWebController: OWSViewController {
    var urlString: String

    init(urlString: String) {
        self.urlString = urlString
        super.init()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white

        let webView = WKWebView(frame: .zero)
        webView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(webView)

        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.topAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])

        if let url = URL(string: urlString) {
            webView.load(URLRequest(url: url))
        }
        
        applyTheme()
    }
    
    override func applyTheme() {
        view.backgroundColor = Theme.backgroundColor
    }
}
