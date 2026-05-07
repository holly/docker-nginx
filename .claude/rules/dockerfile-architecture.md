---
globs: Dockerfile
description: Dockerfile のマルチステージ構成と依存関係管理に関する規約
---

# Dockerfile アーキテクチャ規約

## ビルドステージ構成

Dockerfile は以下の 7 つのステージで構成されます。各ステージは独立したビルドを行い、成果物を最終ステージ（`nginx_executor`）にコピーします。

| ステージ名 | ベース | 主な処理 | 出力 |
|---|---|---|---|
| `openssl_builder` | ubuntu | OpenSSL をソースからコンパイル（バージョン: `ARG OPENSSL_VERSION=3.6.2`） | OpenSSL ソースツリー |
| `geoip2_builder` | ubuntu | GitHub からモジュールソースをクローン | `ngx_http_geoip2_module/` |
| `brotli_builder` | ubuntu | brotli ライブラリ + nginx モジュールをコンパイル（`-Ofast -march=native`） | 静的ライブラリ + `.so` |
| `njs_builder` | ubuntu | njs スクリプティングモジュール（`./configure` のみ；nginx が `--add-dynamic-module=../njs/nginx` で統合） | njs ソースツリー |
| `dhparam_builder` | ubuntu | DH パラメータ取得（Mozilla RFC 7919 `ffdhe4096.txt`）+ QUIC ホストキー生成 | `dhparam.pem`、16 バイトキー |
| `nginx_builder` | ubuntu | freenginx をソースからコンパイル（モジュール統合） | freenginx バイナリ + `.so` |
| `nginx_executor` | ubuntu | ランタイムミニマル構成（ビルドツール除去） | 実行用イメージ + njs CLI バイナリ |

## 重要な実装ルール

- **OpenSSL バージョン管理：** グローバル `ARG OPENSSL_VERSION=3.6.2` で版を指定；`--branch openssl-${OPENSSL_VERSION} --depth 1` でターゲット取得
- **ソース取得：** nginx は Mercurial (`hg`) 経由で `http://freenginx.org/hg/nginx` からフェッチ
- **並列ビルド：** `make -j$(nproc)` で全 CPU コアを利用
- **APT キャッシュ高速化：** 全ステージで `--mount=type=cache,sharing=locked,target=/var/lib/apt/lists` と `--mount=type=cache,sharing=locked,target=/var/cache/apt/archives` を使用
- **OpenSSL オプション：** Dockerfile に `--with-openssl-opt="enable-ktls"` を指定（カーネル TLS サポート）
- **nginx コンパイルフラグ：** `--add-dynamic-module` で brotli・njs・geoip2 を動的モジュールとして統合；`--add-dynamic-module=../njs/nginx` で njs を nginx_builder ステージ内でコンパイル
- **ステージ境界：** 各ステージの出力パスが明確に定義されていること（`COPY --from=` で参照される）
- **njs ビルド：** njs_builder では `./configure` のみ実行；実際のモジュールコンパイルは nginx_builder の `auto/configure` で `--add-dynamic-module=../njs/nginx` として行われる
- **dhparam 生成：** `openssl dhparam` コマンド（数分掛かる）は使用せず、Mozilla の定義済み RFC 7919 ffdhe4096.txt を curl で取得（高速化）

## 編集時の留意点

- ステージ追加・削除時は、`COPY --from=` 依存関係が正確に更新されること
- `openssl_builder` を最初に実行する必要がある（後続ステージが依存）
- njs_builder は nginx_builder に COPY されるが、configure のみ行い make 実行はしないこと
- brotli コンパイルフラグ（`-Ofast -march=native`）を変更する際は、パフォーマンス影響を検証
- OpenSSL バージョンアップ時は kernel TLS 互換性と njs 互換性を確認
