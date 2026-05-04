# ビルドコマンド

Docker イメージをビルドします。

## 実行方法

```bash
./build.sh
```

## 処理内容

1. **タグ生成** — ディレクトリ名から `docker-` プレフィックスを除去してタグ化
   - ディレクトリ名 `docker-nginx` → タグ `$USER/nginx:latest`

2. **Docker ビルド実行** — Dockerfile に基づいてマルチステージビルドを開始
   - 7 つのビルドステージが順序に従って実行
   - 各依存関係（brotli、OpenSSL、njs、GeoIP2 モジュール）がコンパイル
   - 最終的なランタイムイメージ `$USER/nginx:latest` が生成

## ビルド時間

- 初回：5～10分（すべての依存関係をコンパイル）
- 2回目以降：2～5分（Docker キャッシュを利用）

## トラブルシューティング

**ビルド失敗時：**
- `docker system prune -a` でキャッシュをクリアして再試行
- Mercurial (`hg`) が利用可能か確認（freenginx ソース取得に必須）
- インターネット接続を確認（外部ソース取得のため）

**イメージサイズ確認：**
```bash
docker images | grep "$USER/nginx"
```

## 次のステップ

- イメージをレジストリに push：`./push.sh`
- ローカルで実行：`./run.sh`
