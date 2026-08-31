# 回答例

## 課題

Cloud Deploy でカナリアデプロイを組み、10% → 50% → 100% と段階的に切り替える。

## 回答

`clouddeploy.tf` を参照。作るものは5つ。

| リソース | 役割 |
|---|---|
| `google_cloud_run_v2_service.canary` | デプロイ先のサービス。**入れ物だけ作る** |
| `google_cloud_run_v2_service_iam_member` ×2 | 公開用 + Cloud Deploy への更新権限 |
| `google_storage_bucket.deploy` | レンダリング済みマニフェストの保管場所 |
| `google_clouddeploy_target` | デプロイ先(どのプロジェクト・リージョンの Cloud Run か) |
| `google_clouddeploy_delivery_pipeline` | どういう順・割合で出すか |

実行主体のサービスアカウントは**新しく作らない**。
講師が用意した `<自分の名前>-build` を使う
(`roles/logging.logWriter` と `roles/clouddeploy.jobRunner` が付いている)。

カナリアの指定はここだけ。

```hcl
canary {
  runtime_config {
    cloud_run {
      automatic_traffic_control = true
    }
  }
  canary_deployment {
    percentages = [10, 50]
  }
}
```

`[10, 50]` と書くと **10% → 50% → 100%** の3段階になる。
最後の 100% は自動で足されるので書かない。

## ★ なぜサービスを Terraform で先に作るのか

「Cloud Deploy に新規作成させればいい」と思うところだが、それをやると失敗する。

```
error checking Cloud Run State: Error 403:
Permission 'run.services.get' denied on resource
'namespaces/[プロジェクトID]/services/[自分の名前]-canary'
```

**サービス単位のIAMは、すでにあるサービスにしか付けられない。**
まだ無いものを作る権限は、プロジェクト単位にならざるを得ない。

しかしこのプロジェクトは共有で、他の本番 Cloud Run も動いている。
プロジェクト単位の `roles/run.developer` を配ると、
受講者のCIが**他人の本番サービスも触れる**状態になる。それは通せない。

だから **入れ物は Terraform、中身は Cloud Deploy** に分ける。
サービスが先に存在すれば、権限をサービス単位で付けられる。

講義でやった責務の分け方が、ここでは
**「権限を絞れる形はどれか」という別の理由からも要求される。**

## ★ デプロイ先を別サービスにしている理由

Cloud Deploy は **サービスの定義まるごと**をマニフェストで持つ。

講義で作った `<自分の名前>-app` は Terraform が
環境変数(`SPANNER_*` / `CACHE_HOST`)・Direct VPC egress・サービスアカウントまで
管理しているので、Cloud Deploy をそのまま当てると全部上書きされてアプリが壊れる。

**サービスの定義は Terraform か Cloud Deploy のどちらか一方に持たせる。**

| 持たせる先 | デプロイの形 |
|---|---|
| Terraform | CI/CD は image だけ差し替える(**講義のやり方**) |
| Cloud Deploy | サービス定義ごとリリースで管理する |

宿題では講義の環境を壊さないよう、`<自分の名前>-canary` を新規に作らせる。

## 確認方法

### 1. apply

```
terraform apply
```

### 2. リリースを作る

アプリのリポジトリで作業する。`deploy/` にある2ファイルを使う。

```
# Terraform の出力を確認
PIPELINE=$(terraform output -raw deploy_pipeline)
REPO=$(terraform output -raw repository_url)

# サービス名と実行SAを埋める
mkdir -p ~/rel
sed -e "s/APP_NAME/[自分の名前]-canary/" \
    -e "s/RUN_SA/[自分の名前]-run@[プロジェクトID].iam.gserviceaccount.com/" \
    deploy/run-service.yaml > ~/rel/run-service.yaml
cp deploy/skaffold.yaml ~/rel/

cd ~/rel && gcloud deploy releases create rel-1 \
  --delivery-pipeline=$PIPELINE \
  --region=asia-northeast1 \
  --images=app=$REPO/app:latest
```

★ `run-service.yaml` の中身は、Terraform で作ったサービスと
   **同じ形にしておくこと**。Cloud Deploy はこのファイルで
   サービス定義を丸ごと置き換えるので、
   ここに書いていない設定は消える。

### 3. ロールアウトの状態を見る

```
gcloud deploy rollouts list \
  --delivery-pipeline=[自分の名前]-pipeline \
  --release=[リリース名] --region=asia-northeast1
```

**★ 最初のリリースは止まって見えるが、故障ではない ★**

**1回目のリリースでは、カナリアは必ずスキップされる。**

Cloud Deploy は「**自分がデプロイしたリビジョン**」を基準にして
トラフィックを分ける。Terraform が作ったリビジョンは基準にならない。
比べる相手がいないので、カナリアの2フェーズが `SKIPPED` になり、
`stable` フェーズの手前で待機する。

```
gcloud deploy rollouts describe [ロールアウト名] \
  --delivery-pipeline=[自分の名前]-pipeline --release=rel-1 \
  --region=asia-northeast1 --format="yaml(phases)"
```

```
- id: canary-10
  state: SKIPPED
  skipMessage: Skipped because Google Cloud Deploy doesn't have a pre-existing
    Cloud Run service revision to canary-deploy against. This is expected for
    the first canary deployment, and you can safely advance the rollout.
- id: canary-50
  state: SKIPPED
- id: stable
  state: PENDING          ← ここで人待ち
```

`rollouts list` の STATE は `IN_PROGRESS` のままなので、
一見ハングしているように見える。**`phases` を見ると理由が分かる。**

進めれば 100% でデプロイされる。

```
gcloud deploy rollouts advance [ロールアウト名] \
  --delivery-pipeline=[自分の名前]-pipeline --release=rel-1 \
  --region=asia-northeast1
```

**これで Cloud Deploy 管理のリビジョンができる。
カナリアが本当に効くのは、ここから先の2回目のリリース。**

### 4. 2回目のリリースで 10% を確認する

アプリを少し変えて push し、新しいイメージができたら
もう一度リリースを作る。

```
gcloud run services describe [自分の名前]-canary --region=asia-northeast1 \
  --format="value(status.traffic)"
```

新しいリビジョンに 10% だけ流れていることが確認できる。

### 5. 次の段階へ進める

```
gcloud deploy rollouts advance [ロールアウト名] \
  --delivery-pipeline=[自分の名前]-pipeline \
  --release=[リリース名] --region=asia-northeast1
```

10% → 50% → 100% と、叩くたびに進む。

## AWSとの違い

| | CodeDeploy (ECS Blue/Green) | Cloud Deploy (Cloud Run) |
|---|---|---|
| トラフィック制御 | ALBのターゲットグループ2つ + リスナー切り替え | リビジョンのトラフィック割合 |
| 必要なリソース | ターゲットグループ / テスト用リスナー / SG ルール | なし |
| 割合の指定 | デプロイ設定(`CodeDeployDefault.ECSCanary10Percent5Minutes` など)から選ぶ | `percentages = [10, 50]` と直接書く |
| 次へ進める | 時間で自動、または手動 | `rollouts advance` |

AWS版 第8回では、Blue/Green のために
ターゲットグループ・テスト用リスナー(4443番)・そのSGルールを追加していた。
Cloud Run はリビジョン単位でトラフィックを割れるので、その一式が要らない。

## 参考

- [Cloud Deploy のドキュメント](https://cloud.google.com/deploy/docs)
- [Cloud Run へのデプロイ](https://cloud.google.com/deploy/docs/deploy-app-run)
- [デプロイ戦略(カナリア)](https://cloud.google.com/deploy/docs/deployment-strategies)
