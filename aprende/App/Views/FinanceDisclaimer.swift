import SwiftUI
import AprendeCore

struct FinanceDisclaimer: View {
    var onAccept: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Antes de Finanzas")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(LufyColor.ink)
                    Text(StudyNotice.financeBody)
                        .font(.body)
                        .foregroundStyle(LufyColor.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Button(action: onAccept) {
                        Text("Entiendo: esto no es asesoría")
                            .font(.body.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 48)
                    }
                    .buttonStyle(WineButtonStyle())
                }
                .padding(24)
            }
            .background(LufyColor.paper)
        }
        .presentationDetents([.medium, .large])
    }
}
