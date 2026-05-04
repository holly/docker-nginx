# Git コミットコマンド

変更をリポジトリにコミットします。

## 実行方法

```bash
git add <files>
git commit -m "コミットメッセージ"
```

または

```bash
git commit -am "コミットメッセージ"  # 変更済みファイルを自動ステージング
```

## コミットメッセージの規約

### フォーマット

```
<type>: <subject>

<body>
```

### タイプ（type）

| タイプ | 説明 | 例 |
|---|---|---|
| `feat` | 新機能追加 | `feat: add HTTP/3 support` |
| `fix` | バグ修正 | `fix: correct DH param generation` |
| `docs` | ドキュメント更新 | `docs: update README with build instructions` |
| `refactor` | リファクタリング（機能変更なし） | `refactor: simplify Dockerfile stages` |
| `perf` | パフォーマンス改善 | `perf: optimize brotli compile flags` |
| `chore` | ビルドツール・設定ファイル更新 | `chore: update .gitignore` |
| `ci` | CI/CD 設定変更 | `ci: add GitHub Actions workflow` |

### サブジェクト（subject）

- **命令形** — "add" / "fix" / "update" / "remove"（現在形、過去形ではなく）
- **小文字で開始**
- **句点 `.` なし**
- **50字以内**

### ボディ（body）

- **何を変更したか**、**なぜ変更したか**を説明
- 空行で区切る
- 72字でラップ
- 実装の詳細より、**動機・目的**を重視

## よい例

```bash
git commit -m "fix: correct nginx config reload interval

The entrypoint.sh previously reloaded nginx every 24 hours.
This caused stale GeoIP data for 24 hours after updates.

Changed the reload interval to 5 minutes to match the GeoIP
auto-reload frequency in geoip2.conf."
```

```bash
git commit -m "docs: add Japanese translation to CLAUDE.md"
```

```bash
git commit -m "chore: create rules and commands structure

Extract Dockerfile architecture and runtime layout constraints
into .claude/rules/ for better maintainability and reusability."
```

## このプロジェクト固有の注意事項

### 変更対象別のメッセージ例

**Dockerfile を修正した場合：**
```bash
git commit -m "fix: add missing QUIC host key generation

The nginx build was missing the QUIC host key generation step
in the dhparam_builder stage, causing HTTP/3 negotiation failures."
```

**app/nginx.conf を更新した場合：**
```bash
git commit -m "perf: increase worker connections to 8192

Benchmarks show 30% higher throughput with this setting on
modern hardware. Requires Linux kernel tuning (ulimit)."
```

**新しいモジュールを追加した場合：**
```bash
git commit -m "feat: add ngx_http_gzip_static_module for pre-compressed assets

Allows serving .gz files directly without runtime compression.
Reduces CPU usage by 15% on static asset requests."
```

**セキュリティヘッダーを追加した場合：**
```bash
git commit -m "feat: add Permissions-Policy header for security hardening

Restricts browser features (geolocation, microphone, camera) to
prevent privilege escalation attacks."
```

## コミット前のチェックリスト

- [ ] 変更内容が単一の目的に絞られている（複数の機能は複数コミット）
- [ ] `.env` ファイルや認証情報がステージングされていない
- [ ] `git diff --staged` で確認した内容が意図通り
- [ ] コミットメッセージが過去形ではなく命令形
- [ ] なぜその変更が必要なのかが説明されている（ボディ）

## トラブルシューティング

**誤ったコミットをした場合：**
```bash
# 最新コミットを修正（ローカルのみ）
git commit --amend -m "新しいメッセージ"

# 最新コミットを取り消す（変更は保持）
git reset --soft HEAD~1

# 最新コミットを取り消す（変更も破棄）
git reset --hard HEAD~1
```

**ファイルの一部だけをコミットしたい場合：**
```bash
git add -p  # 対話的に hunk を選択
git commit -m "..."
```

## リモートへのプッシュ

コミット後、リモートに送信：
```bash
git push origin main
```
