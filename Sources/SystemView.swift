import SwiftUI

// 系统：业务 / 权限 / 运维 / 设置 全部模块
struct SystemView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("业务与账号")) {
                    NavCell(icon: "person.2.fill", color: .appTeal, title: "会员管理", subtitle: "余额、积分、状态", dest: AnyView(UserView()))
                    NavCell(icon: "person.crop.circle.badge.checkmark", color: .appBlue, title: "管理员管理", subtitle: "账号、重置密码", dest: AnyView(AdminView()))
                }
                Section(header: Text("权限")) {
                    NavCell(icon: "person.3.fill", color: .appBlue, title: "管理员组", subtitle: "后台角色分组", dest: AnyView(AuthGroupView()))
                    NavCell(icon: "list.bullet.rectangle", color: .appViolet, title: "权限规则", subtitle: "菜单与节点权限", dest: AnyView(AuthRuleView()))
                    NavCell(icon: "person.2.badge.gearshape", color: .appTeal, title: "会员组", subtitle: "前台用户分组", dest: AnyView(UserGroupView()))
                    NavCell(icon: "list.bullet.indent", color: .appGreen, title: "会员规则", subtitle: "前台权限规则", dest: AnyView(UserRuleView()))
                }
                Section(header: Text("安全与运维")) {
                    NavCell(icon: "doc.text.magnifyingglass", color: .appOrange, title: "操作日志", subtitle: "后台操作记录", dest: AnyView(AdminLogView()))
                    NavCell(icon: "paperclip", color: .appOrange, title: "附件管理", subtitle: "已上传的文件", dest: AnyView(AttachmentView()))
                    NavCell(icon: "puzzlepiece.extension.fill", color: .appViolet, title: "插件管理", subtitle: "启用 / 禁用插件", dest: AnyView(AddonView()))
                    NavCell(icon: "terminal.fill", color: .gray, title: "在线命令", subtitle: "命令执行记录", dest: AnyView(CommandView()))
                }
                Section(header: Text("设置")) {
                    NavCell(icon: "ladybug.fill", color: .appViolet, title: "授权弹窗设置", subtitle: "dylib 公告 / 时间锁", dest: AnyView(ConfigView()))
                    NavCell(icon: "key.fill", color: .appAccent, title: "个人资料 / 改密码", subtitle: "昵称、邮箱、密码", dest: AnyView(ProfileView()))
                }
                Section {
                    Button {
                        state.logout()
                    } label: {
                        HStack {
                            Spacer()
                            Label("退出登录", systemImage: "rectangle.portrait.and.arrow.right")
                                .foregroundColor(.appRed)
                            Spacer()
                        }
                    }
                }
                Section(footer: Text("优淘后台 v1.0 · 站点 \(state.config?.siteRoot ?? "")")) {
                    EmptyView()
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("系统")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct NavCell: View {
    let icon: String
    let color: Color
    let title: String
    let subtitle: String
    let dest: AnyView

    var body: some View {
        NavigationLink(destination: dest) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 34, height: 34)
                    .background(RoundedRectangle(cornerRadius: 9).fill(color))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.body)
                    Text(subtitle).font(.caption).foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 2)
        }
    }
}
