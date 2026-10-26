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

## V0 的边界

下面这些不在 V0 里，本仓库也不给它们留字段或资源：

- 在线摄像头主路径
- 自动服装识别
- 虚拟试衣、虚拟形象
- memo365 的整套能力
- 向量嵌入（embedding）、检测框（bbox，bounding box）、人脸数据
- 把 Pi 5 当作图形处理器（GPU，Graphics Processing Unit）
- 把云端当作主代理

人填写的 `acquired_at`、`season`、`wear_count`、`wash_count` 禁止靠看图推断。规则写在 [契约](docs/wardrobe-v1-contract.md)。

## 隐私

仓库里没有真实衣橱照片，没有真实 COS 密钥，也没有其他凭证。`examples/wardrobe-v1.sample.json` 里的 id、对象键和 `sha256` 都是假的。真实清单在节点本机的 `data/wardrobe-index.json`，已列入 `.gitignore`。

## 文件

- 契约（对象键、清单规则、硬约束）：[docs/wardrobe-v1-contract.md](docs/wardrobe-v1-contract.md)
- JSON Schema（JSON 结构约定）：[schema/wardrobe-v1.schema.json](schema/wardrobe-v1.schema.json)
- 假样本：[examples/wardrobe-v1.sample.json](examples/wardrobe-v1.sample.json)
- 本机真实清单（不入库）：`data/wardrobe-index.json`
- 事件规则（另文件；V0 只登记路径，不定义内容）：`data/wardrobe-events.json`

## 以后谁来读

第二刀的本地晨间代理和第三刀的 Pi 5 晨间屏幕，都读节点本机的 `data/wardrobe-index.json`。它们用这份 schema 校验清单，用节点本地凭证按 `cos_keys[].key` 从私有桶取对象，再用 `sha256` 核对原始字节。`sha256` 是 SHA-256（安全散列算法，256 位）的小写十六进制摘要。它们不把 `examples/` 里的假数据当成衣橱。读法和不变量见契约。这一刀没有代理、屏幕或上传代码。

## 许可

[MIT](LICENSE)
