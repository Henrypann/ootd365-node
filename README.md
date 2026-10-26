# ootd365-node

Local morning-outfit node: private COS object keys, a sidecar wardrobe manifest, and a local rule-based morning outfit command (V0 knives 1 and 2).

这是 Henry 简历里的开源核心。这里的 OSS 指开源软件（Open Source Software），不是某一家云的对象存储产品。对象放在私有 COS（Cloud Object Storage，云对象存储）里。整套东西是：本地晨间穿搭代理、私有 COS、以及一台树莓派 5（Raspberry Pi 5，下文称 Pi 5）家庭节点。

第一刀锁定存储契约。第二刀是本机晨间命令行（CLI，Command Line Interface）：读 sidecar 清单，用规则回答「今天穿什么」。第三刀才是 Pi 5 上的编排和屏幕。sidecar 指放在对象旁边的本地索引文件，不进桶，也不进 git。

## V0 三刀

| 刀 | 内容 | 状态 |
| --- | --- | --- |
| 1 | 私有 COS 对象键 + 本地 sidecar 衣橱清单 | 已锁定，见契约 |
| 2 | 本机晨间代理（规则，不跑模型） | 本仓库 `python -m morning` |
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

仓库里没有真实衣橱照片，没有真实 COS 密钥，也没有其他凭证。`examples/wardrobe-v1.sample.json` 里的 id、对象键和 `sha256` 都是假的。真实清单在节点本机的 `data/wardrobe-index.json`，已列入 `.gitignore`。晨间输出 `data/morning/` 和可选天气缓存 `data/weather.json` 同样只留在本机。

密钥、桶名、天气接口令牌不进 git。第二刀的快乐路径不需要它们，也不访问网络。

## 文件

- 契约（对象键、清单规则、硬约束）：[docs/wardrobe-v1-contract.md](docs/wardrobe-v1-contract.md)
- 清单 JSON Schema（JSON 结构约定）：[schema/wardrobe-v1.schema.json](schema/wardrobe-v1.schema.json)
- 假样本：[examples/wardrobe-v1.sample.json](examples/wardrobe-v1.sample.json)
- 第二刀说明：[docs/morning-agent-v0.md](docs/morning-agent-v0.md)
- 晨间输出 JSON Schema：[schema/morning-recommendation-v0.schema.json](schema/morning-recommendation-v0.schema.json)
- 本机命令行：`morning/`
- 本机真实清单（不入库）：`data/wardrobe-index.json`
- 事件规则（另文件；不存在则跳过）：`data/wardrobe-events.json`
- 晨间结果（不入库）：`data/morning/YYYY-MM-DD.json`

## 第二刀：本机晨间代理

这一刀不是 Pi 5 进程。Pi 5 以后只做编排和屏幕，不在这里跑模型，也不把 COS 原图读进内存。本进程只读清单 JSON，把选中的 `{ key, sha256 }` 原样抄进结果。`sha256` 是 SHA-256（安全散列算法，256 位）的小写十六进制摘要。

语言模型（LLM，Large Language Model）默认关闭。`--llm` 会直接拒绝。

在仓库根目录：

```bash
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt
.venv/bin/python -m morning --index examples/wardrobe-v1.sample.json --date 2026-10-26 --now 2026-10-26T00:30:00Z
```

不传 `--index` 时读 `data/wardrobe-index.json`。结果打印到标准输出，并写入 `data/morning/2026-10-26.json`。样本命令会在本机生成这个 gitignore 文件。

没有天气密钥时，用 `--temp-c` 和 `--condition`，例如 `--temp-c 8 --condition clear`。也可以把本机缓存放在 `data/weather.json`。事件文件不存在就跳过。

校验失败或凑不齐上装和下装时，同一路径只写 `error`，不编造套装。读法、冷天规则和输出字段见 [docs/morning-agent-v0.md](docs/morning-agent-v0.md)。

测试：

```bash
.venv/bin/python -m unittest discover -s tests -t . -v
```

## 谁来读清单

第二刀读节点本机的 `data/wardrobe-index.json`，不用假样本当活衣橱。它用 schema 校验形状，并检查键内 id 等于父记录 id、套装 `item_ids` 都能在 `items` 里找到。它不从私有桶取对象。取回后用 `sha256` 核对原始字节，仍是以后真正下载对象时的事。

第三刀的 Pi 5 晨间屏幕还没有写。本仓库没有上传代码。

## 许可

[MIT](LICENSE)
