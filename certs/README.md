# HTTPS 证书目录

将腾讯云下载的 Nginx 证书放在此目录，并使用以下固定文件名：

- `fullchain.crt`：腾讯云证书包中的 `*_bundle.crt`
- `private.key`：腾讯云证书包中的 `*.key`

证书和私钥已被 Git 忽略，不会提交到仓库，也不会在 `git pull` 时被覆盖。
