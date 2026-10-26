import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { validateIndex } from "../scripts/validate.mjs";

const sample = JSON.parse(
  readFileSync(new URL("../examples/wardrobe-v1.sample.json", import.meta.url), "utf8"),
);

// 每个用例从假样本复制一份，改坏一处，确认只报出那一处。
function broken(mutate) {
  const doc = structuredClone(sample);
  mutate(doc);
  return validateIndex(doc);
}

function assertOnly(errors, path) {
  assert.deepEqual(
    errors.map((e) => e.path),
    [path],
    JSON.stringify(errors, null, 2),
  );
}

test("假样本通过", () => {
  assert.deepEqual(validateIndex(sample), []);
});

test("schema 错误照常报出", () => {
  const errors = broken((d) => {
    d.items[0].kind = "item";
  });
  assert.ok(errors.length > 0);
  assert.ok(errors.every((e) => e.message.startsWith("schema:")));
});

test("items[].id 重复", () => {
  assertOnly(
    broken((d) => d.items.push(structuredClone(d.items[0]))),
    "/items/5/id",
  );
});

test("outfits[].id 重复", () => {
  assertOnly(
    broken((d) => d.outfits.push(structuredClone(d.outfits[0]))),
    "/outfits/1/id",
  );
});

test("单品键里的 id 段与父记录不一致", () => {
  assertOnly(
    broken((d) => {
      d.items[0].cos_keys[0].key = "wardrobe/v1/items/demo_other/demo_asset_front.jpg";
    }),
    "/items/0/cos_keys/0/key",
  );
});

test("套装键里的 id 段与父记录不一致", () => {
  assertOnly(
    broken((d) => {
      d.outfits[0].cos_keys[0].key = "wardrobe/v1/outfits/demo_other/demo_asset_board.jpg";
    }),
    "/outfits/0/cos_keys/0/key",
  );
});

test("同一条 cos_keys 里键重复、sha256 不同", () => {
  assertOnly(
    broken((d) => {
      d.items[0].cos_keys.push({
        key: d.items[0].cos_keys[0].key,
        sha256: "1".repeat(64),
      });
    }),
    "/items/0/cos_keys/2/key",
  );
});

test("套装 item_ids 指向不存在的单品", () => {
  assertOnly(
    broken((d) => {
      d.outfits[0].item_ids.push("demo_item_missing");
    }),
    "/outfits/0/item_ids/3",
  );
});

test("acquired_at 不是真实日期", () => {
  assertOnly(
    broken((d) => {
      d.items[0].acquired_at = "2025-02-30";
    }),
    "/items/0/acquired_at",
  );
});

test("acquired_at 闰日可以通过", () => {
  assert.deepEqual(
    broken((d) => {
      d.items[0].acquired_at = "2024-02-29";
    }),
    [],
  );
});

test("updated_at 不是真实时间", () => {
  assertOnly(
    broken((d) => {
      d.items[0].updated_at = "2026-01-15T24:00:00Z";
    }),
    "/items/0/updated_at",
  );
});

test("省略 outfits 也能通过", () => {
  assert.deepEqual(
    broken((d) => {
      delete d.outfits;
    }),
    [],
  );
});
