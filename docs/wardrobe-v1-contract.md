# 衣橱 V1 契约

Private COS object-key rules and the local sidecar wardrobe index (V0 knife 1).

这一份只锁定 V0 第一刀：私有桶里的对象键，以及本地节点或树莓派 5（Raspberry Pi 5，下文称 Pi 5）上的 sidecar 衣橱清单。sidecar 指放在对象旁边的本地索引，不进桶，也不进 git。第二刀（本地晨间代理）和第三刀（Pi 5 编排与晨间屏幕）以后按这里读数据。本文件不实现它们。

这里的 OSS 若出现在仓库介绍里，指开源软件（Open Source Software）。对象存储是私有 COS（Cloud Object Storage，云对象存储）。本契约不绑定某一家云的 SDK、地域或签名算法。

字段表与 [`schema/wardrobe-v1.schema.json`](../schema/wardrobe-v1.schema.json) 一起生效。改一边时同时改另一边。假样本在 [`examples/wardrobe-v1.sample.json`](../examples/wardrobe-v1.sample.json)。

## 对象键

键是桶内相对键。不以 `/` 开头，不含桶名，不含网址，不含查询串。

```text
wardrobe/v1/items/{item_id}/{asset_id}.{ext}
wardrobe/v1/outfits/{outfit_id}/{asset_id}.{ext}
```

路径已经区分单品和套装。清单里不设 `kind` 字段。

标识符 `{item_id}`、`{outfit_id}`、`{asset_id}` 使用同一语法：

```text
^[a-z0-9][a-z0-9_-]{0,63}$
```

`{ext}` 是分隔点后面的小写扩展名，1 到 8 个字母或数字：

```text
^[a-z0-9]{1,8}$
```

样本使用 `jpg`、`png`、`webp`。这一刀不规定转码，也不规定哪一张是封面。`cos_keys` 的数组顺序只是列表顺序。

单品上的每条 `key` 必须落在 `wardrobe/v1/items/` 下，且其中的 `{item_id}` 等于该单品的 `id`。套装上的每条 `key` 必须落在 `wardrobe/v1/outfits/` 下，且其中的 `{outfit_id}` 等于该套装的 `id`。同一条 `cos_keys` 里的 `key` 不得重复。

JSON Schema 校验键的形状：前缀、字符、扩展名，以及 `sha256`。键内 id 段、键不重复这类跨字段规则 schema 表达不了，统一列在下文「跨字段规则」。

仓库里只出现假键。下面这条是假的，桶里没有这个对象：

```text
wardrobe/v1/items/demo_item_navy_tee/demo_asset_front.jpg
```

## 桶与对象

- 桶保持私有。对象不做公开读。长期访问地址不写进清单，也不写进 git。
- 桶名和访问凭证放在节点本地环境。它们不进入清单字段，不进入本仓库。
- 已写入的对象键不再覆盖。要换一张图，就新分配 `asset_id`，写入新键，再更新本地清单里的指针。
- 清单可以改写，因为它是本地索引，不是 COS 对象。对象字节保持不变。
- `sha256` 是上传前原始字节的 SHA-256（安全散列算法，256 位），写成 64 个小写十六进制字符。这条叫 Iris Fix：摘要针对原始字节本身。它是内容散列，用来在取回后核对字节。同一条 `cos_keys` 记录必须同时带 `key` 和 `sha256`。

## 清单放哪

| 路径 | 角色 |
| --- | --- |
| `data/wardrobe-index.json` | 节点本机的真实清单。gitignore。可以不存在（空衣橱由节点自己建）。 |
| `schema/wardrobe-v1.schema.json` | 清单的 JSON Schema。入库。 |
| `examples/wardrobe-v1.sample.json` | 假样本。入库。不是活数据。 |
| `data/wardrobe-events.json` | 事件规则的预留路径。见下文。gitignore。 |

真实清单是 UTF-8 编码的 JSON 对象，形状由 schema 固定：

- `schema_version`：常量 `wardrobe-v1`
- `items`：单品数组，必填，可以为空数组
- `outfits`：套装数组，可省略

schema 拒绝未声明的属性。因此 embedding、人脸、bbox、自动识别置信度、虚拟形象资源和 `kind` 都放不进去。

## 事件规则

事件规则用另一个文件，不写进衣橱清单。V0 第一刀只登记路径：

```text
data/wardrobe-events.json
```

这一刀不定义该文件的字段、schema 或样本。文件可以不存在。代理和屏幕在以后的刀里再决定要不要读它。

## 单品字段

| 字段 | 必填 | 形状 | 填写者 |
| --- | --- | --- | --- |
| `id` | 是 | 标识符语法 | 人分配的稳定 id |
| `category` | 是 | `top`、`bottom`、`shoes`、`outer`、`other` | 人。V0 不含自动服装识别 |
| `season` | 是 | 字符串数组，元素为 `spring`、`summer`、`autumn`、`winter`，可为空数组，元素不重复 | 人。禁止看图推断 |
| `color` | 是 | 1 到 64 个字符的短标签，语言不限 | 人写下的颜色词 |
| `acquired_at` | 否 | `YYYY-MM-DD` | 人。禁止看图推断，也不要用文件时间补上 |
| `wear_count` | 是 | 大于等于 0 的整数 | 人维护的穿着次数。禁止看图推断。`0` 是人记下的零次 |
| `wash_count` | 是 | 大于等于 0 的整数 | 人维护的洗涤次数。禁止看图推断。`0` 是人记下的零次 |
| `status` | 是 | `active` 或 `retired` | 人 |
| `cos_keys` | 是 | `{ "key", "sha256" }` 数组，可以为空 | 节点在对象写入时记下。空数组表示还没有对象 |
| `updated_at` | 是 | UTC（Coordinated Universal Time，协调世界时）时间，`YYYY-MM-DDTHH:MM:SSZ` | 这条清单记录的更新时间 |

