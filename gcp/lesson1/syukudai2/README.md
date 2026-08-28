# 回答例

## 課題

Secret Manager にシークレットを作り、
第1回で作ったサービスアカウントに「そのシークレットだけ」を読む権限を与える。

## 回答

`secret_manager.tf` を参照。

## なぜ値(secret_data)をTerraformに書かないのか

`google_secret_manager_secret_version` の `secret_data` にパスワードを書くと、
**tfstateに平文で保存される**。tfstateはGCSに置いてあるので、
バケットを読める人全員にパスワードが見えることになる。

シークレットの「入れ物」はTerraformで、「中身」はCLIやCI/CDから投入するのが基本。

## 確認方法

apply したあと、値をCLIから登録する。

```
echo -n "infra-study-gcp" | gcloud secrets versions add [自分の名前]-app-secret --data-file=-
```

サービスアカウントになりすまして読めることを確認する。

```
gcloud secrets versions access latest \
  --secret=[自分の名前]-app-secret \
  --impersonate-service-account=[自分の名前]-app@[プロジェクトID].iam.gserviceaccount.com
```

```
infra-study-gcp
```

他人のシークレットは読めないことも確認しておく(リソース単位で権限を付けた効果)。

```
gcloud secrets versions access latest \
  --secret=[他の人の名前]-app-secret \
  --impersonate-service-account=[自分の名前]-app@[プロジェクトID].iam.gserviceaccount.com
```

```
ERROR: (gcloud.secrets.versions.access) PERMISSION_DENIED: ...
```

## 後片付け

シークレットは `terraform destroy` で削除されるが、
CLIで追加したバージョンも一緒に消える。

## 参考

- [Secret Manager のドキュメント](https://cloud.google.com/secret-manager/docs)
- [Secret Manager のアクセス制御](https://cloud.google.com/secret-manager/docs/access-control)
