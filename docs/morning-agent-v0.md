# 本机晨间代理 V0

第二刀。读 wardrobe-v1 清单，用规则回答「今天穿什么」。第一刀的字段不在这里扩展，见 [契约](wardrobe-v1-contract.md) 和 [schema/wardrobe-v1.schema.json](../schema/wardrobe-v1.schema.json)。

这一刀跑在 Mac 或一台够用的本地机器上。它不是树莓派 5（Raspberry Pi 5，下文称 Pi 5）上的进程。Pi 5 的编排和晨间屏幕是第三刀。这里不跑模型，不把私有 COS（Cloud Object Storage，云对象存储）里的原图读进内存，也不上传对象。

## 怎么跑

在仓库根目录：

```bash
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt
.venv/bin/python -m morning --index examples/wardrobe-v1.sample.json --date 2026-10-26 --now 2026-10-26T00:30:00Z
```

默认清单是本机的 `data/wardrobe-index.json`（gitignore，可以还不存在）。`examples/wardrobe-v1.sample.json` 只用于演示，不是活衣橱。

标准输出一份 JSON（JavaScript Object Notation，一种文本数据格式）。同一份内容写入：

```text
data/morning/YYYY-MM-DD.json
```

`YYYY-MM-DD` 是 `--date`，省略时用本机本地日历日。`generated_at` 是 UTC（Coordinated Universal Time，协调世界时），格式 `YYYY-MM-DDTHH:MM:SSZ`。

密钥、桶名、天气接口令牌放在本机环境，不进 git，也不进这两份 JSON。没有密钥也能跑通：用 `--temp-c` 和 `--condition`，或本机缓存 `data/weather.json`。这两条路都不访问网络。

语言模型（LLM，Large Language Model）开关 `--llm` 默认关闭。传入它会拒绝，退出码 2，不读密钥，不发起请求。

退出码：`0` 写出推荐；`1` 清单、天气、事件或选衣失败；`2` 参数不合法，或显式打开了 `--llm`。

## 读什么

1. 清单 JSON。用 `schema/wardrobe-v1.schema.json` 校验形状。
2. 读取方再检查两件事，schema 表达不了：每条 `cos_keys[].key` 路径里的 id 等于父记录 `id`；每个套装 `item_ids[]` 都能在同一份清单的 `items` 里找到。重复的单品 id、套装 id，或同一条 `cos_keys` 里重复的 `key`，同样失败。
3. 可选天气。`--temp-c` / `--condition` / `--season` 覆盖缓存里的同名字段。默认若存在 `data/weather.json` 就读它。`--no-weather` 跳过。缓存只接受 `temp_c`、`condition`、`season`。
4. 可选事件文件 `data/wardrobe-events.json`。不存在就跳过。V0 只认一个字段：`exclude_item_ids`（要避开的单品 id 数组）。空对象 `{}` 合法。其它字段会失败，避免悄悄丢掉一条你以为已经生效的规则。

失败时不编造单品或套装。同一条输出路径写入 `error`，不写空文件，也不写一半的推荐。

## 规则

只从 `status=active` 里选。`retired` 不参与。

若给出季节，单品的 `season` 必须包含该值。空数组表示人还没记录季节，不当成四季都可穿，因此对不上。不从日期推断季节，否则样本清单在十月会因为上装和下装的季节不重叠而失败。

必须有一件上装和一件下装。缺了就失败。冷天再加一件外搭：气温小于或等于 12°C，或 `condition` 为 `snow`、`sleet`、`freezing`、`cold`、`ice`。没有符合条件的外搭时，仍然给出上装和下装，并在 `reason` 里写明。有符合条件的鞋就选一双，没有不失败。不自动加 `other`。

同一品类里 `wear_count` 更低者优先。`wear_count` 相同则取 `id` 字典序较小者。

选出的 id 集合与某套装的 `item_ids` 完全一致时，写入 `outfit_id`，并带上该套装的 `cos_keys`。不为了凑套装而多选。多个套装集合相同时，取 `id` 字典序较小者。

不改清单，不增加 `wear_count`。

## 写出什么

成功时字段只有这些：

| 字段 | 内容 |
| --- | --- |
| `date` | 这一天，`YYYY-MM-DD` |
| `text` | 一句中文。形状是「今天穿」加品类和 id，例如上装、下装、鞋 |
| `item_ids` | 选中的单品 id。顺序为上装、下装、外搭（若有）、鞋（若有） |
| `outfit_id` | 可选。只有集合完全命中已有套装时才出现 |
| `cos_keys` | 从清单原样抄出的 `{ "key", "sha256" }`。先是单品，命中套装时再加套装的键 |
| `reason` | 短规则标签。只允许天气、季节、`wear_count`、`status` 和上面的选择结果 |
| `generated_at` | UTC 时间 |

`cos_keys` 里禁止 URL（Uniform Resource Locator，统一资源定位符），禁止没有 `sha256` 的缩略图路径。`sha256` 仍是契约里的 Iris Fix：原始字节的 SHA-256（安全散列算法，256 位）。本刀不下载对象，也不重新计算摘要，只把清单里的两个字段原样抄过来，供以后取回时核对。

`text` 和 `reason` 是封闭句式。看起来、颜色匹配、配色、好看一类视觉措辞过不了输出 schema。V0 没有认衣基线，也不看 `color`。

不写天气卡、分数或候选列表。天气只出现在 `reason` 标签里。

失败时同一路径只有：

| 字段 | 内容 |
| --- | --- |
| `date` | 这一天 |
| `error` | 原因 |
| `generated_at` | UTC 时间 |

没有 `item_ids`，没有 `outfit_id`，没有 `text`。

输出形状见 [schema/morning-recommendation-v0.schema.json](../schema/morning-recommendation-v0.schema.json)。

对样本、不传季节、不传天气时，结果是上装 `demo_item_navy_tee`、下装 `demo_item_grey_trousers`、鞋 `demo_item_white_sneakers`，并命中 `demo_outfit_monday`。已退役的外套和 `other` 皮带不会入选。`cos_keys` 五条都是清单里的 `{ key, sha256 }`，含套装那条，不含退役外套。

失败示例（键内 id 不等于父 id）：

```json
{
  "date": "2026-10-26",
  "error": "清单校验失败：单品 demo_item_navy_tee 的 cos_keys[0].key「wardrobe/v1/items/demo_item_grey_trousers/demo_asset_front.jpg」路径 id「demo_item_grey_trousers」不等于父 id「demo_item_navy_tee」。",
  "generated_at": "2026-10-26T00:30:00Z"
}
```

## 明确不做

- 摄像头、自动服装识别、虚拟试衣、虚拟形象
- embedding（向量嵌入）、人脸、检测框
- 把 Pi 5 当图形处理器（GPU，Graphics Processing Unit）
- 把云端当主代理，或把原图拉进本进程
- memo365
- 真实衣橱照片、COS 密钥、令牌、`.env`
