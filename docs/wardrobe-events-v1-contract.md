# 事件 V1 契约

Append-only wear and wash log on the local node (V0).

这一份定义 `data/wardrobe-events.json`：人记下的穿着和洗涤事件。衣橱清单见 [衣橱 V1 契约](wardrobe-v1-contract.md)，路线见 [路线图](roadmap.md)。字段表与 [`schema/wardrobe-events-v1.schema.json`](../schema/wardrobe-events-v1.schema.json) 一起生效，改一边时同时改另一边。假样本在 [`examples/wardrobe-events-v1.sample.json`](../examples/wardrobe-events-v1.sample.json)。

## 文件

真实日志在节点本机的 `data/wardrobe-events.json`，已在 `.gitignore`。它是 UTF-8 编码的 JSON 对象：

- `schema_version`：常量 `wardrobe-events-v1`
- `events`：事件数组，必填，可以为空

日志只追加。已写入的事件不改、不删、不重排。唯一的例外是 `look_key`：照片在事件写入后第二步上传，一个 `wear` 事件可以补上一次 `look_key`，补上之后同样不改。记错了就由人处理，V0 不提供撤销接口。

## 事件字段

| 字段 | 必填 | 形状 | 含义 |
| --- | --- | --- | --- |
| `id` | 是 | 标识符语法，与衣橱清单相同 | 事件 id，日志内唯一 |
| `type` | 是 | `wear` 或 `wash` | 穿着或洗涤 |
| `date` | 是 | `YYYY-MM-DD` | 穿着或洗涤发生的本地日期 |
| `item_ids` | 是 | 单品 `id` 数组，至少 1 个，元素不重复 | 这次涉及的单品 |
| `source` | 是 | 只能是 `manual` | 由人记录。`camera` 与 `confidence` 在以后的版本里加入，不放宽这一版 |
| `recorded_at` | 是 | UTC，`YYYY-MM-DDTHH:MM:SSZ` | 事件写入的时间 |
| `look_key` | 否 | `{ "key", "sha256" }` | 这次穿着的镜子照片，只用于 `wear` |

## 镜子照片

镜子照片的对象键：

```text
wardrobe/v1/looks/{event_id}/{asset_id}.{ext}
```

标识符和扩展名语法与衣橱清单相同。`{event_id}` 等于该事件的 `id`。`sha256` 遵守 Iris Fix：上传前原始字节的 SHA-256，64 个小写十六进制字符。

这些照片是人自己拍、自己标注的，是路线图 V1 被动识别的标注数据。规则：

- 只存在节点本机。V0 不上传到 COS，不进 git。
- 已写入的键不覆盖。
- 不做人脸检测、人脸识别，也不提取任何人脸数据。
- 人可以删除。删除照片时，事件保留，`look_key` 不再指向可取回的对象。

## 计数

V0 里每个事件都是人的记录。节点写入 `wear` 事件时，在同一次写入里把涉及单品的 `wear_count` 加 1；`wash` 事件对应 `wash_count`。这和衣橱契约里「计数由人维护」一致：计数仍然来自人。

清单里的计数可以包含用 app 之前的历史，所以校验器不要求「计数 = 事件数」。

## 跨字段规则

[`scripts/validate.mjs`](../scripts/validate.mjs) 校验事件日志时，先跑 schema，再检查：

1. `events[].id` 在日志里唯一。
2. `look_key.key` 里的 id 段等于事件 `id`。
3. `look_key` 只出现在 `wear` 事件上。
4. `date` 是真实日期，`recorded_at` 是真实的 UTC 时间。
5. 同时给出衣橱清单（`--index`）时，每个 `item_ids` 都能在清单的 `items` 里找到。

```text
node scripts/validate.mjs examples/wardrobe-events-v1.sample.json --index examples/wardrobe-v1.sample.json
```

## 明确不收录

- `confidence`、`camera` 来源（以后的版本）
- embedding、bbox、人脸数据
- 撤销、修改已写事件的记录
