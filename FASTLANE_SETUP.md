# Fastlane セットアップ詳細手順

README に書ききれなかった試行錯誤の記録。環境構築でハマったポイントを中心にまとめる。

---

## 1. Ruby のインストール

### なぜ Homebrew Ruby が必要か

macOS には Ruby 2.6 系が標準搭載されているが、fastlane の依存ライブラリが Ruby 3.x を要求するため動かない。
実際に試すと以下のようなエラーが出る：

```
Your Ruby version is 2.6.10, but your Gemfile specified >= 3.0
```

### Homebrew で Ruby をインストール

```bash
brew install ruby
```

インストール後、シェルに PATH を通す。毎回手動でやるか、`.zshrc` に書いておく：

```bash
# 一時的に通す（セッション限定）
export PATH="/opt/homebrew/opt/ruby/bin:$PATH"

# 永続化する場合は .zshrc に追記
echo 'export PATH="/opt/homebrew/opt/ruby/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

PATH が通っているか確認：

```bash
which ruby   # => /opt/homebrew/opt/ruby/bin/ruby
ruby -v      # => ruby 3.x.x ...
```

### rbenv は使わなかった理由

rbenv や asdf も選択肢だが、このプロジェクト専用に使うだけなので Homebrew の方がシンプルで管理しやすかった。
複数プロジェクトで Ruby バージョンを切り替えたい場合は rbenv が向いている。

---

## 2. Bundler と依存ライブラリのインストール

### vendor/bundle にインストールする理由

`bundle install` をグローバルにやるとシステムへの書き込み権限エラーが出ることがある。
また、プロジェクト内に閉じ込めることで他プロジェクトとの干渉を防げる。

```bash
cd /path/to/MyCropResize

# vendor/bundle にインストール先を固定
bundle config set path 'vendor/bundle'
bundle install
```

`.bundle/config` に設定が保存されるので、次回以降は `bundle install` だけでよい。

### よくあるエラー

**`gem install` 時に権限エラー**
```
ERROR: While executing gem ... (Gem::FilePermissionError)
You don't have write permissions for /Library/Ruby/Gems/...
```
→ システム Ruby が使われている証拠。`which ruby` で確認して PATH を修正する。

**`ffi` や `nokogiri` のビルドエラー**
```
An error occurred while installing ffi (1.17.x)
```
→ Xcode Command Line Tools が入っていない場合に起きる。
```bash
xcode-select --install
```

**`jwt` gem が見つからない**

Fastfile 内で JWT を使って ASC API トークンを生成しているが、Gemfile に `jwt` が含まれていないと実行時にエラーになる。
Gemfile に追記してから `bundle install`：

```ruby
gem "jwt"
```

---

## 3. App Store Connect API キーの準備

### API キーの種類に注意

App Store Connect API には **Team キー** と **Individual キー** の2種類がある。
fastlane で使うのは **Team キー**（App Manager 権限以上が必要）。

### キーの取得手順

1. [App Store Connect](https://appstoreconnect.apple.com) → ユーザとアクセス → **統合** タブ
2. App Store Connect API セクションの **「+」** をクリック
3. 名前: 任意（例: `Fastlane CI`）、権限: **App Manager**
4. ダウンロードボタンが出るのは **1回だけ**。必ず `.p8` ファイルを保存する

> `.p8` を紛失した場合はキーを削除して再生成するしかない。  
> `.gitignore` に `*.p8` を含めてあるので、誤って commit する心配はない。

### `.env.local` に書く内容

`fastlane/.env.local`（gitignore済み）に以下を記載する。
このファイルは自分で手動作成が必要：

```
ASC_KEY_ID=<Key ID>
ASC_ISSUER_ID=<Issuer ID>
ASC_KEY_FILEPATH=/path/to/AuthKey_XXXXXXXX.p8
MATCH_PASSWORD=<任意のパスワード>
MATCH_GIT_URL=git@github.com:<user>/ios-certificates.git
APPLE_ID=<apple_id@example.com>
TEAM_ID=<XXXXXXXXXX>
REVIEW_PHONE=+81XXXXXXXXXX
REVIEW_EMAIL=<review_contact@example.com>
```

---

## 4. fastlane の初回実行でハマった点

### Xcode 自動署名の Team ID

`update_code_signing_settings` に `team_id` を渡す必要がある。
省略すると署名設定が壊れて `xcodebuild` が失敗する：

```
error: No signing certificate "iOS Distribution" found
```

### `-allowProvisioningUpdates` フラグ

CI/CD 環境や初回ビルド時にプロビジョニングプロファイルが存在しないことがある。
`export_xcargs: "-allowProvisioningUpdates"` を付けると Xcode が自動でプロファイルを生成・更新してくれる。

### App Icon のアルファチャンネルエラー

App Store へのアップロード時に以下のエラーが出ることがある：

```
ITMS-90717: "Invalid App Store Icon. The App Store Icon in the asset catalog in 'MyCropResize.app' can't be transparent nor can contain an alpha channel."
```

Finder の「情報を見る」で確認しても透過かどうかわからないことがある。以下のコマンドで強制的にアルファチャンネルを除去する：

```bash
sips -s format jpeg -s formatOptions 100 AppIcon.png --out /tmp/tmp.jpg
sips -s format png /tmp/tmp.jpg --out AppIcon.png
```

---

## 5. App Store 審査提出でハマった点（最大の罠）

### `submit_for_review: true` が使えない問題

fastlane の `upload_to_app_store` に `submit_for_review: true` を渡すと、
空の提出物（アイテムなし）が作られて Apple 側でエラーになる：

```
Your submission was received but could not be processed.
No items were added to the review submission.
```

これは Apple が 2023 年頃に審査提出フローを新しい **`reviewSubmissions` API** に移行したが、
fastlane の `deliver` アクションがまだ旧 API を使っているために起きる問題。

### 解決策：reviewSubmissions API を直接叩く

Fastfile 内で ASC REST API を直接呼び出す `submit_version` メソッドを実装した。
大まかな流れ：

1. `GET /v1/apps/{appId}/appStoreVersions?filter[appStoreState]=PREPARE_FOR_SUBMISSION`  
   → 審査待ちバージョンの ID を取得

2. `POST /v1/reviewSubmissions`  
   → 提出物を作成（platform: IOS）

3. `POST /v1/reviewSubmissionItems`  
   → バージョンをアイテムとして追加

4. `PATCH /v1/reviewSubmissions/{id}` with `submitted: true`  
   → 提出を確定

### JWT トークンの手動生成

ASC REST API は Bearer トークンが必要。fastlane の `app_store_connect_api_key` が返すオブジェクトは
内部的に JWT を生成しているが、カスタム HTTP リクエストには使えない。
そのため `jwt` gem を使って自前で生成している（`make_asc_client` メソッド）。

```ruby
private_key = OpenSSL::PKey::EC.new(File.read(ENV["ASC_KEY_FILEPATH"]))
jwt_token = JWT.encode(
  { iss: ENV["ASC_ISSUER_ID"], iat: Time.now.to_i, exp: Time.now.to_i + 1200, aud: "appstoreconnect-v1" },
  private_key, "ES256",
  { kid: ENV["ASC_KEY_ID"], typ: "JWT" }
)
```

---

## 6. 価格・配信地域の設定

初回リリース時は価格と配信地域を API で設定する必要がある（App Store Connect の画面でやると二重設定エラーになることがある）。

### 無料価格の設定（`ensure_free_pricing`）

```
GET /v1/apps/{appId}/appPricePoints?filter[territory]=USA
```
で customerPrice が 0 のポイントを探して `POST /v1/appPriceSchedules` に渡す。

すでに設定済みの場合は `manualPrices` が存在するのでスキップする。
二重 POST すると 409 エラーになる。

### 全地域への配信（`ensure_availability`）

```
GET /v1/territories?limit=200
```
で全地域の ID を取得して `POST /v2/appAvailabilities` に一括で渡す。

こちらも 409 が返ってきた場合は「設定済み」なのでスキップしてよい。

---

## 7. 年齢レーティングの設定

審査提出時に年齢レーティングが未設定だとリジェクトされる。
Fastfile の `ensure_age_rating` メソッドで 4+ に設定している：

```
GET /v1/apps/{appId}/appInfos
→ PREPARE_FOR_SUBMISSION 状態の appInfo を取得

