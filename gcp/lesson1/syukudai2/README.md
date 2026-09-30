# 回答例

## 課題

Secret Manager にシークレットを作り、
第1回で作ったサービスアカウントに「そのシークレットだけ」を読む権限を与える。

シークレットの値も Terraform で入れる。**ただし、値を tfstate に平文で残さないこと。**

## 回答

`secret_manager.tf` を参照。

`syukudai1` の内容(カスタムロールを含む)に、`secret_manager.tf` を足したもの。
**宿題1の続きで作業している場合、足すのは `secret_manager.tf` だけでよい。**
`custom_role.tf` を含めずに plan すると、宿題1で作ったカスタムロールが destroy の対象に出る。

## シークレットの値を、tfstate に残さずに入れる

シークレットの「入れ物」と「値」の両方を Terraform で作る。
**ただし、値を tfstate に平文で残さない。**

`google_secret_manager_secret_version` には値を渡す引数が2つある。

| 引数 | tfstate に値が | 使いどころ |
|---|---|---|
| `secret_data` | **平文で保存される** | 使わない。tfstate を読める人全員に値が見える |
| `secret_data_wo` (write-only) | **保存されない** | こちらを使う |

`secret_data_wo` は書き込み専用で、API からも読み戻さない。
値は **ephemeral(一時的)な変数**で受け取る。ephemeral な値は
tfstate にも plan にも残らず、apply の間だけメモリ上にある(`secret_manager.tf` を参照)。

Terraform 1.11 以降で使える(ephemeral は 1.10 以降)。

## 確認方法

**値を入力して apply する。** 環境変数で渡す。`read -s` で入力すれば、
画面にも**シェルの履歴にも残らない**(`-var` で渡すと履歴に残る)。

```
read -rs TF_VAR_secret_value      # 値を入力して Enter(画面には出ない)
export TF_VAR_secret_value
terraform apply
unset TF_VAR_secret_value         # 終わったら消す
```

- **値は何でもよい**(`test-secret-123` など)。空だけは通らない。本物のパスワードや API キーは入れない
- **確認プロンプトには `yes` と3文字入力する**。`y` や Enter だけだと `Apply cancelled.` になる
- **`gcloud` には `--project=[プロジェクトID]` を付ける**。Cloud Shell には既定のプロジェクトが無く、
  付けないと `Failed to find attribute [project]` になる

値が入ったことを確認する(自分のアカウントで読める)。

```
gcloud secrets versions access latest \
  --secret=[自分の名前]-app-secret \
  --project=[プロジェクトID]
```

値を渡し忘れて apply すると、Secret Manager が拒否する(空のシークレットは作られない)。

```
Error: Error creating SecretVersion: googleapi: Error 400: Field [payload] is required.
```

**tfstate に値が無いことを確認する**(この課題の一番大事なところ)。

```
terraform state pull | grep "入力した値"
```

何も出なければ OK。比較したいなら `secret_data_wo` を `secret_data` に変えて
apply し直し、もう一度同じコマンドを打ってみる(今度は平文で出る)。
**比較が終わったら、必ず `secret_data_wo` に戻して apply し直すこと**
(平文の値が GCS の tfstate に残ったままになる)。

サービスアカウントになりすまして読めることを確認する。
**IAM の反映待ちで、apply 直後は約1分失敗する**(第1回 S85 と同じ)。

```
gcloud secrets versions access latest \
  --secret=[自分の名前]-app-secret \
  --project=[プロジェクトID] \
  --impersonate-service-account=[自分の名前]-app@[プロジェクトID].iam.gserviceaccount.com
```

```
(入力した値)
```

他人のシークレットは読めないことも確認しておく(リソース単位で権限を付けた効果)。

```
gcloud secrets versions access latest \
  --secret=[他の人の名前]-app-secret \
  --project=[プロジェクトID] \
  --impersonate-service-account=[自分の名前]-app@[プロジェクトID].iam.gserviceaccount.com
```

```
ERROR: (gcloud.secrets.versions.access) PERMISSION_DENIED: ...
```

## 値を更新するとき

**値だけ変えても、Terraform は変更を検知しない。** 値を持っていないので、
比較のしようがない(`No changes` と出て、Secret Manager の値は古いまま)。
**`secret_data_wo_version` の数字を上げる。**

```hcl
secret_data_wo_version = 2   # 1 → 2
```

**数字を上げると、古いバージョンは破棄される**(`1 to add, 1 to destroy`)。
ロールバック用に残したいなら `deletion_policy` を見直す。

## それでも Terraform に値を渡さない選択肢がある

write-only で「tfstate に残る」問題は避けられる。それでも、値を Terraform の外から
`gcloud` や CI で入れる運用が選ばれることがある。理由を考えてみてほしい。

- **値を扱う人と、インフラを作る人の権限を分けたい。**
  `terraform apply` を実行する人(や CI)に、値そのものを見せたくない
- **値の更新を、インフラのデプロイと切り離したい。**
  ローテーションのたびに Terraform を回したくないし、
  バージョン番号を手で上げるのも忘れやすい
- **値の出どころは結局どこかにある。**
  `TF_VAR_...` の環境変数も、CI のシークレットも、誰かが管理している。
  Terraform は「tfstate に残さない」ことは解決するが、
  「値をどう安全に受け渡すか」までは解決しない

## 後片付け

シークレットは `terraform destroy` で削除される。
**`secret_value` は既定値(空文字)があるので、destroy のときに値を聞かれない。**
(既定値が無いと、destroy のたびに値を聞かれる)

## 参考

- [Secret Manager のドキュメント](https://cloud.google.com/secret-manager/docs)
- [Secret Manager のアクセス制御](https://cloud.google.com/secret-manager/docs/access-control)
