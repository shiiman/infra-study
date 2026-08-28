# 回答例

## 課題

Cloud Armor でセキュリティポリシーを作り、社内IPからのみアクセスできるようにする。

## 回答

`armor.tf` と `lb.tf` を参照。
`terraform.tfvars` の `company_ip` に会社のIPレンジを入れる。

```hcl
company_ip = ["xxx.xxx.xxx.xxx/32"]
```

## この課題のポイント

### Firewall Rules とどう違うのか

| | Firewall Rules | Cloud Armor |
|---|---|---|
| 効く場所 | VPCの中 | VPCの外(Googleのフロントエンド) |
| 守る対象 | VM | ロードバランサのバックエンドサービス |
| 判定できるもの | IP / ポート / プロトコル | IP / 地域 / HTTPヘッダ / URLパス / SQLi・XSSパターン |
| AWSでいうと | Security Group | WAF |

**Cloud Armor はロードバランサに到達する前に弾く。**
VMまでリクエストが来ないので、VM側の負荷にならない。

第2回でやった Firewall Rules は「VPCに入ってから」の話だったので、
守る層が違う。両方を組み合わせて使う。

### ルールの評価順

`priority` が小さいものから順に評価され、**最初に一致したもの**が適用される。

```
priority 1000        社内IP        → allow
priority 2147483647  すべて(*)     → deny(403)
```

`priority 2147483647` のデフォルトルールは**省略できない**。
書かないとポリシーが作れずエラーになる。

## 確認方法

```
terraform plan
terraform apply
```

ポリシーの反映には数分かかる。

### 社内から

```
curl -I https://[自分の名前].[勉強会のドメイン]
```

```
HTTP/2 200
```

### 社外から(スマホのテザリングなど)

```
HTTP/2 403
```

Cloud Armor が返した403。VMには一切リクエストが届いていない。

### 誰が弾かれたかをログで見る

```
gcloud logging read \
  'resource.type="http_load_balancer" AND jsonPayload.enforcedSecurityPolicy.outcome="DENY"' \
  --limit=5 --format=json
```

第8回(監視・運用)でこのログの読み方を扱います。

## ハマりどころ

- **ヘルスチェックは Cloud Armor の影響を受けない**。
  ヘルスチェックはGoogle内部から来るので、社内IP以外を全部拒否しても
  バックエンドはHEALTHYのまま。これは正しい挙動
- ポリシーの反映に数分かかる。applyしてすぐ403が出なくても慌てない
- `src_ip_ranges` に `/32` を付け忘れると構文エラーになる

## 発展: プリセットルール

Cloud Armor には SQLインジェクションやXSSを検知する
**事前構成 WAF ルール**が用意されている。

```hcl
rule {
  action   = "deny(403)"
  priority = 900
  match {
    expr {
      expression = "evaluatePreconfiguredExpr('sqli-v33-stable')"
    }
  }
}
```

IP制限だけでなく、こうした攻撃パターンの検知も1行で足せる。

## 参考

- [Google Cloud Armor の概要](https://cloud.google.com/armor/docs/cloud-armor-overview)
- [セキュリティポリシーのルール](https://cloud.google.com/armor/docs/rules-language-reference)
- [事前構成 WAF ルール](https://cloud.google.com/armor/docs/waf-rules)
