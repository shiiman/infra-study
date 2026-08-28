# 回答例

## 課題

事前定義ロール `roles/storage.objectViewer` の代わりに、
必要な権限だけを持つカスタムロールを作成してサービスアカウントに付与する。

## 回答

`custom_role.tf` を参照。

## 確認方法

カスタムロールだけで読めることを確認したいので、
`iam.tf` の `google_storage_bucket_iam_member.app_object_viewer` を
一時的にコメントアウトしてから apply する。

```
terraform plan
terraform apply
```

サービスアカウントになりすまして読めることを確認する。

```
gcloud storage ls gs://[プロジェクトID]-tfstate-[自分の名前]/ \
  --impersonate-service-account=[自分の名前]-app@[プロジェクトID].iam.gserviceaccount.com
```

権限が絞れていることも確認する。書き込みは失敗するはず。

```
echo test > /tmp/test.txt
gcloud storage cp /tmp/test.txt gs://[プロジェクトID]-tfstate-[自分の名前]/ \
  --impersonate-service-account=[自分の名前]-app@[プロジェクトID].iam.gserviceaccount.com
```

```
ERROR: (gcloud.storage.cp) HTTPError 403: ... does not have storage.objects.create access ...
```

確認が終わったらコメントアウトを元に戻すこと。

## 3種類のロールの違い

| 種類 | 例 | 使いどころ |
|---|---|---|
| 基本ロール | roles/owner, roles/editor, roles/viewer | 本番では使わない。強すぎる |
| 事前定義ロール | roles/storage.objectViewer | 基本はこれを使う |
| カスタムロール | 自分で作る | 事前定義ロールでは粒度が合わない時だけ |

## ハマりどころ

- `role_id` にハイフンは使えない。`replace()` 関数で `_` に変換している
- カスタムロールを `terraform destroy` で削除しても、7日間は「削除済み」状態で残る。
  同じ `role_id` ですぐに作り直すとエラーになるので注意
  (`gcloud iam roles undelete` で復活させるか、7日待つか、別のIDにする)

## 参考

- [カスタムロールの作成と管理](https://cloud.google.com/iam/docs/creating-custom-roles)
- [IAM の権限リファレンス](https://cloud.google.com/iam/docs/permissions-reference)
