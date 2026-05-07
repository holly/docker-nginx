# CLAUDE.md

このファイルは、このリポジトリで作業する Claude Code (claude.ai/code) へのガイダンスを提供します。

## プロジェクト概要

このプロジェクトは、[freenginx](http://freenginx.org) フォークをソースからコンパイルしてカスタム nginx Docker イメージを構築します。HTTP/3 (QUIC)、カーネル TLS、brotli 圧縮、GeoIP2、njs スクリプティングモジュールを含み、7 段階のマルチステージ Dockerfile ですべてソースからコンパイルされます。

## 技術スタック

- **ベース：** freenginx（nginx.org フォーク）
- **プロトコル：** HTTP/3 (QUIC)、TLSv1.2/1.3
- **セキュリティ：** カーネル TLS（enable-ktls）、4096-bit DH パラメータ
- **圧縮：** Brotli（レベル 7）
- **ロケーション情報：** GeoIP2（Country/City/ASN、5min auto-reload）
- **スクリプティング：** njs モジュール

## コマンド

### シェルスクリプト

```bash
./build.sh   # Docker イメージを $USER/nginx:latest としてビルド
./push.sh    # イメージをレジストリにプッシュ
./run.sh     # GeoIP データベース更新（.env 必須）、コンテナ起動
```

### Docker Compose（推奨）

```bash
docker compose up        # ビルド + GeoIP更新 + 実行（geoipupdate が自動で先に起動）
docker compose up --no-build  # 既存イメージで実行
docker compose down      # 停止・削除
```

@.claude/commands/build.md — build.sh の詳細（ビルドプロセス、トラブルシューティング）

@.claude/skills/build-and-diagnose/SKILL.md — Docker ビルド実行・出力監視・エラー診断・修正提案

@.claude/commands/push.md — push.sh の詳細（レジストリプッシュ、認証設定）

@.claude/commands/run.md — run.sh の詳細（GeoIP 更新、ポートマッピング、ライフサイクル）

@.claude/commands/docker-compose.md — Docker Compose でのビルド・実行（build.sh + run.sh統合）

@.claude/skills/commitizen-commit/SKILL.md — Commitizen形式でコミット（type/scope/subject確認、プロジェクト固有scope）

---

## 設定規約

@.claude/rules/dockerfile-architecture.md — Dockerfile マルチステージ構成、依存関係管理

@.claude/rules/runtime-layout.md — app/ ディレクトリ構造、バインドマウント、設計上の重要な制約
