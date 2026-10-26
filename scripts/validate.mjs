#!/usr/bin/env node
// 校验衣橱清单与事件日志：先跑 JSON Schema，再查 schema 表达不了的跨字段规则。
// 规则见 docs/wardrobe-v1-contract.md 与 docs/wardrobe-events-v1-contract.md 的「跨字段规则」。
//
// 用法：node scripts/validate.mjs [文件 ...] [--index 清单路径]
// 按 schema_version 判断文件类型。给了 --index 时，事件里的 item_ids 要能在那份清单里找到。
// 不给文件时校验两份假样本。

import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import Ajv2020 from "ajv/dist/2020.js";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const ajv = new Ajv2020({ strict: true, allErrors: true });

function loadSchema(name) {
  return ajv.compile(
    JSON.parse(readFileSync(join(root, "schema", name), "utf8")),
  );
}

const indexSchema = loadSchema("wardrobe-v1.schema.json");
const eventsSchema = loadSchema("wardrobe-events-v1.schema.json");

// 键形如 wardrobe/v1/{items|outfits|looks}/{id}/{asset_id}.{ext}，第 4 段是父记录 id。
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

function schemaErrors(validate) {
  return validate.errors.map((e) => ({
    path: e.instancePath || "/",
    message: `schema: ${e.message}`,
  }));
}

function checkUniqueIds(records, base, errors) {
  const seen = new Map();
  records.forEach((rec, i) => {
    if (seen.has(rec.id)) {
      errors.push({
        path: `${base}/${i}/id`,
        message: `id "${rec.id}" 与 ${base}/${seen.get(rec.id)} 重复`,
      });
    } else {
      seen.set(rec.id, i);
    }
  });
  return seen;
}

function checkKeyOwner(key, ownerId, path, errors) {
  if (keyOwnerId(key) !== ownerId) {
    errors.push({
      path,
      message: `键里的 id 段 "${keyOwnerId(key)}" 不等于父记录 id "${ownerId}"`,
    });
  }
}

function checkRecords(records, base, errors) {
  const seen = checkUniqueIds(records, base, errors);
  records.forEach((rec, i) => {
    const keys = new Set();
    rec.cos_keys.forEach((entry, j) => {
      const keyAt = `${base}/${i}/cos_keys/${j}/key`;
      checkKeyOwner(entry.key, rec.id, keyAt, errors);
      if (keys.has(entry.key)) {
        errors.push({ path: keyAt, message: `键 "${entry.key}" 在同一条 cos_keys 里重复` });
      }
      keys.add(entry.key);
    });
  });
  return seen;
}

/**
 * 校验一份已解析的衣橱清单。返回错误数组，空数组表示通过。
 * schema 不通过时只返回 schema 错误，跨字段规则依赖正确的形状。
 */
export function validateIndex(doc) {
  if (!indexSchema(doc)) return schemaErrors(indexSchema);

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

/**
 * 校验一份已解析的事件日志。给了 index（已解析的衣橱清单）时，
 * 再检查每个 item_ids 都能在 index.items 里找到。
 */
export function validateEvents(doc, { index } = {}) {
  if (!eventsSchema(doc)) return schemaErrors(eventsSchema);

  const errors = [];
  checkUniqueIds(doc.events, "/events", errors);
  const itemIds = index ? new Set(index.items.map((item) => item.id)) : null;

  doc.events.forEach((event, i) => {
    const at = `/events/${i}`;
    if (event.look_key) {
      checkKeyOwner(event.look_key.key, event.id, `${at}/look_key/key`, errors);
      if (event.type !== "wear") {
        errors.push({ path: `${at}/look_key`, message: "镜子照片只能挂在 wear 事件上" });
      }
    }
    if (!isRealDate(event.date)) {
      errors.push({ path: `${at}/date`, message: `"${event.date}" 不是真实日期` });
    }
    if (!isRealDateTime(event.recorded_at)) {
      errors.push({
        path: `${at}/recorded_at`,
        message: `"${event.recorded_at}" 不是真实的 UTC 时间`,
      });
    }
    if (itemIds) {
      event.item_ids.forEach((id, j) => {
        if (!itemIds.has(id)) {
          errors.push({ path: `${at}/item_ids/${j}`, message: `"${id}" 在衣橱清单里找不到` });
        }
      });
    }
  });

  return errors;
}

/** 按 schema_version 选择校验器。 */
export function validateDocument(doc, options = {}) {
  switch (doc?.schema_version) {
    case "wardrobe-v1":
      return validateIndex(doc);
    case "wardrobe-events-v1":
      return validateEvents(doc, options);
    default:
      return [{ path: "/schema_version", message: "不认识的 schema_version" }];
  }
}

function readJson(file) {
  return JSON.parse(readFileSync(file, "utf8"));
}

function main(argv) {
  const files = [];
  let indexPath;
  for (let i = 0; i < argv.length; i++) {
    if (argv[i] === "--index") indexPath = argv[++i];
    else files.push(argv[i]);
  }
  if (!files.length) {
    indexPath ??= join(root, "examples/wardrobe-v1.sample.json");
    files.push(indexPath, join(root, "examples/wardrobe-events-v1.sample.json"));
  }

  let index;
  if (indexPath) {
    try {
      index = readJson(indexPath);
    } catch (err) {
      console.error(`✗ --index ${indexPath}: 读不了或不是 JSON：${err.message}`);
      return 1;
    }
    if (validateIndex(index).length) {
      console.error(`✗ --index ${indexPath} 本身没通过校验，先修它`);
      return 1;
    }
  }

  let failed = false;
  for (const file of files) {
    let doc;
    try {
      doc = readJson(file);
    } catch (err) {
      console.error(`✗ ${file}: 读不了或不是 JSON：${err.message}`);
      failed = true;
      continue;
    }
    const errors = validateDocument(doc, { index });
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
