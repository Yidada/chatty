import SwiftUI

/// 查看本轮改动。原型阶段展示演示 diff。
struct DiffSheet: View {
    let files: [FileChange]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("文件") {
                    ForEach(files) { file in
                        HStack {
                            Text(file.path)
                                .font(.system(.callout, design: .monospaced))
                                .lineLimit(1)
                                .truncationMode(.head)
                            Spacer()
                            Text("+\(file.added)").foregroundStyle(.green)
                            Text("−\(file.removed)").foregroundStyle(.red)
                        }
                        .font(.footnote.monospacedDigit())
                    }
                }

                if let first = files.first {
                    Section(first.path) {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(DemoData.sampleDiff().enumerated()), id: \.offset) { _, line in
                                Text("\(String(line.kind)) \(line.text)")
                                    .font(.system(.caption, design: .monospaced))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, 2)
                                    .padding(.horizontal, 6)
                                    .background(background(for: line.kind))
                            }
                        }
                        .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
                    }
                }
            }
            .navigationTitle("本轮改动")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }

    private func background(for kind: Character) -> Color {
        switch kind {
        case "+": Color.green.opacity(0.12)
        case "-": Color.red.opacity(0.12)
        default: Color.clear
        }
    }
}
