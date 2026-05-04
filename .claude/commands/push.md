# プッシュコマンド

ビルドされたイメージをレジストリにプッシュします。

## 実行方法

```bash
./push.sh
```

## 前提条件

- イメージが既にビルドされていること：`./build.sh` を実行済み
- Docker レジストリにログイン済み：`docker login` を実行済み

## 処理内容

1. **タグ生成** — build.sh と同じロジックでタグを決定
   - ディレクトリ名 `docker-nginx` → `$USER/nginx:latest`

2. **レジストリへのプッシュ** — ローカルイメージをレジストリに送信
   - デフォルトは Docker Hub（`docker.io`）
   - 認証情報は `docker login` で設定

## 実行例

```bash
$ ./push.sh
The push refers to repository [docker.io/username/nginx]
latest: digest: sha256:abc123... size: 1234567
```

## トラブルシューティング

**認証エラー：**
```bash
docker login
# Docker Hub のユーザー名・パスワード（またはアクセストークン）を入力
```

**タグ不一致エラー：**
- ローカルイメージが存在するか確認：`docker images | grep nginx`
- 必要に応じて `./build.sh` を再実行

**ネットワークエラー：**
- インターネット接続を確認
- ファイアウォール / プロキシ設定を確認

## 注意事項

- `$USER` 変数がシェルで定義されていること
- レジストリ認証情報を安全に管理（認証情報をコミットしない）
