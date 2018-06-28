//
//  ArtworkSelectorViewItem.swift
//  Subler
//
//  Created by Damiano Galassi on 13/06/2018.
//

import Cocoa

class ArtworkSelectorViewItemLabel : NSTextField {

    @IBInspectable var highlightColor: NSColor = .alternateSelectedControlColor
    @IBInspectable var highlightTextColor: NSColor = .alternateSelectedControlTextColor
    @IBInspectable var cornerRadius: CGFloat = 3

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addObservers()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        addObservers()
    }

    deinit {
        removeObservers()
    }

    private func addObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(windowDidBecomeKey), name: NSWindow.didBecomeKeyNotification, object: window)
        NotificationCenter.default.addObserver(self, selector: #selector(windowDidBecomeKey), name: NSWindow.didResignKeyNotification, object: window)
    }

    private func removeObservers() {
        NotificationCenter.default.removeObserver(self, name: NSWindow.didBecomeKeyNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: NSWindow.didResignKeyNotification, object: nil)
    }

    @objc func windowDidBecomeKey() {
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        let windowIsKeyWindow = window?.isKeyWindow ?? false

        var attributedString = attributedStringValue

        if isHighlighted && windowIsKeyWindow == true {
            let mutableAttributedString = attributedString.mutableCopy() as! NSMutableAttributedString
            let range = NSRange(location: 0, length: mutableAttributedString.length)
            mutableAttributedString.removeAttribute(NSAttributedString.Key.foregroundColor, range: range)
            mutableAttributedString.addAttributes([NSAttributedString.Key.foregroundColor : highlightTextColor], range: range)
            attributedString = mutableAttributedString
        }

        let framesetter = CTFramesetterCreateWithAttributedString(attributedString)

        let path = CGMutablePath()
        path.addRect(CGRect(x: 0, y: 0, width: bounds.size.width, height: bounds.size.height))

        let totalFrame = CTFramesetterCreateFrame(framesetter, CFRange(), path, nil)

        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.saveGState()
        context.textMatrix = .identity
        context.translateBy(x: 0, y: bounds.size.height)
        context.scaleBy(x: 1, y: -1)

        // Highlight the text specified
        let lines = CTFrameGetLines(totalFrame) as! [CTLine]
        let lineCount = lines.count

        var origins = [CGPoint](repeating: CGPoint.zero, count: lineCount)
        CTFrameGetLineOrigins(totalFrame, CFRange(), &origins)

        for index in 0 ..< lineCount {
            let line = lines[index]
            let glyphRuns = CTLineGetGlyphRuns(line) as! [CTRun]

            let origin = origins[index]
            context.textPosition = origin

            for i in 0 ..< glyphRuns.count {
                let run = glyphRuns[i]
                // let attributes = CTRunGetAttributes(run)
                // if CFDictionaryGetValue(attributes, "HighlightText") {
                if isHighlighted {
                    var runBounds = CGRect.zero
                    var ascent: CGFloat = 0, descent: CGFloat = 0, leading: CGFloat = 0

                    runBounds.size.width = CGFloat(CTRunGetTypographicBounds(run, CFRange(), &ascent, &descent, &leading))
                    runBounds.size.height = ascent + descent

                    runBounds.origin.x = CTLineGetOffsetForStringIndex(line, CTRunGetStringRange(run).location, nil) + origin.x
                    runBounds.origin.y = origin.y - descent

                    let highlightCGColor = highlightColor.cgColor
                    let roundeRect = runBounds.insetBy(dx: -4, dy: 0)
                    let roundedPath = NSBezierPath(roundedRect: roundeRect.integral, xRadius: cornerRadius, yRadius: cornerRadius)

                    context.setFillColor(windowIsKeyWindow ? highlightCGColor : NSColor.gridColor.cgColor)
                    roundedPath.fill()
                }
                CTRunDraw(run, context, CFRange())
            }
        }
        // CTFrameDraw(totalFrame, context)
        context.restoreGState()
    }
}

class ArtworkSelectorViewItemView: NSView {

