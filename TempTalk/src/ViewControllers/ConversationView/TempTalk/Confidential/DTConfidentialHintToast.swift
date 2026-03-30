//
//  DTConfidentialHintToast.swift
//  TempTalk
//
//  Created by henry on 2026/03/12.
//  Copyright © 2026 Difft. All rights reserved.
//

import UIKit
import TTMessaging

final class DTConfidentialHintToast: UIView {

    private let iconImageView = UIImageView()
    private let label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupView() {
        backgroundColor = Theme.bgtooltipColor.withAlphaComponent(0.7)
        layer.cornerRadius = 20
        layer.masksToBounds = true

        iconImageView.image = UIImage(named: "confident_tips")
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.tintColor = .white
        addSubview(iconImageView)

        label.text = Localized("CONFIDENTIAL_MESSAGE_VIEW_ALERT_MESSAGE")
        label.textColor = .white
        label.font = UIFont.systemFont(ofSize: 14)
        label.numberOfLines = 1
        addSubview(label)

        iconImageView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(18)
        }

        label.snp.makeConstraints { make in
            make.leading.equalTo(iconImageView.snp.trailing).offset(6)
            make.trailing.equalToSuperview().offset(-16)
            make.centerY.equalToSuperview()
        }

        snp.makeConstraints { make in
            make.height.equalTo(40)
        }
    }

    // MARK: - Public
    func show(in parentView: UIView) {
        guard superview == nil else { return }
        parentView.addSubview(self)
        snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottom.equalToSuperview().offset(-90)
        }
    }
}
