# 実行コマンド

GeoIP データベースを更新してから、nginx コンテナをローカルで起動します。

## 実行方法

```bash
./run.sh
```

## 前提条件

- イメージがビルド済み：`./build.sh` を実行済み
- MaxMind 認証情報ファイル：`./.env` が存在すること
  ```env
  GEOIPUPDATE_ACCOUNT_ID=your_account_id
  GEOIPUPDATE_LICENSE_KEY=your_license_key
  ```

## 処理内容

1. **GeoIP データベース更新**
   - MaxMind アップデーターコンテナを実行
   - `.env` から認証情報を読み込み
   - `geoipupdate_data` 名前付きボリュームに以下をダウンロード：
     - `GeoLite2-Country.mmdb`
     - `GeoLite2-City.mmdb`
     - `GeoLite2-ASN.mmdb`

2. **nginx コンテナ起動**
   - ポートマッピング：
     - `80/tcp` (HTTP)
     - `443/tcp` (HTTPS)
     - `443/udp` (HTTP/3 QUIC)
   - バインドマウント：
     - `./nginx/volume/etc/nginx/vhosts.d` → `/etc/nginx/vhosts.d`
     - `./nginx/volume/etc/nginx/njs` → `/etc/nginx/njs`
     - `./nginx/volume/var/nginx/vhosts` → `/var/nginx/vhosts`
   - 名前付きボリューム：`geoipupdate_data` (GeoIP .mmdb ファイル)

## コンテナライフサイクル

- **前景実行** — ログが標準出力に表示される
- **自動リロード** — entrypoint.sh が 24 時間ごとに nginx 設定をリロード
- **終了** — Ctrl+C で SIGTERM 送信、graceful shutdown

## トラブルシューティング

**.env がない場合：**
```bash
cp .env.example .env

# エディタで認証情報を設定
vim .env
# GEOIPUPDATE_ACCOUNT_ID と GEOIPUPDATE_LICENSE_KEY を編集
```

**ポート競合エラー：**
```bash
docker container ls
docker stop <container_id>
```

**GeoIP データなしで起動したい場合：**
```bash
# GeoIP モジュールはロードされるが、変数がセットされない（graceful degradation）
docker run -d -p 80:80 -p 443:443 -p 443:443/udp $USER/nginx:latest
```

## 確認コマンド

**コンテナが起動しているか確認：**
```bash
docker ps | grep nginx
```

**ログを確認：**
```bash
docker logs <container_id>
```

**nginx が受け付けているか確認：**
```bash
curl -i http://localhost/
curl -i https://localhost/ --insecure  # HTTPS（自己署名証明書用）
```
