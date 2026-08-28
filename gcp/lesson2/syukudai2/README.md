# 回答例

## 課題

大阪リージョン(asia-northeast2)にサブネットを追加し、
そのリージョン用の Cloud Router と Cloud NAT を作る。

| 名前 | CIDR | リージョン |
|---|---|---|
| osaka-public | 172.16.100.0/24 | asia-northeast2 |
| osaka-private | 172.16.110.0/24 | asia-northeast2 |

## 回答

`subnet.tf` / `cloud_nat.tf` / `terraform.tfvars` を参照。

## この課題のポイント

**VPCを作り直していない。** 東京と大阪のサブネットが同じVPCに同居している。

AWSで同じことをやろうとすると、大阪リージョンにVPCをもう1つ作り、
VPCピアリングまたはTransit Gatewayで接続する必要があった。
GCPのVPCはグローバルリソースなので、サブネットを足すだけで済む。

一方で **Cloud NAT と Cloud Router はリージョン単位**なので、
リージョンを増やしたらその分だけ作る必要がある。
「VPCはグローバル、その中身はリージョン」という境界を意識すること。

## 確認方法

```
terraform plan
terraform apply
```

同じVPCに東京と大阪のサブネットが並んでいることを確認する。

```
gcloud compute networks subnets list --filter="network:[自分の名前]-vpc"
```

```
NAME                          REGION           NETWORK      RANGE
shiiman-cache-subnet          asia-northeast1  shiiman-vpc  172.16.50.0/24
shiiman-db-subnet             asia-northeast1  shiiman-vpc  172.16.40.0/24
shiiman-private-subnet        asia-northeast1  shiiman-vpc  172.16.10.0/24
shiiman-public-subnet         asia-northeast1  shiiman-vpc  172.16.0.0/24
shiiman-web-subnet            asia-northeast1  shiiman-vpc  172.16.20.0/22
shiiman-osaka-private-subnet  asia-northeast2  shiiman-vpc  172.16.110.0/24
shiiman-osaka-public-subnet   asia-northeast2  shiiman-vpc  172.16.100.0/24
```

Cloud Routerが2つ(東京・大阪)できていることを確認する。

```
gcloud compute routers list
```

## 発展: 東京のVMから大阪のVMへ通信できるか

同じVPCなので、Firewall Ruleさえ許可すればリージョンをまたいで
プライベートIPで直接通信できる。試してみると理解が深まる。

なお `routing_mode` が `REGIONAL`(デフォルト)の場合、
Cloud Router はリージョンをまたいだ経路を学習しない。
オンプレ接続などで全リージョンに経路を配りたい場合は `GLOBAL` にする。
今回のようにVPC内部の通信だけであれば `REGIONAL` のままで問題ない。

## 参考

- [VPC ネットワークの概要](https://cloud.google.com/vpc/docs/vpc)
- [Cloud NAT の概要](https://cloud.google.com/nat/docs/overview)
- [動的ルーティングモード](https://cloud.google.com/vpc/docs/vpc#routing_for_hybrid_networks)
