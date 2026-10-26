// 节点本机的数据目录：清单、事件日志、对象字节、配对令牌。
// 所有写入都在一把进程内锁里完成：读最新文件、改、过校验、写临时文件再改名。

import { mkdir, readFile, rename, rm, writeFile } from "node:fs/promises";
import { dirname, join } from "node:path";
import { validateEvents, validateIndex } from "../scripts/validate.mjs";
import { newToken, OBJECT_KEY_PATTERN } from "./ids.mjs";

export class HttpError extends Error {
  constructor(status, message, details) {
    super(message);
    this.status = status;
    this.details = details;
  }
}

const EMPTY_INDEX = { schema_version: "wardrobe-v1", items: [] };
const EMPTY_EVENTS = { schema_version: "wardrobe-events-v1", events: [] };

export class Store {
  constructor(dataDir) {
    this.dataDir = dataDir;
    this.indexPath = join(dataDir, "wardrobe-index.json");
    this.eventsPath = join(dataDir, "wardrobe-events.json");
    this.tokenPath = join(dataDir, "node-token");
    this.objectsDir = join(dataDir, "objects");
    this.queue = Promise.resolve();
  }

  /** 建目录，缺文件时建空清单、空日志和令牌。返回令牌。 */
  async init() {
    await mkdir(this.objectsDir, { recursive: true });
    for (const [path, empty] of [
      [this.indexPath, EMPTY_INDEX],
      [this.eventsPath, EMPTY_EVENTS],
    ]) {
      try {
        await writeFile(path, `${JSON.stringify(empty, null, 2)}\n`, { flag: "wx" });
      } catch (err) {
        if (err.code !== "EEXIST") throw err;
      }
    }
    try {
      this.token = (await readFile(this.tokenPath, "utf8")).trim();
    } catch (err) {
      if (err.code !== "ENOENT") throw err;
      this.token = newToken();
      await writeFile(this.tokenPath, `${this.token}\n`, { mode: 0o600 });
    }
    const { index, events } = await this.read();
    const errors = [...validateIndex(index), ...validateEvents(events, { index })];
    if (errors.length) {
      throw new Error(
        `数据目录里的文件没通过校验：\n${errors.map((e) => `  ${e.path}: ${e.message}`).join("\n")}`,
      );
    }
    return this.token;
  }

  async read() {
    const [index, events] = await Promise.all(
      [this.indexPath, this.eventsPath].map(async (p) => JSON.parse(await readFile(p, "utf8"))),
    );
    return { index, events };
  }

  /**
   * 在锁里改数据。fn 收到最新的 { index, events }，原地修改并返回结果。
   * 改完的两份文件都要过校验，否则抛 422，磁盘上什么都不变。
   */
  mutate(fn) {
    const run = this.queue.then(async () => {
      const data = await this.read();
      const result = await fn(data);
      const errors = [
        ...validateIndex(data.index),
        ...validateEvents(data.events, { index: data.index }),
      ];
      if (errors.length) throw new HttpError(422, "没通过契约校验", errors);
      await Promise.all([
        writeTmp(this.indexPath, data.index),
        writeTmp(this.eventsPath, data.events),
      ]);
      await rename(`${this.indexPath}.tmp`, this.indexPath);
      await rename(`${this.eventsPath}.tmp`, this.eventsPath);
      return result;
    });
    // 一次失败不能卡住后面的写入。
    this.queue = run.catch(() => {});
    return run;
  }

  objectPath(key) {
    if (!OBJECT_KEY_PATTERN.test(key)) throw new HttpError(400, "对象键形状不对");
    return join(this.objectsDir, ...key.split("/"));
  }

  /** 写对象字节。键已存在时抛 409，绝不覆盖。 */
  async writeObject(key, bytes) {
    const path = this.objectPath(key);
    await mkdir(dirname(path), { recursive: true });
    try {
      await writeFile(path, bytes, { flag: "wx" });
    } catch (err) {
      if (err.code === "EEXIST") throw new HttpError(409, `对象键已存在：${key}`);
      throw err;
    }
  }

  /** 只用于回滚刚写入、还没进清单的对象。 */
  async discardObject(key) {
    await rm(this.objectPath(key), { force: true });
  }

  async readObject(key) {
    try {
      return await readFile(this.objectPath(key));
    } catch (err) {
      if (err.code === "ENOENT") throw new HttpError(404, "没有这个对象");
      throw err;
    }
  }
}

function writeTmp(path, doc) {
  return writeFile(`${path}.tmp`, `${JSON.stringify(doc, null, 2)}\n`);
}
