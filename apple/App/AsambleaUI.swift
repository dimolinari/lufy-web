import SwiftUI
import LufyCore

struct PantallaAsamblea: View {
    @Environment(FeedTienda.self) private var feed
    @Environment(CatalogoTienda.self) private var tienda
    @State private var busqueda = ""
    @State private var provincia = ""
    @State private var partido = ""

    var body: some View {
        Group {
            if let asamblea = feed.asamblea {
                lista(asamblea)
            } else {
                VStack(spacing: 12) {
                    Text("No se pudo abrir el índice de la Asamblea.")
                        .multilineTextAlignment(.center)
                    if let origen = tienda.catalogo?.origen {
                        Button("Reintentar") {
                            Task { await feed.actualizarSiToca(origen: origen) }
                        }
                        .frame(minHeight: 44)
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color("Fondo"))
            }
        }
        .navigationTitle("Asamblea")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private func lista(_ asamblea: IndiceAsamblea) -> some View {
        let provincias = Array(Set(asamblea.asambleistas.map(\.provincia))).sorted()
        let partidos = Array(Set(asamblea.asambleistas.map(\.partido))).sorted()
        let visibles = asamblea.asambleistas.filter { persona in
            (provincia.isEmpty || persona.provincia == provincia)
                && (partido.isEmpty || persona.partido == partido)
                && coincide(persona.nombre, busqueda)
        }
        return List {
            Section {
                if asamblea.ejemplo {
                    Text(asamblea.aviso)
                        .font(.subheadline)
                        .foregroundStyle(Color("TextoSobreOro"))
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color("Oro"), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .accessibilityLabel(asamblea.aviso)
                }
                if let actualizado = feed.actualizado {
                    Text("Actualizado: \(actualizado)")
                        .font(.subheadline)
                        .foregroundStyle(Color("Suave"))
                        .accessibilityLabel("Actualizado: \(actualizado)")
                }
                filtro(titulo: "Provincia", vacio: "Todas", valor: $provincia, opciones: provincias)
                filtro(titulo: "Partido", vacio: "Todos", valor: $partido, opciones: partidos)
            }
            .listRowBackground(Color("Fondo"))

            if visibles.isEmpty {
                Text("Nadie coincide con ese filtro.")
                    .foregroundStyle(Color("Suave"))
                    .listRowBackground(Color("Fondo"))
            } else {
                ForEach(visibles) { persona in
                    NavigationLink {
                        PantallaPerfil(identificador: persona.id)
                    } label: {
                        HStack(spacing: 12) {
                            AvatarPerfil(nombre: persona.nombre, foto: persona.foto, origen: tienda.catalogo?.origen, lado: 48)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(persona.nombre)
                                    .font(.headline)
                                    .foregroundStyle(Color("Texto"))
                                Text("\(persona.provincia) · \(persona.partido)")
                                    .font(.subheadline)
                                    .foregroundStyle(Color("Suave"))
                            }
                        }
                        .frame(minHeight: 44)
                    }
                    .accessibilityLabel("\(persona.nombre), \(persona.provincia), \(persona.partido)")
                    .listRowBackground(Color("Tarjeta"))
                }
            }
        }
        .searchable(text: $busqueda, prompt: "Buscar por nombre")
        .background(Color("Fondo"))
        .scrollContentBackground(.hidden)
        .refreshable {
            if let origen = tienda.catalogo?.origen {
                await feed.actualizarSiToca(origen: origen)
            }
        }
    }

    private func filtro(titulo: String, vacio: String, valor: Binding<String>, opciones: [String]) -> some View {
        Menu {
            Picker(titulo, selection: valor) {
                Text(vacio).tag("")
                ForEach(opciones, id: \.self) { opcion in
                    Text(opcion).tag(opcion)
                }
            }
        } label: {
            HStack {
                Text(titulo)
                Spacer()
                Text(valor.wrappedValue.isEmpty ? vacio : valor.wrappedValue)
                    .foregroundStyle(Color("Enlace"))
            }
            .frame(minHeight: 44)
        }
        .accessibilityLabel("\(titulo): \(valor.wrappedValue.isEmpty ? vacio : valor.wrappedValue)")
    }

    private func coincide(_ nombre: String, _ consulta: String) -> Bool {
        let limpia = consulta.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !limpia.isEmpty else { return true }
        let plano = nombre.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "es"))
        let buscada = limpia.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "es"))
        return plano.contains(buscada)
    }
}

struct PantallaPerfil: View {
    let identificador: String
    @Environment(FeedTienda.self) private var feed
    @Environment(CatalogoTienda.self) private var tienda
    @Environment(\.openURL) private var openURL

    var body: some View {
        if let asamblea = feed.asamblea, let persona = asamblea.persona(id: identificador) {
            perfil(persona, asamblea: asamblea)
        } else {
            Text("Este perfil no está en el índice.")
                .padding()
        }
    }

