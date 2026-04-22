import SwiftUI

struct WorkspaceStatusBar: View {
    let theme: PaperTheme
    let status: EditorStatus

    var body: some View {
        HStack {
            HStack(spacing: 16) {
                Text(status.format)
                if !status.encoding.isEmpty {
                    separator
                    Text(status.encoding)
                    separator
                    Text("Ln \(status.line), Col \(status.column)")
                }
            }

            Spacer()

            HStack(spacing: 16) {
                if !status.metrics.isEmpty {
                    Text(status.metrics)
                }
                separator
                Label(status.gitBranch, systemImage: "arrow.triangle.branch")
                separator
                HStack(spacing: 6) {
                    Circle()
                        .fill(status.lspOnline ? theme.success : theme.textSubtle)
                        .frame(width: 6, height: 6)
                    Text("LSP")
                }
            }
        }
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(theme.textMuted)
        .padding(.horizontal, 16)
        .frame(height: 24)
        .background(theme.windowBackground)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(theme.border)
                .frame(height: 1)
        }
    }

    private var separator: some View {
        Rectangle()
            .fill(theme.border)
            .frame(width: 1, height: 12)
    }
}
