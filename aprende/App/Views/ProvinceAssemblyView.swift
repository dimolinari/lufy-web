import SwiftUI
import AprendeCore

struct ProvinceAssemblyView: View {
    @Environment(Library.self) private var library
    @Environment(LearnerRepository.self) private var repository
    @Environment(AsambleaStore.self) private var asamblea

    var body: some View {
        let people = asamblea.directory.legislators(in: selection)
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Tu provincia")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(LufyColor.ink)
                Text(FeedStamp.label(updatedAt: asamblea.directory.updatedAt))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(LufyColor.ink)
                Text(asamblea.statusMessage)
                    .font(.caption)
                    .foregroundStyle(LufyColor.muted)
                if asamblea.directory.exampleData {
                    Text("\(DataCaution.exampleBanner). Nombres, organizaciones y votos de esta lista son ficticios.")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(LufyColor.warn)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(LufyColor.card)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                NavigationLink(value: SpatialLink.hemicycle) {
                    Text("Ver el hemiciclo en 3D")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .tint(LufyColor.gold)
                .accessibilityHint("Coloca los escaños de esta copia, coloreados por un voto registrado.")
                Text(asamblea.directory.source.note)
                    .font(.footnote)
                    .foregroundStyle(LufyColor.muted)
                    .fixedSize(horizontal: false, vertical: true)
                Picker("Circunscripción", selection: selectionBinding) {
                    ForEach(districts, id: \.self) { name in
                        Text(name).tag(name)
                    }
                }
                .pickerStyle(.menu)
                .accessibilityLabel("Circunscripción")
                if people.isEmpty {
                    Text("Esta copia no lista asambleístas de \(selection).")
                        .font(.body)
                        .foregroundStyle(LufyColor.muted)
                } else {
                    ForEach(people) { person in
                        legislatorCard(person)
                    }
                }
                Text("\(asamblea.directory.source.institution). \(asamblea.directory.source.dataset). \(asamblea.directory.source.date).")
                    .font(.caption2)
                    .foregroundStyle(LufyColor.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(20)
        }
        .background(LufyColor.paper)
        .navigationTitle("Tu provincia")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task {
            await asamblea.refreshIfDue(manifestURL: library.brand.asambleaManifestURL)
        }
    }

    private var districts: [String] {
        var names = library.figures.dataset(id: "provincias-esquema")?.places.map(\.name) ?? []
        names.append(contentsOf: ["Nacional", "Exterior"])
        return names
    }

    private var selection: String {
        if let saved = repository.state.selectedDistrict, districts.contains(saved) {
            return saved
        }
        return districts.contains("Pichincha") ? "Pichincha" : (districts.first ?? "Pichincha")
    }

    private var selectionBinding: Binding<String> {
        Binding(
            get: { selection },
            set: { newValue in
                var state = repository.state
                state.selectedDistrict = newValue
                repository.replace(state)
            }
        )
    }

    private func legislatorCard(_ person: Legislator) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(person.publicName)
                .font(.title3.weight(.bold))
                .foregroundStyle(LufyColor.ink)
            Text(person.partyLabel)
                .font(.subheadline)
                .foregroundStyle(LufyColor.muted)
            Text(person.district)
                .font(.caption.weight(.semibold))
                .foregroundStyle(LufyColor.good)
            if person.committees.isEmpty {
                Text("Sin comisión registrada en esta copia.")
                    .font(.subheadline)
            } else {
                Text(person.committees.joined(separator: ", "))
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
            }
            ForEach(person.votes) { vote in
                VStack(alignment: .leading, spacing: 4) {
                    Text(vote.title)
                        .font(.subheadline.weight(.semibold))
                    Text("\(vote.date) · \(vote.choiceLabel)")
                        .font(.subheadline)
                        .foregroundStyle(voteColor(vote.choice))
                    Text(vote.source)
                        .font(.caption)
                        .foregroundStyle(LufyColor.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 4)
                .accessibilityElement(children: .combine)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LufyColor.card)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(LufyColor.line))
        .accessibilityElement(children: .combine)
    }

    private func voteColor(_ choice: String) -> Color {
        switch choice {
        case "afavor": return LufyColor.good
        case "encontra": return LufyColor.warn
        default: return LufyColor.ink
        }
    }
}
