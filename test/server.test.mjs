import { test, before, after } from "node:test";
import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { createServer } from "node:http";
import { mkdtemp, readFile, readdir, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { createHandler } from "../server/app.mjs";
import { Store } from "../server/store.mjs";

let dataDir, store, server, base, token;

before(async () => {
  dataDir = await mkdtemp(join(tmpdir(), "ootd365-node-"));
  store = new Store(dataDir);
  token = await store.init();
  server = createServer(createHandler(store));
  await new Promise((resolve) => server.listen(0, "127.0.0.1", resolve));
  base = `http://127.0.0.1:${server.address().port}`;
});

after(async () => {
  await new Promise((resolve) => server.close(resolve));
  await rm(dataDir, { recursive: true, force: true });
});

function call(method, path, { body, headers = {}, auth = token } = {}) {
  const init = { method, headers: { ...headers } };
  if (auth) init.headers.authorization = `Bearer ${auth}`;
  if (body instanceof Uint8Array) {
    init.body = body;
  } else if (body !== undefined) {
    init.body = JSON.stringify(body);
    init.headers["content-type"] = "application/json";
  }
  return fetch(`${base}${path}`, init);
}

const sha = (bytes) => createHash("sha256").update(bytes).digest("hex");
const image = (text) => new TextEncoder().encode(text);

function upload(path, bytes, claimed = sha(bytes)) {
  return call("POST", path, {
    body: bytes,
    headers: { "content-type": "image/jpeg", "x-sha256": claimed },
  });
}

const tee = { category: "top", season: ["summer"], color: "navy", status: "active" };

test("没有令牌或令牌不对时 401", async () => {
  assert.equal((await call("GET", "/v1/ping", { auth: null })).status, 401);
  assert.equal((await call("GET", "/v1/ping", { auth: "nope" })).status, 401);
  assert.equal((await call("GET", "/v1/ping")).status, 200);
});

test("建单品、改单品", async () => {
  const created = await call("PUT", "/v1/items/item_tee", { body: tee });
  assert.equal(created.status, 201);
  const item = await created.json();
  assert.equal(item.wear_count, 0);
  assert.deepEqual(item.cos_keys, []);

  const updated = await call("PUT", "/v1/items/item_tee", { body: { color: "dark navy" } });
  assert.equal(updated.status, 200);
  assert.equal((await updated.json()).color, "dark navy");
});

test("不许通过接口改 cos_keys", async () => {
  const res = await call("PUT", "/v1/items/item_tee", { body: { cos_keys: [] } });
  assert.equal(res.status, 400);
});

test("不合契约的单品返回 422，磁盘不变", async () => {
  const before = await readFile(store.indexPath, "utf8");
  const res = await call("PUT", "/v1/items/item_bad", { body: { ...tee, category: "hat" } });
  assert.equal(res.status, 422);
  assert.ok((await res.json()).details.length > 0);
  assert.equal(await readFile(store.indexPath, "utf8"), before);
});

test("上传单品照片，摘要不对时 400", async () => {
  const bytes = image("fake jpeg bytes");
  assert.equal((await upload("/v1/items/item_tee/photos", bytes, "0".repeat(64))).status, 400);

  const res = await upload("/v1/items/item_tee/photos", bytes);
  assert.equal(res.status, 201);
  const entry = await res.json();
  assert.match(entry.key, /^wardrobe\/v1\/items\/item_tee\/a_[0-9a-f]{12}\.jpg$/);
  assert.equal(entry.sha256, sha(bytes));

  const got = await call("GET", `/v1/objects/${entry.key}`);
  assert.equal(got.status, 200);
  assert.equal(got.headers.get("content-type"), "image/jpeg");
  assert.deepEqual(new Uint8Array(await got.arrayBuffer()), bytes);
});

test("给不存在的单品传照片时 404，不留下对象", async () => {
  const res = await upload("/v1/items/item_missing/photos", image("x"));
  assert.equal(res.status, 404);
  await assert.rejects(readdir(join(dataDir, "objects/wardrobe/v1/items/item_missing")));
});

test("对象键已存在时不覆盖", async () => {
  const key = "wardrobe/v1/items/item_tee/a_fixed.jpg";
  await store.writeObject(key, image("first"));
  await assert.rejects(store.writeObject(key, image("second")), { status: 409 });
  assert.equal((await store.readObject(key)).toString(), "first");
});

test("对象路径只认契约里的键形状", async () => {
  const res = await call("GET", "/v1/objects/..%2F..%2Fnode-token");
  assert.equal(res.status, 400);
});

test("wear 事件让 wear_count 加 1，wash 让 wash_count 加 1", async () => {
  const wear = await call("POST", "/v1/events", {
    body: { type: "wear", date: "2026-10-26", item_ids: ["item_tee"] },
  });
  assert.equal(wear.status, 201);
  const event = await wear.json();
  assert.equal(event.source, "manual");

  await call("POST", "/v1/events", {
    body: { type: "wash", date: "2026-10-26", item_ids: ["item_tee"] },
  });

  const index = await (await call("GET", "/v1/index")).json();
  const item = index.items.find((i) => i.id === "item_tee");
  assert.equal(item.wear_count, 1);
  assert.equal(item.wash_count, 1);

  const events = await (await call("GET", "/v1/events")).json();
  assert.equal(events.events.length, 2);
});

test("事件引用不存在的单品时 422", async () => {
  const res = await call("POST", "/v1/events", {
    body: { type: "wear", date: "2026-10-26", item_ids: ["item_missing"] },
  });
  assert.equal(res.status, 422);
});

test("事件不收多余字段", async () => {
  const res = await call("POST", "/v1/events", {
    body: { type: "wear", date: "2026-10-26", item_ids: ["item_tee"], confidence: 1 },
  });
  assert.equal(res.status, 400);
});

test("镜子照片只能补一次，只能挂在 wear 上", async () => {
  const event = await (
    await call("POST", "/v1/events", {
      body: { type: "wear", date: "2026-10-27", item_ids: ["item_tee"] },
    })
  ).json();
  const path = `/v1/events/${event.id}/look`;
  assert.equal((await upload(path, image("mirror"))).status, 201);
  assert.equal((await upload(path, image("mirror 2"))).status, 409);

  const wash = await (
    await call("POST", "/v1/events", {
      body: { type: "wash", date: "2026-10-27", item_ids: ["item_tee"] },
    })
  ).json();
  assert.equal((await upload(`/v1/events/${wash.id}/look`, image("mirror"))).status, 422);
});
