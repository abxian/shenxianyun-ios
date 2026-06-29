import Library
import NetworkExtension
import SwiftUI

#if canImport(UIKit)
    import UIKit
#elseif canImport(AppKit)
    import AppKit
#endif

// 神仙云安卓式首页：大启动按钮 + 提取码订阅 / 更新节点 / 续费 / 节点选择 / 设置。
@MainActor
public struct ShenxianyunHomeView: View {
    @EnvironmentObject private var environments: ExtensionEnvironments

    @State private var showImport = false
    @State private var working = false
    @State private var toast: String?
    @State private var profileName = ""

    public init() {}

    private var connected: Bool {
        environments.extensionProfile?.status == .connected
    }

    private var statusText: String {
        switch environments.extensionProfile?.status {
        case .connected: return "已连接"
        case .connecting: return "连接中…"
        case .disconnecting: return "断开中…"
        default: return "未连接"
        }
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                VStack(spacing: 4) {
                    Text("神仙云").font(.largeTitle).bold()
                    Text("智能加速 · 稳定连接").font(.footnote).foregroundStyle(.secondary)
                }
                .padding(.top, 12)

                powerButton.padding(.top, 8)

                VStack(spacing: 2) {
                    Text(statusText).font(.headline)
                        .foregroundStyle(connected ? .green : .secondary)
                    Text(profileName.isEmpty ? "未选择配置" : profileName)
                        .font(.caption).foregroundStyle(.secondary)
                }

                if let toast {
                    Text(toast).font(.footnote).foregroundStyle(.secondary)
                }

                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        actionCard("提取码订阅", "key.fill") { showImport = true }
                        actionCard("更新节点", "arrow.triangle.2.circlepath") { Task { await updateNodes() } }
                    }
                    HStack(spacing: 12) {
                        NavigationLink {
                            GroupListView()
                        } label: { cardLabel("节点选择", "dot.radiowaves.left.and.right") }
                            .buttonStyle(.plain)
                        actionCard("续费提取码", "creditcard.fill") { openRenew() }
                    }
                    NavigationLink {
                        SettingView()
                    } label: { cardLabel("设置 / 配置文件切换", "gearshape.fill") }
                        .buttonStyle(.plain)
                }
                .padding(.horizontal)
            }
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity)
            .padding(.bottom, 24)
        }
        .sheet(isPresented: $showImport) {
            ShenxianyunImportView()
                .environmentObject(environments)
        }
        .onAppear { Task { await loadProfileName() } }
        .onChangeCompat(of: showImport) { presented in
            if !presented { Task { await loadProfileName() } }
        }
    }

    private var powerButton: some View {
        Button {
            Task { await toggle() }
        } label: {
            ZStack {
                Circle()
                    .fill(connected ? Color.green : Color.gray.opacity(0.3))
                    .frame(width: 168, height: 168)
                    .shadow(color: (connected ? Color.green : Color.black).opacity(0.3), radius: 18)
                VStack(spacing: 6) {
                    if working {
                        ProgressView().controlSize(.large).tint(.white)
                    } else {
                        Image(systemName: "power").font(.system(size: 48, weight: .bold))
                            .foregroundStyle(connected ? .white : .primary)
                        Text(connected ? "停止" : "启动").font(.title3).bold()
                            .foregroundStyle(connected ? .white : .primary)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(working || environments.extensionProfile == nil)
    }

    private func actionCard(_ title: String, _ icon: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) { cardLabel(title, icon) }.buttonStyle(.plain)
    }

    private func cardLabel(_ title: String, _ icon: String) -> some View {
        HStack {
            Image(systemName: icon).foregroundStyle(.green)
            Text(title).fontWeight(.medium)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(Color.gray.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func toggle() async {
        guard let profile = environments.extensionProfile else { return }
        working = true
        defer { working = false }
        do {
            if profile.status == .connected {
                try await profile.stop()
            } else {
                try await profile.start()
            }
        } catch {
            toast = "操作失败：\(error.localizedDescription)"
        }
    }

    private func loadProfileName() async {
        let id = await SharedPreferences.selectedProfileID.get()
        if let p = try? await ProfileManager.get(id) {
            await MainActor.run { profileName = p?.name ?? "" }
        }
    }

    private func updateNodes() async {
        working = true
        defer { working = false }
        let id = await SharedPreferences.selectedProfileID.get()
        guard let profile = try? await ProfileManager.get(id), let profile, profile.type == .remote else {
            toast = "请先用提取码导入订阅"
            return
        }
        do {
            try await profile.updateRemoteProfile()
            toast = "节点已更新"
        } catch {
            toast = "更新失败：\(error.localizedDescription)"
        }
    }

    private func openRenew() {
        let code = ShenxianyunConfig.savedCode
        let url = code.isEmpty ? ShenxianyunConfig.payNewURL() : ShenxianyunConfig.payRenewURL(code)
        #if canImport(UIKit)
            UIApplication.shared.open(url)
        #elseif canImport(AppKit)
            NSWorkspace.shared.open(url)
        #endif
    }
}
