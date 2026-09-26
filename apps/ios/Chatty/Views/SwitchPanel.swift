import SwiftUI

/// 切换面板：先选 Harness，再从它支持的 Model 中选一个（参考 ChatGPT 的标题选模型）。
struct SwitchPanel: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var harnessID = ""
    @State private var modelID = ""

    var body: some View {
        NavigationStack {
            List {
                Section("引擎") {
                    ForEach(store.harnesses) { harness in
                        Button {
                            guard harness.isAvailable else { return }
                            harnessID = harness.id
                            if harness.model(modelID) == nil {
                                modelID = harness.defaultModelID ?? ""
                            }
                        } label: {
                            HStack {
                                Text(harness.name)
                                    .foregroundStyle(harness.isAvailable ? .primary : .secondary)
                                Spacer()
                                if let note = harness.note {
                                    Text(note).font(.caption).foregroundStyle(.secondary)
                                }
                                if harness.id == store.currentSession?.harnessID {
                                    Text("当前").font(.caption).foregroundStyle(.secondary)
                                }
                                if harness.id == harnessID {
                                    Image(systemName: "checkmark").foregroundStyle(.tint)
                                }
                            }
                        }
                        .disabled(!harness.isAvailable)
                    }
                }

                Section {
                    ForEach(store.harness(harnessID)?.models ?? []) { model in
                        Button {
                            modelID = model.id
                        } label: {
                            HStack {
                                Text(model.name).foregroundStyle(.primary)
                                Spacer()
                                if model.id == modelID {
                                    Image(systemName: "checkmark").foregroundStyle(.tint)
                                }
                            }
                        }
                    }
                } header: {
                    Text("模型（只列 \(store.harness(harnessID)?.name ?? "") 支持的）")
                } footer: {
                    Text("换引擎后，对话会压缩成摘要交给新引擎，工作目录保持不变。")
                }
            }
            .navigationTitle("切换引擎与模型")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    store.switchEngine(harnessID: harnessID, modelID: modelID)
                    dismiss()
                } label: {
                    Text(confirmTitle).frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!hasChange)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
        }
        .onAppear {
            harnessID = store.currentSession?.harnessID ?? ""
            modelID = store.currentSession?.modelID ?? ""
        }
    }

    private var hasChange: Bool {
        guard let session = store.currentSession else { return false }
        return !modelID.isEmpty && (session.harnessID != harnessID || session.modelID != modelID)
    }

    private var confirmTitle: String {
        guard let session = store.currentSession else { return "确定" }
        if session.harnessID != harnessID {
            return "切换到 \(store.harness(harnessID)?.name ?? harnessID)"
        }
        if session.modelID != modelID {
            return "使用 \(store.modelName(harnessID: harnessID, modelID: modelID))"
        }
        return "未修改"
    }
}
