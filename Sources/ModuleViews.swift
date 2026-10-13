import SwiftUI

// 管理员组（auth/group，需要 __token__）
struct AuthGroupView: View {
    static let fields: [FormField] = [
        FormField("pid", "父级分组 ID", kind: .number, required: true, value: "0", section: "分组", footer: "0 表示顶级分组"),
        FormField("name", "分组名称", required: true, section: "分组"),
        FormField("rules", "权限规则 ID", kind: .textarea, section: "权限", footer: "英文逗号分隔的规则 ID，例如 1,2,3,62；留空表示无权限"),
        FormField("status", "状态", kind: .options([FieldOption("normal", "正常"), FieldOption("hidden", "禁用")]), value: "normal", section: "状态")
    ]
    var body: some View {
        GenericListView(title: "管理员组", path: "auth/group", icon: "person.3.fill",
                        color: .appBlue, primaryKey: "name", secondaryKeys: ["id"], statusKey: "status",
                        formFields: Self.fields, useToken: true,
                        formDefaults: ["pid": "0", "status": "normal"],
                        editInitial: { row in
                            var d = row.stringDict
                            if d["rules"] == nil { d["rules"] = "" }
                            return d
                        })
    }
}

// 权限规则（auth/rule，需要 __token__）
struct AuthRuleView: View {
    static let fields: [FormField] = [
        FormField("ismenu", "是否菜单", kind: .options([FieldOption("1", "是"), FieldOption("0", "否")]), value: "1", section: "规则"),
        FormField("pid", "父级 ID", kind: .number, required: true, value: "0", section: "规则"),
        FormField("name", "规则名称", placeholder: "如 category/index", required: true, section: "规则"),
        FormField("title", "标题", required: true, section: "规则"),
        FormField("icon", "图标", placeholder: "如 fa fa-list", section: "规则"),
        FormField("weigh", "权重", kind: .number, value: "0", section: "规则"),
        FormField("condition", "条件", kind: .textarea, section: "高级"),
        FormField("remark", "备注", kind: .textarea, section: "高级"),
        FormField("status", "状态", kind: .options([FieldOption("normal", "正常"), FieldOption("hidden", "禁用")]), value: "normal", section: "状态")
    ]
    var body: some View {
        GenericListView(title: "权限规则", path: "auth/rule", icon: "list.bullet.rectangle",
                        color: .appViolet, primaryKey: "title", secondaryKeys: ["name", "type"], statusKey: "status",
                        formFields: Self.fields, useToken: true,
                        formDefaults: ["ismenu": "1", "pid": "0", "weigh": "0", "status": "normal"],
                        editInitial: { $0.stringDict })
    }
}

// 会员组（user/group）
struct UserGroupView: View {
    static let fields: [FormField] = [
        FormField("name", "分组名称", required: true, section: "分组"),
        FormField("rules", "会员规则 ID", kind: .textarea, section: "权限", footer: "英文逗号分隔的规则 ID"),
        FormField("status", "状态", kind: .options([FieldOption("normal", "正常"), FieldOption("hidden", "禁用")]), value: "normal", section: "状态")
    ]
    var body: some View {
        GenericListView(title: "会员组", path: "user/group", icon: "person.2.badge.gearshape",
                        color: .appTeal, primaryKey: "name", secondaryKeys: ["id"], statusKey: "status",
                        formFields: Self.fields, formDefaults: ["status": "normal"],
                        editInitial: { $0.stringDict })
    }
}

// 会员规则（user/rule）
struct UserRuleView: View {
    static let fields: [FormField] = [
        FormField("ismenu", "是否菜单", kind: .options([FieldOption("1", "是"), FieldOption("0", "否")]), value: "1", section: "规则"),
        FormField("pid", "父级 ID", kind: .number, value: "0", section: "规则"),
        FormField("name", "规则名称", required: true, section: "规则"),
        FormField("title", "标题", required: true, section: "规则"),
        FormField("weigh", "权重", kind: .number, value: "0", section: "规则"),
        FormField("remark", "备注", kind: .textarea, section: "高级"),
        FormField("status", "状态", kind: .options([FieldOption("normal", "正常"), FieldOption("hidden", "禁用")]), value: "normal", section: "状态")
    ]
    var body: some View {
        GenericListView(title: "会员规则", path: "user/rule", icon: "list.bullet.indent",
                        color: .appGreen, primaryKey: "title", secondaryKeys: ["name"], statusKey: "status",
                        formFields: Self.fields, formDefaults: ["ismenu": "1", "pid": "0", "weigh": "0", "status": "normal"],
                        editInitial: { $0.stringDict })
    }
}

// 附件管理（general/attachment）
struct AttachmentView: View {
    static let fields: [FormField] = [
        FormField("url", "文件地址", required: true, section: "文件", footer: "相对路径或完整 URL"),
        FormField("urls", "云存储地址", section: "文件"),
        FormField("imagetype", "存储引擎", kind: .options([
            FieldOption("local", "本地"), FieldOption("aliyun", "阿里云 OSS"),
            FieldOption("qiniu", "七牛"), FieldOption("upyun", "又拍云"), FieldOption("oss", "OSS")
        ]), value: "local", section: "文件"),
        FormField("imageframes", "图片帧数", kind: .number, value: "0", section: "文件"),
        FormField("filesize", "文件大小（字节）", kind: .number, value: "0", section: "文件"),
        FormField("mimetype", "MIME 类型", placeholder: "image/jpeg", section: "文件"),
        FormField("extparam", "扩展参数", section: "高级"),
        FormField("uploadtime", "上传时间（时间戳）", kind: .number, value: "0", section: "高级"),
        FormField("storage", "存储位置", kind: .options([FieldOption("local", "本地"), FieldOption("cloud", "云存储")]), value: "local", section: "高级")
    ]
    var body: some View {
        GenericListView(title: "附件管理", path: "general/attachment", icon: "paperclip",
                        color: .appOrange, primaryKey: "url", secondaryKeys: ["mimetype", "filesize"], statusKey: nil,
                        formFields: Self.fields, addTitle: "新增附件",
                        formDefaults: ["imagetype": "local", "imageframes": "0", "filesize": "0", "uploadtime": "0", "storage": "local"],
                        editInitial: { $0.stringDict })
    }
}

// 在线命令（FastAdmin 的 CRUD 生成器，只读展示）
struct CommandView: View {
    var body: some View {
        GenericListView(title: "在线命令", path: "command", icon: "terminal.fill",
                        color: .gray, primaryKey: "command", secondaryKeys: ["type"], statusKey: "status")
    }
}
