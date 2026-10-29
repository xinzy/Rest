import Foundation
import os
import ServiceManagement

/// 开机自启（plan.md §2.1）：用 SMAppService 把主 App 注册为登录项。
@MainActor
final class LoginItem {
    private let logger = Logger(subsystem: "com.shaozeng.xiehuier", category: "LoginItem")

    var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// 已注册但还需要用户在系统设置中允许
    var requiresApproval: Bool {
        SMAppService.mainApp.status == .requiresApproval
    }

    /// 修改登录项；失败时抛出，由设置界面提示
    func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }

    /// 第一次启动时按默认值注册一次；ad-hoc 签名注册失败就保持关闭，不打扰用户
    func enableByDefaultIfNeeded() {
        let key = "loginItemConfigured"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.set(true, forKey: key)
        do {
            try setEnabled(true)
        } catch {
            logger.error("默认注册登录项失败：\(String(describing: error), privacy: .public)")
        }
    }
}
