---
globs: Dockerfile
description: Dockerfile のマルチステージ構成と依存関係管理に関する規約
---

# Dockerfile アーキテクチャ規約

## ビルドステージ構成

Dockerfile は以下の 7 つのステージで構成されます。各ステージは独立したビルドを行い、成果物を最終ステージ（`nginx_executor`）にコピーします。

| ステージ名 | ベース | 主な処理 | 出力 |
|---|---|---|---|
| `geoip2_builder` | ubuntu | GitHub からモジュールソースをクローン | `ngx_http_geoip2_module/` |
| `brotli_builder` | ubuntu | brotli ライブラリ + nginx モジュールをコンパイル（`-Ofast -march=native`） | 静的ライブラリ + `.so` |
| `openssl_builder` | ubuntu | OpenSSL 最新版をソースからコンパイル | OpenSSL ソースツリー |
| `njs_builder` | ubuntu | njs スクリプティングモジュールをコンパイル | `njs_modules.so` |
| `dhparam_builder` | ubuntu | 4096 ビット DH パラメータ + QUIC ホストキー生成 | `dhparam.pem`、16 バイトキー |
| `nginx_builder` | ubuntu | freenginx をソースからコンパイル（モジュール統合） | freenginx バイナリ + `.so` |
| `nginx_executor` | ubuntu | ランタイムミニマル構成（ビルドツール除去） | 実行用イメージ |

## 重要な実装ルール

- **ソース取得：** nginx は Mercurial (`hg`) 経由で `http://freenginx.org/hg/nginx` からフェッチ
- **並列ビルド：** `make -j$(grep -c processor /proc/cpuinfo)` で全 CPU コアを利用
- **OpenSSL フラグ：** Dockerfile に `--with-openssl-opt="enable-ktls"` を指定（カーネル TLS サポート）
- **nginx コンパイルフラグ：** `--add-dynamic-module` で brotli・njs・geoip2 を動的モジュールとして統合
- **ステージ境界：** 各ステージの出力パスが明確に定義されていること（`COPY --from=` で参照される）

## 編集時の留意点

- ステージ追加・削除時は、`COPY --from=` 依存関係が正確に更新されること
- brotli コンパイルフラグ（`-Ofast -march=native`）を変更する際は、パフォーマンス影響を検証
- OpenSSL バージョンアップ時は kernel TLS 互換性を確認
