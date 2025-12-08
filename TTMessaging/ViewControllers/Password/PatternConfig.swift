//
//  PatternConfig.swift
//  Difft
//
//  Created by henry on 2025/9/28.
//  Copyright © 2025 Difft. All rights reserved.
//

let normalColor: UIColor = Theme.isDarkThemeEnabled ? UIColor.color(rgbHex: 0xB7BDC6) : UIColor.color(rgbHex: 0x474D57)
let selectedColor: UIColor = Theme.isDarkThemeEnabled ? UIColor.color(rgbHex: 0xEAECEF) : UIColor.color(rgbHex: 0x1E2329)
let warnColor: UIColor = Theme.isDarkThemeEnabled ? UIColor.color(rgbHex: 0xD9271E) : UIColor.color(rgbHex: 0xF84135)
let lineColor: UIColor = UIColor.color(rgbHex: 0x848E9C)
let noLineColor: UIColor = UIColor.clear

struct PatternLockConfig: PatternLockViewConfig {
    var matrix: Matrix = Matrix(row: 3, column: 3)
    var gridSize: CGSize = CGSize(width: 50, height: 50)
    var connectLine: ConnectLine?
    var autoMediumGridsConnect: Bool = false
    var connectLineHierarchy: ConnectLineHierarchy = .bottom
    var errorDisplayDuration: TimeInterval = 1
    var initGridClosure: (Matrix) -> (PatternLockGrid)

    init() {
        initGridClosure = {(matrix) -> PatternLockGrid in
            let gridView = GridView()
            let outerFillColorStatus = GridPropertyStatus<UIColor>(connect: selectedColor, error: normalColor)
            gridView.outerRoundConfig = RoundConfig(radius: 8, fillColorStatus: outerFillColorStatus)
            let innerFillColorStatus = GridPropertyStatus<UIColor>(normal: normalColor)
            gridView.innerRoundConfig = RoundConfig(radius: 8, fillColorStatus: innerFillColorStatus)
            return gridView
        }
        let lineView = ConnectLineView()
        let pathEnable = ScreenLock.shared.isScreenLockPatternPathEnabled()
        let color = pathEnable ? lineColor : noLineColor
        lineView.lineColorStatus = .init(normal: color, error: color)
        lineView.lineWidth = 4
        connectLine = lineView
    }
}
