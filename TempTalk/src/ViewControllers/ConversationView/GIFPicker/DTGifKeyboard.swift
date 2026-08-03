//
//  DTGifKeyboard.swift
//  TempTalk
//
//  Hosts DTGIFPickerViewController as a keyboard-height panel so the input
//  toolbar stays visible above it (Figma 16808). Only the picker's view is
//  embedded — it is NOT added as a child VC, because a CustomKeyboard is
//  presented inside UIKit's own input view controller and setting a different
//  parent triggers UIViewControllerHierarchyInconsistency. The picker presents
//  its own sheets through `presentationHost` (the conversation VC) instead.
//

import UIKit
import TTServiceKit
import TTMessaging

class DTGifKeyboard: CustomKeyboard {

    private let picker: DTGIFPickerViewController

    init(picker: DTGIFPickerViewController, host: UIViewController?) {
        self.picker = picker
        super.init()

        backgroundColor = Theme.bg1Color
        picker.presentationHost = host

        contentView.addSubview(picker.view)
        picker.view.autoPinEdgesToSuperviewEdges()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
