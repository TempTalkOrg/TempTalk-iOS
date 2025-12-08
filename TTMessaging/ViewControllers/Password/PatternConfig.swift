//
//  PatternConfig.swift
//  Difft
//
//  Created by henry on 2025/9/28.
//  Copyright © 2025 Difft. All rights reserved.
//

struct PatternLockPalette {
    let dotNormalColor: UIColor
    let dotSelectedColor: UIColor
    let warningColor: UIColor
    let outerRingColor: UIColor
    let lineColor: UIColor
    let hiddenLineColor: UIColor = .clear

    init(isDarkThemeEnabled: Bool = Theme.isDarkThemeEnabled) {
        dotNormalColor = UIColor.color(rgbHex: 0x848E9C)
        dotSelectedColor = isDarkThemeEnabled ? UIColor.color(rgbHex: 0xFFFFFF) : UIColor.color(rgbHex: 0x1E2329)
        warningColor = isDarkThemeEnabled ? UIColor.color(rgbHex: 0xD9271E) : UIColor.color(rgbHex: 0xF84135)
        outerRingColor = isDarkThemeEnabled ? UIColor.color(rgbHex: 0x474D57) : UIColor.color(rgbHex: 0xEAECEF)
        lineColor = UIColor.color(rgbHex: 0x848E9C)
    }

    static func current() -> PatternLockPalette {
        PatternLockPalette(isDarkThemeEnabled: Theme.isDarkThemeEnabled)
    }

    func configure(gridView: GridView) {
        let outerFillColorStatus = GridPropertyStatus<UIColor>(connect: outerRingColor)
        gridView.outerRoundConfig = RoundConfig(radius: 16, fillColorStatus: outerFillColorStatus)

        let innerFillColorStatus = GridPropertyStatus<UIColor>(
            normal: dotNormalColor,
            connect: dotSelectedColor,
            error: dotSelectedColor,
            enable: outerRingColor
        )
        gridView.innerRoundConfig = RoundConfig(radius: 8, fillColorStatus: innerFillColorStatus)
    }

    func configure(lineView: ConnectLineView, pathEnabled: Bool) {
        let color = pathEnabled ? lineColor : hiddenLineColor
        lineView.lineColorStatus = .init(normal: color, error: color)
        lineView.lineWidth = 6
    }
}

struct PatternLockConfig: PatternLockViewConfig {
    var matrix: Matrix = Matrix(row: 3, column: 3)
    var gridSize: CGSize = CGSize(width: 50, height: 50)
    var connectLine: ConnectLine?
    var autoMediumGridsConnect: Bool = false
    var connectLineHierarchy: ConnectLineHierarchy = .bottom
    var errorDisplayDuration: TimeInterval = 1
    var initGridClosure: (Matrix) -> (PatternLockGrid)

    private let palette: PatternLockPalette

    init(palette: PatternLockPalette = .current()) {
        self.palette = palette
        initGridClosure = { [palette] matrix -> PatternLockGrid in
            let gridView = GridView()
            palette.configure(gridView: gridView)
            return gridView
        }
        let lineView = ConnectLineView()
        let pathEnable = ScreenLock.shared.isScreenLockPatternPathEnabled()
        palette.configure(lineView: lineView, pathEnabled: pathEnable)
        connectLine = lineView
    }
}
