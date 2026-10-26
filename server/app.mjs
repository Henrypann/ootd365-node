// HTTP 接口。路由、鉴权、请求体解析在这里，读写全部经过 Store。
// 接口说明见 docs/node-api.md。

import { createHash, timingSafeEqual } from "node:crypto";
import { contentTypeFor, extensionFor, ID_PATTERN, newId, utcNow } from "./ids.mjs";
import { HttpError } from "./store.mjs";

const MAX_JSON_BYTES = 64 * 1024;
const MAX_IMAGE_BYTES = 20 * 1024 * 1024;

// PUT /v1/items/:id 能改的字段。id、cos_keys、updated_at 由节点维护。
const EDITABLE_ITEM_FIELDS = new Set([
  "category",
  "season",
  "color",
  "acquired_at",
  "status",
  "wear_count",
  "wash_count",
]);

export function createHandler(store) {
  const routes = [
    ["GET", /^\/v1\/ping$/, () => ({ ok: true, node: "ootd365" })],
    ["GET", /^\/v1\/index$/, async () => (await store.read()).index],
    ["GET", /^\/v1\/events$/, async () => (await store.read()).events],
    ["PUT", /^\/v1\/items\/([^/]+)$/, putItem],
    ["POST", /^\/v1\/items\/([^/]+)\/photos$/, postItemPhoto],
    ["POST", /^\/v1\/events$/, postEvent],
    ["POST", /^\/v1\/events\/([^/]+)\/look$/, postLook],
    ["GET", /^\/v1\/objects\/(.+)$/, getObject],
  ];

  async function putItem(req, res, id) {
    requireId(id);
    const body = await readJson(req);
    for (const field of Object.keys(body)) {
      if (!EDITABLE_ITEM_FIELDS.has(field)) {
        throw new HttpError(400, `字段 ${field} 不能通过这个接口改`);
      }
    }
    const { item, created } = await store.mutate(({ index }) => {
      let item = index.items.find((i) => i.id === id);
      const created = !item;
      if (created) {
        item = { id, wear_count: 0, wash_count: 0, cos_keys: [] };
        index.items.push(item);
      }
      Object.assign(item, body);
      if (body.acquired_at === null) delete item.acquired_at;
      item.updated_at = utcNow();
      return { item, created };
    });
    res.statusCode = created ? 201 : 200;
    return item;
  }

  async function postItemPhoto(req, res, id) {
    requireId(id);
    const { bytes, sha256, ext } = await readImage(req);
    const { index } = await store.read();
    if (!index.items.some((i) => i.id === id)) throw new HttpError(404, "没有这件单品");
    const entry = { key: `wardrobe/v1/items/${id}/${newId("a")}.${ext}`, sha256 };
    await store.writeObject(entry.key, bytes);
    try {
      await store.mutate(({ index }) => {
        const item = index.items.find((i) => i.id === id);
        if (!item) throw new HttpError(404, "没有这件单品");
        item.cos_keys.push(entry);
        item.updated_at = utcNow();
      });
    } catch (err) {
      await store.discardObject(entry.key);
      throw err;
    }
    res.statusCode = 201;
    return entry;
  }

  async function postEvent(req, res) {
    const body = await readJson(req);
    const { type, date, item_ids } = body;
    const extra = Object.keys(body).filter((k) => !["type", "date", "item_ids"].includes(k));
    if (extra.length) throw new HttpError(400, `不认识的字段：${extra.join(", ")}`);
    const event = await store.mutate(({ index, events }) => {
      const now = utcNow();
      const event = { id: newId("ev"), type, date, item_ids, source: "manual", recorded_at: now };
      events.events.push(event);
      // V0 的事件都是人记的，计数随事件一起加。见 docs/wardrobe-events-v1-contract.md「计数」。
      const counter = type === "wash" ? "wash_count" : "wear_count";
      for (const item of index.items) {
        if (Array.isArray(item_ids) && item_ids.includes(item.id)) {
          item[counter] += 1;
          item.updated_at = now;
        }
      }
      return event;
    });
    res.statusCode = 201;
    return event;
  }

  async function postLook(req, res, id) {
    requireId(id);
    const { bytes, sha256, ext } = await readImage(req);
    const { events } = await store.read();
    const existing = events.events.find((e) => e.id === id);
    if (!existing) throw new HttpError(404, "没有这个事件");
    if (existing.look_key) throw new HttpError(409, "这个事件已经有镜子照片");
    const look = { key: `wardrobe/v1/looks/${id}/${newId("a")}.${ext}`, sha256 };
    await store.writeObject(look.key, bytes);
    try {
      await store.mutate(({ events }) => {
        const event = events.events.find((e) => e.id === id);
        if (event.look_key) throw new HttpError(409, "这个事件已经有镜子照片");
        event.look_key = look;
      });
    } catch (err) {
      await store.discardObject(look.key);
      throw err;
    }
    res.statusCode = 201;
    return look;
  }

  async function getObject(req, res, key) {
    let decoded;
    try {
      decoded = decodeURIComponent(key);
    } catch {
      throw new HttpError(400, "对象键形状不对");
    }
    const bytes = await store.readObject(decoded);
    res.setHeader("Content-Type", contentTypeFor(key));
    res.setHeader("Cache-Control", "private, max-age=31536000, immutable");
    res.end(bytes);
  }

  function authorized(req) {
    const header = req.headers.authorization ?? "";
    const given = Buffer.from(header.startsWith("Bearer ") ? header.slice(7) : "");
    const expected = Buffer.from(store.token);
    return given.length === expected.length && timingSafeEqual(given, expected);
  }

  return async function handle(req, res) {
    try {
      if (!authorized(req)) throw new HttpError(401, "令牌不对");
      const path = new URL(req.url, "http://node").pathname;
      for (const [method, pattern, handler] of routes) {
        const match = pattern.exec(path);
        if (!match) continue;
        if (req.method !== method) continue;
        const result = await handler(req, res, ...match.slice(1));
        if (!res.writableEnded) sendJson(res, res.statusCode || 200, result);
        return;
      }
      throw new HttpError(404, "没有这个接口");
    } catch (err) {
      if (err instanceof HttpError) {
        sendJson(res, err.status, { error: err.message, details: err.details });
      } else {
        console.error(err);
        sendJson(res, 500, { error: "节点内部错误" });
      }
    }
  };
}

