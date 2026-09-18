# tools

勉強会の運営用スクリプト。教材そのものではなく、**講師の運営を楽にするためのもの**。

## check-leftover.sh — 片付け漏れの確認

```bash
# 受講者が自分の分を見る
./check-leftover.sh tanaka

# 講師が名簿でまとめて見る
./check-leftover.sh --names-file=members.txt --project=<プロジェクトID>
```

終了コードは `0`=きれい / `1`=残骸あり / `2`=使い方が違う。
CI やリマインドの判定にも使える。

### なぜ必要か

第5回以降は Cloud Run の **Direct VPC egress** がサブネット内にIPを確保する。
Cloud Run を消してもこのIPは **1〜2時間解放されない**ため、
`terraform destroy` が**サブネットの削除だけ失敗する**。

結果、片付けが「destroy → 1〜2時間待つ → destroy」の2段構えになり、
**1回目で終わったつもりになる人が出る。**

残骸が残ると、次回の `0. before` が同名のVPC・サブネットを作ろうとして
**409 で落ち、冒頭で全員が止まる。** これを事前に潰すためのスクリプト。

### 名簿ファイルの書き方

1行に1人。`#` 以降はコメント、空行は無視する。

```
# 2026年度 受講者
tanaka
suzuki
sato    # 第5回から参加
```

### 「全件表示」モードを作っていない理由

勉強会は**業務用リソースが同居する共有プロジェクト**で動いている。
名前で絞らずに一覧すると業務用のVMやCloud SQLまで
「残っている」に並び、**消してよいものの判断を誤る。**
だから受講者名を必ず渡す設計にしてある。

## cleanup-lesson.sh — 講師がまとめて destroy する

```bash
# まず dry-run(既定)。何が消えるかを見る
./cleanup-lesson.sh 8 --names-file=members.txt \
    --project=<プロジェクトID> --var-file=cleanup.tfvars

# 中身を確認したうえで実行する
./cleanup-lesson.sh 8 --names-file=members.txt \
    --project=<プロジェクトID> --var-file=cleanup.tfvars --apply
```

`--apply` を付けない限り何も消さない。付けても `yes` の入力を求める。

### なぜ必要か

`check-leftover.sh` の項に書いたとおり、第5回以降の片付けは
「destroy → IPの解放を1〜2時間待つ → destroy」の2段構えになる。
**2回目を受講者にやらせると必ず取りこぼす**(夕方〜夜に当たる)。

そこで**受講者は講義中の1回だけ**にして、2回目を講師がこれでまとめて流す。
第6回の実測では解放まで**約2時間20分**かかっており、公式の「1〜2時間」より長い。
**当日の夜ではまだ解放されていないので、翌朝に流すこと。**

### 仕組み

受講者の tfstate は GCS にあり、置き場所が命名規則で決まっている。

```
バケット: <プロジェクトID>-tfstate-<受講者名>
prefix  : lesson<N>
```

つまり**受講者名が分かれば講師は各人の state に到達できる。**
リポジトリ内の「その回の最終スナップショット」を config として使い、
`backend` のバケットだけ受講者のものに差し替えて destroy する。

| 回 | 使う config |
|---|---|
| 1 | `lesson1/syukudai2` |
| 2 | `lesson2/syukudai2` |
| 3 | `lesson3/syukudai3` |
| 4 | `lesson4/syukudai2` |
| 5 | `lesson5/syukudai1` |
| 6 | `lesson6/syukudai3` |
| 7 | `lesson7/syukudai3` |
| 8 | `lesson8/syukudai3` |

**config が state のスーパーセットであれば destroy は通る**ので、
宿題をどこまでやった受講者でもこれ1つで消せる。

**state を正しく使うので実体とズレない。** これが `gcloud` で直接消すのとの
決定的な違い。state を無視して消すと、次回の apply が
「state にはあるが実体が無い」状態でもっと厄介な形で失敗する。

### 変数ファイル

```bash
cp cleanup.tfvars.example cleanup.tfvars
```

必要な値は**全員共通のもの**(サブネットCIDR・DNSゾーン名・社内IP・
Cloud Build のリポジトリリンク・Slack通知チャンネル名)だけ。
`user_name` と `project_id` はスクリプトが1人ずつ上書きする。
`db_password` と `alert_email` は destroy にしか使わないのでダミーで構わない。

