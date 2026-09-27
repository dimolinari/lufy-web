import SwiftUI
import AprendeCore

struct SettingsView: View {
    @Environment(Library.self) private var library
    @Environment(LearnerRepository.self) private var repository
    @Environment(LessonPlayer.self) private var player
    @Environment(PremiumStore.self) private var premium

    var body: some View {
        NavigationStack {
            PaperScreen {
                Form {
                    Section("Reproducción") {
                        Picker("Velocidad", selection: speedBinding) {
                            ForEach(LearnerSettings.speeds, id: \.self) { speed in
                                Text(speedLabel(speed)).tag(speed)
                            }
                        }
                        Text("Sirve para el audio de la lección y para la voz del dispositivo. En la pantalla de bloqueo también puedes adelantar o retroceder 15 segundos.")
                            .font(.footnote)
                            .foregroundStyle(LufyColor.muted)
                    }
                    Section("Cursos extra") {
                        Text("Los cursos publicados en esta versión son gratis. Más adelante, Lufy puede ofrecer cursos opcionales de pago. El núcleo sigue sin cuenta y sin pago.")
                        ForEach(library.catalog.planned) { planned in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(planned.title)
                                Text(planned.access == .premium ? "Previsto como curso extra" : "Previsto, gratis")
                                    .font(.footnote)
                                    .foregroundStyle(LufyColor.muted)
                            }
                        }
                        if premium.isConfigured {
                            Button("Actualizar compras") {
                                Task { await premium.refresh() }
                            }
                        }
                    }
                    Section("Privacidad") {
                        Text("No hay cuenta, ni servidor, ni analítica, ni rastreo. La racha, la experiencia y los repasos se quedan en este dispositivo.")
                    }
                    Section("Lufy") {
                        Text("\(library.brand.appName) es la app de estudio de Lufy, un proyecto independiente de educación cívica y datos públicos del Ecuador. Hay caminos de historia, territorio, naturaleza, cultura, economía, gobierno y finanzas. Las lecciones explican. No acusan a nadie y no recomiendan inversiones.")
                        Text("Si una lección no tiene MP3, suena la voz en español del sistema. Para una narración grabada se usa el generador opcional, fuera de la app.")
                            .font(.footnote)
                            .foregroundStyle(LufyColor.muted)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Ajustes")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
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
}
