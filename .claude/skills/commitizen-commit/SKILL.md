---
name: Commitizen形式でコミット
description: 変更をCommitizen形式のメッセージでGitコミットする。対話的にtype/scope/subjectを確認してからコミット
---

# Commitizen形式でコミット

変更をCommitizen標準形式でGitコミットします。

## フォーマット

```
<type>(<scope>): <subject>

<body>

<footer>
```

### type（必須）

| type | 説明 | 例 |
|---|---|---|
| `feat` | 新機能追加 | HTTP/3サポート追加 |
| `fix` | バグ修正 | DH param生成エラー修正 |
| `docs` | ドキュメント更新 | README.md更新 |
| `refactor` | リファクタリング | Dockerfile最適化 |
| `perf` | パフォーマンス改善 | brotliコンパイルフラグ最適化 |
| `test` | テスト追加・修正 | — |
| `chore` | ビルド・CI・設定 | .gitignore更新 |
| `ci` | CI/CD設定変更 | GitHub Actions追加 |

### scope（推奨）

このプロジェクトで一般的なscope：

| scope | 対象 |
|---|---|
| `dockerfile` | Dockerfileの変更 |
| `app` | app/ 配下のnginx設定ファイル |
| `entrypoint` | app/entrypoint.sh |
| `scripts` | build.sh, push.sh, run.sh |
| `rules` | .claude/rules/ファイル |
| `commands` | .claude/commands/ファイル |
| `skills` | .claude/skills/ファイル |
| `docs` | CLAUDE.md, README.md等 |

### subject（必須、50字以内）

- 命令形で記述（「修正した」ではなく「修正する」）
- 小文字で開始
- 句点なし
- 何をしたかを簡潔に

### body（推奨）

- 空行で分ける
- **なぜ**この変更が必要なのかを説明
- 実装の詳細より、動機・目的を重視
- 72字でラップ

### footer（オプション）

- Breaking changes: `BREAKING CHANGE: description`
- Issue close: `Closes #123`, `Fixes #456`

## このプロジェクト固有の例

### 例1：Dockerfileの修正

```
feat(dockerfile): add QUIC host key generation to dhparam stage

The previous build was missing the QUIC host key generation,
causing HTTP/3 negotiation failures. Added key generation
step to dhparam_builder stage.

BREAKING CHANGE: nginx binary now requires 16-byte QUIC key at startup
```

実行コマンド：
```bash
git add Dockerfile
git commit -m "feat(dockerfile): add QUIC host key generation to dhparam stage" \
  -m "The previous build was missing the QUIC host key generation,
causing HTTP/3 negotiation failures. Added key generation
step to dhparam_builder stage.

BREAKING CHANGE: nginx binary now requires 16-byte QUIC key at startup"
```

### 例2：nginx設定の更新

```
perf(app): increase worker connections to 8192

Benchmarks show 30% higher throughput with this setting on
modern hardware (24+ cores). Also updated documentation for
ulimit requirements.

Closes #42
```

### 例3：セキュリティヘッダー追加

```
feat(app): add Permissions-Policy header

Restricts browser features (geolocation, microphone, camera)
to prevent privilege escalation attacks. Aligns with modern
security best practices.
```

### 例4：ドキュメント更新

```
docs(rules): clarify GeoIP auto-reload behavior in runtime-layout.md

Added explicit note that Country/ASN databases reload every 5 minutes
without nginx restart, but configuration changes require reload.
```

### 例5：スクリプト修正

```
fix(scripts): handle $USER variable in build.sh

Previously failed when $USER env var was unset. Now falls back
to 'nobody' if unset, with clear error message.
```

## 実行手順（対話的）

1. **変更をステージング**
   ```bash
   git add <files>
   ```

2. **このスキルで対話的にコミット**
   - type を確認：feat / fix / docs / refactor / perf / test / chore / ci のいずれか
   - scope を確認：dockerfile / app / entrypoint / scripts / rules / commands / skills / docs
   - subject を確認：50字以内、命令形、小文字開始、句点なし
   - body を確認：**なぜ**この変更が必要か（実装の詳細ではなく）
   - footer を確認：Breaking change / Issue close がある場合のみ

3. **ワンライナーで実行（迅速な場合）**
   ```bash
   git commit -m "feat(app): 新機能の説明"
   ```

4. **詳細なボディを含める（重要な変更）**
   ```bash
   git commit -m "feat(dockerfile): マルチステージの最適化" \
     -m "理由を説明する複数行のテキスト。
     
   なぜこの変更が必要だったのかを述べる。"
   ```

## チェックリスト（実行前）

- [ ] 変更をステージングした：`git status` で確認
- [ ] type を選択した（feat/fix/docs/refactor/perf/test/chore/ci）
- [ ] scope を選択した（該当するもの）
- [ ] subject は命令形か
- [ ] subject は50字以内か
- [ ] body に**動機・目的**が記述されているか（実装の詳細ではなく）
- [ ] 関連するIssueがあれば `Closes #123` を footer に記述したか

## よくある間違い

❌ `feat: added HTTP/3 support` — 過去形（NG）

✅ `feat: add HTTP/3 support` — 命令形（OK）

---

❌ `fix(dockerfile): Fixed the issue where QUIC host key was not generated` — 長すぎる

✅ `fix(dockerfile): add missing QUIC host key generation` — 50字以内（OK）

---

❌ コミットメッセージに実装の詳細のみ

✅ **なぜ**この変更が必要なのかを body に記述

## 関連ドキュメント

@.claude/commands/commit.md — Git コミット規約（詳細リファレンス）
