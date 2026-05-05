# iOS Voice Development Guide

## Overview

This app is an iOS voice/IM prototype for Xiao Xing. It supports:

- Local wake word entry for "小星小星"; internally we also accept "小心小心" in typed text and in spoken listening (ASR/near-sound tolerance). **Do not** advertise or document "小心小心" to customers—customer-facing copy stays on "小星小星" only.
- IM chat with customer and Xiao Xing message bubbles.
- Full-screen voice call flow after wake-up.
- Speech recognition and speech synthesis.
- Intent parsing for reminders and smart watch data queries.
- A future server-side DeepSeek NLU path for more flexible intent parsing.
- Reserved integration points for iFlytek AIKit wake word SDK and backend APIs.

## Main Flows

### IM Chat

`ViewController` is the main IM screen.

- Customer messages are shown on the right with a customer icon.
- Xiao Xing messages are shown on the left with a Xiao Xing icon.
- System messages are centered and visually muted.
- The keyboard send key and the visible send button both submit text directly and keep the keyboard active.
- If the typed text is only a wake word, the app opens the call screen.
- If the typed text starts with a wake word, the wake word is removed before intent parsing.

### Voice Call

`CallViewController` is the full-screen voice interaction screen.

- It requests speech recognition and microphone permissions.
- It plays the opening prompt.
- It listens continuously after Xiao Xing finishes speaking.
- Partial ASR results are shown as "识别中".
- If ASR does not produce a final result, the last partial result is treated as finished after a short idle delay.
- Final text is sent to the same intent parser used by IM.

### Wake Word

Wake word logic is split into two layers:

- `LocalWakeWordService`: manages microphone capture and delegates audio frames to a detector.
- `WakeWordTextMatcher`: handles typed or ASR text wake word compatibility.
- Development fallback: when the official iFlytek KWS integration is not ready, `ViewController` uses Apple speech recognition to listen for the wake word text so saying "小星小星" can still open the call screen during development.

Supported text wake words (development / robustness):

- `小星小星` — primary; safe for customer-facing guidance.
- `小心小心` — **internal only**: matched in IM typed input and in continuous listening paths for ASR mishearing tolerance; **must not** appear in customer-facing manuals, onboarding, or marketing.
- `小新小新`
- `小兴小兴`
- `小型小型`
- `小星星`

`voice/keyword.txt` includes both 「小星小星」 and 「小心小心」 for the future iFlytek wake word resource; the latter remains internal QA tolerance—still no customer-facing disclosure.

## Key Classes

### `ViewController`

Main IM screen.

Responsibilities:

- Setup IM UI.
- Start and stop local wake listening.
- Submit typed text to the parser.
- Open `CallViewController` after wake-up.
- Append call messages back into the IM history.

### `CallViewController`

Voice call screen.

Responsibilities:

- Manage ASR and TTS lifecycle.
- Detect speech completion from final ASR or partial-result idle timeout.
- Submit recognized text to the parser.
- Render call messages as chat bubbles.

### `AlarmIntentParser`

Current generic intent parser. The class name is still historical, but its behavior is broader than alarms.

Supported intents:

- `create_reminder`
- `query_device_data`

Future cleanup recommendation: rename this class to `IntentParser` once the API shape is stable.

### `SpeechRecognitionService`

Wrapper around Apple `SFSpeechRecognizer`.

Responsibilities:

- Request speech and microphone permissions.
- Start and stop recognition.
- Emit partial and final recognition text through `SpeechRecognitionServiceDelegate`.
- Restart recognition sessions when needed.

### `SpeechSynthesisService`

Wrapper around `AVSpeechSynthesizer`.

Responsibilities:

- Speak Xiao Xing responses.
- Stop current speech when the user closes the call.
- Notify completion so listening can resume.

### `IFlytekAIKitWakeWordDetector`

Placeholder for iFlytek AIKit wake word SDK integration.

Current behavior:

- Validates config and SDK presence.
- Falls back to the development detector if SDK artifacts or credentials are missing.
- Until the official strong-typed wake callback is wired, the app uses ASR-based development wake detection instead of the placeholder detector so it can actually wake on spoken "小星小星".

Future work:

- Replace the soft bridge comments with official AIKit calls from the SDK demo.
- Stream PCM frames to AIKit.
- Return real wake word detection results.

## Intent JSON

### Create Reminder

Example user text:

`明天早上 8 点提醒我吃药`

Example JSON:

