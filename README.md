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
./run.sh
```

**前提条件：** MaxMind 認証情報ファイル `geoipupdate.env`

```env
GEOIPUPDATE_ACCOUNT_ID=your_account_id
GEOIPUPDATE_LICENSE_KEY=your_license_key
```

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
│       └── auth.js            # njs スクリプト（js_import で読み込む）
└── var/nginx/vhosts/          → /var/nginx/vhosts/
    └── example.com/
        └── index.html         # Web ルート
```

#### vhost サンプル（`vhosts.d/example.com.conf`）

```nginx
server {
    listen 443 ssl http2;
    server_name example.com;

    # /etc/nginx/conf.d/ の設定スニペット群を個別に include
    include /etc/nginx/conf.d/ssl.conf;
    include /etc/nginx/conf.d/resolver.conf;
    include /etc/nginx/conf.d/default_header.conf;

    ssl_certificate     /etc/nginx/ssl/fullchain.pem;
    ssl_certificate_key /etc/nginx/ssl/privkey.pem;

    root /var/nginx/vhosts/example.com;
    index index.html;

    location / {
        try_files $uri $uri/ =404;
    }
}
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
# geoipupdate.env が存在するか確認
ls -la geoipupdate.env

# MaxMind 認証情報を確認
cat geoipupdate.env
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
