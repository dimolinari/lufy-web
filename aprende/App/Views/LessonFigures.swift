import SwiftUI
import Charts
import AprendeCore
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif

struct LessonFigureStack: View {
    let figures: [LessonFigure]
    let library: StudyLibrary

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            ForEach(figures) { figure in
                figureView(figure)
            }
        }
    }

    @ViewBuilder
    private func figureView(_ figure: LessonFigure) -> some View {
        switch figure.kind {
        case "chart":
            if let dataset = library.dataset(id: figure.ref) {
                ScrubSeriesChart(dataset: dataset)
            }
        case "sketch":
            if let dataset = library.dataset(id: figure.ref) {
                ProvinceSketch(dataset: dataset)
            }
        case "photo":
            if let credit = library.photo(id: figure.ref) {
                CreditedPhoto(credit: credit, url: library.photoURL(credit))
            }
        case "calculator":
            CompoundCalculator()
        default:
            EmptyView()
        }
    }
}

struct ScrubSeriesChart: View {
    let dataset: StudyDataset
    @State private var index = 0

    private var point: YearPoint? {
        guard dataset.points.indices.contains(index) else { return dataset.points.last }
        return dataset.points[index]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(dataset.title)
                .font(.headline)
                .foregroundStyle(LufyColor.ink)
            Text(valueLine)
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundStyle(valueColor)
                .accessibilityLabel(accessibilityValue)
            Text(yearLine)
                .font(.subheadline)
                .foregroundStyle(LufyColor.muted)
            chart
                .frame(height: 180)
            Text("Arrastra el dedo sobre el gráfico para ver cada año.")
                .font(.caption)
                .foregroundStyle(LufyColor.muted)
            Text(dataset.note)
                .font(.caption)
                .foregroundStyle(LufyColor.muted)
                .fixedSize(horizontal: false, vertical: true)
            Text(DataCaution.caption(dataset))
                .font(.caption2)
                .foregroundStyle(dataset.exampleData ? LufyColor.warn : LufyColor.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(LufyColor.card)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(LufyColor.line))
        .onAppear {
            index = max(0, dataset.points.count - 1)
        }
    }

    private var valueLine: String {
        guard let point else { return "—" }
        return ChartFormat.spanish(point.value, decimals: dataset.decimals) + (dataset.unit.isEmpty ? "" : " \(dataset.unit)")
    }

    private var yearLine: String {
        guard let point else { return "" }
        return String(point.year)
    }

    private var accessibilityValue: String {
        "\(dataset.title). \(valueLine). Año \(yearLine)."
    }

    private var valueColor: Color {
        guard dataset.kind == "bar", let point else { return LufyColor.ink }
        return point.value < 0 ? LufyColor.warn : LufyColor.good
    }

    private var chart: some View {
        Chart {
            ForEach(dataset.points) { item in
                if dataset.kind == "bar" {
                    BarMark(
                        x: .value("Año", String(item.year)),
                        y: .value("Valor", item.value)
                    )
                    .foregroundStyle(item.value < 0 ? LufyColor.warn : LufyColor.good)
                } else {
                    LineMark(
                        x: .value("Año", item.year),
                        y: .value("Valor", item.value)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(LufyColor.good)
                    AreaMark(
                        x: .value("Año", item.year),
                        y: .value("Valor", item.value)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(LufyColor.good.opacity(0.16))
                }
            }
            if let point {
                if dataset.kind == "bar" {
                    RuleMark(x: .value("Año", String(point.year)))
                        .foregroundStyle(LufyColor.ink.opacity(0.45))
                } else {
                    RuleMark(x: .value("Año", point.year))
                        .foregroundStyle(LufyColor.ink.opacity(0.45))
                    PointMark(x: .value("Año", point.year), y: .value("Valor", point.value))
                        .foregroundStyle(LufyColor.ink)
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4))
        }
        .chartOverlay { proxy in
            GeometryReader { geo in
                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { drag in
                                guard let frame = proxy.plotFrame else { return }
                                let plot = geo[frame]
                                let span = max(plot.width, 1)
                                let fraction = (drag.location.x - plot.origin.x) / span
                                index = ChartProbe.index(at: fraction, count: dataset.points.count)
                            }
                    )
            }
        }
        .animation(.snappy(duration: 0.25), value: index)
        .accessibilityHidden(true)
    }
}

struct ProvinceSketch: View {
    let dataset: StudyDataset

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(dataset.title)
                .font(.headline)
            Text(dataset.note)
                .font(.caption)
                .foregroundStyle(LufyColor.muted)
                .fixedSize(horizontal: false, vertical: true)
            GeometryReader { geo in
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(LufyColor.paper)
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(LufyColor.line)
                    ForEach(dataset.places) { place in
                        VStack(spacing: 2) {
                            Circle()
                                .fill(color(for: place.region))
                                .frame(width: 12, height: 12)
                            Text(short(place.name))
                                .font(.system(size: 8, weight: .semibold))
                                .foregroundStyle(LufyColor.ink)
                                .lineLimit(1)
                        }
                        .position(x: place.x * geo.size.width, y: place.y * geo.size.height)
                        .accessibilityLabel("\(place.name), región \(place.region)")
                    }
                }
            }
            .frame(height: 360)
            .accessibilityElement(children: .contain)
            legend
            DisclosureGroup("Lista de provincias") {
                ForEach(regions, id: \.self) { region in
                    Text(region)
                        .font(.subheadline.weight(.semibold))
                        .padding(.top, 6)
                    Text(names(in: region))
                        .font(.subheadline)
                        .foregroundStyle(LufyColor.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .tint(LufyColor.good)
            Text(DataCaution.caption(dataset))
                .font(.caption2)
                .foregroundStyle(LufyColor.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(LufyColor.card)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(LufyColor.line))
    }

    private var regions: [String] {
        var seen: [String] = []
        for place in dataset.places where !seen.contains(place.region) {
            seen.append(place.region)
        }
        return seen
    }

    private var legend: some View {
        HStack(spacing: 12) {
            ForEach(regions, id: \.self) { region in
                HStack(spacing: 4) {
                    Circle().fill(color(for: region)).frame(width: 8, height: 8)
                    Text(region).font(.caption2)
                }
            }
        }
        .accessibilityHidden(true)
    }

    private func names(in region: String) -> String {
        dataset.places.filter { $0.region == region }.map(\.name).joined(separator: ", ")
    }

    private func short(_ name: String) -> String {
        if name.count > 12 { return String(name.prefix(10)) }
        return name
    }

    private func color(for region: String) -> Color {
        switch region {
        case "Costa": return Color(hex: 0x2E8C9A)
        case "Sierra": return Color(hex: 0xC47B2B)
        case "Amazonía": return LufyColor.good
        default: return Color(hex: 0x3A6EA5)
        }
    }
}

struct CreditedPhoto: View {
    let credit: PhotoCredit
    let url: URL?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            image
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .accessibilityLabel(credit.title)
            Text(credit.title)
                .font(.subheadline.weight(.semibold))
            Text("\(credit.author) · \(credit.license)")
                .font(.caption)
                .foregroundStyle(LufyColor.muted)
            Text(credit.sourceURL)
                .font(.caption2)
                .foregroundStyle(LufyColor.muted)
                .textSelection(.enabled)
        }
    }

