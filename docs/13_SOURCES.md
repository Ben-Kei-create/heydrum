# 13 — 公式技術参照

確認日 2026-10-19。API名や設定は実装時の最新リリースと照合すること。参考文献は仕様変更リスクのある箇所の根拠であり、最終挙動は実機検証を優先。

## Apple
- AVSpeechSynthesizer（Apple内蔵読み上げ・キュー・pause/stop）: https://developer.apple.com/documentation/avfaudio/avspeechsynthesizer
- Speech Synthesis（utteranceのrate/pitch/volume/voice）: https://developer.apple.com/documentation/avfaudio/speech-synthesis
- AVSpeechSynthesizerDelegate（発話rangeと完了/キャンセル）: https://developer.apple.com/documentation/avfaudio/avspeechsynthesizerdelegate
- AVAudioSession Playback Category: https://developer.apple.com/documentation/avfaudio/avaudiosession/category-swift.struct/playback
- AVAudioSession Mix With Others: https://developer.apple.com/documentation/avfaudio/avaudiosession/categoryoptions-swift.struct/mixwithothers
- StoreKit Transaction.currentEntitlements（非消耗型の権利）: https://developer.apple.com/documentation/storekit/transaction/currententitlements
- StoreKit AppStore.sync（明示復元時のみ）: https://developer.apple.com/documentation/storekit/appstore/sync()
- Apple App Tracking Transparency: https://developer.apple.com/documentation/apptrackingtransparency
- App Store App Privacy申告 (JP): https://developer.apple.com/jp/app-store/app-privacy-details/

## Google
- AdMob iOS Banner（SwiftUI/anchored adaptive/test AdUnit）: https://developers.google.com/admob/ios/banner
- AdMob iOS UMP Privacy（同意更新・canRequestAds）: https://developers.google.com/admob/ios/privacy

## 提示素材について
- `reference/HeyDrum_UI_Mockup.png` はこの会話の要望を基に作られたデザイン参照。
- `assets/drum.wav` と `assets/metal.wav` は本パッケージの制作工程で合成した独自PCM音源。著作権保有者の既成レコード/サンプリング素材は利用していない。
