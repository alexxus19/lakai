import AppKit
import SwiftUI

struct ScriptTextEditor: NSViewRepresentable {
    @Binding var text: String
    let scriptSync: ScriptSyncService

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, scriptSync: scriptSync)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .noBorder

        let textView = NSTextView()
        textView.isRichText = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 0, height: 10)
        textView.textContainer?.widthTracksTextView = true
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textColor = .white
        textView.insertionPointColor = .white
        textView.autoresizingMask = [.width]
        textView.delegate = context.coordinator
        textView.textStorage?.setAttributedString(scriptSync.attributedScript(text))
        context.coordinator.textView = textView

        scrollView.documentView = textView
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = context.coordinator.textView else {
            return
        }

        if textView.string != text {
            context.coordinator.applyStyledText(text, to: textView, preserveSelection: false)
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        @Binding private var text: String
        private let scriptSync: ScriptSyncService
        weak var textView: NSTextView?
        private var isApplyingUpdate = false

        init(text: Binding<String>, scriptSync: ScriptSyncService) {
            _text = text
            self.scriptSync = scriptSync
        }

        func textDidChange(_ notification: Notification) {
            guard !isApplyingUpdate,
                  let textView = notification.object as? NSTextView else {
                return
            }

            let updatedText = textView.string
            text = updatedText
            applyStyledText(updatedText, to: textView, preserveSelection: true)
        }

        func applyStyledText(_ text: String, to textView: NSTextView, preserveSelection: Bool) {
            isApplyingUpdate = true
            let selectedRanges = preserveSelection ? textView.selectedRanges : []
            textView.textStorage?.setAttributedString(scriptSync.attributedScript(text))
            if preserveSelection {
                textView.selectedRanges = selectedRanges
            }
            isApplyingUpdate = false
        }
    }
}