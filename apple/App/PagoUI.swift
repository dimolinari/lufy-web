import SwiftUI
import LufyCore

struct BotonSeguir: View {
    let clase: Seguimiento.Clase
    let clave: String
    let titulo: String
    @Environment(TiendaPagos.self) private var pagos
    @Environment(SeguimientosTienda.self) private var seguimientos

    var body: some View {
        if Configuracion.capaDePagoActiva, pagos.suscrito, !clave.isEmpty {
            Button {
                seguimientos.alternar(clase, clave)
            } label: {
                let activo = seguimientos.sigue(clase, clave)
                Label(activo ? "Dejar de seguir" : titulo, systemImage: activo ? "bell.slash" : "bell")
            }
            .frame(minHeight: 44)
        }
    }
}

struct PantallaPago: View {
    @Environment(TiendaPagos.self) private var pagos
    @Environment(FeedTienda.self) private var feed
    @Environment(CatalogoTienda.self) private var tienda
    @Environment(\.openURL) private var openURL

    var body: some View {
        ColumnaLectura {
            VStack(alignment: .leading, spacing: 16) {
                if !Configuracion.capaDePagoActiva {
                    Text("El acceso anticipado no está activo en esta compilación. El contenido de base sigue abierto.")
                        .font(.body)
                } else {
                    Text("El contenido de base sigue gratis. La suscripción abre los hallazgos nuevos antes de la fecha publicada y los avisos de lo que sigues. Cada dossier se puede bajar con la suscripción o comprarlo aparte.")
                        .font(.body)
                    if pagos.suscrito {
                        Text("Suscripción activa.")
                            .font(.headline)
                    } else if let producto = pagos.producto(ProductosLufy.suscripcionMensual) {
                        Button("Suscribirme · \(producto.displayPrice)") {
                            Task { _ = await pagos.comprar(id: producto.id) }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color("Vino"))
                        .frame(minHeight: 44)
                    } else {
                        Text("El producto de suscripción no está en esta tienda de prueba.")
                            .font(.footnote)
                            .foregroundStyle(Color("Suave"))
                    }
                    Text("Dossiers")
                        .font(.system(.title2, design: .serif))
                        .accessibilityAddTraits(.isHeader)
                    let ahora = Date()
                    let visibles = feed.dossiers.filter { dossier in
                        AccesoTemprano.dossierVisible(
                            hasta: dossier.earlyAccessUntil,
                            ahora: ahora,
                            capaDePagoActiva: Configuracion.capaDePagoActiva,
                            suscrito: pagos.suscrito,
                            comprado: pagos.comprados.contains(dossier.producto)
                        )
                    }
                    if visibles.isEmpty {
                        Text("No hay dossiers en este corte.")
                            .foregroundStyle(Color("Suave"))
                    } else {
                        ForEach(visibles) { dossier in
                            dossierVista(dossier)
                        }
                    }
                    Button("Restaurar compras") {
                        Task { await pagos.restaurar() }
                    }
                    .frame(minHeight: 44)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
        }
        .navigationTitle("Acceso anticipado")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .background(Color("Fondo"))
    }

    @ViewBuilder
    private func dossierVista(_ dossier: DossierPublico) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(dossier.titulo).font(.headline)
            Text(dossier.texto)
            FuenteVista(fuente: dossier.fuente, origen: tienda.catalogo?.origen ?? "")
            if pagos.posee(dossier.producto) {
                if let origen = tienda.catalogo?.origen,
                   let copia = dossier.archivo,
                   let url = PoliticaEnlaces.urlLufy(origen: origen, ruta: copia.ruta) {
                    Button("Descargar el dossier") { openURL(url) }
                        .frame(minHeight: 44)
                } else {
                    Text("Lufy todavía no publicó el archivo de este dossier.")
                        .font(.footnote)
                        .foregroundStyle(Color("Suave"))
                }
            } else if let producto = pagos.producto(dossier.producto) {
                Button("Comprar dossier · \(producto.displayPrice)") {
                    Task { _ = await pagos.comprar(id: producto.id) }
                }
                .frame(minHeight: 44)
            }
        }
        .tarjeta()
    }
}

struct PantallaAvisos: View {
    @Environment(SeguimientosTienda.self) private var seguimientos
    @Environment(TiendaPagos.self) private var pagos

    var body: some View {
        ColumnaLectura {
            VStack(alignment: .leading, spacing: 16) {
                if !Configuracion.capaDePagoActiva {
                    Text("Los avisos no están activos en esta compilación.")
                } else if !pagos.suscrito {
                    Text("Los avisos de un perfil, una institución o un tema van con la suscripción.")
                } else {
                    Text("El aviso repite el título publicado. No añade una conclusión.")
                        .font(.footnote)
                        .foregroundStyle(Color("Suave"))
                    if seguimientos.avisosLocales {
                        Text("Los avisos de este dispositivo están activos.")
                            .font(.subheadline)
                    } else {
                        Button("Activar avisos en este dispositivo") {
                            Task { await seguimientos.activarAvisosLocales() }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color("Vino"))
                        .frame(minHeight: 44)
                    }
                    if seguimientos.avisos.isEmpty {
                        Text("Todavía no hay avisos.")
                            .foregroundStyle(Color("Suave"))
                    } else {
                        ForEach(seguimientos.avisos.reversed()) { aviso in
                            VStack(alignment: .leading, spacing: 6) {
                                if let sello = aviso.sello {
                                    PastillaSello(sello: sello)
                                }
                                Text(aviso.titulo).font(.headline)
                                Text(aviso.lineaFuente)
                                    .font(.footnote)
                                    .foregroundStyle(Color("Suave"))
                            }
                            .tarjeta()
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
        }
        .navigationTitle("Avisos")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .background(Color("Fondo"))
        .task {
            await seguimientos.revisarPermiso()
        }
    }
}
