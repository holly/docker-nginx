---
name: Docker イメージビルドと診断
description: Docker ビルドを実行し、出力を監視してエラーを検出・分析・修正提案する
---

# Docker イメージビルドと診断

Docker イメージをビルドしながら、出力内容を監視してエラーや異常な出力を検出し、修正提案を行うスキルです。

## 実行方法

```bash
./build.sh
```

## 処理フロー

### Phase 1: ビルド実行と出力監視

1. `./build.sh` を実行
2. 以下をリアルタイムで監視：
   - **成功パターン** — `Successfully tagged`、`digest: sha256:...`
   - **エラーパターン** — `ERROR`、`error`、`failed`、`ERROR: failed to solve`
   - **警告パターン** — `WARNING`、`deprecated`、`LegacyKeyValueFormat`
   - **ビルドステップ** — `Step N/M`、`FROM`、`RUN`、`COPY`

### Phase 2: エラー検出と分類

検出時に以下を分析：

| エラータイプ | 症状 | 修正例 |
|---|---|---|
| **Network Error** | `failed to fetch`、`Connection refused` | インターネット接続確認、プロキシ設定確認 |
| **Missing Tool** | `not found`、`hg: command not found` | 依存ツール（`hg`、`git`、`cmake`）のインストール |
| **Dockerfile Syntax** | `parse error`、`invalid syntax` | Dockerfile 文法エラー修正 |
| **Permission Denied** | `Permission denied` | ファイルパーミッション修正 |
| **Out of Disk** | `no space left on device` | ディスク容量確保、Docker キャッシュクリア |
| **Compilation Error** | `error: failed to compile`、gcc エラー | コンパイルフラグ確認、依存ライブラリ確認 |
| **Cache Issue** | `COPY --from` エラー | Docker キャッシュクリア提案 |

### Phase 3: 修正提案

エラー検出時に以下を提案：

1. **問題の説明** — 何が起きたか、なぜか
2. **原因の推測** — 考えられる理由
3. **修正手順** — コマンドと変更方法
4. **検証方法** — 修正後の確認方法

## よくあるエラーと修正パターン

### 1. Mercurial が見つからない

**エラー出力：**
```
error: command 'hg' not found
```

**修正：**
```bash
# Mercurial をインストール
apt install mercurial

# 再度ビルド
./build.sh
```

**確認：**
```bash
hg --version
```

---

### 2. freenginx ソース取得失敗

**エラー出力：**
```
error: failed to fetch from http://freenginx.org/hg/nginx
Connection refused / Network is unreachable
```

**修正：**
```bash
# インターネット接続確認
ping -c 1 freenginx.org

# DNS 確認
nslookup freenginx.org

# プロキシ経由の場合は環境変数設定
export http_proxy=http://proxy.example.com:8080
export https_proxy=http://proxy.example.com:8080
./build.sh
```

---

### 3. Docker キャッシュの問題

**エラー出力：**
```
error: failed to solve with frontend dockerfile.v0
failed to build LLB: ...
```

**修正：**
```bash
# Docker キャッシュをクリア
docker system prune -a

# ビルド再実行
./build.sh
```

---

### 4. ENV 形式の警告（hadolint）

**警告出力：**
```
LegacyKeyValueFormat: "ENV key=value" should be used instead of legacy "ENV key value" format
```

**修正：**
```dockerfile
# 古い形式
ENV DEBIAN_FRONTEND noninteractive

# 新しい形式に変更
ENV DEBIAN_FRONTEND=noninteractive
```

**確認：**
```bash
# hadolint で検証（インストール必須）
hadolint Dockerfile
```

---

### 5. ディスク容量不足

**エラー出力：**
```
no space left on device
```

**修正：**
```bash
# ディスク空き容量確認
df -h

# Docker イメージ・コンテナ・ボリュームクリア
docker system prune -a --volumes

# 不要なイメージ削除
docker rmi $(docker images -q)

# ビルド再実行
./build.sh
```

---

### 6. OpenSSL / brotli コンパイルエラー

**エラー出力：**
```
error: undefined reference to `...`
gcc: error: unrecognized command-line option
```

**修正：**
```bash
# コンパイラとビルドツール確認
gcc --version
make --version

# 依存ライブラリ確認（Dockerfile で確認）
# brotli_builder, openssl_builder ステージの apt install を確認

# キャッシュクリアして再ビルド
docker system prune -a
./build.sh
```

---

## 診断チェックリスト（ビルド失敗時）

- [ ] **ネットワーク** — インターネット接続、DNS 解決、プロキシ設定確認
- [ ] **ツール** — `hg`, `git`, `cmake`, `gcc` がインストール済みか
- [ ] **ディスク** — `df -h` で容量確認、不要なファイル削除
- [ ] **Docker** — `docker system prune -a` でキャッシュクリア
- [ ] **Dockerfile 構文** — Dockerfile の ENV 形式など
- [ ] **ステージ依存** — COPY --from の参照先が正確か
- [ ] **コンパイルフラグ** — brotli (`-Ofast -march=native`)、OpenSSL (`enable-ktls`)

## 成功時の確認

ビルド完了後：

```bash
# イメージが作成されたか確認
docker images | grep "$USER/nginx"

# イメージサイズ確認
docker inspect $(docker images -q --filter="reference=$USER/nginx:latest") | grep Size

# イメージの詳細確認
docker history $USER/nginx:latest
```

## 関連コマンド

@.claude/commands/build.md — ビルドコマンドの基本説明

@.claude/rules/dockerfile-architecture.md — Dockerfile の構成と編集ルール
