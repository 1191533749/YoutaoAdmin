import SwiftUI

// 管理员组
struct AuthGroupView: View {
    var body: some View {
        GenericListView(title: "管理员组", path: "auth/group", icon: "person.3.fill",
                        color: .appBlue, primaryKey: "name", secondaryKeys: ["id"], statusKey: "status")
    }
}

// 权限规则
struct AuthRuleView: View {
    var body: some View {
        GenericListView(title: "权限规则", path: "auth/rule", icon: "list.bullet.rectangle",
                        color: .appViolet, primaryKey: "title", secondaryKeys: ["name", "type"], statusKey: "status")
    }
}

// 会员组
struct UserGroupView: View {
    var body: some View {
        GenericListView(title: "会员组", path: "user/group", icon: "person.2.badge.gearshape",
                        color: .appTeal, primaryKey: "name", secondaryKeys: ["id"], statusKey: "status")
    }
}

// 会员规则
struct UserRuleView: View {
    var body: some View {
        GenericListView(title: "会员规则", path: "user/rule", icon: "list.bullet.indent",
                        color: .appGreen, primaryKey: "title", secondaryKeys: ["name"], statusKey: "status")
    }
}

// 附件管理
struct AttachmentView: View {
    var body: some View {
        GenericListView(title: "附件管理", path: "general/attachment", icon: "paperclip",
                        color: .appOrange, primaryKey: "url", secondaryKeys: ["mimetype", "filesize"], statusKey: nil)
    }
}

// 在线命令
struct CommandView: View {
    var body: some View {
        GenericListView(title: "在线命令", path: "command", icon: "terminal.fill",
                        color: .gray, primaryKey: "command", secondaryKeys: ["type"], statusKey: "status")
    }
}
