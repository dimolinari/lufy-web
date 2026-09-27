import SwiftUI
import AprendeCore

struct QuizFlow: View {
    var questions: [Question]
    var onComplete: ([String: SubmittedAnswer]) -> Void
    @State private var index = 0
    @State private var answers: [String: SubmittedAnswer] = [:]
    @State private var optionID: String?
    @State private var flag: Bool?
    @State private var order: [Choice] = []
    @State private var text = ""

    var body: some View {
        let question = questions[index]
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Pregunta \(index + 1) de \(questions.count)")
                    .font(.subheadline)
                    .foregroundStyle(LufyColor.gold)
                Text(question.prompt)
                    .font(.system(.title3, design: .serif))
                    .foregroundStyle(LufyColor.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                editor(for: question)
                Button(index + 1 == questions.count ? "Comprobar" : "Siguiente") {
                    advance(question)
                }
                .buttonStyle(WineButtonStyle())
                .disabled(!canContinue(question))
                .accessibilityHint(canContinue(question) ? "Guarda esta respuesta." : "Elige una respuesta para continuar.")
            }
            .padding(20)
        }
        .onAppear { prepare(question) }
        .onChange(of: index) { _, _ in
            prepare(questions[index])
        }
    }

    @ViewBuilder
    private func editor(for question: Question) -> some View {
        switch question.body {
        case .multipleChoice(let options, _):
            VStack(spacing: 10) {
                ForEach(options) { option in
                    choiceButton(title: option.text, selected: optionID == option.id) {
                        optionID = option.id
                    }
                }
            }
        case .trueFalse:
            VStack(spacing: 10) {
                choiceButton(title: "Verdadero", selected: flag == true) { flag = true }
                choiceButton(title: "Falso", selected: flag == false) { flag = false }
            }
        case .order:
            VStack(spacing: 10) {
                ForEach(Array(order.enumerated()), id: \.element.id) { offset, item in
                    HStack(spacing: 8) {
                        Text(item.text)
                            .font(.body)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Button("Subir") { move(offset, by: -1) }
                            .disabled(offset == 0)
                            .frame(minHeight: 44)
                            .accessibilityLabel("Subir \(item.text)")
                        Button("Bajar") { move(offset, by: 1) }
                            .disabled(offset == order.count - 1)
                            .frame(minHeight: 44)
                            .accessibilityLabel("Bajar \(item.text)")
                    }
                    .padding(12)
                    .background(LufyColor.card)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(LufyColor.line))
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Ordena los hechos. El primero es el más antiguo o el primer paso.")
        case .fillBlank:
            TextField("Tu respuesta", text: $text)
                .textFieldStyle(.roundedBorder)
                .font(.body)
                .submitLabel(.done)
                .accessibilityLabel("Respuesta para completar el espacio")
        }
    }

    private func choiceButton(title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.body)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if selected {
                    Image(systemName: "checkmark")
                        .accessibilityHidden(true)
                }
            }
            .padding(14)
            .frame(minHeight: 48)
            .background(selected ? LufyColor.gold.opacity(0.18) : LufyColor.card)
            .foregroundStyle(LufyColor.ink)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(selected ? LufyColor.gold : LufyColor.line, lineWidth: selected ? 2 : 1)
            )
        }
        .accessibilityAddTraits(selected ? .isSelected : AccessibilityTraits())
    }

    private func canContinue(_ question: Question) -> Bool {
        switch question.body {
        case .multipleChoice:
            return optionID != nil
        case .trueFalse:
            return flag != nil
        case .order:
            return order.count == questionCount(question)
        case .fillBlank:
            return !AnswerNormalizer.normalize(text).isEmpty
        }
    }

    private func questionCount(_ question: Question) -> Int {
        if case .order(let items, _) = question.body { return items.count }
        return 0
    }

    private func advance(_ question: Question) {
        answers[question.id] = captured(question)
        if index + 1 == questions.count {
            onComplete(answers)
        } else {
            index += 1
        }
    }

    private func captured(_ question: Question) -> SubmittedAnswer {
        switch question.body {
        case .multipleChoice:
            return .option(optionID ?? "")
        case .trueFalse:
            return .bool(flag ?? false)
        case .order:
            return .order(order.map(\.id))
        case .fillBlank:
            return .text(text)
        }
    }

    private func prepare(_ question: Question) {
        optionID = nil
        flag = nil
        text = ""
        if case .order(let items, let correct) = question.body {
            var shuffled = items.shuffled()
            if shuffled.map(\.id) == correct, shuffled.count > 1 {
                shuffled.swapAt(0, 1)
            }
            order = shuffled
        } else {
            order = []
        }
    }

    private func move(_ offset: Int, by delta: Int) {
        let target = offset + delta
        guard order.indices.contains(target) else { return }
        order.swapAt(offset, target)
    }
}

struct ReviewView: View {
    @Environment(Library.self) private var library
    @Environment(LearnerRepository.self) private var repository
    @State private var active: Question?
    @State private var feedback: ReviewOutcome?

    private var due: [Question] {
        repository.engine.dueQuestions(state: repository.state, catalog: library.catalog, on: Date())
    }

    var body: some View {
        NavigationStack {
            PaperScreen {
                Group {
                    if let active {
                        reviewSession(active)
                    } else if due.isEmpty {
                        ContentUnavailableView(
                            "Nada para hoy",
                            systemImage: "checkmark.circle",
                            description: Text("Las preguntas que falles en una lección vuelven al día siguiente.")
                        )
                    } else {
                        List(due) { question in
                            Button(question.prompt) {
                                open(question)
                            }
                            .frame(minHeight: 44)
                        }
                        .scrollContentBackground(.hidden)
                    }
                }
            }
            .navigationTitle("Repaso")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
    }

    @ViewBuilder
    private func reviewSession(_ question: Question) -> some View {
        if let feedback {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Label(feedback.correct ? "Correcta" : "Para repasar", systemImage: feedback.correct ? "checkmark.circle" : "arrow.clockwise")
                        .font(.headline)
                        .foregroundStyle(feedback.correct ? LufyColor.good : LufyColor.warn)
                    Text(question.prompt)
                        .font(.body)
                    Text(feedback.explanation)
                        .font(.body)
                        .foregroundStyle(LufyColor.muted)
                    if feedback.xpAwarded > 0 {
                        Text("Sumaste \(feedback.xpAwarded) XP.")
                            .foregroundStyle(LufyColor.gold)
                    }
                    Button("Seguir") {
                        self.feedback = nil
                        active = nil
                    }
                    .buttonStyle(WineButtonStyle())
                }
                .padding(20)
            }
        } else {
            QuizFlow(questions: [question]) { answers in
                guard let answer = answers[question.id] else { return }
                submit(question, answer: answer)
            }
        }
    }

    private func open(_ question: Question) {
        feedback = nil
        active = question
    }

    private func submit(_ question: Question, answer: SubmittedAnswer) {
        guard let (state, outcome) = try? repository.engine.submitReview(
            state: repository.state,
            catalog: library.catalog,
            questionID: question.id,
            answer: answer,
            on: Date()
        ) else { return }
        repository.replace(state)
        feedback = outcome
    }
}
