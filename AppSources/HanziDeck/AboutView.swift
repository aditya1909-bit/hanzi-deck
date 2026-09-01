#if os(macOS)
import AppKit
import SwiftUI

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Spacer()
                Button { dismiss() } label: { Image(systemName: "xmark") }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.cancelAction)
                    .accessibilityLabel("Close About")
            }

            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)
                .accessibilityLabel("Hanzi Deck logo")
            Text("Hanzi Deck")
                .font(.title.bold())
                .foregroundStyle(AppTheme.primaryText)
            Text("Offline Chinese word and character study for macOS")
                .foregroundStyle(AppTheme.secondaryText)

            Divider().overlay(AppTheme.divider)

            VStack(alignment: .leading, spacing: 10) {
                Text("Dictionary")
                    .font(.headline)
                    .foregroundStyle(AppTheme.primaryText)
                Text("Dictionary data is provided by CC-CEDICT, published by MDBG and community contributors, under the Creative Commons Attribution-ShareAlike 4.0 International license.")
                    .foregroundStyle(AppTheme.secondaryText)
                Link("CC-CEDICT project and download", destination: URL(string: "https://www.mdbg.net/chinese/dictionary?page=cc-cedict")!)
                    .foregroundStyle(AppTheme.orange)
                Link("Creative Commons BY-SA 4.0", destination: URL(string: "https://creativecommons.org/licenses/by-sa/4.0/")!)
                    .foregroundStyle(AppTheme.orange)
                Text("Bundled release: 2026-08-31 · Source archive SHA-256: 5dc61b731e80a5ada2706b7d43acdbbaabfa028601854459c978eda801284fe8")
                    .font(.caption.monospaced())
                    .foregroundStyle(AppTheme.secondaryText)
                    .textSelection(.enabled)
            }
            .padding(18)
            .darkPanel()
        }
        .padding(24)
        .frame(width: 560, height: 520)
        .background(AppTheme.background)
    }
}
#endif
