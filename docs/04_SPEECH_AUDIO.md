# 04 — 読み上げ・効果音実装設計

## 1. 音声合成: Apple内蔵APIのみ
- `AVSpeechSynthesizer` 1個を `SystemSpeechService` のライフタイムで保持し、`AVSpeechSynthesizerDelegate` を受け取る。インスタンスをタップごとに破棄しない。
- 各セッション1 `AVSpeechUtterance(string: normalizedText)`。`utterance.voice = AVSpeechSynthesisVoice(identifier: configuredVoiceID)`、利用不可なら `AVSpeechSynthesisVoice(language:"ja-JP")`、それも不可ならユーザーにエラー。
- `utterance.rate` は3段階の保守的な値。初期案: `slow = 0.43`、`normal = 0.50`、`fast = 0.57`。OS APIの `AVSpeechUtteranceMinimumSpeechRate` / Maximumでclamp。最終的には**実機試聴**で調整。
- `utterance.pitchMultiplier = 1.08` を初期案とする。女性風・ロボット風はOSが提供する具体声質で決まるため、ピッチ操作単独で女性声と保証しない。極端なピッチ変更は禁止。
- `utterance.volume = max(0,min(1,settings.masterVolume))`。マスター音量0%時にもイベントは正常終了。
- `preUtteranceDelay = 0`。長文500文字で句読点・改行を保持。
- 発話の自然終了/キャンセル/ポーズ/再開はdelegateからstateに反映。`synthesizer.isSpeaking` と画面表示stateが乖離しないようイベントを直列化。
- **誤解防止:** 外部AI API/課金TTSを使わない、という意味でAI非使用。iOS音声の基盤となるOS実装を「ML完全不使用」と保証はしない。

### voice selection policy
1. 実機で `speechVoices()` 内の `language == "ja-JP"` を列挙する。
2. 一覧は安定した表示名と識別子を保存。作成者が実機で聞いて「女性ロボット風」に近い識別子を既定候補にする（識別子を推測しない）。
3. 保存されたidentifierが使えなくなれば `ja-JP` デフォルトへfallback。TTS出力が海外アクセントになったらユーザーに声を選び直す案内。
4. iOS設定で音声の追加ダウンロードが必要なケースや、実機に音声が無い場合の案内を用意。
5. 実機の機内モードで再生できることをテストする。もし選択音声がオフライン動作しない場合はローカルで動作する別声にfallbackする。
6. 声が「女性」であることのプログラム的判定をハードコードしない。

## 2. UTF-16の読み上げ位置と累積表示（v1.1仕様変更）
`AVSpeechSynthesizerDelegate.speechSynthesizer(_:willSpeakRangeOfSpeechString:utterance:)` から `NSRange` を受け取る。UTF-16位置なので `String.Index(utf16Offset:in:)` や `Range(nsRange, in:utterance.speechString)` を使い、Swift文字列を**`.count` だけで切り取らない**。不正範囲は無視。結合絵文字・改行・旧字を含むサンプルでテストする。

**累積表示（オーナー指示 2026-10-20）:** 読上げ画面は、開始前・カウントダウン中は本文を出さず、`willSpeakRangeOfSpeechString` の通知のたびに「その範囲の末尾まで」を先頭から追加表示する。下線・背景ハイライトは使わない。
- 範囲の末尾はUTF-16オフセット→**Character境界に切り上げ**（サロゲートペア・ZWJ絵文字・結合文字を途中で切らない、文字欠損なし）。不正範囲（負値・本文外・オーバーフロー）は無視。表示は**前進のみ**（逆順・重複・小さい末尾では巻き戻さない）。`speaking` 中の通知だけを反映し、`preparing` と `paused` 中の通知、旧sessionの通知は無視。
- 通知は「単語等のまとまりの開始」であり、1文字ごとの音素同期は保証しない。文字数だけの独立タイマーで進めない（進行は常に音声エンジンの通知に従う）。
- 自然終了(`didFinish`)で全文（末尾の句読点含む）を表示。システムによる取消(`didCancel`)・手動停止・背景化・割込みでは未読部分を公開しない。再生し直し・再試行・新規sessionで表示を空に戻す。
- **range通知が来ない環境:** `didStart` から2秒たっても通知が1件も来なければ、全文を一度に表示する（段階表示なし。読み上げは止めない）。これは通知欠如時の安全策であり、進行表示用タイマーではない。通知が1件でも来ていれば発動しない。
- VoiceOver: 本文要素のラベルは「現在表示中の文字」のみ。表示のたびの逐一通知はしない（読み上げ二重化防止）。表示前は「読み上げ待機中」。

