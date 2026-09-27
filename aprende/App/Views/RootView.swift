import SwiftUI
import AprendeCore

@MainActor
@Observable
final class Library {
    let brand: Brand
    let catalog: Catalog

    init(brand: Brand, catalog: Catalog) {
        self.brand = brand
        self.catalog = catalog
    }
}

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var library: Library?
    @State private var repository: LearnerRepository?
    @State private var premium = PremiumStore(productIDs: [])
    @State private var player = LessonPlayer()
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if let library, let repository {
                MainShell()
                    .environment(library)
                    .environment(repository)
                    .environment(premium)
                    .environment(player)
            } else if let errorMessage {
                ContentUnavailableView(
                    "No se pudo abrir el camino",
                    systemImage: "book.closed",
                    description: Text(errorMessage)
                )
            } else {
                ProgressView("Abriendo tu camino")
                    .tint(LufyColor.wine)
            }
        }
        .task {
            guard library == nil else { return }
            do {
                let brand = try Brand.bundled()
                let catalog = try ContentLoader.loadBundled()
                let store = PremiumStore(productIDs: brand.storeKit.premiumProductIds)
                await store.refresh()
                premium = store
                repository = LearnerRepository(context: modelContext)
                library = Library(brand: brand, catalog: catalog)
            } catch {
                errorMessage = String(describing: error)
            }
        }
    }
}

private struct MainShell: View {
    var body: some View {
        TabView {
            PathView()
                .tabItem { Label("Camino", systemImage: "book.closed") }
            ReviewView()
                .tabItem { Label("Repaso", systemImage: "arrow.clockwise") }
            SettingsView()
                .tabItem { Label("Ajustes", systemImage: "gearshape") }
        }
        .tint(LufyColor.gold)
    }
}

struct PathView: View {
    @Environment(Library.self) private var library
    @Environment(LearnerRepository.self) private var repository
    @Environment(PremiumStore.self) private var premium
    @Environment(LessonPlayer.self) private var player
    @State private var paywallCourse: Course?
    @State private var path: [String] = []

