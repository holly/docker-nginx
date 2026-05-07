# docker-nginx

高性能でセキュアな nginx Docker イメージ。[freenginx](http://freenginx.org) をソースからコンパイルし、HTTP/3 (QUIC)、カーネル TLS、brotli 圧縮、GeoIP2、njs スクリプティングなどの高度な機能を備えています。

## 特徴

- **HTTP/3 (QUIC)** — 次世代プロトコル対応
- **カーネル TLS (ktls)** — TLS オフロードで最高のパフォーマンス
- **Brotli 圧縮** — レベル 7 での最大圧縮率
- **GeoIP2** — MaxMind データベース統合（Country / City / ASN）
- **njs スクリプティング** — nginx 内で JavaScript 実行
- **セキュリティ強化** — TLSv1.2/1.3 のみ、強力な暗号スイート、4096-bit DH パラメータ
- **源コンパイル** — OpenSSL、brotli、njs、GeoIP2 モジュール、すべてソースからビルド

## クイックスタート

### 1. ビルド

```bash
./build.sh
```

ビルド時間：初回 5～10分、2回目以降 2～5分（Docker キャッシュ利用）

### 2. 実行

```bash
# Docker Compose（推奨）
docker compose up
```

または

```bash
# シェルスクリプト
export $(cat .env | grep -v '^#' | xargs)
./run.sh
```

詳細は「環境変数管理」セクションを参照してください。

### 3. テスト

```bash
# HTTP
curl -i http://localhost/

# HTTPS（自己署名証明書）
curl -i https://localhost/ --insecure

# HTTP/3 (QUIC)
curl -i --http3 https://localhost/ --insecure
```

## コマンド

| コマンド | 説明 |
|---|---|
| `./build.sh` | Docker イメージをビルド（`$USER/nginx:latest`） |
| `./push.sh` | イメージを Docker Hub にプッシュ |
| `./run.sh` | GeoIP 更新 + nginx コンテナ起動 |

## ポートマッピング

コンテナは以下を公開します：

- `80/tcp` — HTTP
- `443/tcp` — HTTPS
- `443/udp` — HTTP/3 (QUIC)

## 環境変数管理

すべての構成は `.env` ファイルで一元管理します。

### セットアップ

```bash
# .env.example から .env を作成
cp .env.example .env

# エディタで認証情報・バージョンを設定
vim .env
```

### .env に含まれる設定

| 変数 | 説明 | 用途 |
|---|---|---|
| `OPENSSL_VERSION` | nginx ビルドに使う OpenSSL バージョン（デフォルト: 3.6.2） | `docker compose up` / `./build.sh` |
| `GEOIPUPDATE_ACCOUNT_ID` | MaxMind アカウント ID | geoipupdate コンテナ |
| `GEOIPUPDATE_LICENSE_KEY` | MaxMind ライセンスキー | geoipupdate コンテナ |
| `GEOIPUPDATE_EDITION_IDS` | ダウンロードする GeoIP DB | geoipupdate コンテナ |

### 使用方法

#### 方法 A：docker compose（推奨）

```bash
# .env から全環境変数を自動読み込み
docker compose up

# バージョン指定でビルド（.env を上書き）
OPENSSL_VERSION=3.7.0 docker compose up
```

#### 方法 B：./build.sh

```bash
# .env から環境変数を読み込んでビルド
export $(cat .env | grep -v '^#' | xargs)
./build.sh

# または直接指定
OPENSSL_VERSION=3.7.0 ./build.sh
```

#### 方法 C：./run.sh

```bash
# .env は自動で読み込まれないため手動でエクスポート
export $(cat .env | grep -v '^#' | xargs)
./run.sh
```

### .env の管理

- `.env` は `.gitignore` で無視（個人の認証情報を保護）
- リポジトリには `.env.example` のみコミット
- 新しく clone したときは `cp .env.example .env` して設定を記入

## 設定

### 設定ファイル（イメージに焼き込み）

```
app/nginx.conf              # メイン設定
app/modules.conf            # 動的モジュール読み込み（4つの .so をロード）
app/modules.d/              # モジュール固有の設定
  ├── brotli.conf           # Brotli 圧縮設定（レベル 7、MIME タイプ）
  └── geoip2.conf           # GeoIP2 変数マッピング（Country/City/ASN）
app/conf.d/                 # vhost から include して使う設定スニペット
  ├── ssl.conf              # TLSv1.2/1.3、暗号スイート、DHParam、0-RTT
  ├── default_header.conf   # CSP、X-Frame-Options、Referrer-Policy 等
  └── resolver.conf         # Cloudflare DNS resolver
```

### バインドマウント（実行時に動的提供）

イメージ再ビルドなしに設定を更新可能。`compose.yml` または `run.sh` でボリュームマウントを有効化します。

#### ディレクトリ構成例

```
./nginx/volume/
├── etc/nginx/
│   ├── vhosts.d/              → /etc/nginx/vhosts.d/
│   │   └── example.com.conf   # 仮想ホスト定義（下記サンプル参照）
│   └── njs/                   → /etc/nginx/njs/
│       └── hello.js           # njs スクリプト例（js_import で読み込む）
└── var/nginx/vhosts/          → /var/nginx/vhosts/
    └── example.com/
        └── index.html         # Web ルート
```

#### vhost サンプル（`vhosts.d/example.com.conf`）

HTTP/3 (QUIC) 対応の例：

```nginx
server {
    listen 443 ssl http2;
    listen 443 ssl http3;
    http3_max_field_size 16k;
    
    server_name example.com;

    # /etc/nginx/conf.d/ の設定スニペット群を個別に include
    include /etc/nginx/conf.d/ssl.conf;
    include /etc/nginx/conf.d/resolver.conf;
    include /etc/nginx/conf.d/default_header.conf;

    ssl_certificate     /etc/nginx/ssl/fullchain.pem;
    ssl_certificate_key /etc/nginx/ssl/privkey.pem;

    # njs スクリプト読み込み
    js_path "/etc/nginx/njs/";
    js_import hello from hello.js;

    root /var/nginx/vhosts/example.com;
    index index.html;

    location / {
        try_files $uri $uri/ =404;
    }

    # njs スクリプト例：HTTP API エンドポイント
    location /api/hello {
        js_content hello.hello;
    }
}
```

#### njs スクリプト例（`njs/hello.js`）

```javascript
export default {
  hello: hello_handler,
}

function hello_handler(r) {
  r.return(200, 'hello, njs\n')
}
```

#### アクセス例

HTTP/1.1 でアクセス：
```bash
curl -i https://example.com/api/hello --insecure
```

レスポンス：
```
HTTP/1.1 200 OK
Server: nginx
Date: Wed, 07 May 2026 12:34:56 GMT
Content-Type: text/plain
Content-Length: 12
Connection: keep-alive

hello, njs
```

HTTP/3 (QUIC) でアクセス：
```bash
curl -i --http3 https://example.com/api/hello --insecure
```

HTTP/3 レスポンス：
```
HTTP/3 200
Server: nginx
Date: Wed, 07 May 2026 12:34:56 GMT
Content-Type: text/plain
Content-Length: 12

hello, njs
```

#### Docker Compose での有効化

`compose.yml` のボリュームをコメント解除：

```yaml
volumes:
  - ./nginx/volume/etc/nginx/vhosts.d:/etc/nginx/vhosts.d
  - ./nginx/volume/etc/nginx/njs:/etc/nginx/njs
  - ./nginx/volume/var/nginx/vhosts:/var/nginx/vhosts
  - geoipupdate_data:/usr/share/GeoIP
```

#### シェルスクリプト（`run.sh`）での有効化

```bash
docker run -d \
  -p 80:80 -p 443:443/tcp -p 443:443/udp \
  -v ./nginx/volume/etc/nginx/vhosts.d:/etc/nginx/vhosts.d \
  -v ./nginx/volume/etc/nginx/njs:/etc/nginx/njs \
  -v ./nginx/volume/var/nginx/vhosts:/var/nginx/vhosts \
  -v geoipupdate_data:/usr/share/GeoIP \
  $USER/nginx:latest
```

## アーキテクチャ

### マルチステージ Dockerfile

7 つの独立ステージで各依存関係をコンパイル：

| ステージ | 主な処理 | 出力 |
|---|---|---|
| openssl_builder | OpenSSL 3.6.2 をソースからコンパイル | OpenSSL ソースツリー |
| geoip2_builder | GitHub からモジュールソースをクローン | ngx_http_geoip2_module/ |
| brotli_builder | brotli ライブラリ + nginx モジュール（-Ofast -march=native） | 静的ライブラリ + .so |
| njs_builder | njs スクリプティングモジュール configure | njs ソースツリー |
| dhparam_builder | DHParam 取得（RFC 7919）+ QUIC キー生成 | dhparam.pem、quic_host_key |
| nginx_builder | freenginx ビルド（全モジュール統合） | nginx バイナリ + .so |
| nginx_executor | ランタイムミニマル構成 | 実行イメージ + njs CLI バイナリ |

## トラブルシューティング

### GeoIP データ取得エラー

```bash
# .env が存在するか確認
ls -la .env

# MaxMind 認証情報を確認
cat .env
```

### HTTP/3 が動作しない

```bash
# ホストのファイアウォールで UDP 443 が許可されているか確認
sudo ufw allow 443/udp

# クラウド環境の場合はセキュリティグループを確認
```

### ビルド失敗

```bash
# Docker キャッシュをクリア
docker system prune -a

# 再度ビルド
./build.sh
```

### OpenSSL バージョンを変更したい場合

デフォルトは `OPENSSL_VERSION=3.6.2` です。セキュリティ更新が必要な場合は以下を確認してください。

**重要：breaking changes の確認**

OpenSSL 4.0.0 以降では、deprecated EVP_* API（`EVP_CIPHER`、`EVP_MD`、`EVP_PKEY`、`EVP_PKEY_ASN1` のカスタム実装）が削除されています。nginx・njs の互換性確認が必須です。

参考：https://github.com/openssl/openssl/releases/tag/openssl-4.0.0

**バージョンアップ手順：**

1. **Dockerfile を編集**

   ```dockerfile
   ARG OPENSSL_VERSION=3.7.0  # または希望のバージョン（デフォルト: 3.6.2）
   ```

2. **ビルド**

   ```bash
   ./build.sh
   ```

3. **互換性テスト**

   ```bash
   # バージョン確認
   docker run --rm $USER/nginx:latest nginx -V

   # 起動確認
   docker compose up

   # SSL/TLS 動作確認
   curl -i https://localhost/ --insecure

   # njs モジュール確認（js_import を使う vhost で動作確認）
   curl -i https://localhost/njs-test
   ```

   テストが通らない場合は、元のバージョン（3.6.2）に戻してください。

詳細なエラー診断は [@.claude/skills/build-and-diagnose](/.claude/skills/build-and-diagnose/SKILL.md) を参照。

## 開発ガイダンス

詳細なプロジェクト規約・スキル・コマンドは [@CLAUDE.md](./CLAUDE.md) を参照。

- **Dockerfile 編集** — [@.claude/rules/dockerfile-architecture.md](/.claude/rules/dockerfile-architecture.md)
- **nginx 設定編集** — [@.claude/rules/runtime-layout.md](/.claude/rules/runtime-layout.md)
- **Git コミット** — [@.claude/skills/commitizen-commit](/.claude/skills/commitizen-commit/SKILL.md)
- **Docker ビルド診断** — [@.claude/skills/build-and-diagnose](/.claude/skills/build-and-diagnose/SKILL.md)

## ライセンス

MIT License — Copyright © 2024 holly

## サポート

問題が発生した場合：

1. [トラブルシューティング](#トラブルシューティング) セクションを確認
2. ビルド出力を確認（build-and-diagnose スキル参照）
3. Dockerfile / app/ の設定確認（rules 参照）