## 3. 状態定義とセッション分離
- `idle`: 読上げ画面未表示。
- `preparing`: 読上げ要求送信、`didStart`待ち。UIは本文を表示し中央ボタンloading。
- `speaking`: 一時停止ボタン表示。
- `paused`: 再開ボタン表示。
- `finished`: リプレイボタン表示。
- `failed`: エラー表示と再試行ボタン。

`AVSpeechSynthesizer`は内部キューを持つ。新規 `speak` 前に旧セッションを `.immediate` 停止し、delegateの古いキャンセルをsessionIDで無視。イベントのsessionIDは作成時のutteranceと対応づけるマップで確実に割り当てる。停止直後の `didCancel` はユーザーによる戻り操作と競合してはならない。

## 4. 音声周りのOS設定
- 音声が主目的なので基本は `AVAudioSession.sharedInstance().setCategory(.playback, options:[.mixWithOthers])`、必要時にactivationし終了後可能な場合deactivation。
- Silent switchでも音が鳴る挙動を選ぶ。端末音量・イヤホン・Bluetooth・AirPlayはシステムに従う。**出音を大きくしすぎない**（ユーザー音量70%初期値）。
- v1は背景再生なし。`UIBackgroundModes` のaudioを有効にしない。`scenePhase == .background` で停止。画面ロックも背景停止。
- `AVAudioSession.interruptionNotification` を監視。通話/Siri等の割込み時は発話を停止（勝手に再開しない）。停止の後でも新しいsessionが使えるよう再設定。
- 音量の端末側0やBluetooth切断は故障ではない。再生状態はAPI結果に基づき更新。
- `isOtherAudioPlaying` 状態に関わらずユーザー操作時に再生するが、背景音とmixするため他アプリ音楽を全面停止させない。

## 5. 効果音（同梱・2ファイルのみ）
- ファイル: `drum.wav`（低い短い打撃音）、`metal.wav`（乾いた金属の打撃と減衰）。本パッケージ内で生成したPCM wav（原音素材なし）。
- `AVAudioPlayer(contentsOf:)` で起動時に各音をpreloadし、`prepareToPlay()`。`DrumSoundService`で音ごとプール最大4同時再生。音量はmasterVolume。
- 同じボタン連打は先に再生が終わったプレイヤーを使う。4枠全使用時は最古の同種プレイヤーを停止/再利用。**無制限のプレイヤー増殖なし**。
- `play` はtapで1回呼ばれる。ロングプレス・指離し双方で二重再生しない。
- 音声TTSと効果音の同時発火は画面上無いため、通常は起こらないが、モード遷移時は前の効果音を停止してよい。
- 端末差でピークや高周波が耳障りでないことを実機聴取。必要ならWAVそのものを修正する（余計なUIスライダーを増やさない）。

## 6. 設定の再生プレビュー
設定の「音声を試す」は短い固定サンプル1個。VoiceEditorや履歴に入れない。設定から離れたら音声停止。プレビューが再生中に他のプレビューを押したら古いものを停止して置き換える。声の追加/削除後もfallbackを試せる。

## 7. 音声の実機受入項目
- `こんにちは` / `本日は晴天なり` / `次は13時45分` / `酸化と還元` / `こんにちは😀。` / `あいうえお\nかきくけこ` / `東京2026年`。
- セッション開始0秒、pause/resume、stop即時、完了、再生途中で画面背景化/電話着信、連続10回発話。
- ピッチと速度は**同じ端末・音量で**試聴比較。女性ロボット風が実現できない場合、曖昧に実装完了とせず、選択音声の限界を記録。
