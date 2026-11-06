import SwiftUI
import UIKit

struct SettingsView: View {
    @Bindable var vm: StudyViewModel
    @State private var permissionDenied = false
    @State private var togglingReminder = false

    private var reminderTime: Binding<Date> {
        Binding {
            Calendar.current.date(bySettingHour: vm.state.reminderHour, minute: vm.state.reminderMinute, second: 0, of: Date()) ?? Date()
        } set: { date in
            let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
            vm.setReminderTime(hour: comps.hour ?? 20, minute: comps.minute ?? 0)
        }
    }

    private var reminderEnabled: Binding<Bool> {
        Binding {
            vm.state.reminderEnabled
        } set: { enabled in
            togglingReminder = true
            Task { @MainActor in
                let ok = await vm.setReminder(enabled: enabled)
                permissionDenied = enabled && !ok
                togglingReminder = false
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    section("学习提醒") {
                        Toggle(isOn: reminderEnabled) {
                            rowLabel("每日提醒", detail: "到点提醒你背今天的一词，学完当天不再打扰", symbol: "bell.badge.fill")
                        }
                        .disabled(togglingReminder)
                        if vm.state.reminderEnabled {
                            DatePicker(selection: reminderTime, displayedComponents: .hourAndMinute) {
                                rowLabel("提醒时间", detail: nil, symbol: "clock.fill")
                            }
                        }
                        if permissionDenied {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("通知权限未开启，请在系统设置中允许「小象单词」发送通知。")
                                    .font(.footnote)
                                    .foregroundStyle(Theme.wrong)
                                Button("打开系统设置") {
                                    if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                                        UIApplication.shared.open(url)
                                    }
                                }
                                .font(.footnote.weight(.bold))
                                .foregroundStyle(Theme.gold)
                            }
                        }
                    }

                    section("发音") {
                        Toggle(isOn: $vm.state.autoPronounce) {
                            rowLabel("自动朗读", detail: "看到新词和答题后自动播放发音", symbol: "speaker.wave.2.fill")
                        }
                    }

                    section("词书与会员") {
                        navRow("更换词书", detail: vm.currentBook?.name, symbol: "book.closed.fill") { vm.go(.bookSelect) }
                        navRow(vm.state.isPremium ? "Pro 会员" : "升级 Pro", detail: vm.state.isPremium ? "已解锁" : "无限学习新词", symbol: "crown.fill") { vm.go(.premium) }
                    }

                    Text("小象单词 \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")")
                        .font(.caption)
                        .foregroundStyle(Theme.textTertiary)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 8)
                }
                .padding()
                .readableWidth()
            }
        }
        .pageChrome("设置") { vm.go(.home) }
        .tint(Theme.goldDeep)
        .task {
            // Reflect a permission revoked in system Settings.
            if vm.state.reminderEnabled, !(await ReminderScheduler.isAuthorized()) {
                permissionDenied = true
            }
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.textSecondary)
                .padding(.leading, 4)
            VStack(alignment: .leading, spacing: 16) {
                content()
            }
            .card()
        }
    }

    private func rowLabel(_ title: String, detail: String?, symbol: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .foregroundStyle(Theme.gold)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                if let detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(Theme.textTertiary)
                }
            }
        }
    }

    private func navRow(_ title: String, detail: String?, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                rowLabel(title, detail: detail, symbol: symbol)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Theme.textTertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
    }
}
