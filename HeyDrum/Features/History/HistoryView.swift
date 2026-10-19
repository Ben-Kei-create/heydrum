import SwiftUI

struct HistoryView: View {
    @Environment(HistoryViewModel.self) private var history
    @State private var confirmDeleteAll = false
    @State private var confirmReset = false

    var body: some View {
        Group {
            if let problem = history.loadProblem {
                problemView(problem)
            } else if history.entries.isEmpty {
                emptyView
            } else {
                list
            }
        }
        .background(Palette.paper)
        .navigationTitle("履歴")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if history.loadProblem == nil && !history.entries.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("すべて削除", role: .destructive) { confirmDeleteAll = true }
                        .accessibilityIdentifier("historyDeleteAll")
                }
            }
        }
        .confirmationDialog("履歴100件以内をすべて削除します。元に戻せません", isPresented: $confirmDeleteAll, titleVisibility: .visible) {
            Button("すべて削除", role: .destructive) { Task { await history.deleteAll() } }
            Button("キャンセル", role: .cancel) {}
        }
        .alert("履歴", isPresented: Binding(get: { history.message != nil }, set: { if !$0 { history.message = nil } })) {
            Button("OK") { history.message = nil }
        } message: {
            Text(history.message ?? "")
        }
        .task { await history.reload() }
    }

    private var list: some View {
        List {
            ForEach(history.entries) { entry in
                HistoryRow(entry: entry) { Task { await history.play(entry) } }
                    .listRowInsets(EdgeInsets(top: 4, leading: Metrics.outerPadding, bottom: 4, trailing: Metrics.outerPadding))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button("削除", role: .destructive) { Task { await history.delete(entry) } }
                    }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .accessibilityIdentifier("historyList")
    }

    private var emptyView: some View {
        VStack(spacing: 8) {
            Text("履歴はまだありません").font(.headline).foregroundStyle(Palette.ink)
            Text("音声モードで読み上げた文章がここに残ります").font(.subheadline).foregroundStyle(Palette.muted)
                .multilineTextAlignment(.center)
        }
        .padding(Metrics.outerPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier("historyEmpty")
    }

    private func problemView(_ problem: HistoryLoadProblem) -> some View {
        VStack(spacing: 16) {
            Text("履歴を読み込めませんでした").font(.headline).foregroundStyle(Palette.ink)
            Text(problem == .unsupportedSchema
                 ? "この履歴ファイルは新しいバージョンのアプリで作成されたため読み込めません。元のファイルは変更していません。"
                 : "履歴ファイルが壊れている可能性があります。元のファイルは変更していません。")
                .font(.subheadline).foregroundStyle(Palette.muted).multilineTextAlignment(.center)
            Button("再試行") { Task { await history.reload() } }
                .buttonStyle(HeyDrumButtonStyle(kind: .secondary))
                .accessibilityIdentifier("historyRetry")
            Button("履歴を初期化", role: .destructive) { confirmReset = true }
                .frame(minHeight: Metrics.minTap)
                .accessibilityIdentifier("historyReset")
        }
        .padding(Metrics.outerPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .confirmationDialog("壊れた履歴ファイルを退避して、空の履歴で開始します。", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("初期化する", role: .destructive) { Task { await history.resetCorruptStore() } }
            Button("キャンセル", role: .cancel) {}
        }
    }
}
