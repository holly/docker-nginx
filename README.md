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
# GeoIP データベース更新 + コンテナ起動
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

### バインドマウント（実行時に動的提供）

イメージ再ビルドなしに設定を更新可能：

```bash
./nginx/volume/etc/nginx/vhosts.d/    # カスタム vhost 定義
./nginx/volume/etc/nginx/njs/         # njs スクリプト
./nginx/volume/var/nginx/vhosts/      # Web root
```

### 設定ファイル（イメージに焼き込み）

```
app/nginx.conf              # メイン設定
app/modules.conf            # 動的モジュール読み込み
app/modules.d/brotli.conf   # Brotli 設定
app/modules.d/geoip2.conf   # GeoIP2 設定
app/conf.d/ssl.conf         # TLS 設定
app/conf.d/default_header.conf  # セキュリティヘッダー
app/conf.d/resolver.conf    # DNS resolver（Cloudflare）
```

## アーキテクチャ

### マルチステージ Dockerfile

7 つの独立ステージで各依存関係をコンパイル：

| ステージ | 成果物 |
|---|---|
| geoip2_builder | GeoIP2 モジュール |
| brotli_builder | brotli ライブラリ + nginx モジュール |
| openssl_builder | OpenSSL（QUIC/HTTP3 対応） |
| njs_builder | njs スクリプティングモジュール |
| dhparam_builder | 4096-bit DH パラメータ + QUIC ホストキー |
| nginx_builder | freenginx バイナリ（モジュール統合） |
| nginx_executor | 最小限ランタイムイメージ |

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
