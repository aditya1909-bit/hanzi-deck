#if os(iOS)
import SwiftData
import SwiftUI

struct MobileStudyView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let configuration: StudyConfiguration
    @State private var index = 0
    @State private var isRevealed = false

    private var prompt: StudyPrompt? {
        configuration.prompts.indices.contains(index) ? configuration.prompts[index] : nil
    }

    var body: some View {
        NavigationStack {
            Group {
                if let prompt {
                    studyCard(prompt)
                } else {
                    completion
                }
            }
            .background(AppTheme.background)
            .navigationTitle(configuration.deckName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                if prompt != nil {
                    ToolbarItem(placement: .principal) {
                        VStack(spacing: 1) {
                            Text(configuration.deckName)
                                .font(.headline)
                            Text("\(index + 1) of \(configuration.prompts.count)")
                                .font(.caption2)
                                .foregroundStyle(AppTheme.secondaryText)
                        }
                    }
                }
            }
        }
        .tint(AppTheme.orange)
    }

    private func studyCard(_ prompt: StudyPrompt) -> some View {
        VStack(spacing: 24) {
            Text("\(configuration.method.title) · \(configuration.schedulerAlgorithm.title)")
                .font(.caption)
                .foregroundStyle(AppTheme.secondaryText)

            Spacer()

            Text(frontText(for: prompt))
                .font(.system(size: frontSize(for: prompt), weight: .semibold))
                .foregroundStyle(AppTheme.primaryText)
                .minimumScaleFactor(0.35)
                .lineLimit(4)
                .multilineTextAlignment(.center)
                .accessibilityLabel("Prompt: \(frontText(for: prompt))")

            if isRevealed {
                answer(for: prompt)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            } else {
                Text(promptInstruction(for: prompt))
                    .foregroundStyle(AppTheme.secondaryText)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            if isRevealed {
                gradingControls(prompt)
            } else {
                Button {
                    withAnimation(.easeOut(duration: 0.16)) { isRevealed = true }
                } label: {
                    Text("Reveal Answer")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(OrangeButtonStyle())
            }
        }
        .padding(20)
    }

    private func gradingControls(_ prompt: StudyPrompt) -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 7) {
                ForEach(ReviewGrade.allCases) { grade in
                    Button {
                        rate(grade, prompt: prompt)
                    } label: {
                        Text(grade.title)
                            .font(.caption.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .foregroundStyle(grade == .good ? Color.black : AppTheme.primaryText)
                            .background(grade == .good ? AppTheme.orange : AppTheme.elevatedSurface)
                            .clipShape(RoundedRectangle(cornerRadius: 9))
                    }
                }
            }
            Text(configuration.updatesSchedule
                 ? "Choose how well you recalled it."
                 : "Practice ratings do not change due dates.")
                .font(.caption)
                .foregroundStyle(AppTheme.secondaryText)
        }
    }

    @ViewBuilder
    private func answer(for prompt: StudyPrompt) -> some View {
        switch prompt {
        case .word(let word, let style):
            VStack(spacing: 10) {
                if style != .hanziRecognition {
                    Text(word.hanzi)
                        .font(.system(size: 43, weight: .semibold))
                }
                if style != .pinyinRecall {
                    Text(word.pinyin)
                        .font(.title2.bold())
                        .foregroundStyle(AppTheme.orange)
                }
                if style != .meaningRecall {
                    Text(word.meaning)
                        .foregroundStyle(AppTheme.primaryText)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity)
            .darkPanel()
        case .character(let character):
            VStack(alignment: .leading, spacing: 9) {
                ForEach(contextLines(for: character), id: \.self) { line in
                    Text(line)
                        .font(.title3.weight(.medium))
                        .foregroundStyle(AppTheme.primaryText)
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .darkPanel()
        }
    }

    private var completion: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(AppTheme.orange)
            Text("Session complete")
                .font(.title.bold())
                .foregroundStyle(AppTheme.primaryText)
            Text("You reviewed \(configuration.prompts.count) cards.")
                .foregroundStyle(AppTheme.secondaryText)
            Button("Done") { dismiss() }
                .buttonStyle(OrangeButtonStyle())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func frontText(for prompt: StudyPrompt) -> String {
        switch prompt {
        case .word(let word, let style):
            switch style {
            case .hanziRecognition: word.hanzi
            case .meaningRecall: word.meaning
            case .pinyinRecall: word.pinyin
            }
        case .character(let character): character.glyph
        }
    }

    private func frontSize(for prompt: StudyPrompt) -> CGFloat {
        switch prompt {
        case .character: 108
        case .word(_, .meaningRecall): 38
        case .word: 68
        }
    }

    private func promptInstruction(for prompt: StudyPrompt) -> String {
        switch prompt {
        case .word(_, .hanziRecognition): "Recall the pronunciation and meaning."
        case .word(_, .meaningRecall): "Recall the Chinese word."
        case .word(_, .pinyinRecall): "Recall the characters and meaning."
        case .character: "Recall the reading and source words."
        }
    }

    private func contextLines(for character: CharacterCard) -> [String] {
        let lines = character.sourceContexts.compactMap { context -> String? in
            guard let source = context.sourceWord else { return nil }
            return "\(context.pinyin) — \(source.hanzi)"
        }
        return Array(Set(lines)).sorted()
    }

    private func rate(_ grade: ReviewGrade, prompt: StudyPrompt) {
        if configuration.updatesSchedule {
            switch prompt {
            case .word(let word, _):
                if let state = word.reviewState {
                    Scheduler.apply(
                        grade,
                        to: state,
                        algorithm: configuration.schedulerAlgorithm,
                        desiredRetention: configuration.desiredRetention
                    )
                }
                word.deck?.updatedAt = .now
            case .character(let character):
                if let state = character.reviewState {
                    Scheduler.apply(
                        grade,
                        to: state,
                        algorithm: configuration.schedulerAlgorithm,
                        desiredRetention: configuration.desiredRetention
                    )
                }
                character.deck?.updatedAt = .now
            }
            try? modelContext.save()
        }
        index += 1
        isRevealed = false
    }
}
#endif
