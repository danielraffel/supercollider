import SwiftUI

/// Template picker that overlays on top of everything.
/// No sheet dismiss/appear — just fades in/out.
struct TemplateCoverView: View {
    @EnvironmentObject var app: AppState
    @StateObject private var fileManager = SCFileManager()

    var body: some View {
        ZStack {
            // Dim background
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.easeOut(duration: 0.2)) {
                        app.showTemplates = false
                    }
                }

            // Template content
            NavigationStack {
                templateContent
                    .navigationTitle("Choose a Template")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") {
                                withAnimation(.easeOut(duration: 0.2)) {
                                    app.showTemplates = false
                                }
                            }
                        }
                    }
            }
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .padding(.horizontal, 12)
            .padding(.vertical, 40)
            .shadow(color: .black.opacity(0.4), radius: 20, y: 8)
            .transition(.scale(scale: 0.95).combined(with: .opacity))
        }
        .animation(.easeOut(duration: 0.25), value: app.showTemplates)
    }

    var templateContent: some View {
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

            withAnimation(.easeOut(duration: 0.2)) {
                app.showTemplates = false
            }
            // Navigate to editor after template closes
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                app.showEditor = true
            }
        }
    }
}

/// Categories for template picker (reuse from TemplatePickerView)
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