    @ViewBuilder
    private var image: some View {
        #if canImport(UIKit)
        if let url, let uiImage = UIImage(contentsOfFile: url.path) {
            Image(uiImage: uiImage).resizable().scaledToFit()
        } else {
            missing
        }
        #elseif canImport(AppKit)
        if let url, let nsImage = NSImage(contentsOf: url) {
            Image(nsImage: nsImage).resizable().scaledToFit()
        } else {
            missing
        }
        #else
        missing
        #endif
    }

    private var missing: some View {
        Text(credit.title)
            .frame(maxWidth: .infinity, minHeight: 120)
            .background(LufyColor.card)
    }
}

struct CompoundCalculator: View {
    @State private var principal = 100.0
    @State private var percent = 5.0
    @State private var years = 10.0
    @State private var monthly = 0.0
    @State private var index = 10

    private var inputs: (principal: Double, annualRate: Double, years: Int, monthly: Double) {
        CompoundInterest.clamped(
            principal: principal,
            annualPercent: percent,
            years: Int(years.rounded()),
            monthly: monthly
        )
    }

    private var points: [BalancePoint] {
        let value = inputs
        return CompoundInterest.balances(
            principal: value.principal,
            annualRate: value.annualRate,
            years: value.years,
            monthlyContribution: value.monthly
        )
    }

    private var selected: BalancePoint? {
        let list = points
        guard list.indices.contains(index) else { return list.last }
        return list[index]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Interés compuesto")
                .font(.headline)
            Text(selectedText)
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundStyle(LufyColor.good)
                .accessibilityLabel("Saldo estimado \(selectedText)")
            Text("Año \(selected?.year ?? 0) de la cuenta. No es una predicción de un banco.")
                .font(.subheadline)
                .foregroundStyle(LufyColor.muted)
            slider("Monto inicial", value: $principal, range: 0...5000, step: 50, suffix: " USD")
            slider("Tasa anual", value: $percent, range: 0...15, step: 0.5, suffix: " %")
            slider("Años", value: $years, range: 1...30, step: 1, suffix: "")
            slider("Aporte mensual", value: $monthly, range: 0...500, step: 10, suffix: " USD")
            Chart {
                ForEach(points) { item in
                    LineMark(
                        x: .value("Año", item.year),
                        y: .value("Saldo", item.value)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(LufyColor.good)
                    AreaMark(
                        x: .value("Año", item.year),
                        y: .value("Saldo", item.value)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(LufyColor.good.opacity(0.16))
                }
                if let selected {
                    RuleMark(x: .value("Año", selected.year))
                        .foregroundStyle(LufyColor.ink.opacity(0.45))
                }
            }
            .frame(height: 160)
            .chartOverlay { proxy in
                GeometryReader { geo in
                    Rectangle()
                        .fill(Color.clear)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { drag in
                                    guard let frame = proxy.plotFrame else { return }
                                    let plot = geo[frame]
                                    let fraction = (drag.location.x - plot.origin.x) / max(plot.width, 1)
                                    index = ChartProbe.index(at: fraction, count: points.count)
                                }
                        )
                }
            }
            .animation(.snappy(duration: 0.25), value: index)
            Text("Cálculo con los números que elegiste. Una tasa más alta aquí no es una recomendación de dónde poner el dinero.")
                .font(.caption)
                .foregroundStyle(LufyColor.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(LufyColor.card)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(LufyColor.line))
        .onChange(of: years) { _, _ in
            index = min(index, points.count - 1)
        }
    }

    private var selectedText: String {
        guard let selected else { return "—" }
        return ChartFormat.spanish(selected.value, decimals: 0) + " USD"
    }

    private func slider(_ title: String, value: Binding<Double>, range: ClosedRange<Double>, step: Double, suffix: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(title): \(ChartFormat.spanish(value.wrappedValue, decimals: step < 1 ? 1 : 0))\(suffix)")
                .font(.subheadline)
            Slider(value: value, in: range, step: step)
                .tint(LufyColor.good)
        }
        .accessibilityElement(children: .combine)
    }
}
