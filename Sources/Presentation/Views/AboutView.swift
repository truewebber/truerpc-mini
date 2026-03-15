import AppKit
import SwiftUI

public struct AboutView: View {
    @ObservedObject var viewModel: AboutViewModel
    @Environment(\.dismiss) private var dismiss

    public init(viewModel: AboutViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 0) {
            appHeaderSection

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    buildSection
                    appSection
                    developerSection
                    trueRPCPromoSection
                }
                .padding(20)
            }

            Divider()

            HStack {
                Spacer()
                Button("Close") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .frame(width: 500)
    }

    // MARK: - Header

    private var appHeaderSection: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 80, height: 80)

            VStack(alignment: .leading, spacing: 6) {
                Text(viewModel.info.appName)
                    .font(.title2)
                    .fontWeight(.semibold)

                HStack(spacing: 6) {
                    versionBadge("v\(viewModel.info.marketingVersion)")
                    versionBadge("build \(viewModel.info.buildVersion)")
                }

                Text(viewModel.info.shortDescription)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(20)
    }

    // MARK: - Build section

    private var buildSection: some View {
        infoCard(title: "Build") {
            cardRow(label: "Swift", value: viewModel.info.swiftVersion)
            Divider().padding(.leading, 16)
            cardRow(label: "Xcode", value: viewModel.info.xcodeVersion)
        }
    }

    // MARK: - Developer section

    private var developerSection: some View {
        infoCard(title: "Developer") {
            cardRow(label: "Name", value: viewModel.info.developerName)
            Divider().padding(.leading, 16)
            cardLinkRow(label: "Website", rawURL: viewModel.info.developerWebsiteURL)
        }
    }

    // MARK: - App section

    private var appSection: some View {
        infoCard(title: "TrueRPC Mini") {
            cardLinkRow(label: "GitHub", rawURL: viewModel.info.githubURL)
            Divider().padding(.leading, 16)
            cardEmailRow(label: "Email", email: viewModel.info.developerEmail)
        }
    }

    // MARK: - TrueRPC promo

    private var trueRPCPromoSection: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "arrow.trianglehead.2.counterclockwise")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(Color.accentColor)
                .frame(width: 36, height: 36)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text("TrueRPC")
                        .font(.headline)
                    Text("coming soon")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.accentColor, in: Capsule())
                }

                Text("Full-featured gRPC client — modern UX, workspaces, api definitions and more.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let url = URL(string: "https://truerpc.app") {
                    Link("truerpc.app →", destination: url)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
            }

            Spacer()
        }
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.accentColor.opacity(0.35), lineWidth: 1))
    }

    // MARK: - Reusable card components

    private func infoCard(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .padding(.leading, 4)

            VStack(spacing: 0) {
                content()
            }
            .background(.background.secondary, in: RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(.separator, lineWidth: 0.5))
        }
    }

    private func cardRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 70, alignment: .leading)
            Text(value)
                .fontWeight(.medium)
            Spacer()
        }
        .font(.callout)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func cardLinkRow(label: String, rawURL: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 70, alignment: .leading)
            if let url = URL(string: rawURL), rawURL != "unknown" {
                Link(rawURL, destination: url)
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .truncationMode(.middle)
            } else {
                Text(rawURL).fontWeight(.medium)
            }
            Spacer()
        }
        .font(.callout)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func cardEmailRow(label: String, email: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 70, alignment: .leading)
            if let url = URL(string: "mailto:\(email)"), email != "unknown" {
                Link(email, destination: url)
                    .fontWeight(.medium)
            } else {
                Text(email).fontWeight(.medium)
            }
            Spacer()
        }
        .font(.callout)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func versionBadge(_ label: String) -> some View {
        Text(label)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(.quaternary, in: Capsule())
    }
}

#if DEBUG
    struct AboutView_Previews: PreviewProvider {
        static var previews: some View {
            AboutView(viewModel: AboutViewModel())
        }
    }
#endif
