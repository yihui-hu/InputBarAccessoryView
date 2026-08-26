//
//  InputTextView.swift
//  InputBarAccessoryView
//
//  Copyright © 2017-2020 Nathan Tannar.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.
//
//  Created by Nathan Tannar on 8/18/17.
//

import Foundation
import UIKit

/**
 A UITextView that has a UILabel embedded for placeholder text
 
 ## Important Notes ##
 1. Changing the font, textAlignment or textContainerInset automatically performs the same modifications to the placeholderLabel
 2. Intended to be used in an `InputBarAccessoryView`
 3. Default placeholder text is "Aa"
 4. Will pass a pasted image it's `InputBarAccessoryView`'s `InputPlugin`s
 */
open class InputTextView: UITextView {
    
    // MARK: - Properties
    
    /// UIKit resets `typingAttributes` whenever `text`/`attributedText` is
    /// assigned programmatically, which would silently drop a configured
    /// fixed-line-height paragraph style until the next keystroke restores
    /// it — and any layout in between would measure with the wrong metrics.
    /// Both setters below restore the pre-assignment typing attributes.
    private var typingAttributesBeforeAssignment: [NSAttributedString.Key: Any]?

    open override var text: String! {
        willSet {
            typingAttributesBeforeAssignment = typingAttributes
        }
        didSet {
            if let preserved = typingAttributesBeforeAssignment {
                typingAttributes = preserved
                typingAttributesBeforeAssignment = nil
            }
            postTextViewDidChangeNotification()
        }
    }

    open override var attributedText: NSAttributedString! {
        willSet {
            typingAttributesBeforeAssignment = typingAttributes
        }
        didSet {
            if let preserved = typingAttributesBeforeAssignment {
                typingAttributes = preserved
                typingAttributesBeforeAssignment = nil
            }
            postTextViewDidChangeNotification()
        }
    }
    
    /// The images that are currently stored as NSTextAttachment's
    open var images: [UIImage] {
        return parseForAttachedImages()
    }
    
    open var components: [Any] {
        return parseForComponents()
    }
    
    open var isImagePasteEnabled: Bool = true