    var body: some View {
        NavigationStack(path: $path) {
            PaperScreen {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        WineHeader(
                            title: library.brand.appName,
                            subtitle: "Escucha una lección corta. Luego responde, y la que falles vuelve otro día."
                        )
                        progressStrip
                        ForEach(library.catalog.courses) { course in
                            courseSection(course)
                        }
                        if !library.catalog.planned.isEmpty {
                            plannedSection
                        }
                    }
                    .padding(.bottom, 28)
                }
            }
            .navigationTitle("Camino")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .navigationDestination(for: String.self) { lessonID in
                LessonScreen(lessonID: lessonID)
            }
            .sheet(item: $paywallCourse) { course in
                PaywallView(courseTitle: course.title)
            }
            .safeAreaInset(edge: .bottom) {
                if player.lessonID != nil, path.isEmpty {
                    NowPlayingBar()
                }
            }
        }
    }

    private var progressStrip: some View {
        HStack(spacing: 12) {
            stat(title: "Racha", value: "\(repository.state.streak.current)", detail: "días")
            stat(title: "Experiencia", value: "\(repository.state.totalXP)", detail: "XP")
        }
        .padding(.horizontal, 20)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Racha de \(repository.state.streak.current) días. \(repository.state.totalXP) puntos de experiencia.")
    }

    private func stat(title: String, value: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(LufyColor.muted)
            Text(value)
                .font(.system(.title, design: .serif))
                .foregroundStyle(LufyColor.ink)
            Text(detail)
                .font(.caption)
                .foregroundStyle(LufyColor.gold)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(LufyColor.card)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(LufyColor.line))
    }

    private func courseSection(_ course: Course) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(course.title)
                .font(.system(.title2, design: .serif))
                .foregroundStyle(LufyColor.ink)
                .accessibilityAddTraits(.isHeader)
            Text(course.summary)
                .font(.body)
                .foregroundStyle(LufyColor.muted)
                .fixedSize(horizontal: false, vertical: true)
            ForEach(course.units) { unit in
                Text(unit.title)
                    .font(.headline)
                    .foregroundStyle(LufyColor.wine)
                    .padding(.top, 8)
                    .accessibilityAddTraits(.isHeader)
                VStack(spacing: 0) {
                    ForEach(Array(unit.lessons.enumerated()), id: \.element.id) { index, lesson in
                        lessonRow(course: course, lesson: lesson, index: index, isLast: index == unit.lessons.count - 1)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
    }

    private func lessonRow(course: Course, lesson: Lesson, index: Int, isLast: Bool) -> some View {
        let availability = repository.engine.availability(
            lessonID: lesson.id,
            catalog: library.catalog,
            state: repository.state,
            entitlements: premium.entitlements
        )
        return Button {
            open(lesson, availability: availability, course: course)
        } label: {
            HStack(alignment: .top, spacing: 14) {
                VStack(spacing: 0) {
                    node(for: availability)
                    if !isLast {
                        Rectangle()
                            .fill(LufyColor.gold.opacity(0.55))
                            .frame(width: 2)
                            .frame(maxHeight: .infinity)
                            .accessibilityHidden(true)
                    }
                }
                .frame(width: 28)
                VStack(alignment: .leading, spacing: 4) {
                    Text(lesson.title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(LufyColor.ink)
                        .multilineTextAlignment(.leading)
                    Text("Unos \(lesson.estimatedMinutes) minutos · \(statusText(availability))")
                        .font(.subheadline)
                        .foregroundStyle(LufyColor.muted)
                        .multilineTextAlignment(.leading)
                }
                .padding(.bottom, 18)
                Spacer(minLength: 0)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Lección \(index + 1). \(lesson.title). Unos \(lesson.estimatedMinutes) minutos. \(statusText(availability)).")
        .accessibilityHint(hint(availability))
    }

    private func node(for availability: LessonAvailability) -> some View {
        ZStack {
            Circle()
                .stroke(LufyColor.gold, lineWidth: 2)
                .background(Circle().fill(fill(availability)))
            Image(systemName: symbol(availability))
                .font(.caption.weight(.bold))
                .foregroundStyle(iconColor(availability))
        }
        .frame(width: 28, height: 28)
        .accessibilityHidden(true)
    }

    private func fill(_ availability: LessonAvailability) -> Color {
        switch availability {
        case .completed: return LufyColor.gold
        case .ready: return LufyColor.card
        case .lockedUntilPrevious, .needsPurchase: return LufyColor.paper
        }
    }

    private func iconColor(_ availability: LessonAvailability) -> Color {
        switch availability {
        case .completed: return LufyColor.wineFill
        default: return LufyColor.ink
        }
    }

    private func symbol(_ availability: LessonAvailability) -> String {
        switch availability {
        case .completed: return "checkmark"
        case .ready: return "ear"
        case .lockedUntilPrevious: return "lock"
        case .needsPurchase: return "lock"
        }
    }

    private func statusText(_ availability: LessonAvailability) -> String {
        switch availability {
        case .completed: return "Completa"
        case .ready: return "Lista para escuchar"
        case .lockedUntilPrevious: return "Se abre al completar la anterior"
        case .needsPurchase: return "Curso extra"
        }
    }

    private func hint(_ availability: LessonAvailability) -> String {
        switch availability {
        case .lockedUntilPrevious: return "Completa la lección anterior para abrirla."
        case .needsPurchase: return "Abre la información del curso extra."
        default: return "Abre la lección."
        }
    }

    private func open(_ lesson: Lesson, availability: LessonAvailability, course: Course) {
        switch availability {
        case .needsPurchase:
            paywallCourse = course
        case .lockedUntilPrevious:
            break
        case .ready, .completed:
            path.append(lesson.id)
        }
    }

    private var plannedSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Más adelante")
                .font(.system(.title3, design: .serif))
                .foregroundStyle(LufyColor.ink)
                .accessibilityAddTraits(.isHeader)
            ForEach(library.catalog.planned) { planned in
                VStack(alignment: .leading, spacing: 4) {
                    Text(planned.title)
                        .font(.headline)
                    Text(planned.summary)
                        .font(.subheadline)
                        .foregroundStyle(LufyColor.muted)
                    Text(planned.access == .premium ? "Próximamente · curso extra" : "Próximamente")
                        .font(.caption)
                        .foregroundStyle(LufyColor.gold)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(LufyColor.card)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(LufyColor.line))
            }
        }
        .padding(.horizontal, 20)
    }
}

private struct NowPlayingBar: View {
    @Environment(LessonPlayer.self) private var player

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(player.lessonTitle)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(player.isPlaying ? "Reproduciendo" : "En pausa")
                    .font(.caption)
                    .foregroundStyle(LufyColor.muted)
            }
            Spacer()
            Button {
                player.toggle()
            } label: {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel(player.isPlaying ? "Pausar" : "Reproducir")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .accessibilityElement(children: .contain)
    }
}