    private func perfil(_ persona: Asambleista, asamblea: IndiceAsamblea) -> some View {
        ColumnaLectura {
            VStack(alignment: .leading, spacing: 16) {
                if asamblea.ejemplo {
                    Text(asamblea.aviso)
                        .font(.subheadline)
                        .foregroundStyle(Color("TextoSobreOro"))
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color("Oro"), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                HStack(alignment: .center, spacing: 16) {
                    AvatarPerfil(nombre: persona.nombre, foto: persona.foto, origen: tienda.catalogo?.origen, lado: 72)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(persona.nombre)
                            .font(.system(.title2, design: .serif))
                            .accessibilityAddTraits(.isHeader)
                        Text(persona.circunscripcion)
                            .font(.subheadline)
                            .foregroundStyle(Color("Suave"))
                    }
                }
                if let actualizado = feed.actualizado {
                    Text("Actualizado: \(actualizado)")
                        .font(.subheadline)
                        .foregroundStyle(Color("Suave"))
                }
                ficha("Provincia", persona.provincia)
                ficha("Partido", persona.partido)
                ficha("Bloque", persona.bloque)
                ficha("Período", persona.periodo)
                if !persona.comisiones.isEmpty {
                    Text("Comisiones")
                        .font(.headline)
                        .accessibilityAddTraits(.isHeader)
                    ForEach(Array(persona.comisiones.enumerated()), id: \.offset) { _, comision in
                        Text(comision)
                    }
                }
                Text("Proyectos presentados")
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                if persona.proyectos.isEmpty {
                    Text("No hay proyectos en este corte.")
                        .foregroundStyle(Color("Suave"))
                } else {
                    ForEach(persona.proyectos) { proyecto in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(proyecto.titulo).font(.headline)
                            Text("\(proyecto.estado) · \(proyecto.fecha)")
                                .font(.subheadline)
                                .foregroundStyle(Color("Suave"))
                            FuenteVista(fuente: proyecto.fuente, origen: tienda.catalogo?.origen ?? "")
                        }
                        .tarjeta()
                    }
                }
                Text("Votos registrados")
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                Text("Un voto no es un sello.")
                    .font(.footnote)
                    .foregroundStyle(Color("Suave"))
                let votos = feed.votaciones(de: persona.id)
                if votos.isEmpty {
                    Text("No hay votos registrados en este corte.")
                        .foregroundStyle(Color("Suave"))
                } else {
                    ForEach(votos, id: \.votacion.id) { item in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(item.votacion.titulo).font(.headline)
                            Text(etiqueta(item.voto))
                                .font(.subheadline.weight(.semibold))
                            Text("\(item.votacion.sesion) · \(item.votacion.acta) · \(item.votacion.fecha)")
                                .font(.subheadline)
                                .foregroundStyle(Color("Suave"))
                            FuenteVista(fuente: item.votacion.fuente, origen: tienda.catalogo?.origen ?? "")
                        }
                        .tarjeta()
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(item.votacion.titulo). Voto: \(etiqueta(item.voto)). \(item.votacion.acta).")
                    }
                }
                Text("Asistencia")
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                if let asistencia = persona.asistencia {
                    Text("\(asistencia.presente) de \(asistencia.sesiones) sesiones")
                        .font(.title3)
                    FuenteVista(fuente: asistencia.fuente, origen: tienda.catalogo?.origen ?? "")
                } else {
                    Text("Sin registro de asistencia en este corte.")
                        .foregroundStyle(Color("Suave"))
                }
                Text("Hallazgos de Lufy")
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                let ligados = feed.hallazgos(de: persona.hallazgos)
                if ligados.isEmpty {
                    Text("Lufy no publicó un hallazgo sobre este perfil.")
                        .foregroundStyle(Color("Suave"))
                } else {
                    ForEach(ligados) { hallazgo in
                        VStack(alignment: .leading, spacing: 8) {
                            PastillaSello(sello: hallazgo.sello)
                            Text(hallazgo.titulo).font(.headline)
                            Text(hallazgo.texto)
                            FuenteVista(fuente: hallazgo.fuente, origen: tienda.catalogo?.origen ?? "")
                        }
                        .tarjeta()
                    }
                }
                Button("Solicitar corrección") {
                    if let url = Configuracion.urlCorreccion(perfil: persona.id) {
                        openURL(url)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(Color("Vino"))
                .frame(minHeight: 44)
                .accessibilityHint("Abre un borrador de correo con el identificador del perfil y el campo nombre.")
                Text("Identificador: \(persona.id)")
                    .font(.caption)
                    .foregroundStyle(Color("Suave"))
                    .textSelection(.enabled)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
        }
        .navigationTitle(persona.nombre)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private func ficha(_ etiqueta: String, _ valor: String) -> some View {
        LabeledContent(etiqueta, value: valor)
    }

    private func etiqueta(_ voto: SentidoVoto) -> String {
        switch voto {
        case .afavor: "A favor"
        case .enContra: "En contra"
        case .abstencion: "Abstención"
        case .ausente: "Ausente"
        case .blanco: "En blanco"
        }
    }
}

struct AvatarPerfil: View {
    let nombre: String
    let foto: FotoPublica?
    let origen: String?
    var lado: CGFloat = 48

    var body: some View {
        Group {
            if let foto, let origen, foto.puedeMostrarse, let url = PoliticaEnlaces.urlLufy(origen: origen, ruta: foto.ruta) {
                AsyncImage(url: url) { fase in
                    if case .success(let imagen) = fase {
                        imagen.resizable().scaledToFill()
                    } else {
                        iniciales
                    }
                }
            } else {
                iniciales
            }
        }
        .frame(width: lado, height: lado)
        .clipShape(Circle())
        .accessibilityLabel(foto?.puedeMostrarse == true ? "Foto de \(nombre)" : "Iniciales de \(nombre)")
    }

    private var iniciales: some View {
        Text(NombresPublicos.iniciales(nombre))
            .font(.headline)
            .foregroundStyle(Color("TextoSobreOro"))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color("Vino"))
    }
}
