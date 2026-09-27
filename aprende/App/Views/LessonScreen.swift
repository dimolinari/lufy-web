import SwiftUI
import AprendeCore

struct LessonScreen: View {
    var lessonID: String
    @Environment(Library.self) private var library
    @Environment(LearnerRepository.self) private var repository
    @Environment(PremiumStore.self) private var premium
    @Environment(LessonPlayer.self) private var player
    @Environment(\.dismiss) private var dismiss
    @State private var phase: Phase = .listen
    @State private var outcome: QuizOutcome?
    @State private var errorMessage: String?
    @State private var currentID = ""

    private enum Phase {
        case listen
        case quiz
        case result
    }

    private var activeID: String { currentID.isEmpty ? lessonID : currentID }

    private var found: (course: Course, unit: CourseUnit, lesson: Lesson, index: Int)? {
        library.catalog.lesson(id: activeID)
    }

    var body: some View {
        PaperScreen {
            if let found {
                switch phase {
                case .listen:
                    listen(found.lesson)
                case .quiz:
                    QuizFlow(questions: found.lesson.questions) { answers in
                        submit(found.lesson, answers: answers)
                    }
                case .result:
                    if let quiz = outcome {
                        ResultView(lesson: found.lesson, outcome: quiz) {
                            phase = .quiz
                        } onClose: {
                            dismiss()
                        } onNext: { nextID in
                            currentID = nextID
                            outcome = nil
                            phase = .listen
                            loadPlayer()
                        }
                    }
                }
            } else {
                ContentUnavailableView("Lección no encontrada", systemImage: "questionmark", description: Text(lessonID))
            }
        }
        .navigationTitle(found?.lesson.title ?? "Lección")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .alert("No se pudo guardar", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("Entendido", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .onAppear(perform: loadPlayer)
    }

    private func loadPlayer() {
        guard let lesson = found?.lesson else { return }
        if player.lessonID != lesson.id {
            player.load(
                lesson: lesson,
                brandName: library.brand.appName,
                speed: repository.state.settings.playbackSpeed
            )
        }
    }

    private func listen(_ lesson: Lesson) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(lesson.summary)
                    .font(.body)
                    .foregroundStyle(LufyColor.muted)
                    .fixedSize(horizontal: false, vertical: true)
                if found?.course.disclaimer == StudyNotice.finance {
                    Text(StudyNotice.financeBody)
                        .font(.footnote)
                        .foregroundStyle(LufyColor.ink)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(LufyColor.card)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                if !lesson.resolvedFigures.isEmpty {
                    LessonFigureStack(figures: lesson.resolvedFigures, library: library.figures)
                }
                if let status = player.statusMessage {
                    Text(status)
                        .font(.subheadline)
                        .foregroundStyle(LufyColor.ink)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(LufyColor.card)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                PlayerControls(durationLabel: "Unos \(lesson.estimatedMinutes) minutos")
                DisclosureGroup("Leer el texto") {
                    Text(lesson.script)
                        .font(.body)
                        .foregroundStyle(LufyColor.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 8)
                }
                .font(.headline)
                .tint(LufyColor.wine)
                if !lesson.sources.isEmpty {
                    DisclosureGroup("Fuentes") {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(lesson.sources, id: \.self) { source in
                                Text(source)
                                    .font(.footnote)
                                    .foregroundStyle(LufyColor.muted)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .padding(.top, 8)
                    }
                    .font(.headline)
                    .tint(LufyColor.wine)
                }
                Button {
                    player.pause()
                    phase = .quiz
                } label: {
                    Text(player.finished ? "Responder las preguntas" : "Ya escuché, ir a las preguntas")
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 48)
                }
                .buttonStyle(.borderedProminent)
                .tint(LufyColor.wineFill)
                .foregroundStyle(LufyColor.onWine)
            }
            .padding(20)
        }
    }

    private func submit(_ lesson: Lesson, answers: [String: SubmittedAnswer]) {
        do {
            let (state, quiz) = try repository.engine.submitLesson(
                state: repository.state,
                catalog: library.catalog,
                lessonID: lesson.id,
                answers: answers,
                on: Date(),
                entitlements: premium.entitlements
            )
            repository.replace(state)
            outcome = quiz
            phase = .result
        } catch {
            errorMessage = "Revisa que la lección esté abierta y vuelve a intentar."
        }
    }
}

struct PlayerControls: View {
    var durationLabel: String
    @Environment(LessonPlayer.self) private var player
    @Environment(LearnerRepository.self) private var repository
    @ScaledMetric(relativeTo: .largeTitle) private var playSide = 76

