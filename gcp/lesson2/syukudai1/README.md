# 回答例

## 課題

web / db / cache 用のサブネットを追加する。

| 名前 | CIDR | リージョン |
|---|---|---|
| web | 172.16.20.0/22 | asia-northeast1 |
| db | 172.16.40.0/24 | asia-northeast1 |
| cache | 172.16.50.0/24 | asia-northeast1 |

## 回答

`subnet.tf` と `terraform.tfvars` を参照。

## AWS版との違い

AWS版の同じ課題では、ゾーンごとに 2つずつ(web1/web2, db1/db2, cache1/cache2)
合計6つのサブネットを作る必要があった。

GCPのサブネットは**リージョン単位**でリージョン内の全ゾーンにまたがるため、
用途ごとに1つ、合計3つで済む。

もう1つの違いは**ルーティングの手当てが不要**なこと。

AWS版ではサブネットを追加するたびに
`aws_route_table_association` を足してルートテーブルに紐づける必要があったが、
GCPのルートはVPC単位なので、サブネットを足すだけで経路は自動的に通る。

Cloud NATも `source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"`
にしてあるため、追加したサブネットが自動でNAT対象に入る。

## 確認方法

```
terraform plan
terraform apply
```

```
gcloud compute networks subnets list --filter="network:[自分の名前]-vpc"
```

Cloud NATの対象に入っていることを確認する。

```
gcloud compute routers get-status [自分の名前]-router --region=asia-northeast1
```

## ハマりどころ

同一VPC内でサブネットのCIDRは重複できない。
`172.16.20.0/22` は `172.16.20.0` 〜 `172.16.23.255` を占めるので、
次のサブネットは `172.16.24.0` 以降にする必要がある。

## 参考

- [VPC ネットワークの概要](https://cloud.google.com/vpc/docs/vpc)
- [サブネットの操作](https://cloud.google.com/vpc/docs/create-modify-vpc-networks)
