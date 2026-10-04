import SwiftUI
import AprendeCore

struct SettingsView: View {
    @Environment(Library.self) private var library
    @Environment(LearnerRepository.self) private var repository
    @Environment(LessonPlayer.self) private var player
    @Environment(PremiumStore.self) private var premium
    @State private var showingSubscription = false

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
                    Section("Compartir") {
                        Text("La racha, lo aprendido hoy y el voto de la provincia salen como una imagen de \(ShareCanvas.storyWidth)×\(ShareCanvas.storyHeight), el tamaño de una historia. La hoja del sistema la envía. No hay red propia.")
                        ShareStoryButton(
                            card: ShareCardBuilder.invite(appName: library.brand.appName, inviteURL: library.brand.inviteURL),
                            title: "Invitar"
                        )
                    }
                    Section("Suscripción") {
                        Text("Los cursos publicados son el núcleo y siguen gratis. La suscripción abre cursos extra, lecciones del dato más reciente y audiolibros narrados. Hoy está \(premium.subscriptionsEnabled ? "encendida" : "apagada").")
                        ForEach(library.catalog.planned) { planned in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(planned.title)
                                Text(OfferingCaption.planned(planned))
                                    .font(.footnote)
                                    .foregroundStyle(LufyColor.muted)
                            }
                        }
                        Button("Ver la suscripción") {
                            showingSubscription = true
                        }
                    }
                    Section("Privacidad") {
                        Text("No hay cuenta, ni servidor, ni analítica, ni rastreo. La racha, la experiencia y los repasos se quedan en este dispositivo.")
                    }
                    Section("Lufy") {
                        Text("\(library.brand.appName) es la app de estudio de Lufy, un proyecto independiente de educación cívica y datos públicos del Ecuador. Hay caminos de historia, territorio, naturaleza, cultura, economía, gobierno y finanzas. Las lecciones explican. No acusan a nadie y no recomiendan inversiones.")
                        Text("En un iPhone, el mapa, los gráficos y el hemiciclo se pueden colocar sobre una mesa. La cámara solo sirve para eso: no se guarda ni se envía. En Apple Vision Pro, el mismo modelo se abre en un volumen o en un salón.")
                            .font(.footnote)
                            .foregroundStyle(LufyColor.muted)
                        Text("Si una lección no tiene MP3, suena la voz en español del sistema. Para una narración grabada se usa el generador opcional, fuera de la app.")
                            .font(.footnote)
                            .foregroundStyle(LufyColor.muted)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .sheet(isPresented: $showingSubscription) {
                SubscriptionSheet()
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
