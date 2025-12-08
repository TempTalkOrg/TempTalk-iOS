//
//  PatternConfig.swift
//  Difft
//
//  Created by henry on 2025/9/28.
//  Copyright © 2025 Difft. All rights reserved.
//

let normalColor: UIColor = UIColor.color(rgbHex: 0x848E9C)
let selectedColor: UIColor = Theme.isDarkThemeEnabled ? UIColor.color(rgbHex: 0xFFFFFF) : UIColor.color(rgbHex: 0x1E2329)
let warnColor: UIColor = Theme.isDarkThemeEnabled ? UIColor.color(rgbHex: 0xD9271E) : UIColor.color(rgbHex: 0xF84135)
let outerColor: UIColor = Theme.isDarkThemeEnabled ? UIColor.color(rgbHex: 0x474D57) : UIColor.color(rgbHex: 0xEAECEF)
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
            let outerFillColorStatus = GridPropertyStatus<UIColor>(connect: outerColor)
            gridView.outerRoundConfig = RoundConfig(radius: 16, fillColorStatus: outerFillColorStatus)
            let innerFillColorStatus = GridPropertyStatus<UIColor>(normal: normalColor, connect: selectedColor, error: selectedColor, enable: outerColor)
            gridView.innerRoundConfig = RoundConfig(radius: 8, fillColorStatus: innerFillColorStatus)
            return gridView
        }
        let lineView = ConnectLineView()
        let pathEnable = ScreenLock.shared.isScreenLockPatternPathEnabled()
        let color = pathEnable ? lineColor : noLineColor
        lineView.lineColorStatus = .init(normal: color, error: color)
        lineView.lineWidth = 6
        connectLine = lineView
    }
}
