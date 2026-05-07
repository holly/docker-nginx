# Docker Compose コマンド

`compose.yml` を使用して nginx をビルド・実行します。

## 使い方

### 標準的な実行

```bash
docker compose up
```

この場合：
1. nginx イメージをビルド
2. geoipupdate コンテナを常時稼働（GeoIP データベース取得、72 時間ごとに定期更新）
3. geoipupdate が健康状態（healthy）になった時点で nginx コンテナを起動

**前提条件：** `.env` ファイルが存在し、MaxMind 認証情報が設定されていること

```env
GEOIPUPDATE_ACCOUNT_ID=your_account_id
GEOIPUPDATE_LICENSE_KEY=your_license_key
GEOIPUPDATE_EDITION_IDS=GeoLite2-ASN GeoLite2-City GeoLite2-Country
GEOIPUPDATE_FREQUENCY=72
OPENSSL_VERSION=3.6.2
```

## 処理内容

### 1. ビルドフェーズ

```bash
docker build -t $USER/nginx:latest -f Dockerfile .
```

- 7 つのマルチステージビルド実行
- OpenSSL（バージョン管理）、brotli、njs、geoip2 をコンパイル
- DH パラメータ・QUIC ホストキー取得
- nginx バイナリ生成

### 2. GeoIP 更新フェーズ（常時稼働デーモン）

```bash
ghcr.io/maxmind/geoipupdate:latest (compose.yml より、restart: unless-stopped)
```

- `.env` から認証情報を読み込み
- GeoLite2 データベース 3 つをダウンロード
  - `GeoLite2-Country.mmdb`
  - `GeoLite2-City.mmdb`
  - `GeoLite2-ASN.mmdb`
- `geoipupdate_data` 名前付きボリュームに保存
- **72 時間ごとに自動更新**（`GEOIPUPDATE_FREQUENCY` で制御）
- 公式イメージの healthcheck で更新状態を監視
- nginx は geoipupdate が healthy になった時点で起動

### 3. Nginx 実行フェーズ

```yaml
ports:
  - "80:80"           # HTTP
  - "443:443/tcp"     # HTTPS
  - "443:443/udp"     # HTTP/3 (QUIC)

volumes:
  - geoipupdate_data:/usr/share/GeoIP
  # 以下をコメント解除してバインドマウントを有効化
  # - ./nginx/volume/etc/nginx/vhosts.d:/etc/nginx/vhosts.d
  # - ./nginx/volume/etc/nginx/njs:/etc/nginx/njs
  # - ./nginx/volume/var/nginx/vhosts:/var/nginx/vhosts
```

## バインドマウント有効化

イメージ再ビルドなしに設定を反映する場合、`compose.yml` のボリューム設定をコメント解除します。

### ディレクトリ構成例

```
./nginx/volume/
├── etc/nginx/
│   ├── vhosts.d/              → /etc/nginx/vhosts.d/
│   │   └── example.com.conf   # 仮想ホスト設定（下記サンプル参照）
│   └── njs/                   → /etc/nginx/njs/
│       └── auth.js            # njs スクリプト
└── var/nginx/vhosts/          → /var/nginx/vhosts/
    └── example.com/
        └── index.html
```

### vhost サンプル（`vhosts.d/example.com.conf`）

```nginx
server {
    listen 443 ssl http2;
    server_name example.com;

    # /etc/nginx/conf.d/ のスニペット群を個別に include
    include /etc/nginx/conf.d/ssl.conf;
    include /etc/nginx/conf.d/resolver.conf;
    include /etc/nginx/conf.d/default_header.conf;

    ssl_certificate     /etc/nginx/ssl/fullchain.pem;
    ssl_certificate_key /etc/nginx/ssl/privkey.pem;

    root /var/nginx/vhosts/example.com;
    index index.html;
}
```

### conf.d スニペット

`/etc/nginx/conf.d/` には以下が事前設置されています（vhost から include して使用）：

| ファイル | 内容 |
|---|---|
| `ssl.conf` | TLSv1.2/1.3、暗号スイート、DHParam、0-RTT |
| `resolver.conf` | Cloudflare DNS（1.1.1.1/1.0.0.1） |
| `default_header.conf` | CSP、X-Frame-Options、Referrer-Policy 等 |

## シナリオ別の実行方法

### シナリオ 1: 通常実行（GeoIP 更新 + nginx 起動）

```bash
docker compose up
```

geoipupdate が完了後に nginx が起動します。

### シナリオ 2: バックグラウンド実行

```bash
docker compose up -d

# ログ確認
docker compose logs -f nginx
```

### シナリオ 3: 既存イメージで実行（ビルドスキップ）

```bash
docker compose up --no-build
```

### シナリオ 4: ビルドキャッシュクリア

```bash
docker compose build --no-cache
docker compose up
```

### シナリオ 5: 停止・削除

```bash
docker compose down
```

ボリュームも削除する場合：
```bash
docker compose down -v
```

## トラブルシューティング

### .env がない場合

```bash
# .env.example から .env を作成
cp .env.example .env

# エディタで認証情報を設定
vim .env
# GEOIPUPDATE_ACCOUNT_ID と GEOIPUPDATE_LICENSE_KEY を編集

# 実行
docker compose up
```

詳細は公式 Docker Hub ページを参照：https://hub.docker.com/r/maxmindinc/geoipupdate

### GeoIP 更新に失敗した場合

```bash
# ボリュームをクリア（空の状態で nginx を起動）
docker compose down -v
docker compose up
```

nginx は GeoIP データがなくても起動します（graceful degradation）。

### ビルド失敗時

```bash
docker compose build --no-cache
docker compose up
```

### ポート競合エラー

```bash
# 既存コンテナ停止
docker compose down

# または別のポートで実行（カスタム compose override）
docker compose run -p 8080:80 nginx /app/entrypoint.sh
```

### イメージサイズ確認

```bash
docker images | grep "$USER/nginx"
```

## 従来のコマンドとの対応

| 従来 | docker compose |
|---|---|
| `./build.sh` | `docker compose build` |
| `./run.sh` | `docker compose up` |
| `./push.sh` | `docker push $USER/nginx:latest` |

## 関連ファイル

- `.claude/commands/build.md` — build.sh の詳細
- `.claude/commands/run.md` — run.sh の詳細
- `.claude/commands/push.md` — push.sh の詳細
- `README.md` — バインドマウント活用ガイド
