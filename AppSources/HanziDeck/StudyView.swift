import SwiftData
import SwiftUI

struct StudyView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let configuration: StudyConfiguration
    @State private var index = 0
    @State private var isRevealed = false

    private var prompt: StudyPrompt? {
        configuration.prompts.indices.contains(index) ? configuration.prompts[index] : nil
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(AppTheme.divider)
            if let prompt {
                studyCard(prompt)
            } else {
                completion
            }
        }
        .background(AppTheme.background)
    }

    private var header: some View {
        HStack {
            Button { dismiss() } label: { Image(systemName: "xmark") }
                .buttonStyle(.plain)
                .keyboardShortcut(.escape, modifiers: [])
                .accessibilityLabel("Exit study session")

            VStack(alignment: .leading, spacing: 3) {
                Text(configuration.deckName)
                    .font(.headline)
                    .foregroundStyle(AppTheme.primaryText)
                Text(
                    "\(configuration.method.title) · \(configuration.sessionKind.title) · \(configuration.schedulerAlgorithm.title)"
                )
                    .font(.caption)
                    .foregroundStyle(
                        configuration.updatesSchedule ? AppTheme.secondaryText : AppTheme.orange
                    )
            }
            Spacer()
            if prompt != nil {
                Text("\(index + 1) / \(configuration.prompts.count)")
                    .foregroundStyle(AppTheme.secondaryText)
            }
        }
        .padding(20)
    }

    private func studyCard(_ prompt: StudyPrompt) -> some View {
        VStack(spacing: 26) {
            Spacer()
            Text(frontText(for: prompt))
                .font(.system(size: frontSize(for: prompt), weight: .semibold))
                .foregroundStyle(AppTheme.primaryText)
                .minimumScaleFactor(0.4)
                .lineLimit(3)
                .multilineTextAlignment(.center)
                .accessibilityLabel("Prompt: \(frontText(for: prompt))")

            if isRevealed {
                answer(for: prompt)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            } else {
                Text(promptInstruction(for: prompt))
                    .foregroundStyle(AppTheme.secondaryText)
            }

            Spacer()

            if isRevealed {
                gradingControls(for: prompt)
            } else {
                Button("Reveal Answer") {
                    withAnimation(.easeOut(duration: 0.16)) { isRevealed = true }
                }
                .buttonStyle(OrangeButtonStyle())
                .keyboardShortcut(.space, modifiers: [])
            }
        }
        .padding(36)
    }

    private func gradingControls(for prompt: StudyPrompt) -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                ForEach(ReviewGrade.allCases) { grade in
                    ReviewGradeButton(
                        grade: grade,
                        updatesSchedule: configuration.updatesSchedule
                    ) {
                        rate(grade, prompt: prompt)
                    }
                }
            }
            Text(
                configuration.updatesSchedule
                    ? "Choose how well you recalled the answer."
                    : "This practice session does not change your schedule."
            )
            .font(.caption)
            .foregroundStyle(AppTheme.secondaryText)
        }
    }

    @ViewBuilder
    private func answer(for prompt: StudyPrompt) -> some View {
        switch prompt {
        case .word(let word, let style):
            wordAnswer(word, style: style)
        case .character(let character):
            let contexts = contextLines(for: character)
            VStack(alignment: .leading, spacing: 12) {
                ForEach(contexts, id: \.self) { line in
                    Text(line)
                        .font(.title3.weight(.medium))
                        .foregroundStyle(AppTheme.primaryText)
                }
            }
            .padding(22)
            .frame(maxWidth: 620)
            .darkPanel()
            .accessibilityElement(children: .combine)
            .accessibilityLabel(contexts.joined(separator: ", "))
        }
    }

    private func wordAnswer(_ word: WordCard, style: WordPromptStyle) -> some View {
        VStack(spacing: 12) {
            if style != .hanziRecognition {
                Text(word.hanzi)
                    .font(.system(size: 48, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryText)
            }
            if style != .pinyinRecall {
                Text(word.pinyin)
                    .font(.system(size: 27, weight: .semibold))
                    .foregroundStyle(AppTheme.orange)
            }
            if style != .meaningRecall {
                Text(word.meaning)
                    .font(.title3)
                    .foregroundStyle(AppTheme.primaryText)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(22)
        .frame(maxWidth: 620)
        .darkPanel()
    }

    private var completion: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(AppTheme.orange)
            Text("Session complete")
                .font(.title.bold())
                .foregroundStyle(AppTheme.primaryText)
            Text("You reviewed \(configuration.prompts.count) cards from \(configuration.deckName).")
                .foregroundStyle(AppTheme.secondaryText)
            Button("Done") { dismiss() }
                .buttonStyle(OrangeButtonStyle())
                .keyboardShortcut(.defaultAction)
            Spacer()
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
        case .character(let character):
            character.glyph
        }
    }

    private func frontSize(for prompt: StudyPrompt) -> CGFloat {
        switch prompt {
        case .character: 132
        case .word(_, .meaningRecall): 44
        case .word: 78
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
        let lines = character.contexts.compactMap { context -> String? in
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
            case .character(let character):
                if let state = character.reviewState {
                    Scheduler.apply(
                        grade,
                        to: state,
                        algorithm: configuration.schedulerAlgorithm,
                        desiredRetention: configuration.desiredRetention
                    )
                }
            }
            try? modelContext.save()
        }
        index += 1
        isRevealed = false
    }
}

private struct ReviewGradeButton: View {
    let grade: ReviewGrade
    let updatesSchedule: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Text(grade.title)
                Text("\(grade.rawValue)")
                    .font(.caption2)
                    .opacity(0.65)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
        }
        .buttonStyle(ReviewGradeButtonStyle(isPrimary: grade == .good))
        .keyboardShortcut(KeyEquivalent(Character(String(grade.rawValue))), modifiers: [])
        .accessibilityHint(
            updatesSchedule
                ? "Updates this card's review schedule"
                : "Moves to the next card without changing its schedule"
        )
    }
}

private struct ReviewGradeButtonStyle: ButtonStyle {
    let isPrimary: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(isPrimary ? Color.black : AppTheme.primaryText)
            .background(
                isPrimary
                    ? AppTheme.orange.opacity(configuration.isPressed ? 0.75 : 1)
                    : AppTheme.elevatedSurface.opacity(configuration.isPressed ? 0.7 : 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 9)
                    .stroke(isPrimary ? Color.clear : AppTheme.divider)
            )
            .clipShape(RoundedRectangle(cornerRadius: 9))
    }
}