    let imageLayer: CALayer = CALayer()
    let backgroundLayer: CALayer = CALayer()
    let emptyLayer: CAShapeLayer = CAShapeLayer()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setUp()
    }

    required init?(coder decoder: NSCoder) {
        super.init(coder: decoder)
        setUp()
    }

    private func setUp() {
        wantsLayer = true

        imageLayer.anchorPoint = CGPoint.zero
        imageLayer.position = CGPoint(x: 4, y: 40)
        imageLayer.contentsGravity = .resizeAspect
        imageLayer.shadowRadius = 1
        imageLayer.shadowColor = NSColor.labelColor.cgColor
        imageLayer.shadowOffset = CGSize.zero
        imageLayer.shadowOpacity = 0.8
        imageLayer.isOpaque = true

        backgroundLayer.anchorPoint = CGPoint.zero
        backgroundLayer.position = CGPoint(x: 0, y: 36)
        backgroundLayer.cornerRadius = 8
        backgroundLayer.isHidden = true
        backgroundLayer.isOpaque = true

        emptyLayer.anchorPoint = CGPoint.zero
        emptyLayer.position = CGPoint(x: 10, y: 46)
        emptyLayer.lineWidth = 3.0
        emptyLayer.lineDashPattern = [12,5]
        emptyLayer.strokeColor = NSColor.secondarySelectedControlColor.cgColor
        emptyLayer.fillColor = NSColor.windowBackgroundColor.cgColor
        emptyLayer.isOpaque = true

        let actions: [String : CAAction] = ["contents": NSNull(),
                                            "hidden": NSNull(),
                                            "bounds": NSNull()]
        imageLayer.actions = actions
        backgroundLayer.actions = actions
        emptyLayer.actions = actions

        layer?.addSublayer(backgroundLayer)
        layer?.addSublayer(emptyLayer)
        layer?.addSublayer(imageLayer)
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard let superview = superview else { return nil }

        if super.hitTest(point) != nil {
            let convertedPoint = superview.convert(point, to: self)
            if imageLayer.hitTest(convertedPoint) != nil {
                return self
            }
            return superview
        } else {
            return nil
        }
    }

    override func layout() {
        super.layout()
        imageLayer.bounds = CGRect(x: 0, y: 0, width: bounds.width - 8, height: bounds.height - 44)
        backgroundLayer.bounds = CGRect(x: 0, y: 0, width: bounds.width, height: bounds.height - 36)

        emptyLayer.bounds = CGRect(x: 0, y: 0, width: bounds.width - 16, height: bounds.height - 56)
        let path = CGMutablePath()
        path.addRoundedRect(in: emptyLayer.bounds, cornerWidth: 14, cornerHeight: 14)
        emptyLayer.path = path

        if #available(OSX 10.14, *) {
            imageLayer.shadowColor = NSColor.labelColor.cgColor
            backgroundLayer.backgroundColor = NSColor.unemphasizedSelectedContentBackgroundColor.cgColor
        } else {
            backgroundLayer.backgroundColor = NSColor.controlHighlightColor.cgColor
        }
    }

}

@available(OSX 10.11, *)
class ArtworkSelectorViewItem: NSCollectionViewItem {

    // MARK: Properties

    var itemView : ArtworkSelectorViewItemView { get { return (view as? ArtworkSelectorViewItemView)! } }
    @IBOutlet var subTextField: NSTextField!

    var doubleAction: Selector?
    weak var target: AnyObject?

    override var title: String? {
        set (title) {
            textField?.stringValue = title ?? ""
            super.title = title
        }
        get {
            return super.title
        }
    }

    var subtitle: String? {
        didSet {
            subTextField?.stringValue = subtitle ?? ""
        }
    }

    var image: NSImage? {
        didSet {
            itemView.imageLayer.contents = image
            itemView.emptyLayer.isHidden = image != nil
        }
    }

    override var highlightState: NSCollectionViewItem.HighlightState {
        set (value) {
            super.highlightState = value
            updateSelectionHighlight()
        }
        get {
            return super.highlightState
        }
    }

    override var isSelected: Bool {
        set (value) {
            super.isSelected = value
            updateSelectionHighlight()
        }
        get {
            return super.isSelected
        }
    }

    private func updateSelectionHighlight() {
        if highlightState == .forSelection || (isSelected && highlightState != .forDeselection) {
            itemView.backgroundLayer.isHidden = false
            textField?.isHighlighted = true
        } else {
            itemView.backgroundLayer.isHidden = true
            textField?.isHighlighted = false
        }
    }

    // MARK: Actions

    override func mouseUp(with event: NSEvent) {
        if event.clickCount > 1, let action = doubleAction {
            target?.performSelector(onMainThread: action, with: nil, waitUntilDone: true)
        } else {
            super.mouseUp(with: event)
        }
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == NSEnterCharacter, let action = doubleAction {
            target?.performSelector(onMainThread: action, with: nil, waitUntilDone: true)
        } else {
            super.keyDown(with: event)
        }
    }
    
}
