---
globs: app/**
description: ランタイム設定ディレクトリ構造とバインドマウント・ボリューム規約
---

# ランタイム設定規約

## ディレクトリ構造

```
app/
├── entrypoint.sh          # コンテナ起動スクリプト（nginx を前景で実行、24h 自動リロードループ）
├── nginx.conf             # メイン設定：ワーカーチューニング、LTSV ログ形式、GeoIP フィールド、vhost インクルード
├── modules.conf           # 動的モジュール 4 つをロード（brotli filter/static、njs、geoip2）
├── modules.d/             # モジュール固有の設定（nginx.conf の http コンテキストで include）
│   ├── brotli.conf        # Brotli 圧縮レベル 7、静的 .br ファイル配信、MIME タイプ拡張
│   └── geoip2.conf        # MaxMind .mmdb データベース 3 つの変数マッピング（auto-reload 5min）
└── conf.d/                # vhost から個別に include して使う設定スニペット
    ├── ssl.conf           # TLSv1.2/1.3 のみ、0-RTT 有効、強力暗号スイート、4096-bit DH param
    ├── default_header.conf # セキュリティヘッダー（CSP、X-Frame-Options、Referrer-Policy など）
    └── resolver.conf      # Cloudflare DNS resolver（1.1.1.1、1.0.0.1、2s タイムアウト）
```

## ランタイムバインドマウント

`compose.yml` または `run.sh` でマウント設定できるバインドマウント。イメージに焼き込まれず、実行時に動的に提供される：

```
./nginx/volume/etc/nginx/vhosts.d  → /etc/nginx/vhosts.d   # カスタム vhost 定義
./nginx/volume/etc/nginx/njs       → /etc/nginx/njs        # njs スクリプト
./nginx/volume/var/nginx/vhosts    → /var/nginx/vhosts     # Web root ディレクトリ
```

### conf.d スニペットの使い方

`/etc/nginx/conf.d/` には以下が事前設置されている（vhost の `server {}` ブロック内から個別に include）：

| ファイル | 用途 | vhost での include 例 |
|---|---|---|
| `ssl.conf` | TLS 設定（プロトコル、暗号スイート、DHParam） | `include /etc/nginx/conf.d/ssl.conf;` |
| `resolver.conf` | DNS リゾルバ設定（Cloudflare） | `include /etc/nginx/conf.d/resolver.conf;` |
| `default_header.conf` | セキュリティヘッダー（CSP、X-Frame-Options） | `include /etc/nginx/conf.d/default_header.conf;` |

### バインドマウント有効化の例

`compose.yml` の場合：
```yaml
volumes:
  - ./nginx/volume/etc/nginx/vhosts.d:/etc/nginx/vhosts.d
  - ./nginx/volume/etc/nginx/njs:/etc/nginx/njs
  - ./nginx/volume/var/nginx/vhosts:/var/nginx/vhosts
  - geoipupdate_data:/usr/share/GeoIP
```

**利点：** イメージ再ビルドなしで vhost・スクリプト・静的ファイル・セキュリティ設定を更新可能

## 名前付きボリューム

**`geoipupdate_data`** — GeoIP 2 データベースファイル群

- `GeoLite2-Country.mmdb` — Country ISO、国名（auto-reload 5min）
- `GeoLite2-City.mmdb` — 都市、大陸、地域、郵便番号、緯度経度、タイムゾーン
- `GeoLite2-ASN.mmdb` — ASN 番号、組織名（auto-reload 5min）

**更新：** `run.sh` / `compose.yml` の MaxMind アップデーターコンテナが `./.env`（認証情報）を読み込んで更新

## 設計上の重要な制約

1. **freenginx（nginx.org ではない）** — ソース取得は Mercurial 経由で `freenginx.org/hg/nginx`。ライセンス・パッチの確認が必要。

2. **すべてソースからビルド** — OpenSSL、brotli、njs、geoip2 モジュールは apt インストールではなく、Dockerfile でコンパイル。バージョン・コンパイルフラグの制御が可能。

3. **HTTP/3 は UDP 443 が必須** — コンテナが `443/tcp` と `443/udp` の両方を公開。ホストのファイアウォール・クラウドセキュリティグループが UDP を許可していること。

4. **カーネル TLS（kernel TLS）** — OpenSSL は `enable-ktls` でビルド。Linux カーネルが ktls をサポートしていない場合、nginx 起動はフォールバックするが、パフォーマンス利益を享受できない。

5. **GeoIP 自動リロード** — geoip2 モジュールは Country・ASN DB を 5 分ごとに自動リロード。nginx 再起動不要。ただし、設定ファイル（`.conf`）変更時は nginx を reload/restart 必要。

## 編集時の留意点

- **nginx.conf 変更** — `app/nginx.conf` を編集後は `nginx -s reload` を手動実行（entrypoint.sh の 24h ループでは遅延）
- **modules.d/*.conf の影響範囲** — `modules.d/*.conf` は `nginx.conf` の `http {}` コンテキストで include されるため、ファイル形式・シンタックスエラーが全体に波及
- **conf.d/*.conf は vhost 依存** — `/etc/nginx/conf.d/` のファイルは nginx.conf では include されない。各 vhost の `server {}` ブロック内で明示的に `include /etc/nginx/conf.d/ssl.conf;` のように参照する設計
- **バインドマウント側の更新** — `./nginx/volume/` 配下のファイル（vhost 定義・njs スクリプト・Web root）を編集した際も、変更内容によっては nginx の reload が必要な場合がある
- **GeoIP ボリューム欠落** — `geoipupdate_data` が存在しない場合、geoip2 モジュールはエラーログを出力するが nginx は起動する（graceful degradation）。GeoIP 変数は undefined となる