    /// A UILabel that holds the InputTextView's placeholder text
    public let placeholderLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        if #available(iOS 13, *) {
            label.textColor = .systemGray2
        } else {
            label.textColor = .lightGray
        }
        label.text = "Aa"
        label.backgroundColor = .clear
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    /// The placeholder text that appears when there is no text
    open var placeholder: String? = "Aa" {
        didSet {
            placeholderLabel.text = placeholder
        }
    }
    
    /// The placeholderLabel's textColor
    open var placeholderTextColor: UIColor? = .lightGray {
        didSet {
            placeholderLabel.textColor = placeholderTextColor
        }
    }
    
    /// The UIEdgeInsets the placeholderLabel has within the InputTextView.
    /// The horizontal defaults include the textContainer's lineFragmentPadding
    /// so the placeholder sits exactly where the typed text will appear.
    open var placeholderLabelInsets: UIEdgeInsets = UIEdgeInsets(top: 8, left: 5, bottom: 8, right: 5) {
        didSet {
            updateConstraintsForPlaceholderLabel()
        }
    }
    
    /// The font of the InputTextView. When set the placeholderLabel's font is also updated
    open override var font: UIFont! {
        didSet {
            placeholderLabel.font = font
        }
    }
    
    /// The textAlignment of the InputTextView. When set the placeholderLabel's textAlignment is also updated
    open override var textAlignment: NSTextAlignment {
        didSet {
            placeholderLabel.textAlignment = textAlignment
        }
    }
    
    /// The textContainerInset of the InputTextView. When set the placeholderLabelInsets is also updated
    open override var textContainerInset: UIEdgeInsets {
        didSet {
            placeholderLabelInsets = UIEdgeInsets(
                top: textContainerInset.top,
                left: textContainerInset.left + textContainer.lineFragmentPadding,
                bottom: textContainerInset.bottom,
                right: textContainerInset.right + textContainer.lineFragmentPadding
            )
        }
    }
    
    open override var scrollIndicatorInsets: UIEdgeInsets {
        didSet {
            // When .zero a rendering issue can occur
            if scrollIndicatorInsets == .zero {
                scrollIndicatorInsets = UIEdgeInsets(top: .leastNonzeroMagnitude,
                                                     left: .leastNonzeroMagnitude,
                                                     bottom: .leastNonzeroMagnitude,
                                                     right: .leastNonzeroMagnitude)
            }
        }
    }
    
    /// A weak reference to the InputBarAccessoryView that the InputTextView is contained within
    open weak var inputBarAccessoryView: InputBarAccessoryView?
    
    /// The constraints of the placeholderLabel
    private var placeholderLabelConstraintSet: NSLayoutConstraintSet?
 
    // MARK: - Initializers

    /// Keeps the manually built TextKit 1 stack's NSTextStorage alive:
    /// TextKit's back-references are weak, so the view must retain it.
    private var retainedTextStorage: NSTextStorage?

    public convenience init() {
        // TextKit 1 is required: paragraph styles pinning
        // minimumLineHeight == maximumLineHeight together with .baselineOffset
        // are dropped by TextKit 2's layout manager.
        //
        // Do NOT use init(usingTextLayoutManager:) here — it bypasses the
        // subclass's designated initializer, leaving Swift stored properties
        // (placeholderLabel, insets, ...) uninitialized. An explicit
        // NSTextContainer through the designated init forces TextKit 1 while
        // initializing properties normally.
        let textStorage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        let textContainer = NSTextContainer(size: .zero)
        textContainer.widthTracksTextView = true
        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)
        self.init(frame: .zero, textContainer: textContainer)
        retainedTextStorage = textStorage
    }

    public override init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
        setup()
    }

    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setup()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Setup

    /// Sets up the default properties
    open func setup() {

        backgroundColor = .clear
        font = UIFont.preferredFont(forTextStyle: .body)
        isScrollEnabled = false
        // Non-contiguous layout (UITextView's default) does not reliably
        // produce the extra line fragment for a trailing newline, which
        // misplaces the caret on the empty last line and breaks line-count
        // sizing. Documents here are small; contiguous layout is cheap.
        layoutManager.allowsNonContiguousLayout = false
        scrollIndicatorInsets = UIEdgeInsets(top: .leastNonzeroMagnitude,
                                             left: .leastNonzeroMagnitude,
                                             bottom: .leastNonzeroMagnitude,
                                             right: .leastNonzeroMagnitude)
        setupPlaceholderLabel()
        setupObservers()
    }
    
    /// Adds the placeholderLabel to the view and sets up its initial constraints
    ///
    /// NOTE: with fixed line metrics (see `fixedLineMetrics`), style the
    /// label so its height matches one line of the input text (same font
    /// for the lineSpacing shape; same attributed line height for the
    /// min/max shape) — then the height these pins impose while the view
    /// is empty equals the one-line fitting height while typing, and the
    /// first character cannot shift the layout.
    private func setupPlaceholderLabel() {

        addSubview(placeholderLabel)
        placeholderLabelConstraintSet = NSLayoutConstraintSet(
            top:     placeholderLabel.topAnchor.constraint(equalTo: topAnchor, constant: placeholderLabelInsets.top),
            bottom:  placeholderLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -placeholderLabelInsets.bottom),
            left:    placeholderLabel.leftAnchor.constraint(equalTo: leftAnchor, constant: placeholderLabelInsets.left),
            right:   placeholderLabel.rightAnchor.constraint(equalTo: rightAnchor, constant: -placeholderLabelInsets.right),
            centerX: placeholderLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            centerY: placeholderLabel.centerYAnchor.constraint(equalTo: centerYAnchor)
        )
        placeholderLabelConstraintSet?.centerX?.priority = .defaultLow
        placeholderLabelConstraintSet?.centerY?.priority = .defaultLow
        placeholderLabelConstraintSet?.activate()
    }
    
    /// Adds a notification for .UITextViewTextDidChange to detect when the placeholderLabel
    /// should be hidden or shown
    private func setupObservers() {
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(InputTextView.redrawTextAttachments),
                                               name: UIDevice.orientationDidChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(InputTextView.textViewTextDidChange),
                                               name: UITextView.textDidChangeNotification, object: nil)
    }

    /// Updates the placeholderLabels constraint constants to match the placeholderLabelInsets
    private func updateConstraintsForPlaceholderLabel() {

        placeholderLabelConstraintSet?.top?.constant = placeholderLabelInsets.top
        placeholderLabelConstraintSet?.bottom?.constant = -placeholderLabelInsets.bottom
        placeholderLabelConstraintSet?.left?.constant = placeholderLabelInsets.left
        placeholderLabelConstraintSet?.right?.constant = -placeholderLabelInsets.right
    }

    open override func firstRect(for range: UITextRange) -> CGRect {
        let rect = super.firstRect(for: range)
        // If `layoutManager` is accessed, UITextView switches to TextKit1
        // In iOS 27, UIKit has a bug with Siri writing tools where it requests a preview with
        // range which can result in an invalid rect, so we need to validate it here as a fallback.
        guard rect.isValidForLayout else {
            return bounds
        }
        return rect
    }

    // MARK: - Notifications

    /// Programmatic `text`/`attributedText` assignments normally broadcast
    /// `UITextView.textDidChangeNotification` (see the property overrides).
    /// Set this while making a transient assignment that observers must not
    /// react to — e.g. AutocompleteManager's momentary clear before an
    /// insertion, which would otherwise run the input bar's height pipeline
    /// against an empty document.
    var suppressesTextDidChangeBroadcast = false

    private func postTextViewDidChangeNotification() {
        guard !suppressesTextDidChangeBroadcast else { return }
        NotificationCenter.default.post(name: UITextView.textDidChangeNotification, object: self)
    }
    
    @objc
    private func textViewTextDidChange() {
        let isPlaceholderHidden = !text.isEmpty
        placeholderLabel.isHidden = isPlaceholderHidden
        // Adjust constraints to prevent ambiguous content size
        if isPlaceholderHidden {
            placeholderLabelConstraintSet?.deactivate()
        } else {
            placeholderLabelConstraintSet?.activate()
        }
    }

    // MARK: - Fixed Line-Height Sizing

    /// Deterministic per-line metrics derived from the text attributes:
    /// the line pitch (baseline-to-baseline distance) and the trailing gap
    /// below the last line. Two attribute shapes produce fixed metrics —
    /// a paragraph style pinning `minimumLineHeight == maximumLineHeight`
    /// (pitch = that height, no trailing gap), or natural font metrics
    /// with `lineSpacing` (pitch = font lineHeight + spacing, trailing
    /// gap = spacing).
    struct FixedLineMetrics: Equatable {
        var pitch: CGFloat
        var trailingGap: CGFloat
    }

    /// Reads `typingAttributes` first, falling back to the document's own
    /// attributes so sizing cannot disengage while styled text is present,
    /// even if UIKit transiently resets the typing attributes.
    var fixedLineMetrics: FixedLineMetrics? {
        if let metrics = Self.fixedLineMetrics(in: typingAttributes) {
            return metrics
        }
        guard let attributedText, attributedText.length > 0 else { return nil }
        return Self.fixedLineMetrics(in: attributedText.attributes(at: 0, effectiveRange: nil))
    }

    /// The fixed line pitch, when one is in effect.
    public var fixedLineHeight: CGFloat? {
        fixedLineMetrics?.pitch
    }

    private static func fixedLineMetrics(in attributes: [NSAttributedString.Key: Any]) -> FixedLineMetrics? {
        guard let style = attributes[.paragraphStyle] as? NSParagraphStyle else { return nil }
        // A minimum line height taller than the font's natural height fixes
        // the pitch on its own (with or without a matching maximum).
        if style.minimumLineHeight > 0,
           style.maximumLineHeight == 0 || style.maximumLineHeight == style.minimumLineHeight {
            return FixedLineMetrics(pitch: style.minimumLineHeight, trailingGap: 0)
        }
        if style.lineSpacing > 0, let font = attributes[.font] as? UIFont {
            return FixedLineMetrics(pitch: font.lineHeight + style.lineSpacing, trailingGap: style.lineSpacing)
        }
        return nil
    }

    /// Height fitting the current text as `lineCount × fixedLineHeight` plus
    /// the vertical `textContainerInset`, aligned up to the pixel grid.
    /// `nil` when no fixed line height is in effect.
    ///
    /// Deriving the height from the line count makes it a step function of
    /// the text: it can only change when a line wraps in or out, so sub-point
    /// measurement noise can never resize the view while typing. The trailing
    /// caret line (TextKit's extra line fragment, which is otherwise measured
    /// at the font's natural height) counts as one full line.
    public func fixedLineHeightFittingHeight() -> CGFloat? {
        guard let metrics = fixedLineMetrics else { return nil }
        let verticalInset = textContainerInset.top + textContainerInset.bottom
        func height(forLineCount lineCount: Int) -> CGFloat {
            pixelAligned(verticalInset + CGFloat(lineCount) * metrics.pitch - metrics.trailingGap)
        }
        guard bounds.width > 0 else {
            // Not laid out yet: wrapping is unknowable, so count paragraphs.
            let newlineCount = text.unicodeScalars.lazy.filter { $0 == "\n" }.count
            return height(forLineCount: newlineCount + 1)
        }
        layoutManager.ensureLayout(for: textContainer)
        var lineCount = 0
        var glyphIndex = 0
        let numberOfGlyphs = layoutManager.numberOfGlyphs
        while glyphIndex < numberOfGlyphs {
            var lineRange = NSRange(location: NSNotFound, length: 0)
            layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: &lineRange)
            lineCount += 1
            glyphIndex = NSMaxRange(lineRange)
        }
        if numberOfGlyphs == 0 || text.hasSuffix("\n") {
            lineCount += 1
        }
        return height(forLineCount: lineCount)
    }

    /// The tallest height at or below `maxHeight` showing only complete lines
    /// of the fixed line height. `nil` when no fixed line height is in effect.
    public func fixedLineHeightCap(below maxHeight: CGFloat) -> CGFloat? {
        guard let metrics = fixedLineMetrics else { return nil }
        let verticalInset = textContainerInset.top + textContainerInset.bottom
        let lineCount = max(1, ((maxHeight - verticalInset + metrics.trailingGap) / metrics.pitch).rounded(.down))
        return pixelAligned(verticalInset + lineCount * metrics.pitch - metrics.trailingGap)
    }

    private func pixelAligned(_ height: CGFloat) -> CGFloat {
        let scale = traitCollection.displayScale > 0
            ? traitCollection.displayScale
            : UIScreen.main.scale
        return (height * scale).rounded(.up) / scale
    }

    /// With a fixed line height the intrinsic height must be the exact same
    /// quantized value the InputBarAccessoryView allocates for the text view,
    /// so the two never disagree by a fraction of a point.
    open override var intrinsicContentSize: CGSize {
        guard !isScrollEnabled, let height = fixedLineHeightFittingHeight() else {
            return super.intrinsicContentSize
        }
        return CGSize(width: UIView.noIntrinsicMetric, height: height)
    }

    // MARK: - Caret & Selection Geometry

    /// TextKit bottom-aligns the glyph block inside a line box enlarged by
    /// `minimumLineHeight`, and system caret/selection rects span the full
    /// line fragment — leaving all of the extra height hanging above the
    /// glyphs. Recenter them: the caret hugs the glyph block (like a plain
    /// text field), and selection keeps the full line pitch so multi-line
    /// selections stay contiguous, shifted to leave an even halo.

    open override func caretRect(for position: UITextPosition) -> CGRect {
        var rect = super.caretRect(for: position)
        guard let metrics = fixedLineMetrics, let font,
              metrics.pitch > font.lineHeight
        else { return rect }
        // Also aligns the caret on an empty line (TextKit's extra line
        // fragment has the font's natural height, sitting high) with where
        // the glyph block of typed text will land.
        rect.origin.y += metrics.pitch - font.lineHeight
        rect.size.height = font.lineHeight
        return rect
    }

    open override func selectionRects(for range: UITextRange) -> [UITextSelectionRect] {
        let rects = super.selectionRects(for: range)
        guard let metrics = fixedLineMetrics, let font,
              metrics.pitch > font.lineHeight
        else { return rects }
        let shift = (metrics.pitch - font.lineHeight) / 2
        return rects.map { base in
            guard base.rect.height > font.lineHeight - 0.5 else { return base }
            return RecenteredSelectionRect(base: base, rect: base.rect.offsetBy(dx: 0, dy: shift))
        }
    }

    private final class RecenteredSelectionRect: UITextSelectionRect {
        private let base: UITextSelectionRect
        private let recenteredRect: CGRect

        init(base: UITextSelectionRect, rect: CGRect) {
            self.base = base
            self.recenteredRect = rect
        }

        override var rect: CGRect { recenteredRect }
        override var writingDirection: NSWritingDirection { base.writingDirection }
        override var containsStart: Bool { base.containsStart }
        override var containsEnd: Bool { base.containsEnd }
        override var isVertical: Bool { base.isVertical }
    }

    // MARK: - Image Paste Support
    
    open override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {

        if action == NSSelectorFromString("paste:") && UIPasteboard.general.hasImages {
            return isImagePasteEnabled
        }
        return super.canPerformAction(action, withSender: sender)
    }
    
    open override func paste(_ sender: Any?) {
        
        guard isImagePasteEnabled, let image = UIPasteboard.general.image else {
            return super.paste(sender)
        }
        for plugin in inputBarAccessoryView?.inputPlugins ?? [] {
            if plugin.handleInput(of: image) {
                return
            }
        }
        pasteImageInTextContainer(with: image)
    }
    
    /// Addes a new UIImage to the NSTextContainer as an NSTextAttachment
    ///
    /// - Parameter image: The image to add
    private func pasteImageInTextContainer(with image: UIImage) {
        
        // Add the new image as an NSTextAttachment
        let attributedImageString = NSAttributedString(attachment: textAttachment(using: image))
        
        let isEmpty = attributedText.length == 0
        
        // Add a new line character before the image, this is what iMessage does
        let newAttributedStingComponent = isEmpty ? NSMutableAttributedString(string: "") : NSMutableAttributedString(string: "\n")
        newAttributedStingComponent.append(attributedImageString)
        
        // Add a new line character after the image, this is what iMessage does
        newAttributedStingComponent.append(NSAttributedString(string: "\n"))
        
        // The attributes that should be applied to the new NSAttributedString to match the current attributes
        let defaultTextColor: UIColor
        if #available(iOS 13, *) {
            defaultTextColor = .label
        } else {
            defaultTextColor = .black
        }
        let attributes: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key.font: font ?? UIFont.preferredFont(forTextStyle: .body),
            NSAttributedString.Key.foregroundColor: textColor ?? defaultTextColor
        ]
        newAttributedStingComponent.addAttributes(attributes, range: NSRange(location: 0, length: newAttributedStingComponent.length))
        
        textStorage.beginEditing()
        // Paste over selected text
        textStorage.replaceCharacters(in: selectedRange, with: newAttributedStingComponent)
        textStorage.endEditing()
        
        // Advance the range to the selected range plus the number of characters added
        let location = selectedRange.location + (isEmpty ? 2 : 3)
        selectedRange = NSRange(location: location, length: 0)
        
        // Broadcast a notification to recievers such as the MessageInputBar which will handle resizing
        postTextViewDidChangeNotification()
    }
    
    /// Returns an NSTextAttachment the provided image that will fit inside the NSTextContainer
    ///
    /// - Parameter image: The image to create an attachment with
    /// - Returns: The formatted NSTextAttachment
    private func textAttachment(using image: UIImage) -> NSTextAttachment {
        
        guard let cgImage = image.cgImage else { return NSTextAttachment() }
        let scale = image.size.width / (frame.width - 2 * (textContainerInset.left + textContainerInset.right))
        let textAttachment = NSTextAttachment()
        textAttachment.image = UIImage(cgImage: cgImage, scale: scale, orientation: image.imageOrientation)
        return textAttachment
    }
    
    /// Returns all images that exist as NSTextAttachment's
    ///
    /// - Returns: An array of type UIImage
    private func parseForAttachedImages() -> [UIImage] {
        
        var images = [UIImage]()
        let range = NSRange(location: 0, length: attributedText.length)
        attributedText.enumerateAttribute(.attachment, in: range, options: [], using: { value, range, _ -> Void in
            
            if let attachment = value as? NSTextAttachment {
                if let image = attachment.image {
                    images.append(image)
                } else if let image = attachment.image(forBounds: attachment.bounds,
                                                       textContainer: nil,
                                                       characterIndex: range.location) {
                    images.append(image)
                }
            }
        })
        return images
    }
    
    /// Returns an array of components (either a String or UIImage) that makes up the textContainer in
    /// the order that they were typed
    ///
    /// - Returns: An array of objects guaranteed to be of UIImage or String
    private func parseForComponents() -> [Any] {
        
        var components = [Any]()
        var attachments = [(NSRange, UIImage)]()
        let length = attributedText.length
        let range = NSRange(location: 0, length: length)
        attributedText.enumerateAttribute(.attachment, in: range) { (object, range, _) in
            if let attachment = object as? NSTextAttachment {
                if let image = attachment.image {
                    attachments.append((range, image))
                } else if let image = attachment.image(forBounds: attachment.bounds,
                                                       textContainer: nil,
                                                       characterIndex: range.location) {
                    attachments.append((range,image))
                }
            }
        }
        
        var curLocation = 0
        if attachments.count == 0 {
            let text = attributedText.string.trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty {
                components.append(text)
            }
        }
        else {
            attachments.forEach { (attachment) in
                let (range, image) = attachment
                if curLocation < range.location {
                    let textRange = NSMakeRange(curLocation, range.location - curLocation)
                    let text = attributedText.attributedSubstring(from: textRange).string.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !text.isEmpty {
                        components.append(text)
                    }
                }
                
                curLocation = range.location + range.length
                components.append(image)
            }
            if curLocation < length - 1  {
                let text = attributedText.attributedSubstring(from: NSMakeRange(curLocation, length - curLocation)).string.trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty {
                    components.append(text)
                }
            }
        }
        
        return components
    }
    
    /// Redraws the NSTextAttachments in the NSTextContainer to fit the current bounds
    @objc
    private func redrawTextAttachments() {
        
        guard images.count > 0 else { return }
        let range = NSRange(location: 0, length: attributedText.length)
        attributedText.enumerateAttribute(.attachment, in: range, options: [], using: { value, _, _ -> Void in
            if let attachment = value as? NSTextAttachment, let image = attachment.image {
                
                // Calculates a new width/height ratio to fit the image in the current frame
                let newWidth = frame.width - 2 * (textContainerInset.left + textContainerInset.right)
                let ratio = image.size.height / image.size.width
                attachment.bounds.size = CGSize(width: newWidth, height: ratio * newWidth)
            }
        })
        layoutManager.invalidateLayout(forCharacterRange: range, actualCharacterRange: nil)
    }
    
}

private extension CGRect {

    var isValidForLayout: Bool {
        !isNull && !isInfinite && origin.x.isFinite && origin.y.isFinite && size.width.isFinite && size.height.isFinite
    }
}
