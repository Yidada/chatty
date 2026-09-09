import SwiftUI
import ChattyCore
import ChattyFixtureSupport

private enum ResourceKind: String, CaseIterable, Hashable {
    case runtimes = "Runtimes", agents = "Agents", squads = "Squads"
    var symbol: String {
        switch self { case .runtimes: "desktopcomputer"; case .agents: "sparkles"; case .squads: "person.3" }
    }
}

struct FixtureSettingsView: View {
    let snapshot: FixtureSnapshot

    var body: some View {
        List {
            Section("工作区") {
                Label(snapshot.workspace.name, systemImage: "building.2")
                    .accessibilityIdentifier("settings.workspace")
            }
            Section("运行与协作") {
                ForEach(ResourceKind.allCases, id: \.self) { kind in
                    NavigationLink(value: kind) { Label(kind.rawValue, systemImage: kind.symbol) }
                        .accessibilityIdentifier("settings.\(kind.rawValue.lowercased())")
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(ChattyTheme.background)
        .navigationDestination(for: ResourceKind.self) { kind in
            resources(kind).navigationTitle(kind.rawValue).navigationBarTitleDisplayMode(.inline)
        }
    }

    @ViewBuilder private func resources(_ kind: ResourceKind) -> some View {
        List {
            switch kind {
            case .runtimes:
                ForEach(snapshot.runtimes) { runtime in
                    VStack(alignment: .leading, spacing: 9) {
                        Text(runtime.displayName).font(.headline)
                        Text(runtime.deviceInfo ?? "").foregroundStyle(.secondary)
                        Label(runtime.status == "online" ? "在线" : "离线", systemImage: "circle.fill")
                            .font(.caption).foregroundStyle(ChattyTheme.accent)
                    }.padding(.vertical, 8)
                }
            case .agents:
                VStack(alignment: .leading, spacing: 8) {
                    Text(snapshot.mika.name).font(.headline)
                    Text("Mika · 当前测试 Agent").foregroundStyle(.secondary)
                }
            case .squads:
                ForEach(snapshot.squads) { squad in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(squad.name).font(.headline)
                        Text("\(squad.memberCount ?? 0) 位成员").foregroundStyle(.secondary)
                        Text(squad.description ?? "").font(.callout)
                    }.padding(.vertical, 8)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(ChattyTheme.background)
    }
}
