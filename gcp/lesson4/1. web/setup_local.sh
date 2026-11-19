#!/usr/bin/env bash
#
# 第4回 Step1: VM の中で、ローカルのDB(PostgreSQL)・キャッシュ(Redis)・Spanner エミュレータのコンテナを起動するまでをまとめて実行する
#
# 【なぜスクリプトにしたのか】
# 以前は同じ手順を1行ずつ貼り付けて実行していた。
# SSH で入った VM の中では、複数行をまとめて貼ると行が欠けたり、
# apt-get が標準入力を読んでしまって後ろの行が消えたりする。
# 貼り付ける行を減らし、手順そのものはこのファイルに任せる。
#
# 【使い方】(VM の中で、root で実行する)
#   sudo su -
#   bash "/root/infra-study/gcp/lesson4/1. web/setup_local.sh"
#
# 何度実行しても同じ結果になる(途中で止まったら、そのまま再実行してよい)。

set -euo pipefail

# このファイルは「1. web」の直下にある。コンテナのビルドは web_app の中で行う
APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/web_app"
NETWORK="app-nw"

# 実行するコマンドを画面に出してから実行する(何をしているかが見える)
run() {
  echo "+ $*"
  "$@"
}

step() {
  echo
  echo "=== $* ==="
}

if [ "$(id -u)" -ne 0 ]; then
  echo "root で実行してください。先に 'sudo su -' を実行します。" >&2
  exit 1
fi

step "[1/6] 準備: docker と各種クライアントを入れる"
export DEBIAN_FRONTEND=noninteractive
run apt-get update
run apt-get upgrade -y
run apt-get install -y docker.io git postgresql-client redis-tools
run systemctl start docker

cd "$APP_DIR"

step "[2/6] ネットワーク: コンテナ同士をつなぐ app-nw を作る"
# 作り直しても止まらないように、あれば作らない
if ! docker network inspect "$NETWORK" >/dev/null 2>&1; then
  run docker network create "$NETWORK"
else
  echo "$NETWORK はすでにあります"
fi

# 再実行したときに名前が衝突しないよう、前回のコンテナを消しておく
docker rm -f db cache spanner app >/dev/null 2>&1 || true

step "[3/6] db: PostgreSQL のコンテナをビルドして起動する"
run docker build --pull --no-cache -t db:0.1 -f ./dockerfile_postgres .
run docker run -d --network "$NETWORK" --name db db:0.1

step "[4/6] cache: Redis のコンテナをビルドして起動する"
run docker build --pull --no-cache -t cache:0.1 -f ./dockerfile_redis .
run docker run -d --network "$NETWORK" --name cache cache:0.1

step "[5/6] spanner: Spanner エミュレータのコンテナを起動する"
# エミュレータは、本物の Spanner と同じ API を話すローカル用のプログラム(Google が配布している)
#   9010: gRPC(アプリが使う)  9020: REST(インスタンスとデータベースを作るのに使う)
# あとで本物の Spanner に置き換える。アプリのコードは変えない
run docker run -d --network "$NETWORK" -p 127.0.0.1:9020:9020 --name spanner \
  gcr.io/cloud-spanner-emulator/emulator

# 起動を待ってから、インスタンスとデータベースを作る(テーブルは作らない)
for i in $(seq 1 30); do
  curl -s -o /dev/null http://localhost:9020/v1/projects/test-project/instances && break
  sleep 1
done
run curl -s -X POST http://localhost:9020/v1/projects/test-project/instances \
  -H 'Content-Type: application/json' \
  -d '{"instanceId":"test-instance","instance":{"config":"projects/test-project/instanceConfigs/emulator-config","displayName":"test","nodeCount":1}}' \
  -o /dev/null
run curl -s -X POST http://localhost:9020/v1/projects/test-project/instances/test-instance/databases \
  -H 'Content-Type: application/json' \
  -d '{"createStatement":"CREATE DATABASE `test-db`"}' \
  -o /dev/null

step "[6/6] app: アプリのコンテナをビルドして起動する(約5分かかります)"
run docker build --pull --no-cache -t app:0.1 .
run docker run -d -p 80:8080 --network "$NETWORK" --name app \
  -e DB_HOST=db -e DB_PASS=infra-study -e CACHE_HOST=cache \
  app:0.1

echo
echo "=== 完了: コンテナを起動しました(db・cache・spanner・app)==="
echo "確認は手で実行します(スクリプトには含めていません):"
echo "  curl http://localhost"
echo "「失敗」と出たら少し待って、もう一度実行してください。続くときは docker logs db / docker logs app を見ます。"
