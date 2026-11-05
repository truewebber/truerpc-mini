import SwiftUI
import UniformTypeIdentifiers

/// A button that shows the selected file's name and opens a file picker on tap.
/// Uses SwiftUI's `.fileImporter`, which handles security-scoped resources automatically.
struct SecurityScopedFilePickerButton: View {
    let label: String
    let placeholder: String
    @Binding var url: URL?
    let contentTypes: [UTType]

    @State private var isPickerPresented = false

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Button {
                isPickerPresented = true
            } label: {
                Text(url?.lastPathComponent ?? placeholder)
                    .foregroundStyle(url == nil ? AnyShapeStyle(.secondary) : AnyShapeStyle(.primary))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: 160, alignment: .trailing)
            }
            .buttonStyle(.borderless)

            if url != nil {
                Button {
                    url = nil
                } label: {
                    Label("Clear", systemImage: "xmark.circle.fill")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
                .help("Clear")
            }
        }
        .fileImporter(
            isPresented: $isPickerPresented,
            allowedContentTypes: contentTypes,
            allowsMultipleSelection: false)
        { result in
            if case let .success(urls) = result {
                url = urls.first
            }
        }
    }
}

#if DEBUG
    #Preview("Empty", traits: .sizeThatFitsLayout) {
        @Previewable @State var url: URL?
        SecurityScopedFilePickerButton(
            label: "Custom CA Certificate",
            placeholder: "None",
            url: $url,
            contentTypes: [.data])
            .frame(width: 360)
    }

    #Preview("Selected", traits: .sizeThatFitsLayout) {
        @Previewable @State var url: URL? = URL(fileURLWithPath: "/tmp/ca.pem")
        SecurityScopedFilePickerButton(
            label: "Custom CA Certificate",
            placeholder: "None",
            url: $url,
            contentTypes: [.data])
            .frame(width: 360)
    }

    #Preview("Long Name", traits: .sizeThatFitsLayout) {
        @Previewable @State var url: URL? = URL(
            fileURLWithPath: "/Users/shared/certs/production/west-europe/customer-facing/intermediates/internal-corporate-root-certificate-authority.pem")
        SecurityScopedFilePickerButton(
            label: "Custom CA Certificate",
            placeholder: "None",
            url: $url,
            contentTypes: [.data])
            .frame(width: 360)
    }
#endif
