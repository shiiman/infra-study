# 回答例

## 課題

webインスタンスを別ゾーンにも置いて冗長化する。
`asia-northeast1-a` に障害が起きても `asia-northeast1-b` で動き続ける状態にする。

## 回答

`instance_b.tf` と `lb.tf` を参照。

## この課題のポイント

### インスタンスグループはゾーン単位

**1つのインスタンスグループに、別ゾーンのVMは入れられない。**

ゾーンを増やしたら、そのゾーン用のインスタンスグループを作り、
バックエンドサービスの `backend` ブロックを増やす。

```hcl
resource "google_compute_backend_service" "web" {
  backend {
    group = google_compute_instance_group.web.id     # 1a
  }
  backend {
    group = google_compute_instance_group.web_b.id   # 1b
  }
}
```

サブネットは第2回でやったとおりリージョン単位なので、
**サブネットは増やさなくてよい**。同じ private サブネットに両方のVMが入る。
AWS版ではAZごとにサブネットが必要だったところ。

### 起動スクリプトでセットアップを自動化した

AWS版では「カスタムAMIを作って、それを使って2台目を立てる」手順だった。
GCPでも同じことはできる(`gcloud compute images create`)が、
ここでは `startup-script` メタデータでセットアップを自動化している。

VMの初回起動時にrootで実行されるので、
Dockerのインストールからアプリの起動までを1つにまとめられる。
イメージを作り直す必要がないぶん、コードだけで完結する。

## 確認方法

```
terraform plan
terraform apply
```

起動スクリプトの完走に2〜3分かかる。ログで確認できる。

```
gcloud compute instances get-serial-port-output [自分の名前]-web-b \
  --zone=asia-northeast1-b | grep startup-script
```

両方のバックエンドがHEALTHYになっていることを確認する。

```
gcloud compute backend-services get-health [自分の名前]-web-bs --global
```

```
backend: .../instanceGroups/shiiman-web-ig
status:
  healthStatus:
  - healthState: HEALTHY
    instance: .../instances/shiiman-web
backend: .../instanceGroups/shiiman-web-b-ig
status:
  healthStatus:
  - healthState: HEALTHY
    instance: .../instances/shiiman-web-b
```

### 冗長化できていることを確かめる

ブラウザで何度かリロードすると `hostname` が変わる
(2台に振り分けられている)。

1台を止めても、アクセスが継続することを確認する。

```
gcloud compute instances stop [自分の名前]-web --zone=asia-northeast1-a
```

ヘルスチェックが落ちるまで数十秒かかる。
その間は片方に振られたリクエストがエラーになることがある。
これがヘルスチェックの間隔としきい値のトレードオフ。

確認できたら戻しておく。

```
gcloud compute instances start [自分の名前]-web --zone=asia-northeast1-a
```

## 発展: MIG(マネージドインスタンスグループ)

今回使ったのは手動管理の非マネージドインスタンスグループ。
実務では **MIG** を使うことが多い。

- インスタンステンプレートから自動でVMを作る
- 台数を指定すれば維持してくれる(壊れたら作り直す)
- オートスケール、ローリングアップデートができる
- リージョンMIGにすれば複数ゾーンへの分散も自動

今回の「ゾーンごとにインスタンスグループを作る」手間が消える。
講義では概説のみだったが、興味があれば触ってみてください。

## 参考

- [インスタンスグループ](https://cloud.google.com/compute/docs/instance-groups)
- [起動スクリプトの使用](https://cloud.google.com/compute/docs/instances/startup-scripts/linux)
- [マネージド インスタンス グループ](https://cloud.google.com/compute/docs/instance-groups/creating-groups-of-managed-instances)
