# ootd365-node

Local morning-outfit node: private COS object keys and a sidecar wardrobe manifest (V0 knife 1 only).

这是 Henry 简历里的开源核心。这里的 OSS 指开源软件（Open Source Software），不是某一家云的对象存储产品。对象放在私有 COS（Cloud Object Storage，云对象存储）里。整套东西是：本地晨间穿搭代理、私有 COS、以及一台树莓派 5（Raspberry Pi 5，下文称 Pi 5）家庭节点。

本仓库这一刀只锁定存储契约：对象键怎么命名，本机 sidecar 清单长什么样。sidecar 指放在对象旁边的本地索引文件，不进桶，也不进 git。

## V0 三刀

| 刀 | 内容 | 状态 |
| --- | --- | --- |
| 1 | 私有 COS 对象键 + 本地 sidecar 衣橱清单 | 本仓库 |
| 2 | 本地晨间代理 | 以后 |
| 3 | Pi 5 编排与晨间屏幕 | 以后 |

## 愿景与路线

长期目标是被动的晨间穿搭系统：早上收到天气和推荐搭配，出门时摄像头读出你穿了什么，你只在认错时纠正。手动登记的衣橱是这套系统的底库。阶段、闸门和边界见 [路线图](docs/roadmap.md)。

## V0 的边界

下面这些不在 V0 里，本仓库也不给它们留字段或资源。其中有的在路线图里排了后续阶段，进入时开新版本契约，不放宽 `wardrobe-v1`：

- 在线摄像头主路径（路线图 V1）
- 自动服装识别（路线图 V1）
- 虚拟试衣、虚拟形象（路线图 V3）
- 向量嵌入（embedding）、检测框（bbox，bounding box）（路线图 V1，本机存放）
- memo365 的整套能力
- 人脸数据（长期不做）
- 把 Pi 5 当作图形处理器（GPU，Graphics Processing Unit）（长期不做）
- 把云端当作主代理（长期不做）

人填写的 `acquired_at`、`season`、`wear_count`、`wash_count` 禁止靠看图推断。规则写在 [契约](docs/wardrobe-v1-contract.md)。路线图说明 V1 起 `wear_count`、`wash_count` 改为由人确认过的事件计算。

## 隐私

仓库里没有真实衣橱照片，没有真实 COS 密钥，也没有其他凭证。`examples/wardrobe-v1.sample.json` 里的 id、对象键和 `sha256` 都是假的。真实清单在节点本机的 `data/wardrobe-index.json`，已列入 `.gitignore`。

## 文件

- 路线图与边界地图：[docs/roadmap.md](docs/roadmap.md)
- 契约（对象键、清单规则、硬约束）：[docs/wardrobe-v1-contract.md](docs/wardrobe-v1-contract.md)
- JSON Schema（JSON 结构约定）：[schema/wardrobe-v1.schema.json](schema/wardrobe-v1.schema.json)
- 假样本：[examples/wardrobe-v1.sample.json](examples/wardrobe-v1.sample.json)
- 清单校验（schema + 跨字段规则）：[scripts/validate.mjs](scripts/validate.mjs)，测试在 [test/](test/)。`npm ci && npm run validate && npm test`，CI 每个 PR 都跑
- 本机真实清单（不入库）：`data/wardrobe-index.json`
- 事件契约（穿着、洗涤日志，镜子照片键）：[docs/wardrobe-events-v1-contract.md](docs/wardrobe-events-v1-contract.md)，schema 在 [schema/wardrobe-events-v1.schema.json](schema/wardrobe-events-v1.schema.json)，假样本在 [examples/wardrobe-events-v1.sample.json](examples/wardrobe-events-v1.sample.json)
- 本机真实事件日志（不入库）：`data/wardrobe-events.json`
- 家庭节点（局域网 HTTP，保管清单、日志和照片）：[server/](server/)，接口见 [docs/node-api.md](docs/node-api.md)。`npm run serve`
- 手机 app（Flutter，Android 与 iOS）：[app/](app/)

## 以后谁来读

第二刀的本地晨间代理和第三刀的 Pi 5 晨间屏幕，都读节点本机的 `data/wardrobe-index.json`。它们用这份 schema 校验清单，用节点本地凭证按 `cos_keys[].key` 从私有桶取对象，再用 `sha256` 核对原始字节。`sha256` 是 SHA-256（安全散列算法，256 位）的小写十六进制摘要。它们不把 `examples/` 里的假数据当成衣橱。读法和不变量见契约。晨间代理和屏幕还没有。现在有的是清单校验、家庭节点和用来每天记录的手机 app。

## 许可

[MIT](LICENSE)