    var body: some View {
        VStack(spacing: 16) {
            Text(durationLabel)
                .font(.subheadline)
                .foregroundStyle(LufyColor.muted)
            Slider(
                value: Binding(
                    get: { player.elapsed },
                    set: { player.seek(to: $0) }
                ),
                in: 0...max(player.duration, 1)
            )
            .tint(LufyColor.gold)
            .accessibilityLabel("Posición de la lección")
            .accessibilityValue(Text(clock(player.elapsed)))
            HStack {
                Text(clock(player.elapsed))
                Spacer()
                Text(clock(player.duration))
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(LufyColor.muted)
            .accessibilityHidden(true)
            HStack(spacing: 22) {
                skipButton(delta: -15, label: "Retroceder 15 segundos", systemName: "gobackward.15")
                Button {
                    player.toggle()
                } label: {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title)
                        .frame(width: max(playSide, 44), height: max(playSide, 44))
                        .background(LufyColor.wineFill)
                        .foregroundStyle(LufyColor.onWine)
                        .clipShape(Circle())
                }
                .accessibilityLabel(player.isPlaying ? "Pausar" : "Reproducir")
                skipButton(delta: 15, label: "Adelantar 15 segundos", systemName: "goforward.15")
            }
            Picker("Velocidad", selection: speedBinding) {
                ForEach(LearnerSettings.speeds, id: \.self) { speed in
                    Text(speedLabel(speed)).tag(speed)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityLabel("Velocidad de reproducción")
        }
        .padding(16)
        .background(LufyColor.card)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(LufyColor.line))
    }

    private var speedBinding: Binding<Double> {
        Binding(
            get: { repository.state.settings.playbackSpeed },
            set: { newValue in
                var state = repository.state
                state.settings.playbackSpeed = LearnerSettings.nearest(newValue)
                repository.replace(state)
                player.setSpeed(newValue)
            }
        )
    }

    private func skipButton(delta: Double, label: String, systemName: String) -> some View {
        Button {
            player.skip(by: delta)
        } label: {
            Image(systemName: systemName)
                .font(.title2)
                .frame(width: 44, height: 44)
        }
        .accessibilityLabel(label)
        .foregroundStyle(LufyColor.ink)
    }
}

struct ResultView: View {
    var lesson: Lesson
    var outcome: QuizOutcome
    var onRetry: () -> Void
    var onClose: () -> Void
    var onNext: (String) -> Void
    @Environment(Library.self) private var library

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(outcome.passed ? "Lección completa" : "Puedes intentarlo otra vez")
                    .font(.system(.title, design: .serif))
                    .foregroundStyle(LufyColor.ink)
                    .accessibilityAddTraits(.isHeader)
                Text("\(outcome.correctCount) de \(outcome.total) correctas.")
                    .font(.body)
                if outcome.xpAwarded > 0 {
                    Text("Sumaste \(outcome.xpAwarded) XP.")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(LufyColor.gold)
                } else if outcome.alreadyPassed {
                    Text("Esta lección ya estaba completa. El repaso no vuelve a sumar XP.")
                        .font(.body)
                        .foregroundStyle(LufyColor.muted)
                } else {
                    Text("Hacen falta tres de cuatro. Las que fallaste vuelven mañana.")
                        .font(.body)
                        .foregroundStyle(LufyColor.muted)
                }
                ForEach(outcome.grades) { grade in
                    gradeRow(grade)
                }
                if outcome.passed {
                    Button("Volver al camino", action: onClose)
                        .buttonStyle(WineButtonStyle())
                    if let next = library.catalog.nextLesson(after: lesson.id) {
                        Button("Siguiente: \(next.title)") {
                            onNext(next.id)
                        }
                        .buttonStyle(WineButtonStyle())
                    }
                } else {
                    Button("Reintentar", action: onRetry)
                        .buttonStyle(WineButtonStyle())
                }
            }
            .padding(20)
        }
    }

    private func gradeRow(_ grade: QuestionGrade) -> some View {
        let prompt = lesson.questions.first { $0.id == grade.id }?.prompt ?? ""
        return VStack(alignment: .leading, spacing: 6) {
            Label(grade.correct ? "Correcta" : "Para repasar", systemImage: grade.correct ? "checkmark.circle" : "arrow.clockwise")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(grade.correct ? LufyColor.good : LufyColor.warn)
            Text(prompt)
                .font(.body)
            Text(grade.explanation)
                .font(.subheadline)
                .foregroundStyle(LufyColor.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LufyColor.card)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .combine)
    }
}

struct WineButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(LufyColor.onWine)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(LufyColor.wineFill.opacity(configuration.isPressed ? 0.8 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

struct PaywallView: View {
    var courseTitle: String
    @Environment(PremiumStore.self) private var premium
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            PaperScreen {
                VStack(alignment: .leading, spacing: 16) {
                    Text(courseTitle)
                        .font(.system(.title2, design: .serif))
                    Text("Este curso es opcional y de pago. Las lecciones del núcleo siguen gratis, sin cuenta.")
                        .font(.body)
                        .fixedSize(horizontal: false, vertical: true)
                    if let message = premium.statusMessage {
                        Text(message)
                            .font(.subheadline)
                            .foregroundStyle(LufyColor.warn)
                    }
                    if premium.isConfigured, let product = premium.products.first {
                        Button("Comprar por \(product.displayPrice)") {
                            Task { await premium.purchase(product) }
                        }
                        .buttonStyle(WineButtonStyle())
                    } else {
                        Text("En esta versión el pago no está configurado. No hay nada que comprar.")
                            .font(.body)
                            .foregroundStyle(LufyColor.muted)
                    }
                    Spacer()
                }
                .padding(20)
            }
            .navigationTitle("Curso extra")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }
                }
            }
        }
    }
}

func clock(_ seconds: TimeInterval) -> String {
    guard seconds.isFinite else { return "0:00" }
    let total = max(0, Int(seconds.rounded()))
    return String(format: "%d:%02d", total / 60, total % 60)
}

func speedLabel(_ speed: Double) -> String {
    let formatter = NumberFormatter()
    formatter.locale = Locale(identifier: "es_EC")
    formatter.minimumFractionDigits = speed.truncatingRemainder(dividingBy: 1) == 0 ? 0 : 2
    formatter.maximumFractionDigits = 2
    let number = formatter.string(from: NSNumber(value: speed)) ?? String(speed)
    return "\(number)×"
}