function requireId(id) {
  if (!ID_PATTERN.test(id)) throw new HttpError(400, "id 形状不对");
}

function sendJson(res, status, body) {
  res.statusCode = status;
  res.setHeader("Content-Type", "application/json; charset=utf-8");
  res.end(JSON.stringify(body));
}

async function readBody(req, limit) {
  const chunks = [];
  let size = 0;
  for await (const chunk of req) {
    size += chunk.length;
    if (size > limit) throw new HttpError(413, "请求体太大");
    chunks.push(chunk);
  }
  return Buffer.concat(chunks);
}

async function readJson(req) {
  const raw = await readBody(req, MAX_JSON_BYTES);
  try {
    const body = JSON.parse(raw.toString("utf8"));
    if (body === null || typeof body !== "object" || Array.isArray(body)) throw new Error();
    return body;
  } catch {
    throw new HttpError(400, "请求体不是 JSON 对象");
  }
}

// 图片原样落盘。X-Sha256 是客户端对同一份字节算的摘要，节点再算一遍核对（Iris Fix）。
async function readImage(req) {
  const ext = extensionFor(req.headers["content-type"]);
  if (!ext) throw new HttpError(415, "只收 jpeg、png、webp、heic");
  const claimed = String(req.headers["x-sha256"] ?? "").toLowerCase();
  if (!/^[a-f0-9]{64}$/.test(claimed)) throw new HttpError(400, "缺少 X-Sha256");
  const bytes = await readBody(req, MAX_IMAGE_BYTES);
  if (!bytes.length) throw new HttpError(400, "图片是空的");
  const sha256 = createHash("sha256").update(bytes).digest("hex");
  if (sha256 !== claimed) throw new HttpError(400, "X-Sha256 与收到的字节不一致");
  return { bytes, sha256, ext };
}
