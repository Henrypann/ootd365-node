# ootd365 app

Flutter app (Android and iOS) for the V0 daily loop: register items with photos, then record what you wore each day.

手机只是界面。清单、事件日志和照片都在家里的节点上（见 [节点接口](../docs/node-api.md)），手机不存衣橱数据，也不持有 COS 凭证。

## 功能

- **连接节点**：填 `npm run serve` 打印的地址和令牌，存在系统钥匙串里。
- **今天**：可选一张镜子照片，点选今天穿的单品，保存成一条 `wear` 事件。日期可以改成过去某天。
- **衣橱**：按状态和分类筛选。登记单品：1 到 3 张照片、分类、季节、颜色、入手日期、状态。
- **单品详情**：照片、计数、最近一次穿、「今天洗了」、编辑、退役。
- **记录**：事件按时间倒序，带镜子照片和单品缩略图。

不在这一版：推荐、天气、离线排队（保存失败会提示，可以重试）、扫码配对、套装界面。

## 运行

```text
# 仓库根目录，启动节点
npm ci
npm run serve

# 另一个终端
cd app
flutter pub get
flutter run
```

Android 模拟器里节点地址填 `http://10.0.2.2:8365`。真机要和节点在同一个 Wi-Fi，填节点打印的局域网地址。iOS 第一次连接时会弹「本地网络」权限，要允许。

iOS 只能在 macOS 上编译和安装。CI 在 macOS 上做不签名的编译检查。

## 测试

```text
flutter analyze
flutter test
```

`test/models_test.dart` 直接读仓库里的两份假样本，契约改了而 app 没跟上时会失败。

## 结构

| 路径 | 内容 |
| --- | --- |
| `lib/contract/` | 两份 schema 的 Dart 类型、id 语法、日期格式 |
| `lib/node/` | 节点客户端、地址和令牌的存储 |
| `lib/state/` | `WardrobeStore`：每次写入后从节点重新加载 |
| `lib/ui/` | 各个页面 |
