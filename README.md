# 优淘软件源 iOS 管理端

原生 SwiftUI 管理 App，对接优淘·解锁商店后台（FastAdmin）。不包含任何服务器代码，仅是一个 iOS 客户端。

## 构建（云端 GitHub Actions，无需 Mac）

1. 本仓库已配置 .github/workflows/build.yml，push 到 main 会自动构建。
2. 构建产物是未签名 IPA（YoutaoAdmin.ipa），在 Actions 页面的 Artifacts 里下载。
3. 用「全能签名工具 + P12 证书 + 描述文件」签名后安装到手机。

## 首次使用

1. 打开 App → 填「服务器设置」：站点地址（如 https://r.ytw.asia）、后台入口文件名（FRKToHDckx.php）、管理员账号、密码。
2. 登录（需输入后台图形验证码）。
3. 六个模块：概览 / 卡密 / 黑名单 / 监控 / 分类 / 设置。
