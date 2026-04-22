import Foundation
import SwiftUI

struct CodeEditorView: View {
    var text: String
    var language: EditorFileFormat
    var selection: NSRange
    var showLineNumbers: Bool
    var showsFolding: Bool
    var theme: PaperTheme
    var isDark: Bool
    var foldMarkers: [EditorFoldMarker]
    var onTextChange: (String, NSRange) -> Void
    var onSelectionChange: (NSRange) -> Void
    var onToggleFold: ((Int) -> Void)?

    @State private var draftText = ""
    @State private var suppressCallbacks = false

    var body: some View {
        HStack(spacing: 0) {
            if showLineNumbers {
                lineNumberColumn
            }

            TextEditor(text: $draftText)
                .font(.system(size: 14, weight: .regular, design: .monospaced))
                .scrollContentBackground(.hidden)
                .foregroundStyle(theme.textPrimary)
                .background(theme.editorBackground)
                .autocorrectionDisabled()
                .onAppear(perform: syncExternalState)
                .onChange(of: text) { _, _ in
                    syncExternalState()
                }
                .onChange(of: draftText) { _, newValue in
                    guard !suppressCallbacks else { return }
                    let fallbackSelection = NSRange(location: min(selection.location, newValue.utf16.count), length: 0)
                    onTextChange(newValue, fallbackSelection)
                }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(theme.editorBackground)
    }

    private var lineCount: Int {
        max(1, draftText.components(separatedBy: "\n").count)
    }

    private var lineNumberColumn: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(alignment: .trailing, spacing: 0) {
                ForEach(1...lineCount, id: \.self) { number in
                    Text("\(number)")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(theme.textSubtle)
                        .frame(maxWidth: .infinity, minHeight: 22, alignment: .trailing)
                }
            }
            .padding(.top, 16)
            .padding(.trailing, 12)
        }
        .allowsHitTesting(false)
        .frame(width: 48)
        .background(theme.editorBackground)
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(theme.border)
                .frame(width: 1)
        }
    }

    private func syncExternalState() {
        suppressCallbacks = true
        draftText = text
        DispatchQueue.main.async {
            suppressCallbacks = false
        }
    }
}
