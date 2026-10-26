#!/usr/bin/env node
// 家庭节点：npm run serve。PORT 默认 8365，OOTD_DATA_DIR 默认仓库里的 data/。

import { createServer } from "node:http";
import { networkInterfaces } from "node:os";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { createHandler } from "./app.mjs";
import { Store } from "./store.mjs";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const port = Number(process.env.PORT ?? 8365);
const dataDir = process.env.OOTD_DATA_DIR ?? join(root, "data");

const store = new Store(dataDir);
const token = await store.init();

createServer(createHandler(store)).listen(port, "0.0.0.0", () => {
  const addresses = Object.values(networkInterfaces())
    .flat()
    .filter((a) => a && a.family === "IPv4" && !a.internal)
    .map((a) => `http://${a.address}:${port}`);
  console.log(`ootd365 节点已启动，数据目录：${dataDir}`);
  console.log("在 app 的「连接节点」里填：");
  for (const url of addresses.length ? addresses : [`http://localhost:${port}`]) {
    console.log(`  地址：${url}`);
  }
  console.log(`  令牌：${token}`);
});