GET /v1/appInfos/{id}/ageRatingDeclaration
→ declaration ID を取得

PATCH /v1/ageRatingDeclarations/{id}
→ 全項目を NONE / false に設定（= 4+）
```

すでに `advertising` フィールドが設定されている場合はスキップ。

---

## 8. よく使うデバッグコマンド

```bash
# fastlane のバージョン確認
bundle exec fastlane --version

# 利用可能なレーン一覧
bundle exec fastlane lanes

# 詳細ログを出す
bundle exec fastlane release --env local --verbose

# ASC API で app_id を確認（デバッグ用）
curl -H "Authorization: Bearer <JWT>" \
  "https://api.appstoreconnect.apple.com/v1/apps?filter[bundleId]=com.keisukearai.MyCropResize"

# バージョン一覧を確認
curl -H "Authorization: Bearer <JWT>" \
  "https://api.appstoreconnect.apple.com/v1/apps/<app_id>/appStoreVersions"
```

---

## 9. トラブルシューティング早見表

| エラー | 原因 | 対処 |
|--------|------|------|
| `Your Ruby version is 2.6.x` | システム Ruby が使われている | `export PATH="/opt/homebrew/opt/ruby/bin:$PATH"` |
| `Gem::FilePermissionError` | システム Ruby への書き込み禁止 | 同上 |
| `ffi` ビルドエラー | Xcode CLT 未インストール | `xcode-select --install` |
| `No signing certificate found` | team_id が未設定 | `update_code_signing_settings` に `team_id` を渡す |
| `ITMS-90717` アルファチャンネル | アイコンに透過あり | `sips` でアルファ除去 |
| 空の提出物エラー | `submit_for_review: true` の fastlane バグ | `reviewSubmissions` API を直接叩く |
| JWT 期限切れ | `exp` が 20 分を超えている | `exp: Time.now.to_i + 1200` に設定 |
| 409 Conflict（価格/地域） | すでに設定済み | スキップして問題なし |
