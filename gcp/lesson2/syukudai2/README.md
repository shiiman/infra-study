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
NAME                              REGION           NETWORK           RANGE
yamada-taro-cache-subnet          asia-northeast1  yamada-taro-vpc   172.16.50.0/24
yamada-taro-db-subnet             asia-northeast1  yamada-taro-vpc   172.16.40.0/24
yamada-taro-private-subnet        asia-northeast1  yamada-taro-vpc   172.16.10.0/24
yamada-taro-public-subnet         asia-northeast1  yamada-taro-vpc   172.16.0.0/24
yamada-taro-web-subnet            asia-northeast1  yamada-taro-vpc   172.16.20.0/22
yamada-taro-osaka-private-subnet  asia-northeast2  yamada-taro-vpc   172.16.110.0/24
yamada-taro-osaka-public-subnet   asia-northeast2  yamada-taro-vpc   172.16.100.0/24
```

Cloud Routerが2つ(東京・大阪)できていることを確認する。

```
gcloud compute routers list
```

## 発展: 東京のVMから大阪のVMへ通信できるか

同じVPCなので、Firewall Ruleさえ許可すればリージョンをまたいで
プライベートIPで直接通信できる。試してみると理解が深まる。

`routing_mode` は、Cloud Router が学習した動的経路を適用するリージョンを決める。
`REGIONAL`(デフォルト)では、その Cloud Router と同じリージョンに適用される。
`GLOBAL` では、同じVPCの全リージョンに適用される。
デフォルトの経路広告で、Cloud Router が相手側へ広告するサブネット経路の範囲も、
`REGIONAL` では同じリージョン、`GLOBAL` では全リージョンになる。

VPC内のサブネット間通信は、自動生成されるサブネットルートを使うため、
この設定では制限されない。今回の構成は Cloud Router を Cloud NAT のために置き、
BGP は使わないので、`REGIONAL` のままで問題ない。

## 参考

- [VPC ネットワークの概要](https://cloud.google.com/vpc/docs/vpc)
- [Cloud NAT の概要](https://cloud.google.com/nat/docs/overview)
- [動的ルーティングモード](https://docs.cloud.google.com/network-connectivity/docs/router/concepts/learned-routes)
- [Cloud Router のデフォルトの経路広告](https://docs.cloud.google.com/network-connectivity/docs/router/concepts/advertised-routes)
