import SwiftUI

/// Template picker presented as fullScreenCover from the file sheet.
/// Sits on top of the sheet — no jarring dismiss/appear.
struct TemplateCoverView: View {
    @EnvironmentObject var app: AppState
    @StateObject private var fileManager = SCFileManager()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 24) {
                    ForEach(templateCategories, id: \.0) { category, templates in
                        VStack(alignment: .leading, spacing: 10) {
                            Text(category)
                                .font(.title2.weight(.bold))
                                .padding(.horizontal, 16)

                            LazyVGrid(columns: [
                                GridItem(.flexible(), spacing: 12),
                                GridItem(.flexible(), spacing: 12)
                            ], spacing: 12) {
                                ForEach(templates) { template in
                                    Button {
                                        createFromTemplate(template)
                                    } label: {
                                        templateCard(template)
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                }
                .padding(.vertical, 16)
            }
            .navigationTitle("Choose a Template")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        app.showTemplates = false
                        dismiss()
                    }
                }
            }
        }
    }

    private func templateCard(_ template: SCTemplate) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: template.icon)
                .font(.title2)
                .foregroundColor(template.iconColor)
            Text(template.name)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.primary)
            Text(template.description)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    private func createFromTemplate(_ template: SCTemplate) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyMMdd_HHmmss"
        let timestamp = formatter.string(from: Date())
        let safeName = template.name
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "/", with: "-")
        let filename = "\(safeName)_\(timestamp).scd"

        if let file = fileManager.createFile(name: filename) {
            let _ = fileManager.saveFile(file, content: template.code)
            app.codeText = template.code
            app.lastSavedText = template.code
            app.currentFile = file.path
            app.hasUnsavedChanges = false
            app.isEditing = true
            app.showTemplates = false
            dismiss()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                app.showEditor = true
            }
        }
    }
}

private var templateCategories: [(String, [SCTemplate])] {
    var dict: [String: [SCTemplate]] = [:]
    for t in scTemplates {
        dict[t.category, default: []].append(t)
    }
    let order = ["Getting Started", "Synthesis", "Patterns", "Effects", "Blank"]
    return order.compactMap { cat in
        dict[cat].map { (cat, $0) }
    }
}
