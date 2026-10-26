# 节点接口

LAN HTTP API of the home node, used by the Flutter app in [`app/`](../app/).

节点是家里的一台电脑，以后是 Pi 5。它保管 `data/wardrobe-index.json`、`data/wardrobe-events.json` 和照片字节（`data/objects/`）。手机不存清单，也不持有 COS 凭证。每次写入前，节点都用 [`scripts/validate.mjs`](../scripts/validate.mjs) 校验两份文件，不通过就返回 422，磁盘不变。

## 启动

```text
npm ci
npm run serve
```

启动时打印局域网地址和配对令牌。令牌存在 `data/node-token`，和其他数据一样不进 git。`PORT` 改端口（默认 8365），`OOTD_DATA_DIR` 改数据目录。

V0 在家庭局域网里用明文 HTTP。不要把这个端口映射到公网。

## 鉴权

每个请求都带 `Authorization: Bearer <令牌>`，否则 401。

## 接口

| 方法 | 路径 | 请求体 | 成功 |
| --- | --- | --- | --- |
| GET | `/v1/ping` | | 200 `{ ok, node }` |
| GET | `/v1/index` | | 200 衣橱清单 |
| GET | `/v1/events` | | 200 事件日志 |
| PUT | `/v1/items/{id}` | JSON，只能有 `category` `season` `color` `acquired_at` `status` `wear_count` `wash_count` | 201 新建 / 200 更新，返回单品 |
| POST | `/v1/items/{id}/photos` | 图片原始字节 | 201 `{ key, sha256 }` |
| POST | `/v1/events` | JSON `{ type, date, item_ids }` | 201 事件 |
| POST | `/v1/events/{id}/look` | 图片原始字节 | 201 `{ key, sha256 }` |
| GET | `/v1/objects/{key}` | | 200 图片字节 |

- 单品 `id` 由客户端分配，`updated_at` 和 `cos_keys` 由节点维护。`acquired_at: null` 表示删掉这个字段。
- 事件的 `id`、`source`（`manual`）、`recorded_at` 由节点填。写入 `wear` 或 `wash` 事件时，节点在同一次写入里给涉及单品的计数加 1。
- 图片请求要带 `Content-Type`（`image/jpeg`、`image/png`、`image/webp`、`image/heic`）和 `X-Sha256`（这份字节的小写十六进制 SHA-256）。节点重算一遍，不一致返回 400。上限 20 MB。
- `asset_id` 由节点分配。对象键已存在时返回 409，绝不覆盖。
- 镜子照片每个 `wear` 事件只能补一次，第二次 409。

## 错误

错误体是 `{ "error": "...", "details": [...] }`。`details` 只在 422 时出现，内容是校验器的 `{ path, message }` 列表。

| 状态 | 含义 |
| --- | --- |
| 400 | 请求形状不对、摘要不一致、字段不许改 |
| 401 | 令牌不对 |
| 404 | 没有这件单品、事件、对象或接口 |
| 409 | 对象键已存在，或事件已有镜子照片 |
| 413 | 请求体太大 |
| 415 | 不支持的图片类型 |
| 422 | 没通过契约校验 |