```json
{
  "intent": "create_reminder",
  "status": "ready",
  "category": "medication",
  "originalText": "明天早上 8 点提醒我吃药",
  "slots": {
    "date": "2026-05-05",
    "time": "08:00",
    "repeat": "none",
    "title": "吃药",
    "medicineName": "吃药",
    "dosage": null
  }
}
```

Reminder categories:

- `alarm`
- `medication`
- `general`

Repeat values:

- `none`
- `daily`
- `weekdays`
- `weekly`

### Query Watch Data

Example user text:

`查一下现在心率`

Example JSON:

```json
{
  "intent": "query_device_data",
  "status": "ready",
  "deviceType": "watch",
  "originalText": "查一下现在心率",
  "slots": {
    "metric": "heart_rate",
    "timeRange": "latest",
    "targetUser": "current",
    "unit": "bpm"
  }
}
```

Supported watch metrics:

- `heart_rate`
- `blood_oxygen`
- `steps`
- `sleep`
- `location`
- `battery`
- `fall_event`
- `device_event`
- `medication_adherence`
- `health_summary`

Supported time ranges:

- `latest`
- `today`
- `yesterday`
- `last_night`
- `recent`

## Watch Data Expansion Roadmap

The current watch query table can grow beyond simple metric lookup. Recommended expansion areas:

| Area | Example user phrases | App intent | Backend responsibility | Priority |
| --- | --- | --- | --- | --- |
| Real-time vitals | `现在心率多少`, `血氧正常吗` | `query_device_data` | Fetch latest watch telemetry and normal range hints. | P0 |
| Daily summaries | `今天运动怎么样`, `今天健康情况总结一下` | `query_device_data` | Aggregate steps, heart rate, sleep, medication, and abnormal events. | P0 |
| Abnormal events | `最近有没有跌倒`, `今天有异常吗` | `query_device_data` | Detect and return fall, high heart rate, low SpO2, offline, and low battery events. | P0 |
| Location safety | `看看老人现在在哪里`, `有没有离开家` | `query_device_data` | Return latest location, geofence status, and last update time. | P1 |
| Medication adherence | `今天有没有吃药`, `昨晚药吃了吗` | `query_device_data` | Join reminder records with confirmation data. | P1 |
| Follow-up actions | `心率异常就通知我`, `没吃药提醒一下` | `create_reminder` or future `create_monitor` | Create reminders, monitoring rules, or push-notification subscriptions. | P1 |
| Family/caregiver view | `查一下爸爸的心率`, `妈妈今天步数多少` | `query_device_data` | Resolve `targetUser`, permissions, and bound devices. | P2 |
| Conversational explanation | `这个心率危险吗`, `为什么睡眠差` | Future server-side NLU response | Generate a plain-language explanation from structured watch data. | P2 |

Recommended next intent additions:

- `create_monitor`: create a continuous watch-data rule, such as low battery, fall event, heart rate threshold, geofence exit, or missed medication.
- `query_monitor`: list active monitoring rules.
- `update_monitor`: pause, resume, or change a monitoring rule.
- `escalate_event`: notify a caregiver or emergency contact after user confirmation.

## Server-side DeepSeek NLU Plan

The iOS app must not connect to DeepSeek directly. DeepSeek access should stay behind the backend so API keys, model routing, prompts, rate limits, and safety rules are controlled server-side.

Implemented architecture:

```text
iOS App -> Backend Xiao Xing Intent API -> Backend AI Service -> Backend Execution Services -> iOS App
```

Suggested parsing flow:

1. iOS sends raw user text, wake-word state, locale, timezone, current user id, and lightweight conversation context to the backend.
2. Backend first tries deterministic rules for high-confidence cases such as common reminders and watch metric queries.
3. Backend falls back to DeepSeek for broader natural-language understanding when local rules cannot parse the request confidently.
4. Backend validates the model output against a strict JSON schema.
5. Backend executes the intent or returns a clarification question.
6. iOS only renders `displayText`, plays `spokenText`, and optionally handles structured UI hints.

Backend contract:

```http
POST /ai/xiaoxing/parseIntent
Content-Type: application/x-www-form-urlencoded
```

The endpoint is protected by the backend `SignFilter`, not by `OpenApiHttpClient`.
The request must use query/form parameters because `SignFilter` reads `request.getParameterMap()`.

Required parameters:

- `text`
- `channel`
- `ts`
- `sign`

Optional parameters:

- `locale`
- `timezone`
- `userId`
- `personId`
- `deviceSn`
- `contextJson`

Signature rule:

