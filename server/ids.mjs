import { randomBytes } from "node:crypto";

// 标识符语法：^[a-z0-9][a-z0-9_-]{0,63}$。前缀加 12 位十六进制随机数，碰撞可以忽略。
export function newId(prefix) {
  return `${prefix}_${randomBytes(6).toString("hex")}`;
}

export function newToken() {
  return randomBytes(24).toString("base64url");
}

export const ID_PATTERN = /^[a-z0-9][a-z0-9_-]{0,63}$/;

// 三种对象键：单品、套装、镜子照片。GET /v1/objects 只认这些形状，防路径穿越。
export const OBJECT_KEY_PATTERN =
  /^wardrobe\/v1\/(items|outfits|looks)\/[a-z0-9][a-z0-9_-]{0,63}\/[a-z0-9][a-z0-9_-]{0,63}\.[a-z0-9]{1,8}$/;

const EXTENSIONS = {
  "image/jpeg": "jpg",
  "image/png": "png",
  "image/webp": "webp",
  "image/heic": "heic",
  "image/heif": "heif",
};

export function extensionFor(contentType) {
  return EXTENSIONS[(contentType ?? "").split(";")[0].trim().toLowerCase()];
}

export function contentTypeFor(key) {
  const ext = key.slice(key.lastIndexOf(".") + 1);
  return (
    Object.entries(EXTENSIONS).find(([, e]) => e === ext)?.[0] ??
    "application/octet-stream"
  );
}

// 不带毫秒的 UTC 时间，符合契约里的 YYYY-MM-DDTHH:MM:SSZ。
export function utcNow(now = new Date()) {
  return now.toISOString().replace(/\.\d{3}Z$/, "Z");
}
