# 回答例

宿題1の内容を含みます。差分は `clouddeploy.tf` の `require_approval` 1行だけ。

## 課題

Cloud Deploy に承認ステップを足し、ロールバックを試す。

## 回答: 承認ステップ

```hcl
resource "google_clouddeploy_target" "prod" {
  // これだけ
  require_approval = true
}
```

**パイプラインではなくターゲットに付ける。**
「本番は承認が要る、ステージングは自動」という分け方ができるようになっている。

### 確認方法

```
terraform apply
```

リリースを作ると、`gcloud deploy releases create` の最後に
**`The rollout is pending approval.`** と出て止まる。

★ すぐ `approve` を叩くと失敗する

```
ERROR: (gcloud.deploy.rollouts.approve) Status code: 400.
invalid rollout state for an approve action PENDING_RELEASE: failed precondition.
```

リリースのレンダリングが終わるまでは `PENDING_RELEASE` で、
承認できるのは `PENDING_APPROVAL` になってから。
**十数秒待ってから承認する。**

```
gcloud deploy rollouts list \
  --delivery-pipeline=[自分の名前]-pipeline \
  --release=[リリース名] --region=asia-northeast1 \
  --format="table(name,state,approvalState)"
```

```
STATE              APPROVAL_STATE
PENDING_APPROVAL   NEEDS_APPROVAL
```

承認すると、そこからカナリア(10% → 50% → 100%)が始まる。
**承認はカナリアの手前に1回あるだけで、各段階ごとには要らない。**

承認すると動き出す。

```
gcloud deploy rollouts approve [ロールアウト名] \
  --delivery-pipeline=[自分の名前]-pipeline \
  --release=[リリース名] --region=asia-northeast1
```

却下する場合は `reject`。

## 回答: ロールバック

Cloud Deploy は「前のリリースをもう一度出す」形でロールバックする。

```
# これまでのリリースを見る
gcloud deploy releases list \
  --delivery-pipeline=[自分の名前]-pipeline --region=asia-northeast1

# 戻したいリリースを指定してロールバック
gcloud deploy targets rollback [自分の名前]-prod \
  --delivery-pipeline=[自分の名前]-pipeline \
  --release=[戻したいリリース名] \
  --region=asia-northeast1
```

ロールバックも1つのロールアウトとして記録される。

### ★ ロールバックに承認は要らない

`require_approval = true` でも、ロールバックのロールアウトは
`DOES_NOT_NEED_APPROVAL` になる。
**戻す操作は止めない**という設計。障害対応を考えれば妥当。

### ★★ 進行中のロールアウトがあると、ロールバックは待たされる ★★

これが一番ハマる。

```
NAME                      STATE      APPROVAL_STATE
rel-3-to-perm7-prod-0002  PENDING    DOES_NOT_NEED_APPROVAL   ← ロールバック
```

1つのターゲットで同時に進められるロールアウトは1つだけ。
**壊れたリリースのロールアウトが進行中だと、ロールバックが `PENDING` のまま動かない。**

先に進行中のものをキャンセルする。

```
gcloud deploy rollouts cancel [進行中のロールアウト名] \
  --delivery-pipeline=[自分の名前]-pipeline --release=[そのリリース] \
  --region=asia-northeast1
```

キャンセルすると、待たされていたロールバックが動き出す。

**障害のときに慌てないよう、この順番は覚えておくこと。**
「ロールバックしたのに何も起きない」の原因はたいていこれ。

## Cloud Run だけで戻す方法もある

Cloud Deploy を使わなくても、Cloud Run 単体でリビジョンを戻せる。

```
# リビジョン一覧
gcloud run revisions list --service=[自分の名前]-app --region=asia-northeast1

# 前のリビジョンに100%戻す
gcloud run services update-traffic [自分の名前]-app \
  --region=asia-northeast1 \
  --to-revisions=[前のリビジョン名]=100
```

**講義で作ったパイプライン(Cloud Build から `gcloud run deploy`)の場合は、
これがロールバック手段になる。** 覚えておくと障害対応で効く。

## AWSとの違い

| | AWS | GCP |
|---|---|---|
| 承認 | CodePipeline に手動承認アクションを追加 | ターゲットの `require_approval` |
| ロールバック | CodeDeploy のデプロイを停止 → 自動で Blue に戻る | 前のリリースを再デプロイ |
| 素のロールバック | ECSのタスク定義リビジョンを戻す | `run services update-traffic` |

## 参考

- [ロールアウトの承認](https://cloud.google.com/deploy/docs/promote-release#approving_a_rollout)
- [ロールバック](https://cloud.google.com/deploy/docs/rollback)
- [Cloud Run のトラフィック管理](https://cloud.google.com/run/docs/rollouts-rollbacks-traffic-migration)
