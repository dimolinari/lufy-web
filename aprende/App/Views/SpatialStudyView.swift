import SwiftUI
import AprendeCore
#if os(visionOS)
import AVFoundation
import simd
#endif

struct SpatialStudyView: View {
    var link: String
    var directory: AsambleaDirectory? = nil
    var presentation: SpatialPresentation = .window

    @State private var exhibit: StageExhibit?
    @State private var feed: AsambleaDirectory?
    @State private var errorMessage: String?
    @State private var selection = ""
    @State private var preferCamera = true
    @State private var placementRequest = 0
    #if os(visionOS)
    @State private var voice = RoomVoice()
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    #endif

    var body: some View {
        Group {
            if let errorMessage {
                ContentUnavailableView("No se pudo armar el modelo", systemImage: "cube", description: Text(errorMessage))
            } else if let exhibit {
                stage(exhibit)
            } else {
                ProgressView("Armando el modelo")
                    .tint(LufyColor.gold)
            }
        }
        .task { load() }
        #if os(visionOS)
        .onDisappear { voice.stop() }
        #endif
    }

    @ViewBuilder
    private func stage(_ exhibit: StageExhibit) -> some View {
        switch presentation {
        case .window:
            window(exhibit)
        #if os(visionOS)
        case .volume:
            volume(exhibit)
        case .room:
            room(exhibit)
        #else
        case .volume, .room:
            window(exhibit)
        #endif
        }
    }

