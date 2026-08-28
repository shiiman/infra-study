# 回答例

## 課題

Cloud Armor で静的ファイルの配信にも社内IP制限をかける。

## 回答

`armor.tf` と `cdn.tf` を参照。

```hcl
resource "google_compute_security_policy" "edge" {
  name = "${var.user_name}-edge-policy"

  // ★ これが無いと edge_security_policy に指定できない
  type = "CLOUD_ARMOR_EDGE"

  // ルールの中身は第3回 宿題3 と同じ
}

resource "google_compute_backend_bucket" "static" {
  // バックエンドバケットにも Cloud Armor を付けられる
  edge_security_policy = google_compute_security_policy.edge.id
}
```

`terraform.tfvars` の `company_ip` に会社のIPレンジを入れる。

## ★ 最大のハマりどころ: ポリシーには2種類ある

第3回 宿題3 のポリシーをそのまま使い回そうとすると失敗する。

```
Error: Error setting Backend Service security policy: googleapi: Error 400:
Invalid value for field 'resource': ...
Security policy ... is not an edge security policy., invalid
```

`google_compute_security_policy` の `type` を省略すると `CLOUD_ARMOR` になり、
これは `edge_security_policy` には指定できない。

| type | 付ける属性 | 付けられる対象 | 評価される場所 |
|---|---|---|---|
| `CLOUD_ARMOR`(既定) | `security_policy` | バックエンドサービス | オリジンへ行く手前 |
| `CLOUD_ARMOR_EDGE` | `edge_security_policy` | バックエンドバケット / CDN有効なバックエンドサービス | **CDNのエッジ** |

**バックエンドバケットに `security_policy` という属性は存在しない。**
`edge_security_policy` を使い、ポリシー側に `type = "CLOUD_ARMOR_EDGE"` を書く。

エッジで評価されるので、**キャッシュヒットしたリクエストも弾ける。**
第3回の Cloud Armor(バックエンドサービス)より手前で効く。

なお、エッジポリシーで使えるルールは通常のポリシーより少ない
(レート制限や事前構成のWAFルールは使えない)。
送信元IPでの許可/拒否はどちらでも使える。

## 確認方法

```
terraform apply
```

**ルールの反映に1〜2分かかる。**(実測: apply から約1分30秒で 403 になった)
apply 直後は 200 のままなので、少し待ってから確認すること。

### 社内から

```
curl -I https://[自分の名前].[勉強会のドメイン]/static/index.html
```

```
HTTP/2 200
```

### 社外から(スマホのテザリングなど)

```
HTTP/2 403
```

### バケットに直接アクセスするとどうなるか

```
curl -I https://storage.googleapis.com/[バケット名]/static/index.html
```

**Cloud Armor は効かない。200 が返る。**

実測でも、LB経由が 403 になっている状態で
バケット直アクセスは 200 で中身が読めた。

講義の Step3 で `allUsers` に `objectViewer` を付けたので、
バケットは誰でも直接読める状態になっている。
Cloud Armor はロードバランサの手前にいるので、
LBを経由しないアクセスには関与しない。

**これは重要な落とし穴。**
「CDNにIP制限をかけたから安全」ではない。

### 対策

| 方法 | 内容 |
|---|---|
| 署名付きURL | 有効期限付きのURLを発行する。バケットは非公開のまま |
| 署名付きCookie | CDN配信用。Cloud CDNの機能 |
| バケットを非公開にする | ただしバックエンドバケットからも読めなくなる |

静的ファイルが「見られて困るもの」なら、
公開バケット + Cloud Armor という構成自体を見直すべき。

## 参考

- [Google Cloud Armor の概要](https://cloud.google.com/armor/docs/cloud-armor-overview)
- [エッジセキュリティポリシー](https://cloud.google.com/armor/docs/security-policy-overview#edge-security-policies)
- [署名付きURL](https://cloud.google.com/storage/docs/access-control/signed-urls)
