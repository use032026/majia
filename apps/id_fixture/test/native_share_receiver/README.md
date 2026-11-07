# 本地Android共享接收验收夹具

这个接收器仅为本次原始JSON字节往返验证而建，独立包名`dev.idfixture.qa.share_receiver`，不属于产品功能、不捆绑产品、不发布。API29+；`testOnly=true`、`debuggable=false`，manifest不声明网络或危险存储权限。没有Launcher入口，从系统Sharesheet接收`ACTION_SEND application/json`。

## 本地构建与安装

在 Flutter 应用目录运行：

```sh
python3 test/native_share_receiver/build.py
```

脚本用现有 Android Build Tools 35.0.0、Android API 36 的 `android.jar`、JDK 和标准 `~/.android/debug.keystore` 构建。可用 `ANDROID_SDK_ROOT` 或 `ANDROID_HOME` 指定 SDK，用 `JAVA_HOME` 指定 JDK。未指定时，使用 macOS 默认 SDK 目录和 Android Studio JBR。

`artifacts/native-share-receiver/` 保存 `QA.apk`、`build.log` 和 `build-report.json`，包括签名、权限检查与 SHA256。中间文件位于 `.codex-build/share-receiver-build/`。

将 `ID_FIXTURE_TEST_DEVICE` 设为专用测试设备的序列号，再从 Flutter 应用目录运行：

```sh
adb -s "$ID_FIXTURE_TEST_DEVICE" install -t -r artifacts/native-share-receiver/QA.apk
```

在主应用生成用例并导出，然后从 Android 系统分享面板选“ID Fixture QA Receiver”。接收器通过系统面板取得临时读取授权。

## 授权及原始字节路径

接收器只接受精确authority `dev.idfixture.id_fixture.flutter.share_provider`的`content://`URI。必须同时含临时`FLAG_GRANT_READ_URI_PERMISSION`、且Android `checkUriPermission`对本接收器UID返回GRANTED，再通过`ContentResolver.openInputStream`读取；不申请持久URI权限，不使用root，不读取产品私有文件系统路径，也不修改产品debuggable属性。

原始输入限1MiB；不解析、重排或重新序列化JSON。文件名取FileProvider的DISPLAY_NAME，仅接受本产品安全ASCII JSON名称。为避免同名碰撞，写入`Download/IDFixture-QA/receive-<唯一标识>/<原JSON名>`，每次独立子目录，保留原basename，不覆盖已有捕获。

通过MediaStore.Downloads创建本接收器所有的pending记录，写入原bytes，再读回逐字节与SHA256比较。比较成功才公开文件；失败仅移除本次新建row。界面显示授权、authority、原文件名、字节数、SHA256、实际公开位置和读回一致状态。“完成并返回”结束接收器。

接收器显示Saved后，主应用可通过系统文件选择器进入Downloads→IDFixture-QA→该次receive子目录→选回同名JSON，继续包预览/确认复现。这里只证明合法共享授权、原字节保存和回读路径；不证明号码真实签发或身份有效。验收结束是否卸载QA包由Coordinator处理，不随主包交付。
