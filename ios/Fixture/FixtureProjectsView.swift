import SwiftUI
import ChattyCore

struct FixtureProjectsView: View {
    let projects: [Project]

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                Text("按项目查看所有 Issues 的进度").font(.callout).foregroundStyle(.secondary)
                ForEach(projects) { project in
                    NavigationLink {
                        ProjectPreview(project: project)
                    } label: {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Label(project.title, systemImage: "folder").font(.headline)
                                Spacer()
                                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
                            }
                            ProgressView(value: project.progress)
                            HStack {
                                Text("\(project.doneCount ?? 0) / \(project.issueCount ?? 0) 已完成")
                                Spacer()
                                Text(project.progress, format: .percent.precision(.fractionLength(0)))
                            }
                            .font(.callout).foregroundStyle(.secondary)
                        }
                        .padding(20)
                        .background(ChattyTheme.surface, in: RoundedRectangle(cornerRadius: 22))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("project.\(project.id)")
                }
            }
            .padding(20)
        }
        .accessibilityIdentifier("projects.list")
        .background(ChattyTheme.background)
    }
}

private struct ProjectPreview: View {
    let project: Project
    var body: some View {
        List {
            Section("项目进度") {
                LabeledContent("总数", value: "\(project.issueCount ?? 0)")
                LabeledContent("已完成", value: "\(project.doneCount ?? 0)")
                ProgressView(value: project.progress)
            }
            Section { Text("当前为合成数据的只读预览。").foregroundStyle(.secondary) }
        }
        .navigationTitle(project.title)
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .background(ChattyTheme.background)
    }
}