**`cleanup.tfvars` は `.gitignore` 済み**(社内IPなどの実値を含むため)。

### 未検証の点

**実際の受講者 state に対しては、まだ1度も流していない**(第1回が 2026-10-05)。
全8回分の config が `terraform validate` を通ることと、
backend の差し替えが効くことは確認済み。

**第1回の直後に、自分の state に対して1回 dry-run で試しておくこと。**
そこで通れば以降は同じ形で動く。

## create-build-sa.sh — 受講者ごとのビルド用SAを作る(第7回)

```bash
# まず dry-run(既定)
./create-build-sa.sh --names-file=members.txt --project=<プロジェクトID>

# 中身を確認したうえで実行
./create-build-sa.sh --names-file=members.txt --project=<プロジェクトID> --apply
```

`<名前>-build` という SA を作り、`roles/logging.logWriter` と
`roles/clouddeploy.jobRunner` を付与する。
SA が既にあれば作成を飛ばしてロールだけ付けるので、**何度流しても安全**。

### なぜ講師がやるのか

この2つのロールは**プロジェクト単位でしか付けられない**。
それを付けるための `resourcemanager.projects.setIamPolicy` は
共有プロジェクトでは配れない(付けると誰にでも好きなロールを渡せてしまう)。

受講者は `data "google_service_account"` で参照するだけ
(`lesson7/2. cloud_build/artifact_registry.tf`)。

### ★ 名簿の名前は `user_name` と同じ文字列にすること

SA名が `<user_name>-build` になる。食い違うと受講者側の apply が
「SAが見つからない」で落ちる。

## check-slide-sync.py — 原稿とデッキの突き合わせ

```bash
./check-slide-sync.py --profile=<Google認証プロファイル名>   # 全10回
./check-slide-sync.py 4 7 --profile=<プロファイル名>          # 特定の回
```

原稿(`docs/slides/lessonN.md`)の本文と Google スライドの BODY を比較して、
**原稿を直してデッキに反映し忘れた箇所**を洗い出す。

2026-09-18 に第1回 p72 で「tfstate バケットを Terraform で作る例」が
残っているのが発覚したのを機に作った。詳細は `docs/slides/README.md`。

**誤検出しやすいパターンがある**(図版化されたスライド、タイトルの重複、
スキップスライド)。スクリプト冒頭のコメントに書いてあるので、
`★★要確認` が出ても中身を見てから判断すること。

## スクリプトの使い分け

| | check-leftover.sh | cleanup-lesson.sh | create-build-sa.sh | check-slide-sync.py |
|---|---|---|---|---|
| 何をする | 残骸を**見つける** | 残骸を**消す** | ビルド用SAを**作る** | 原稿とデッキのズレを**見つける** |
| 危険な操作 | 無い | 削除(`--apply` 必須) | 作成・ロール付与(`--apply` 必須) | 無い(読み取りのみ) |
| 誰が使う | 受講者・講師 | **講師のみ** | **講師のみ** | 制作時 |
| いつ | 次回の前・片付けの後 | 各回の翌朝 | 第7回の前に1回 | 原稿を直したあと |

`check-leftover.sh` にあえて削除機能を持たせていないのは、
**受講者に渡すスクリプトだから**。手元のコマンドで消せるようにすると
state を無視した削除が起きる。消すのは必ず
`cleanup-lesson.sh`(= tfstate 経由)か、本人の `terraform destroy` を通す。

## 運用の全体像

| いつ | 誰が | 何を |
|---|---|---|
| 各回の講義中(最後) | 受講者 | `terraform destroy` を**1回だけ**打つ |
| 各回の翌朝 | 講師 | `cleanup-lesson.sh <N> ... --apply` で残りを消す |
| 次回の数日前 | 講師 | `check-leftover.sh --names-file=...` で取りこぼし確認 |
| 第10回の前日 | 講師 | 同上 + vCPU クォータの余裕を確認 |
| 第7回の前 | 講師 | `create-build-sa.sh --apply` でビルド用SAを作る(1回だけ) |

**受講者の手順を1回に固定したのが要点。**
「翌日もう1回」は必ず取りこぼすので、教材からその指示を外してある
(第5〜8回の注意事項スライド)。

クォータ側の状況は `gcp/docs/quota-precheck-2026-09.md` を参照。
