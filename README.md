# MyCropResize

A focused iOS tool for resizing and cropping screenshots for App Store Connect submissions.

## Overview

MyCropResize is built for iOS developers who need to quickly prepare screenshots for App Store Connect. It handles the repetitive work of cropping and resizing screen captures to the exact pixel dimensions required by Apple.

## Features

- **Image selection** — Pick any image from your photo library
- **Crop** — Draw a crop region interactively
- **Preset sizes** — One-tap presets for App Store screenshot sizes:
  - iPhone 6.7" — 1290 × 2796
  - iPhone 6.5" — 1242 × 2688
  - iPhone 5.5" — 1242 × 2208
- **Save** — Export as JPEG or PNG directly to the Photos library

## Requirements

- Xcode 16 or later
- iOS 17 or later
- Swift 5.9+

---

## App Store 申請手順

### 前提情報

| 項目 | 値 |
|------|-----|
| Bundle ID | `com.keisukearai.MyCropResize` |
| Team ID | `HFZSU3MJLR` |
| Apple ID | `araiautocom3@gmail.com` |
| ASC Key ID | `6W3CF67B68` |
| ASC Issuer ID | `2963ded3-07d2-4191-88ff-78338ebcb50e` |

---

## 初回セットアップ（一度だけ実施）

### 1. API キーの取得（手動）

1. [App Store Connect](https://appstoreconnect.apple.com) → ユーザとアクセス → **統合** タブ
2. App Store Connect API → **「+」** でキーを生成
   - 名前: 任意（例: `Fastlane CI`）
   - 権限: **App Manager**
3. `.p8` ファイルをダウンロードして保存  
   保存場所: `/Users/keisukearai/Downloads/AuthKey_6W3CF67B68.p8`
4. Key ID と Issuer ID をメモ

### 2. Bundle ID の登録（手動）

1. [Apple Developer Portal](https://developer.apple.com) → Certificates, Identifiers & Profiles → **Identifiers**
2. **「+」** → App IDs → App
3. Description: `MyCropResize`、Bundle ID（Explicit）: `com.keisukearai.MyCropResize`
4. **Register**

### 3. アプリを App Store Connect に作成（手動）

1. [App Store Connect](https://appstoreconnect.apple.com) → マイ App → **「+」→「新規 App」**
2. 以下を入力して「作成」

| 項目 | 値 |
|------|-----|
| プラットフォーム | iOS |
| 名前 | MyCropResize |
| プライマリ言語 | English |
| バンドル ID | `com.keisukearai.MyCropResize` |
| SKU | `mycropresize` |

### 4. Fastlane のインストール（自動）

```bash
cd /Users/keisukearai/workspace/ios/MyCropResize
export PATH="/opt/homebrew/opt/ruby/bin:$PATH"

# Homebrew の Ruby（4.x）で依存関係をインストール
bundle config set path 'vendor/bundle'
bundle install
```

> システムの Ruby（2.6）は古くて fastlane が動かないため、Homebrew の Ruby を使用。

### 5. スクリーンショットの配置（手動）

Simulator でアプリを起動し `Cmd+S` でスクリーンショットを撮影して以下に配置：

```
fastlane/screenshots/ja/   ← 日本語用
  01_home.png
  02_edit.png
  ...
```

**必要なサイズ（最低限）:**
- 6.5" iPhone: 1242 × 2688 px（必須）
- 5.5" iPhone: 1242 × 2208 px（必須）

### 6. メタデータのアップロード（自動）

```bash
export PATH="/opt/homebrew/opt/ruby/bin:$PATH"
bundle exec fastlane upload_metadata --env local
bundle exec fastlane upload_screenshots --env local
```

**アップロードされる内容:**

| ファイル | 内容 |
|----------|------|
| `fastlane/metadata/ja/name.txt` | アプリ名（日本語） |
| `fastlane/metadata/ja/subtitle.txt` | サブタイトル |
| `fastlane/metadata/ja/description.txt` | 説明文 |
| `fastlane/metadata/ja/keywords.txt` | キーワード |
| `fastlane/metadata/ja/privacy_url.txt` | プライバシーポリシー URL |
| `fastlane/metadata/en-US/` | 英語版メタデータ |
| `fastlane/metadata/primary_category.txt` | カテゴリ（PRODUCTIVITY） |
| `fastlane/screenshots/ja/` | スクリーンショット |

---

## TestFlight へのアップロード（自動）

ビルド番号が自動でインクリメントされ、TestFlight にアップロードされます。

```bash
export PATH="/opt/homebrew/opt/ruby/bin:$PATH"
bundle exec fastlane beta --env local
```

**自動で行われること:**
1. Xcode 自動署名を有効化（Team ID: `HFZSU3MJLR`）
2. ビルド番号をインクリメント（`agvtool next-version`）
3. アーカイブビルド（`xcodebuild archive`）
4. App Store 用エクスポート（`-allowProvisioningUpdates` でプロファイル自動生成）
5. TestFlight にアップロード（API キー認証）

---

## App Store 申請（自動）

```bash
export PATH="/opt/homebrew/opt/ruby/bin:$PATH"
bundle exec fastlane release --env local
```

**自動で行われること:**
1. ビルド・アーカイブ・エクスポート（beta と同じ）
2. App Store Connect にバイナリをアップロード
3. 審査提出（`submit_for_review: true`）

---

## 環境変数（`.env.local` — git 管理外）

`fastlane/.env.local` に以下を記載（初回のみ手動で作成）：

```
ASC_KEY_ID=6W3CF67B68
ASC_ISSUER_ID=2963ded3-07d2-4191-88ff-78338ebcb50e
ASC_KEY_FILEPATH=/Users/keisukearai/Downloads/AuthKey_6W3CF67B68.p8
MATCH_PASSWORD=mycropresize2024
```

---

## Fastlane レーン一覧

| コマンド | 内容 |
|----------|------|
| `fastlane upload_metadata --env local` | 説明文・キーワード等をアップロード |
| `fastlane upload_screenshots --env local` | スクリーンショットをアップロード |
| `fastlane beta --env local` | ビルド → TestFlight アップロード |
| `fastlane release --env local` | ビルド → App Store 申請 |

---

## トラブルシューティング

### Ruby バージョンエラー
システムの Ruby（macOS 標準）は 2.6 系で古すぎます。必ず Homebrew の Ruby を使うこと：
```bash
export PATH="/opt/homebrew/opt/ruby/bin:$PATH"
```

### アプリアイコンのアルファチャンネルエラー
App Store はアイコンに透明度を許可しません。以下で除去できます：
```bash
sips -s format jpeg -s formatOptions 100 AppIcon.png --out /tmp/tmp.jpg
sips -s format png /tmp/tmp.jpg --out AppIcon.png
```

### プロビジョニングプロファイルが見つからない
`build_app` に `export_xcargs: "-allowProvisioningUpdates"` を追加し、Xcode に自動生成させます（Fastfile 設定済み）。
