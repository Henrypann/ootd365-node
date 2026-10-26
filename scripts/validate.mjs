#!/usr/bin/env node
// 校验衣橱清单：先跑 JSON Schema，再查 schema 表达不了的跨字段规则。
// 规则见 docs/wardrobe-v1-contract.md 的「跨字段规则」一节。
//
// 用法：node scripts/validate.mjs [清单路径 ...]
// 不给路径时校验 examples/wardrobe-v1.sample.json。

import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import Ajv2020 from "ajv/dist/2020.js";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const schema = JSON.parse(
  readFileSync(join(root, "schema/wardrobe-v1.schema.json"), "utf8"),
);
const schemaValidate = new Ajv2020({ strict: true, allErrors: true }).compile(
  schema,
);

// 键形如 wardrobe/v1/{items|outfits}/{id}/{asset_id}.{ext}，第 4 段是父记录 id。
function keyOwnerId(key) {
  return key.split("/")[3];
}

// 正则只管形状。这里再确认它是日历上真实存在的日期和时间。
function isRealDate(s) {
  const [y, m, d] = s.split("-").map(Number);
  const t = new Date(Date.UTC(y, m - 1, d));
  return (
    t.getUTCFullYear() === y && t.getUTCMonth() === m - 1 && t.getUTCDate() === d
  );
}

function isRealDateTime(s) {
  const [date, time] = s.slice(0, -1).split("T");
  const [h, min, sec] = time.split(":").map(Number);
  return isRealDate(date) && h < 24 && min < 60 && sec < 60;
}

function checkRecords(records, base, errors) {
  const seen = new Map();
  records.forEach((rec, i) => {
    const at = `${base}/${i}`;
    if (seen.has(rec.id)) {
      errors.push({
        path: `${at}/id`,
        message: `id "${rec.id}" 与 ${base}/${seen.get(rec.id)} 重复`,
      });
    } else {
      seen.set(rec.id, i);
    }

    const keys = new Set();
    rec.cos_keys.forEach((entry, j) => {
      const keyAt = `${at}/cos_keys/${j}/key`;
      if (keyOwnerId(entry.key) !== rec.id) {
        errors.push({
          path: keyAt,
          message: `键里的 id 段 "${keyOwnerId(entry.key)}" 不等于父记录 id "${rec.id}"`,
        });
      }
      if (keys.has(entry.key)) {
        errors.push({ path: keyAt, message: `键 "${entry.key}" 在同一条 cos_keys 里重复` });
      }
      keys.add(entry.key);
    });
  });
  return seen;
}

/**
 * 校验一份已解析的清单。返回错误数组，空数组表示通过。
 * schema 不通过时只返回 schema 错误，跨字段规则依赖正确的形状。
 */
export function validateIndex(doc) {
  if (!schemaValidate(doc)) {
    return schemaValidate.errors.map((e) => ({
      path: e.instancePath || "/",
      message: `schema: ${e.message}`,
    }));
  }

  const errors = [];
  const itemIds = checkRecords(doc.items, "/items", errors);
  checkRecords(doc.outfits ?? [], "/outfits", errors);

  doc.items.forEach((item, i) => {
    if (item.acquired_at !== undefined && !isRealDate(item.acquired_at)) {
      errors.push({
        path: `/items/${i}/acquired_at`,
        message: `"${item.acquired_at}" 不是真实日期`,
      });
    }
    if (!isRealDateTime(item.updated_at)) {
      errors.push({
        path: `/items/${i}/updated_at`,
        message: `"${item.updated_at}" 不是真实的 UTC 时间`,
      });
    }
  });

  (doc.outfits ?? []).forEach((outfit, i) => {
    outfit.item_ids.forEach((id, j) => {
      if (!itemIds.has(id)) {
        errors.push({
          path: `/outfits/${i}/item_ids/${j}`,
          message: `"${id}" 在 items 里找不到`,
        });
      }
    });
  });

  return errors;
}

function main(argv) {
  const files = argv.length
    ? argv
    : [join(root, "examples/wardrobe-v1.sample.json")];
  let failed = false;
  for (const file of files) {
    let doc;
    try {
      doc = JSON.parse(readFileSync(file, "utf8"));
    } catch (err) {
      console.error(`✗ ${file}: 读不了或不是 JSON：${err.message}`);
      failed = true;
      continue;
    }
    const errors = validateIndex(doc);
    if (errors.length) {
      failed = true;
      console.error(`✗ ${file}`);
      for (const e of errors) console.error(`  ${e.path}: ${e.message}`);
    } else {
      console.log(`✓ ${file}`);
    }
  }
  return failed ? 1 : 0;
}

if (process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1]) {
  process.exitCode = main(process.argv.slice(2));
}
