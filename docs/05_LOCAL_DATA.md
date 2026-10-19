# 05 — 履歴・設定の永続化設計

## 1. 採用方式
履歴はFoundation `Codable` JSONを `Application Support/HeyDrum/history-v1.json` に保存。Repositoryを `actor` とし、**読み書きを直列化**してデータ競合を避ける。UIやSpeechServiceにファイルパスを漏らさない。SQLite/SwiftDataも実現可能だが、最大100件かつ単純CRUDなのでv1では導入しない。

## 2. 格納形式
```json
{
  "schemaVersion": 1,
  "items": [
    {
      "id": "EE372CC8-63C4-4FD0-B9D4-A692AA1808E6",
      "text": "本日は晴天なり",
      "createdAt": "2026-10-19T12:00:00Z",
      "lastPlayedAt": "2026-10-19T12:00:00Z"
    }
  ]
}
```
`Date`はISO8601で固定。デコード時に `schemaVersion != 1` は破損扱いとは分け、unsupportedSchemaとして元ファイルを保持する。今後の移行余地を確保。

## 3. レコード・追加時の詳細
- 原文を `trimmingCharacters(in: .whitespacesAndNewlines)` し、空でないこと、文字数 `1...500` を再検査。
- 新規追加時 `UUID` を生成、`createdAt=now`、`lastPlayedAt=now`。
- appendは `items.append(new)`→ `lastPlayedAt` descending + `createdAt` descending + `id` stringで決定順→ `prefix(100)`。
- 全て保存**成功後**にin-memoryデータを確定。書込み失敗でメモリだけ成功としない。
- 原子的書込み `.atomic` オプションか「別tmp書込み→rename」を採用（実装差異は実機・ユニットテストで確認）。
- データを含むフォルダを作成し、必要に応じて `isExcludedFromBackup=true` を検討。ただし意図せず端末バックアップから除外するかは要件上保留。**デフォルトはOS標準バックアップ**。別端末同期の保証はしない。
- 個人の読み上げ文が端末に残ることを設定/プライバシーポリシーで説明。ファイル保護はOS標準のData Protectionに従い、必要なら適切な保護属性を使用する。

## 4. データ変更表
| 操作 | 書込 | 件数 | ソート |
|---|---|---|---|
| TextEditor変更 | なし | 不変 | 不変 |
| 入力から新規発話 | 1追加 | +1、最大100 | 新規が先頭 |
| 履歴から再生 | lastPlayedAt更新 | 不変 | 再生行が先頭 |
| 再生中pause/resume | なし | 不変 | 不変 |
| 再生完了からリプレイ | lastPlayedAt更新可（同じID） | 不変 | 既存行先頭 |
| 手動stop | なし | 不変 | 不変 |
| 行削除 | 1削除 | -1 | 他は保持 |
| 全削除 | 全削除 | 0 | 空 |

## 5. 履歴上限の例
- 100件を保持（最古 `lastPlayedAt` の行が削除対象）。
- 再生して最近使った古い行は上位へ戻り、未使用の古い行から消える。
- 101件目のappendで100件のまま（101件化しない）。
- 同内容2回をTextEditorから開始: distinct UUIDを2行追加。
- 既存行再生: UUID不変、件数不変。
- app restart後もソート・時刻・本文が一致。

## 6. 破損・保存失敗
- 無効JSON/不一致schema/500文字超・重複IDなどは検出し、**破損ファイルを黙って空配列で上書きしない**。
- 起動時に控えめな診断バナー `履歴を読み込めませんでした` と選択可能な `再試行`、後日導線 `履歴を初期化`（破棄確認付）を提供。
- 復旧時に元ファイルを `.corrupt-TIMESTAMP` に退避する等、ファイル破棄を防ぐ。
- ディスク容量不足の書込失敗ではinputを保持し「履歴を保存できません」と表示。プライベート本文はエラーログに含めない。
- concurrent append/markPlayedをactorで直列化し更新消失を防ぐ。テストで50操作並列実行。

## 7. 設定
`UserDefaults` にバージョン化したキー `heydrum.masterVolume`, `heydrum.speechSpeed`, `heydrum.preferredVoiceID`。default volume `0.70`。範囲外値はclamp。保存済みvoiceが消えたらja-JPにfallback。**広告購入状態はUserDefaultsへ保存してもよいがそれを正本にしない**。真の権利はStoreKit2のverified transactions。

## 8. ログ・分析
読み上げ本文、履歴、selected voice ID、広告トラッキングIDを外部に送信する独自コードを追加しない。`print`/`os_log`にも本文を出さない。AdMob広告SDKが独自に収集する項目はリリース時にSDKの公式プライバシー説明と照合する。
