# 回答例

## 課題

講義で作った Cloud SQL(REGIONAL)で、フェイルオーバーを起こして復旧時間を測る。

Cloud SQL を作るコード(`db.tf`)は、講義の `3. cloudsql` と同じ。
この回答例では、講義の状態にそのまま計測の手順を足す。
コードの変更は無いので、講義の続きで作ったリソースをそのまま使える。

★ 講義のあと destroy してしまった場合は、次のコマンドで作り直す。

```
read -rs TF_VAR_db_password      # 自分の user_name を入力(画面には出ない)
export TF_VAR_db_password
terraform apply
unset TF_VAR_db_password
```

## 計測の手順

ターミナルを2つ開く。

**1つ目: アプリを叩き続ける**

講義で起動したアプリのコンテナ(`DB_HOST` に Cloud SQL のエンドポイントIPを渡したもの)を使う。

```
while true; do
  printf '%s ' "$(date +%H:%M:%S)"
  curl -s -m 5 http://localhost | tr '\n' ' '
  echo
  sleep 1
done
```

**2つ目: フェイルオーバーを起こす**

```
gcloud sql instances failover [自分の名前]-db
```

`DB接続` が `失敗` になってから `成功` に戻るまでの秒数を数える。

```
14:20:31 ... DB接続(PostgreSQL): 成功
14:20:32 ... DB接続(PostgreSQL): 失敗   ← ここから
...
14:2x:xx ... DB接続(PostgreSQL): 成功   ← ここまで
```

(時刻は例。実際の秒数を自分で測る)

★ 参考: 作った側の計測では、`gcloud sql instances failover` が35秒で終わり、「失敗」だった時間は約12秒だった(1回のみ。ゾーンは b から c に変わった)。

**「HA構成なら無停止」ではない。** 切り替えの間は接続が切れる。

切り替わったことを確認する。

```
gcloud sql instances describe [自分の名前]-db --format="value(gceZone)"
```

前後でゾーンが変わっている。

## 考えてみてほしいこと

**切り替えの間もアプリを落とさないには?**

- コネクションプールのリトライ設定
- 読み取りだけでもキャッシュで返す
- ヘルスチェックの設計

**今日のアプリはどうなっているか?**

`DB接続: 失敗` と表示されるだけで、HTTPステータスは200のまま。
ロードバランサのヘルスチェックは `/` を見ているので、
**DBが落ちてもバックエンドはHEALTHYのまま**になる。

これは良いのか悪いのか。第8回(監視・運用)で扱います。

**Spanner で同じことをしたら?**

Spanner には `gcloud sql instances failover` に当たるコマンドが無い。
切り替えという操作が無い理由は、講義のまとめ(Cloud SQL と Spanner の違い)を見直してみてください。

## 後片付け

```
terraform destroy
```

★ destroy にも時間がかかるので、余裕を持って実行する。

## 参考

- [Cloud SQL の高可用性](https://cloud.google.com/sql/docs/postgres/high-availability)
- [Cloud SQL のフェイルオーバーを手動で起こす](https://cloud.google.com/sql/docs/postgres/high-availability#failover)
