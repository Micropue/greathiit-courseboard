import ServiceManagement

@MainActor
enum LaunchAtLoginManager {
    static var isOn: Bool {
        switch SMAppService.mainApp.status {
        case .enabled, .requiresApproval:
            return true
        case .notRegistered, .notFound:
            return false
        @unknown default:
            return false
        }
    }

    static var needsApproval: Bool {
        SMAppService.mainApp.status == .requiresApproval
    }

    static var statusText: String {
        switch SMAppService.mainApp.status {
        case .enabled:
            return "已启用"
        case .requiresApproval:
            return "等待在系统设置中允许"
        case .notRegistered:
            return "关闭"
        case .notFound:
            return "当前应用位置不支持登录项"
        @unknown default:
            return "状态未知"
        }
    }

    static func setEnabled(_ enabled: Bool) throws {
        let service = SMAppService.mainApp

        if enabled {
            switch service.status {
            case .enabled, .requiresApproval:
                return
            case .notRegistered, .notFound:
                try service.register()
            @unknown default:
                try service.register()
            }
        } else {
            switch service.status {
            case .notRegistered, .notFound:
                return
            case .enabled, .requiresApproval:
                try service.unregister()
            @unknown default:
                try service.unregister()
            }
        }
    }

    static func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
