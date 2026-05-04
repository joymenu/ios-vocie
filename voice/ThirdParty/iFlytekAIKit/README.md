# 讯飞 AIKit 语音唤醒 SDK 放置说明

从讯飞开放平台下载「AIKit 语音唤醒 iOS SDK」后，把 SDK 包中的内容按下面方式放入工程：

1. 将 `AIKIT.framework` 和语音唤醒能力引擎 framework 添加到 Xcode Target 的 `Frameworks, Libraries, and Embedded Content`，设置为 `Embed & Sign`。
2. 将 `AEEResource.bundle` 添加到 App Target 资源中。
3. 将 `voice/IFlytekAIKitConfig.plist` 中的 `appId`、`apiKey`、`apiSecret` 替换为讯飞开放平台应用信息。
4. `voice/keyword.txt` 已配置为 `小星小星;`，如需多个唤醒词，每行一个并以英文分号结尾。

当前代码已经预留 `IFlytekAIKitWakeWordDetector`，用于替换开发 detector。拿到 SDK 后，按讯飞 Demo 将 `AiHelper initSDK/loadData/specifyDataSet/start/write` 的强类型调用补入该 detector 即可。