1. Sort all request parameter keys ascending.
2. Skip `sign`.
3. Concatenate each `key + value`.
4. Append backend `Constants.SIGN_SECRET`.
5. Base64 encode the concatenated string.
6. MD5 hex the Base64 bytes.

Request example as form/query parameters:

```json
{
  "text": "最近有没有跌倒异常",
  "locale": "zh-CN",
  "timezone": "Asia/Shanghai",
  "channel": "voice",
  "ts": "1777953600000",
  "sign": "calculated-sign"
}
```

The server returns the existing unified `ResponseResult<T>` wrapper. Xiao Xing's parsed result is in `content`.

Response content example:

```json
{
  "success": true,
  "content": {
    "source": "ai",
    "intent": "query_device_data",
    "status": "ready",
    "displayText": "最近没有检测到跌倒异常。",
    "spokenText": "最近没有检测到跌倒异常。",
    "slots": {
      "metric": "fall_event",
      "timeRange": "recent",
      "targetUser": "current",
      "unit": null
    }
  }
}
```

iOS implementation notes:

- Keep `AlarmIntentParser` as the local fallback when the server API fails or returns invalid content.
- Prefer high-confidence watch-data queries over pending reminder slot-filling. For example, after Xiao Xing asks for a reminder time, a new utterance like `查询一下最近查询一下心率` should switch to `query_device_data` and clear the pending reminder context.
- `IntentAPIClient` is the only networking boundary for parsing.
- Never store DeepSeek credentials, endpoint URLs with secrets, or model prompts in the iOS app bundle.
- Log only sanitized text and intent JSON; avoid logging private health details in plain debug output.

Interaction notes:

- The first IM session shows a Xiao Xing welcome card with supported reminder, watch-data, follow-up, wake-word, networking, and health-safety guidance. Customer-visible wake wording uses 「小星小星」 only; do not mention 「小心小心」 to users even though the app accepts it internally for typing and listening.
- The call screen uses a shorter opening prompt so TTS can start quickly.

## Backend Integration Points

`IntentAPIClient` now calls `/ai/xiaoxing/parseIntent` asynchronously. Local parsing remains the fallback path.
The default test backend base URL is `https://uat.stg.fuyunhealth.com`.

Recommended execution routing after parsing:

1. Route by intent:
   - `create_reminder` -> reminder service.
   - `query_device_data` -> watch data service.
   - `create_monitor` -> monitoring rule service.
2. Convert backend execution results into `displayText` and `spokenText`.

## Smart Watch Data Architecture

Recommended architecture:

```text
Smart Watch -> 4G -> Backend -> iOS App IM
```

The iOS app should query the backend rather than connect directly to the watch when using 4G.

Backend responsibilities:

- Device binding.
- Real-time and historical data storage.
- Abnormal event detection.
- Query APIs for IM.
- Push notifications for emergency events.

iOS responsibilities:

- Natural language entry.
- Intent JSON generation.
- Displaying service responses.
- Optional push notification handling.

## Common Test Phrases

Reminder creation:

- `明天早上 8 点提醒我吃药`
- `每天晚上 9 点提醒我吃药`
- `下午 3 点叫我开会`
- `明天 7 点设置闹钟`

Watch queries:

- `查一下现在心率`
- `查询一下最近查询一下心率`
- `今天步数多少`
- `昨晚睡眠怎么样`
- `手表还有多少电`
- `看看老人现在在哪里`
- `今天有没有吃药`
- `最近有没有跌倒异常`

Wake word:

- `小星小星` — primary for users.
- `小心小心` — QA / regression only; internal compatibility (typed + listening); do **not** tell customers.
- `小新小新`
- `小兴小兴`
- `小型小型`
- `小星星`
- `小星小星 明天早上 8 点提醒我吃药`

## Build

Simulator build command:

```sh
xcodebuild -project voice.xcodeproj -scheme voice -sdk iphonesimulator -configuration Debug build
```

## Notes For Future Development

- Rename `AlarmIntentParser` to `IntentParser` after stabilizing the interface.
- Add unit tests for intent parsing before expanding more natural-language rules.
- Move backend calls out of parser classes to keep parsing and networking separate.
- Add `IntentAPIClient` and route DeepSeek usage through the backend only.
- Consider replacing local rule parsing with backend NLU when intent coverage grows, while keeping local rules as a fallback for development and offline debugging.
- Keep wake word text compatibility in `WakeWordTextMatcher` instead of duplicating checks in view controllers.
