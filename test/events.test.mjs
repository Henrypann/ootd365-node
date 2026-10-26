import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { validateDocument, validateEvents } from "../scripts/validate.mjs";

function load(name) {
  return JSON.parse(readFileSync(new URL(`../examples/${name}`, import.meta.url), "utf8"));
}

const sample = load("wardrobe-events-v1.sample.json");
const index = load("wardrobe-v1.sample.json");

// 每个用例从假样本复制一份，改坏一处，确认只报出那一处。
function broken(mutate, options = { index }) {
  const doc = structuredClone(sample);
  mutate(doc);
  return validateEvents(doc, options);
}

function assertOnly(errors, path) {
  assert.deepEqual(
    errors.map((e) => e.path),
    [path],
    JSON.stringify(errors, null, 2),
  );
}

test("假样本通过，带不带清单都通过", () => {
  assert.deepEqual(validateEvents(sample, { index }), []);
  assert.deepEqual(validateEvents(sample), []);
});

test("按 schema_version 分派", () => {
  assert.deepEqual(validateDocument(sample, { index }), []);
  assert.deepEqual(validateDocument(index), []);
  assertOnly(validateDocument({ schema_version: "nope" }), "/schema_version");
});

test("source 只能是 manual", () => {
  const errors = broken((d) => {
    d.events[0].source = "camera";
  });
  assert.ok(errors.length > 0);
  assert.ok(errors.every((e) => e.message.startsWith("schema:")));
});

test("confidence 不收录", () => {
  const errors = broken((d) => {
    d.events[0].confidence = 0.9;
  });
  assert.ok(errors.every((e) => e.message.startsWith("schema:")));
});

test("events[].id 重复", () => {
  assertOnly(
    broken((d) => d.events.push(structuredClone(d.events[1]))),
    "/events/3/id",
  );
});

test("look_key 里的 id 段与事件不一致", () => {
  assertOnly(
    broken((d) => {
      d.events[0].look_key.key = "wardrobe/v1/looks/demo_other/demo_asset_mirror.jpg";
    }),
    "/events/0/look_key/key",
  );
});

test("look_key 挂在 wash 事件上", () => {
  assertOnly(
    broken((d) => {
      d.events[2].look_key = {
        key: "wardrobe/v1/looks/demo_event_0117_wash/demo_asset_mirror.jpg",
        sha256: "2".repeat(64),
      };
    }),
    "/events/2/look_key",
  );
});

test("date 不是真实日期", () => {
  assertOnly(
    broken((d) => {
      d.events[1].date = "2026-02-30";
    }),
    "/events/1/date",
  );
});

test("recorded_at 不是真实时间", () => {
  assertOnly(
    broken((d) => {
      d.events[1].recorded_at = "2026-01-16T00:61:00Z";
    }),
    "/events/1/recorded_at",
  );
});

test("给了清单时，item_ids 要能找到", () => {
  assertOnly(
    broken((d) => {
      d.events[1].item_ids.push("demo_item_missing");
    }),
    "/events/1/item_ids/2",
  );
});

test("没给清单时，不查 item_ids 引用", () => {
  assert.deepEqual(
    broken(
      (d) => {
        d.events[1].item_ids.push("demo_item_missing");
      },
      {},
    ),
    [],
  );
});
