import Library
import SwiftUI

// 提取码订阅：输入提取码 → 校验 → 自动创建指向 /singbox/<code> 的远程订阅并设为当前激活。
@MainActor
public struct ShenxianyunImportView: View {
    @EnvironmentObject private var environments: ExtensionEnvironments
    @Environment(\.dismiss) private var dismiss

    @State private var code: String = ShenxianyunConfig.savedCode
    @State private var working = false
    @State private var message: String?

    public init() {}

    public var body: some View {
        VStack(spacing: 18) {
            Text("输入提取码")
                .font(.title2).bold()
            Text("输入神仙云提取码，自动导入订阅并选为当前配置。")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            TextField("提取码", text: $code)
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled(true)
                #if os(iOS)
                .textInputAutocapitalization(.never)
                #endif
                .font(.title3)

            if let message {
                Text(message).font(.footnote).foregroundStyle(.red)
            }

            Button {
                Task { await importCode() }
            } label: {
                HStack {
                    if working { ProgressView().padding(.trailing, 6) }
                    Text(working ? "导入中…" : "导入订阅")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(working || code.trimmingCharacters(in: .whitespaces).isEmpty)

            Button("没有提取码？去购买") {
                #if canImport(UIKit)
                    UIApplication.shared.open(ShenxianyunConfig.payNewURL())
                #endif
            }
            .font(.footnote)
        }
        .padding(24)
    }

    private func importCode() async {
        let c = code.trimmingCharacters(in: .whitespaces)
        guard !c.isEmpty else { return }
        working = true
        message = nil
        defer { working = false }

        let result = await ShenxianyunConfig.verify(c)
        if !result.ok {
            message = result.message
            return
        }

        // 复用官方的远程订阅创建逻辑：拉取 /singbox/<code> 配置、校验、落盘、入库。
        let vm = NewProfileViewModel()
        vm.profileName = "神仙云"
        vm.profileType = .remote
        vm.remotePath = ShenxianyunConfig.singboxURL(c)
        vm.autoUpdate = true
        vm.autoUpdateInterval = 60

        await vm.createProfile(environments: environments, onSuccess: { profile in
            // 设为当前激活配置
            await SharedPreferences.selectedProfileID.set(profile.mustID)
        })

        if !vm.createSucceeded {
            message = "导入失败，请检查提取码或网络后重试"
            return
        }

        ShenxianyunConfig.savedCode = c
        dismiss()
    }
}
