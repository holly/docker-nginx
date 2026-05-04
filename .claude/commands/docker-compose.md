# Docker Compose コマンド

docker-compose.yml を使用して nginx をビルド・実行します。

## 使い方

### ビルド + GeoIP 更新 + 実行

```bash
# GeoIP 更新を含めて実行（推奨）
docker-compose up --profile geoip

# GeoIP 更新なしで実行
docker-compose up
```

## 処理内容

### 1. ビルドフェーズ

```bash
docker build -t $USER/nginx:latest -f Dockerfile .
```

- 7 つのマルチステージビルド実行
- brotli、OpenSSL、geoip2、dhparam をコンパイル
- nginx バイナリ生成

### 2. GeoIP 更新フェーズ（オプション）

```bash
docker-compose up --profile geoip
```

- MaxMind GeoIP アップデーター コンテナ実行
- `geoipupdate.env` から認証情報読み込み
- GeoLite2 データベースをダウンロード
- `geoipupdate_data` ボリュームに保存
- 完了後、自動的に nginx コンテナ開始

### 3. Nginx 実行フェーズ

```yaml
ports:
  - "80:80"           # HTTP
  - "443:443/tcp"     # HTTPS
  - "443:443/udp"     # HTTP/3 (QUIC)

volumes:
  - ./nginx/volume/etc/nginx/vhosts.d:/etc/nginx/vhosts.d
  - ./nginx/volume/etc/nginx/njs:/etc/nginx/njs
  - ./nginx/volume/var/nginx/vhosts:/var/nginx/vhosts
  - geoipupdate_data:/usr/share/GeoIP
```

## シナリオ別の実行方法

### シナリオ 1: 初回実行（GeoIP 更新含む）

```bash
# 前提：geoipupdate.env が存在すること
docker-compose up --profile geoip
```

この場合：
1. nginx イメージをビルド
2. geoipupdate コンテナを実行（GeoIP データ取得）
3. nginx コンテナを起動

### シナリオ 2: GeoIP データなしで実行

```bash
docker-compose up
```

この場合：
1. nginx イメージをビルド
2. nginx コンテナを起動（GeoIP ボリームは空）

nginx は GeoIP モジュール読み込みエラーで起動失敗します（modules.conf で有効化している場合）。

### シナリオ 3: 既存イメージで実行（ビルドスキップ）

```bash
docker-compose up --no-build
```

### シナリオ 4: バックグラウンド実行

```bash
docker-compose up -d
```

ログ確認：
```bash
docker-compose logs -f nginx
```

コンテナ停止：
```bash
docker-compose down
```

## トラブルシューティング

### geoipupdate.env がない場合

```bash
# 作成
echo 'GEOIPUPDATE_ACCOUNT_ID=your_id' > geoipupdate.env
echo 'GEOIPUPDATE_LICENSE_KEY=your_key' >> geoipupdate.env
chmod 600 geoipupdate.env

# GeoIP 更新で実行
docker-compose up --profile geoip
```

### ビルド失敗時

```bash
# キャッシュクリア
docker-compose build --no-cache

# 再度実行
docker-compose up
```

### ポート競合エラー

```bash
# 既存コンテナ停止
docker-compose down

# または別のポートで実行
docker-compose run -p 8080:80 nginx
```

### イメージサイズ確認

```bash
docker images | grep nginx
```

## 従来のコマンドとの対応

| 従来 | docker-compose |
|---|---|
| `./build.sh` | `docker-compose build` |
| `./run.sh` | `docker-compose up --profile geoip` |
| `./push.sh` | （別途実行：`docker push $USER/nginx:latest`） |

## 関連ファイル

- `.claude/commands/build.md` — build.sh の詳細
- `.claude/commands/run.md` — run.sh の詳細
- `.claude/commands/push.md` — push.sh の詳細