`season` 用英文枚举，方便以后的代理直接分支。含义：`spring` 春，`summer` 夏，`autumn` 秋，`winter` 冬。空数组表示人还没记录季节。四季都可穿时，写入全部四个值。这个字段禁止视觉推断。

`category` 的含义：`top` 上装，`bottom` 下装，`shoes` 鞋，`outer` 外搭，`other` 其他。人选定分类。自动识别不在 V0。

## 套装字段

套装可选，留给以后的晨间屏幕。没有套装时，省略 `outfits` 或给空数组都可以。

| 字段 | 必填 | 形状 |
| --- | --- | --- |
| `id` | 是 | 标识符语法 |
| `item_ids` | 是 | 单品 `id` 数组，至少 1 个，元素不重复 |
| `cos_keys` | 是 | `{ "key", "sha256" }` 数组，可以为空。键前缀是 `wardrobe/v1/outfits/` |
| `label` | 否 | 1 到 80 个字符的短标签 |

同一份清单里，每个 `item_ids` 条目都要对应一个 `items[].id`。

## 跨字段规则

下面这些 JSON Schema 表达不了。写入方写清单时保证它们，读取方读清单时再查一遍。[`scripts/validate.mjs`](../scripts/validate.mjs) 先跑 schema，再逐条检查。

1. `items[].id` 在同一份清单里唯一。
2. `outfits[].id` 在同一份清单里唯一。
3. 每条 `cos_keys[].key` 里的 id 段等于父记录的 `id`：单品键的 `{item_id}`，套装键的 `{outfit_id}`。
4. 同一条 `cos_keys` 里的 `key` 不重复。schema 的 `uniqueItems` 只比较整个 `{ key, sha256 }` 对象，同一个键配不同 `sha256` 会漏过去，所以单独查。
5. 套装 `item_ids` 的每一项都能在同一份清单的 `items` 里找到。
6. `acquired_at` 是日历上真实存在的日期，`updated_at` 是真实的 UTC 时间。schema 的正则只管形状，`2025-02-30`、`T24:00:00Z` 这类会被拒绝。

规则 1、3、4 合起来保证整份清单里的对象键全局唯一：键里带着父记录 id，父记录 id 又不重复。

运行：

```text
npm ci
npm run validate                                # 校验假样本
node scripts/validate.mjs data/wardrobe-index.json  # 校验节点本机清单
npm test                                        # 每条规则的反例测试
```

CI（`.github/workflows/validate.yml`）在每次推送 `main` 和每个 PR 上校验假样本并跑测试。真实清单不入库，CI 不碰它。

## 明确不收录

清单和本仓库都不收录这些：

- embedding，以及任何向量
- 人脸数据
- bbox（bounding box，检测框）
- 自动识别置信度
- 虚拟试衣或虚拟形象资源
- `kind`（路径已经区分单品和套装）
- 桶名、密钥、令牌、签名链接

## 硬约束

1. 对象键一旦写入，不覆盖该键上的字节。
2. 桶是私有的。
3. 密钥、令牌、证书、`.env` 永不进 git。桶名也不进清单、不进仓库。
4. 真实清单 `data/wardrobe-index.json` 与事件预留文件 `data/wardrobe-events.json` 都在 `.gitignore`。入库的只有 schema 和假样本。
5. 仓库不放真实衣橱照片。图片扩展名已在 `.gitignore` 中忽略。
6. `acquired_at`、`season`、`wear_count`、`wash_count` 由人填写，禁止视觉推断。
7. `sha256` 遵守 Iris Fix：原始字节的 SHA-256。
8. 假样本里的 id 都以 `demo_` 开头。里面的 `sha256` 是占位十六进制，不是任何文件的摘要。仓库里没有与这些键对应的对象。

## 以后怎么消费

本地晨间代理（第二刀）和 Pi 5 晨间屏幕（第三刀）以后按这个顺序用清单。本刀没有这段代码。

1. 读本机 `data/wardrobe-index.json`。不读 `examples/wardrobe-v1.sample.json`。
2. 用 `schema/wardrobe-v1.schema.json` 校验字段形状，再检查上文「跨字段规则」的每一条。`scripts/validate.mjs` 导出的 `validateIndex` 两步都做。
3. 用节点本地凭证，从私有桶按 `cos_keys[].key` 取对象。
4. 对取回的原始字节计算 SHA-256，与记录里的 `sha256` 比较。
5. 主代理在本地。Pi 5 负责家庭节点上的编排和屏幕，不承担 GPU 推理。云桶只负责存放私有对象。

事件规则仍走 `data/wardrobe-events.json`。在那份文件有契约之前，代理和屏幕不需要它也能遵守本文件。