    private func window(_ exhibit: StageExhibit) -> some View {
        PaperScreen {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(title(exhibit))
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(LufyColor.ink)
                    notices(exhibit)
                    viewer(exhibit)
                        .frame(height: 420)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                    controls(exhibit)
                    detail(exhibit)
                    choices(exhibit)
                    credits(exhibit)
                }
                .padding(20)
            }
        }
        .navigationTitle(title(exhibit))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    #if os(visionOS)
    private func volume(_ exhibit: StageExhibit) -> some View {
        VolumeStage(exhibit: exhibit, scale: 1, position: SIMD3(0, -0.08, 0), onSelect: { selection = $0 })
            .id(exhibit.token)
            .ornament(attachmentAnchor: .scene(.bottom)) {
                VStack(alignment: .leading, spacing: 8) {
                    notices(exhibit)
                    detail(exhibit)
                }
                .padding(16)
                .frame(width: 420)
                .glassBackgroundEffect()
            }
    }

    private func room(_ exhibit: StageExhibit) -> some View {
        ZStack(alignment: .bottom) {
            VolumeStage(exhibit: exhibit, scale: 3.2, position: SIMD3(0, 0, -1.15), onSelect: { selection = $0 })
                .id(exhibit.token)
            VStack(alignment: .leading, spacing: 10) {
                Text(title(exhibit))
                    .font(.headline)
                notices(exhibit)
                detail(exhibit)
                Button(voice.speaking ? "Detener la narración" : "Escuchar mientras caminas") {
                    voice.toggle(script: narration(exhibit))
                }
                .buttonStyle(.borderedProminent)
                .tint(LufyColor.gold)
                Button("Salir del salón") {
                    voice.stop()
                    Task { await dismissImmersiveSpace() }
                }
            }
            .padding(18)
            .frame(maxWidth: 460, alignment: .leading)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
            .padding(.bottom, 24)
        }
    }
    #endif

    @ViewBuilder
    private func viewer(_ exhibit: StageExhibit) -> some View {
        #if os(visionOS)
        VolumeStage(exhibit: exhibit, scale: 1, position: .zero, onSelect: { selection = $0 })
            .id(exhibit.token)
        #elseif os(iOS)
        if TableMode.augmentedReality && preferCamera {
            ARTableStage(exhibit: exhibit, placementRequest: placementRequest, onSelect: { selection = $0 })
                .accessibilityLabel(exhibit.accessibilityLabel)
        } else {
            OrbitStage(exhibit: exhibit, onSelect: { selection = $0 })
        }
        #else
        OrbitStage(exhibit: exhibit, onSelect: { selection = $0 })
        #endif
    }

    @ViewBuilder
    private func controls(_ exhibit: StageExhibit) -> some View {
        #if os(iOS)
        if TableMode.augmentedReality {
            HStack {
                Button(preferCamera ? "Ver sin cámara" : "Colocar en la mesa") {
                    preferCamera.toggle()
                }
                if preferCamera {
                    Button("Volver a colocar") {
                        placementRequest += 1
                        selection = ""
                    }
                }
            }
            .buttonStyle(.bordered)
            .tint(LufyColor.gold)
            Text(preferCamera
                ? "Apunta a una mesa y toca para colocar el modelo. Después toca una pieza para leerla. La cámara no se guarda ni se envía."
                : "Este modo gira el modelo con el dedo, sin usar la cámara.")
                .font(.footnote)
                .foregroundStyle(LufyColor.muted)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            Text("Este dispositivo no ofrece realidad aumentada. Gira el modelo con el dedo.")
                .font(.footnote)
                .foregroundStyle(LufyColor.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        #elseif os(visionOS)
        HStack {
            Button("Abrir el volumen") {
                openWindow(id: "volumen", value: link)
            }
            Button("Entrar al salón") {
                Task { await openImmersiveSpace(id: "salon", value: link) }
            }
        }
        .buttonStyle(.bordered)
        .tint(LufyColor.gold)
        Text("El volumen deja el modelo en el espacio. En el salón puedes caminar alrededor mientras suena una explicación corta.")
            .font(.footnote)
            .foregroundStyle(LufyColor.muted)
            .fixedSize(horizontal: false, vertical: true)
        #else
        Text("Gira el modelo con el puntero. En un iPhone compatible, la misma pantalla lo coloca sobre una mesa.")
            .font(.footnote)
            .foregroundStyle(LufyColor.muted)
            .fixedSize(horizontal: false, vertical: true)
        #endif
    }

    @ViewBuilder
    private func notices(_ exhibit: StageExhibit) -> some View {
        switch exhibit {
        case .map(let map):
            Text(map.elevationNote)
                .font(.footnote)
                .foregroundStyle(LufyColor.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text(map.insetNote)
                .font(.footnote)
                .foregroundStyle(LufyColor.muted)
                .fixedSize(horizontal: false, vertical: true)
        case .series(let series) where series.exampleData:
            Text("\(DataCaution.exampleBanner). Estos números no son una serie oficial.")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(LufyColor.warn)
        case .series(let series):
            if let evidence = series.evidence {
                Text(evidence.rawValue)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(LufyColor.good)
            }
        case .hemicycle(let scene) where scene.exampleData:
            Text("\(DataCaution.exampleBanner). Nombres, organizaciones y votos de este hemiciclo son ficticios.")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(LufyColor.warn)
                .fixedSize(horizontal: false, vertical: true)
        case .hemicycle:
            EmptyView()
        }
    }

    @ViewBuilder
    private func detail(_ exhibit: StageExhibit) -> some View {
        if selection.isEmpty {
            Text("Toca una pieza para ver el dato.")
                .font(.subheadline)
                .foregroundStyle(LufyColor.muted)
        } else {
            switch exhibit {
            case .map(let map):
                if let province = map.province(id: selection) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(province.name)
                            .font(.title3.weight(.bold))
                        Text(province.region)
                        Text(province.evidence.rawValue)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(LufyColor.good)
                        Text(map.regionNote)
                            .font(.footnote)
                            .foregroundStyle(LufyColor.muted)
                        if province.inset {
                            Text(map.insetNote)
                                .font(.footnote)
                                .foregroundStyle(LufyColor.muted)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            case .series(let series):
                if let year = SpatialLink.year(fromBarID: selection), let bar = series.bar(year: year) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(series.title)
                            .font(.headline)
                        Text("\(bar.year): \(ChartFormat.spanish(bar.value, decimals: 2)) \(series.unit)")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(bar.belowZero ? LufyColor.warn : LufyColor.good)
                        Text(bar.belowZero ? "El rojo marca un número negativo. No es una recomendación." : "El verde marca un número cero o positivo. No es una recomendación.")
                            .font(.footnote)
                            .foregroundStyle(LufyColor.muted)
                        if let evidence = series.evidence {
                            Text(evidence.rawValue)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(LufyColor.good)
                        }
                        Text(series.caption)
                            .font(.footnote)
                            .foregroundStyle(LufyColor.muted)
                    }
                }
            case .hemicycle(let scene):
                if let seat = scene.seat(id: selection) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(seat.publicName)
                            .font(.title3.weight(.bold))
                        Text("\(seat.party) · \(seat.district)")
                            .foregroundStyle(LufyColor.muted)
                        Text(seat.choiceLabel)
                            .font(.headline)
                            .foregroundStyle(seat.choice == "encontra" ? LufyColor.warn : LufyColor.ink)
                        Text(scene.voteTitle)
                            .font(.subheadline)
                        Text(scene.sourceLine)
                            .font(.footnote)
                            .foregroundStyle(LufyColor.muted)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }

    @ViewBuilder
    private func choices(_ exhibit: StageExhibit) -> some View {
        switch exhibit {
        case .map(let map):
            DisclosureGroup("Provincias") {
                ForEach(map.provinces) { province in
                    Button("\(province.name), \(province.region)") {
                        selection = province.id
                    }
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                }
            }
        case .series(let series):
            DisclosureGroup("Años") {
                ForEach(series.bars) { bar in
                    Button("\(bar.year): \(ChartFormat.spanish(bar.value, decimals: 2)) \(series.unit)") {
                        selection = SpatialLink.barID(year: bar.year)
                    }
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                }
            }
        case .hemicycle(let scene):
            if scene.titles.count > 1 {
                Picker("Votación", selection: voteBinding(scene)) {
                    ForEach(scene.titles, id: \.self) { title in
                        Text(title).tag(title)
                    }
                }
                .pickerStyle(.menu)
            }
            DisclosureGroup("Escaños") {
                ForEach(scene.seats) { seat in
                    Button("\(seat.publicName). \(seat.choiceLabel)") {
                        selection = seat.id
                    }
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                }
            }
            Text(FeedStamp.label(updatedAt: scene.updatedAt))
                .font(.caption.weight(.semibold))
        }
    }

    @ViewBuilder
    private func credits(_ exhibit: StageExhibit) -> some View {
        switch exhibit {
        case .map(let map):
            Text(map.attribution)
                .font(.caption2)
                .foregroundStyle(LufyColor.muted)
                .fixedSize(horizontal: false, vertical: true)
        case .series(let series):
            Text(series.caption)
                .font(.caption2)
                .foregroundStyle(LufyColor.muted)
                .fixedSize(horizontal: false, vertical: true)
        case .hemicycle(let scene):
            Text(scene.sourceLine)
                .font(.caption2)
                .foregroundStyle(LufyColor.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func title(_ exhibit: StageExhibit) -> String {
        switch exhibit {
        case .map:
            return "Mapa del Ecuador"
        case .series(let series):
            return series.title
        case .hemicycle:
            return "Hemiciclo"
        }
    }

    private func narration(_ exhibit: StageExhibit) -> String {
        switch exhibit {
        case .map:
            return SpatialNarration.script(for: .map, exampleData: false)
        case .series(let series):
            return SpatialNarration.script(for: .series(series.datasetID), exampleData: series.exampleData)
        case .hemicycle(let scene):
            return SpatialNarration.script(for: .hemicycle, exampleData: scene.exampleData)
        }
    }

    private func voteBinding(_ scene: HemicycleScene) -> Binding<String> {
        Binding(
            get: { scene.voteTitle },
            set: { title in
                guard let feed else { return }
                selection = ""
                exhibit = .hemicycle(HemicycleLayout.scene(from: feed, voteTitle: title))
            }
        )
    }

    private func load() {
        guard exhibit == nil, errorMessage == nil else { return }
        do {
            switch SpatialLink.parse(link) {
            case .map:
                exhibit = .map(try ReliefMapBuilder.loadBundled())
            case .series(let id):
                let library = try FigureLibrary.loadBundled()
                guard let dataset = library.dataset(id: id) else {
                    errorMessage = "No está la serie \(id)."
                    return
                }
                exhibit = .series(SpatialSeriesLayout.make(dataset))
            case .hemicycle:
                let bundled = try FeedLibrary.loadBundled()
                let source = directory ?? SpatialHandoff.directory ?? bundled
                feed = source
                exhibit = .hemicycle(HemicycleLayout.scene(from: source))
            case nil:
                errorMessage = "No hay un modelo para abrir."
            }
        } catch {
            errorMessage = String(describing: error)
        }
    }
}

#if os(visionOS)
@MainActor
@Observable
final class RoomVoice {
    private let synthesizer = AVSpeechSynthesizer()
    private(set) var speaking = false

    func toggle(script: String) {
        if synthesizer.isSpeaking {
            stop()
            return
        }
        let utterance = AVSpeechUtterance(string: script)
        utterance.voice = SpanishVoice.pick()
        synthesizer.speak(utterance)
        speaking = true
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        speaking = false
    }
}
#endif
