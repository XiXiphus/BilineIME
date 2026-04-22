import SwiftUI

struct SettingsPage<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(title)
                    .font(.largeTitle.weight(.semibold))
                    .padding(.bottom, 4)
                content
            }
            .padding(32)
            .frame(maxWidth: 820, alignment: .leading)
        }
    }
}

struct SettingsCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
        )
    }
}

struct SettingsSectionHeading: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.title3.weight(.semibold))
            .padding(.top, 8)
    }
}

struct SettingsRow<Trailing: View>: View {
    let title: String
    let subtitle: String?
    @ViewBuilder var trailing: Trailing

    init(
        title: String,
        subtitle: String? = nil,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .center, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 24)
            trailing
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        Divider()
            .padding(.leading, 20)
    }
}

struct StatusBadge: View {
    let text: String
    let isPositive: Bool

    var body: some View {
        Text(text)
            .font(.callout.weight(.medium))
            .foregroundStyle(isPositive ? .green : .secondary)
    }
}
