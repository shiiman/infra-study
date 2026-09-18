# クォータ事前申請メモ(20人前提)

作成日: 2026-09-16 / 最終更新: 2026-09-16(**全項目を実測して確定**)
対象プロジェクト: 共有プロジェクト `[プロジェクトID]`
前提: **全20人が1つのプロジェクト**で同時に作業する。

> **★ 実際の人数は 15名(受講者14 + 講師1)(2026-09-18 時点)★**
> 2026-09-16 に12名で確定したあと、2026-09-18 に3名増えた。
> 本メモの見積もりは20人前提のままにしてある。
>
> **★★ vCPU だけは余裕がほとんど無い ★★**
>
> `CPUS-per-project-region`(asia-northeast1)は **64 のまま承認待ち**。
> 15人だとピーク(第2回・第3回・第10回)で **60 vCPU** を使い、**余裕は4しかない**。
>
> | 人数 | ピーク時の必要 vCPU | 現行64に対して |
> |---|---|---|
> | 12人 | 48 | 余裕16 |
> | **15人(現在)** | **60** | **余裕4 = e2-medium 2台分** |
> | 16人 | 64 | ちょうど上限 |
> | 17人 | 68 | **★超過** |
>
> **講師が第10回の事前準備で模範解答を apply すると +4 でちょうど上限に張り付く。**
> 12人のときは「承認が通らなくても回る」と判断できたが、
> **15人ではその前提が崩れている。第3回(2026-11-16)までに反映させること。**
>
> 他のクォータは20人前提の申請値が通っているので余裕がある。
> ただし `BACKEND-SERVICES-per-project`(75で固定・引き上げ不可)だけは
> 人数が増えると効いてくるので、7章の残骸対策を落とさないこと。

各回は destroy して終了する運用なので、ピークは「1人が1回の最終構成
(宿題込み)を持つかける状態」×20人で合算する。

> **現行値は 2026-09-16 に Cloud Quotas API(`gcloud quotas info describe`)で
> 全項目を実測済み。** コンソールでの目視確認は不要になった。

---

## 1. 1人あたりのピーク構成(宿題込み・各回の最終スナップショットの実数)

| 項目 | 第2回宿題2 | 第3回宿題3 | 第4回宿題2 | 第6〜8回(積み上げ) | 第10回(自己完結) |
|---|---|---|---|---|---|
| VPC | 1 | 1 | 1 | 1 | **1(別VPC)** |
| サブネット | **7** | 4〜7 | 4〜7 | 4〜7 | 2 |
| Firewall | 2〜4 | 4〜6 | 4〜6 | 4〜6 | 2〜5 |
| VM(e2) | 2台(1台に外部IP) | **2台(zone a/b)** | 1〜2台 | **1台(e2-medium)** | **2台(e2-medium・ゾーンa)** |
| IG | — | 2 | 2 | 2 | 1 |
| グローバル外部IP | — | 1(LB) | **2**(LB+PSSA) | 2 | 1(別IP) |
| 地域内外部IP | 1 | 1 | 1 | 1 | 0 |
| マネージド証明書 | — | 1 | 1 | 1 | 0(HTTPのみ) |
| グローバル転送ルール | — | 2(http/https) | 2 | 2 | 1 |
| Router / NAT | 2 / 2 | 1 / 1 | 1 / 1 | 1 / 1 | 1 / 1 |
| Redis | — | — | **1(1GB)** | 1 | — |
| Spanner(100PU) | — | — | **1** | 1 | — |
| Cloud SQL | — | — | **1(宿題)** | 1 | — |
| GCS バケット | 1(tfstate) | 2 | 2 | **2**(+ログ) | 1(tfstate) |
| サービスアカウント | 2 | 2 | 2 | **2** | 1 |
| Artifact Registry | — | — | — | 2 | — |
| Cloud Run サービス | — | — | — | 2 | — |
| Cloud Build トリガー | — | — | — | 2 | — |
| Cloud Armor ポリシー | — | — | — | 1 | — |

第6〜8回が最大の積み上げ(42リソース前後)。第10回は第8回とは
**独立したVPC・VM・LB**を作るため、**実施日当日だけ第8回の構成と
二重に重なる**ことに注意。

### ゾーンの分布(重要・2026-09-16 に `*.tf` を実測)

**VM のゾーン指定は `asia-northeast1-a` に集中している**(zone-a が42箇所、
zone-b は `lesson3/syukudai2`・`syukudai3` の `instance_b.tf` の4箇所だけ)。
第10回に限った話ではなく、**第2回から全回を通じて zone-a 集中**。
ただし後述のとおり **ゾーン別 vCPU は無制限**なので、効いてくるのは
**リージョン別 vCPU** のほうである。

---

## 2. 20人分の必要量と申請判定(2026-09-16 実測)

🔴=**申請必須** / ⚠️=余裕を持たせたい / ✅=現行値で足りる / ⛔=Cloud Quotas に枠が無く申請対象外

### 🔴 申請必須

| クォータ(quotaId) | サービス | 現行値 | 20人分の必要量 | 申請値 |
|---|---|---|---|---|
| `CPUS-per-project-region`(asia-northeast1) | compute | **64** | 80〜120 | **200** |
| `ROUTERS-per-project` | compute | **20** | ~40(第10回当日) | **60** |
| `SECURITY-POLICIES-per-project` | compute | **10** | ~20 | **30** |
| `SECURITY-POLICIES-per-project-region` | compute | **10** | ~20 | **30** |

**`CPUS-per-project-region` = 64 が最大のボトルネック。**
E2 は `CPUS-PER-VM-FAMILY-per-project-region` に枠を持たず、この汎用枠を消費する。
第3回の宿題3の時点で `e2-medium × 2台 × 20人 = 80 vCPU` となり **64 を超える**。
第10回当日に第8回の構成が残っていれば `(2+4) vCPU × 20人 = 120 vCPU`。

### ⚠️ 余裕を持たせたい(現行値でギリギリ)

| クォータ(quotaId) | サービス | 現行値 | 20人分の必要量 | 申請値 |
|---|---|---|---|---|
| `NETWORKS-per-project` | compute | **50** | 40(第10回当日) | **80** |
| `BACKEND-SERVICES-per-project` | compute | **75** | ~60(第10回当日) | **150** |

### ✅ 現行値で足りる(申請不要・実測で確認済み)

| クォータ | 現行値 | 20人分 |
|---|---|---|
| **ゾーン別 vCPU**(`CPUS-per-project-zone`) | **無制限(-1)** | — |
| **ゾーン別 VM family vCPU**(`CPUS-PER-VM-FAMILY-per-project-zone`) | **無制限(-1)** | — |
| **ゾーン別 SSD 容量**(`SSD-TOTAL-GB-per-project-zone`) | **無制限(-1)** | — |
| インスタンス数(`INSTANCES-per-project-region` asia-northeast1) | 640 | ~60 |
| SSD 総容量(`SSD-TOTAL-GB-per-project-region`) | 500,000 GB | ~600 GB |
| 全リージョン合計 vCPU(`CPUS-ALL-REGIONS-per-project`) | 12,000 | ~120 |
| サブネット数 | 275 | ~140 |
| Firewall ルール数 | 500 | ~120 |
| 使用中IP(`IN-USE-ADDRESSES-per-project-region`) | 2,300 | ~40 |
| 静的IP(`STATIC-ADDRESSES-per-project-region`) | 700 | ~60 |
| ターゲットHTTPSプロキシ / URLマップ | 各 250 | 各 ~40 |
| ヘルスチェック | 1,250 | ~40 |
| **Spanner ノード数**(`SpannerNodesPerProject`) | **100ノード(=100,000PU)** | 2ノード(2,000PU) |
| **Redis 総容量**(`TotalCapacityPerProjectPerRegion`) | **2,000 GB** | 20 GB |
| **Cloud Build 同時実行**(`OngoingBuildsPerProject`) | **30** | 20 |
| Cloud Build 同時実行vCPU(`OngoingBuildCPUs...`) | 128 | ~40 |
| IAM カスタムロール(`CustomRolesPerProject`) | 300 | ~20 |
| Compute API 書き込みレート(`GlobalWritesPerMinutePerProject`) | 2,000/分 | 一斉applyでも余裕 |
| Compute API 読み取りレート(`GlobalReadsPerMinutePerProject`) | 8,000/分 | 同上 |

### ⛔ Cloud Quotas に枠が無い(＝申請できない/する必要がない)

| 項目 | 理由 |
|---|---|
| **Cloud NAT ゲートウェイ数** | プロジェクト枠ではなく **VPCごと・リージョンごと**の上限。各人が自分のVPCを持つので非該当。実質の制約は `ROUTERS-per-project` のほう |
| **Cloud SQL インスタンス数 / vCPU** | `sqladmin.googleapis.com` に数量枠が無い(APIレート枠のみ)。20人×1台は既定内 |
| **GCS バケット数** | `storage.googleapis.com` に枠が無い。ただし**バケット名はグローバル一意**なので `${user_name}-` プレフィクスの徹底が必要(クォータではなく設計の問題) |
| **Cloud Run サービス数 / Artifact Registry リポジトリ数** | 数量枠が無い。既定で十分 |
| **Monitoring / Logging** | アラート・Uptime(1人1個=20)・SLO・シンクとも既定枠内 |

### サービスアカウント数(再集計して解決)

`ServiceAccountsPerProject` は API 上 **無制限(-1)**。
さらに **1人あたりの同時保有数を数え直したところ 2個** だった
(`lesson8/0. before` の実数。初版の「3〜4個」は各回スナップショットを
足し合わせた過大見積もり)。

**20人 × 2個 = 40個 + 既存21個 = 61個**。仮に既定の 100 が効いていても余裕がある。
**申請・確認とも不要。**

---

## 3. 申請のタイミング

| 申請項目 | 期限 | 理由 |
|---|---|---|
| **`CPUS-per-project-region`** | **2026-10-10 まで(第2回前)** | **第3回の宿題3で 80 vCPU に達し、現行 64 を超える。最優先** |
| `ROUTERS-per-project` | 同上 | 第2回で1人2個のRouter/NATを作る |
| `SECURITY-POLICIES`(project / region) | 2027-02-08 まで(第7回前) | Cloud Armor は第6〜8回の積み上げで登場 |
| `NETWORKS` / `BACKEND-SERVICES` | 2027-03-01 まで(第10回前) | 第10回当日に第8回と二重になる日だけ効く |

クォータの引き上げは即日反映のものが多いが、**承認に数日かかる場合も
あるので「各回2週間前」を目安に**。

### 申請の進捗(2026-09-18 時点)

| クォータ | 状態 |
|---|---|
| Cloud Router / VPC / Cloud Armor(project・region) | **反映済み**(即日) |
| **`CPUS-per-project-region` 64 → 200** | **承認待ち**(`reconciling: true`) |

**vCPU だけ自動承認されず、サポートケースが開いてアカウントチームに
エスカレーションされた。**「3〜5営業日のうちにアカウントチームから連絡する」
という返信が来ている(2026-09-16)。

- **2026-09-23 頃までに連絡が来なければ、そのメールスレッドに返信して催促する**
  (返信文にそう書かれている)
- 期限は**第3回(2026-11-16)まで**。第2回は e2-micro なので 60 vCPU でも収まるが、
  第3回で同じく 60 vCPU に達するため、余裕4のまま迎えるのは避けたい
- 状態の確認: `gcloud quotas preferences list --project=[プロジェクトID]`

---

## 4. gcloud での申請方法(2026-09-16 訂正)

> **訂正:** 初版に「gcloud からは申請できない」と書いたのは誤り。
> **`gcloud quotas preferences create` で引き上げ申請を出せる。**

```bash
gcloud quotas preferences create \
  --service=compute.googleapis.com \
  --project=[プロジェクトID] \
  --quota-id=CPUS-per-project-region \
  --preferred-value=200 \
  --dimensions=region=asia-northeast1 \
  --preference-id=infra-study-cpus-asia-northeast1 \
  --justification="社内インフラ勉強会・20名が同一プロジェクトで同時ハンズオン" \
  --email=<申請者のメールアドレス>
```

- `--email` は Google から追加情報を求められたときの連絡先。**指定しないと
  追加確認が必要なケースで自動的に却下される**ので必ず付ける。
- 状態確認は `gcloud quotas preferences list --project=[プロジェクトID]`。
- `gcloud compute project-info add-quota` は存在しないコマンド(初版の確認どおり)。

---

## 5. 現行値の確認方法

`gcloud compute project-info describe` は **プロジェクトレベルの一部しか
返さない**(ゾーン別 vCPU・NAT・SQL・Redis などが載らない)。
**Cloud Quotas API を使えば全サービス・全ディメンションを取得できる。**

```bash
# サービス内のクォータID一覧
gcloud quotas info list --service=compute.googleapis.com \
  --project=[プロジェクトID] --format="value(quotaId)"

# 個別のクォータをディメンション込みで確認
gcloud quotas info describe CPUS-per-project-region \
  --service=compute.googleapis.com --project=[プロジェクトID] \
  --format="json(dimensionsInfos)"
```

確認対象のサービス: `compute` / `sqladmin` / `redis` / `spanner` /
`cloudbuild` / `iam` / `storage` / `run` / `artifactregistry`

`dimensionsInfos[].details.value` が **-1 なら無制限**。
`dimensions` が空のエントリは「そのサービス既定値」、
`region`/`zone` が入っているものが個別に上書きされた値。

---

## 6. 確認手順(チェックリスト)

- [x] 社用アカウントでアクセス確認
      (個人アカウントでは対象プロジェクトに権限がない)
- [x] Cloud Quotas API で **全項目の現行値を実測**(2026-09-16)
- [x] 申請対象を 🔴4件 + ⚠️2件 に確定
- [ ] `gcloud quotas preferences create` で申請を出す
- [ ] `gcloud quotas preferences list` で承認状況を追う
- [x] サービスアカウント数は再集計により問題なしと判断(7章)
- [x] 教材側に残骸対策を入れた(7章)
- [ ] 反映後、`gcloud quotas info describe` で実際に値が上がったか確認する

---

## 7. 教材側で入れた回避策(2026-09-16)

クォータは引き上げたが、**引き上げても足りなくなる唯一の状況**が
「第8回の環境を残したまま第10回を受ける」だった。
これは申請では解けないので、教材側に手を入れて潰した。

### 効くのは「第10回当日の二重取り」を防ぐことだけ

| 状況 | vCPU | backend services |
|---|---|---|
| 第8回を destroy 済みで第10回を受ける | 80 | 20 |
| **第8回が残ったまま第10回を受ける** | **120** | **60** |

`BACKEND-SERVICES-per-project` は **75 で固定(`is_fixed`)、引き上げ不可**。
残骸があると余裕が15しかなくなる。**ここは運用でしか守れない。**

### 入れた修正

スライド**枚数**は変えていない(挿入なし)。第5〜8回の注意事項スライドは本文を
書き換えたので、**Google スライド側も Slides API で差し替え済み**
(第5回 p50 / 第6回 p45 / 第7回 p57 / 第8回 p53)。手作業は残っていない。
やり方は `gcp/docs/slides/README.md` の「1枚だけ直したいとき」に残した。

| ファイル | 追加した内容 |
|---|---|
| `slides/lesson3.md` 事前準備 | **5. vCPU クォータに余裕があること**。第3回は1人 e2-medium×2台で**全10回中いちばんVMが多い回**。確認コマンドと申請コマンドを併記 |
| `slides/lesson8.md` S47 の後 | **講師メモ: destroy の完了を後追いすること**。1回目の destroy が必ず失敗する設計なので、翌日と1週間後に講師が全体を見て個別に声をかける |
| `slides/lesson10.md` 事前準備5 | 受講者への事前連絡に **「第8回までを destroy してから来ること」** と確認コマンドを追加 |
| `slides/lesson10.md` 事前準備7(新設) | **前日に講師がプロジェクト全体の残骸を確認する**手順。消すのは本人にやらせる(講師が消すと tfstate とズレる) |
| `slides/lesson5〜8.md` 注意事項スライド | **受講者の destroy を「講義中の1回」に固定した。** 「翌日もう1回打つ」という指示を教材から外した(下記★) |
| `slides/lesson6〜8.md` 事前準備 | **前回の残骸が消えているか**を開催前に確認する講師メモ |
| `tools/check-leftover.sh`(新規) | 受講者名で絞って残骸を洗い出す。**削除機能は持たせていない**(受講者にも渡すスクリプトなので、state を無視した削除が起きないように) |
| `tools/cleanup-lesson.sh`(新規) | **講師が全員分をまとめて destroy する。** 受講者の tfstate 経由なので実体とズレない。既定は dry-run、`--apply` + `yes` 入力で実行 |

### ★ 受講者の手順を1回に固定したのが一番効いた

第5回以降の片付けは「destroy → IPの解放待ち → destroy」の2段構えになる。
**2回目を受講者にやらせる設計だったのが根本的な誤り**だった。

- 解放は第6回の実測で **約2時間20分**(公式の「1〜2時間」より長い)
- つまり**講義中には終わらず、2回目は夕方〜夜に当たる**
- 「翌日やってください」は必ず取りこぼす

受講者の tfstate は `<プロジェクトID>-tfstate-<受講者名>` / prefix `lesson<N>` と
**命名規則で置き場所が決まっている**ので、名簿さえあれば講師が全員分の state に
到達できる。そこで**2回目は講師がまとめて流す**ことにした。

```
gcp/tools/cleanup-lesson.sh 8 --names-file=<名簿> \
  --project=[プロジェクトID] --var-file=cleanup.tfvars --apply
```

必要な変数は全員共通の値だけ(`user_name` と `project_id` はスクリプトが上書き、
`db_password` と `alert_email` は destroy にしか使わないのでダミーで可)。

**未検証:** 実際の受講者 state に対してはまだ流していない(第1回が 2026-10-05)。
全8回分の config が `terraform validate` を通ることと backend 差し替えが効くことは
確認済み。**第1回の直後に自分の state で1回 dry-run すること。**

### なぜ「残骸」がクォータより先に効くか

第5回以降は Cloud Run の Direct VPC egress がサブネット内にIPを確保し、
**解放に1〜2時間かかる**ため `terraform destroy` がサブネットの削除だけ失敗する。
片付けが2段構えになり、1回目で終わったつもりになる人が出る。

残骸が残ると、次回の `0. before` が同名のVPC・サブネットを作ろうとして
**409 で落ちる。** つまり **クォータに当たる前に、名前の衝突で冒頭から全員が止まる。**
第5→6回、第6→7回、第7→8回、第8→10回の**4回とも同じ形で起きうる**。

第10回の二重取り(vCPU 120 / backend services 60)も、
元をたどれば同じ「第8回の残骸」が原因。**対策は共通で「片付けの後追い」**。

### 検討したが採用しなかったもの

| 案 | 不採用の理由 |
|---|---|
| 第3回のVMを `e2-medium` → `e2-small`/`e2-micro` に下げる | E2 の shared-core は `e2-micro`/`e2-small`/`e2-medium` とも `guestCpus = 2`。クォータが guestCpus 基準なら**効果がゼロ**で、数え方を実測で確定できなかった(検証用VMの作成が権限で通らなかった)。**スライドのコードと1対1で対応しているため、効果が不確実な変更のために原稿を触るのは割に合わない** |
| 第3回のVMを2台→1台にする | 「LBの背後に複数台を置いて冗長化する」がこの回の主題。壊れる |
| 第10回 問2の `count = 2` を 1 にする | `count`/`for_each` を使えるかを見る出題。採点ポイントそのもの |
| VM のゾーンを分散させる | 効くのは**リージョン別**の枠なので、ゾーンを散らしても合計は変わらない |
| Cloud Run を専用サブネットに分離する | 実務的には正しい(direct VPC egress は専用サブネット推奨)が、**この問題は解決しない**。今も失敗するのは private サブネット1個だけで、分離しても「専用サブネット1個が失敗」に変わるだけ |
| Cloud Run を演習の途中で先に消して待ち時間を埋める | 2時間の勉強会に対して待ちが2時間20分。稼げるのは20分程度で誤差。第8回は Cloud Run のメトリクスを見る回なので先に消すと演習が成り立たない |
| `time_sleep` の `destroy_duration` で Terraform に待たせる | Cloud Shell のセッションが2時間持たない |
| 受講者に「翌朝もう1回」を徹底させる | **これが元の設計で、取りこぼす前提が変わらない。** 講師がまとめて流す形に置き換えた |

### 名前の衝突は問題なし(確認済み)

グローバル一意/プロジェクト一意が要るリソースは、**全て `${var.user_name}`
プレフィクスが付いている**ことを確認した
(GCS バケット・Cloud SQL・Redis・Spanner・Artifact Registry・Cloud Run・
Cloud Armor・DNS レコード・カスタムロール)。20人が同時に作っても衝突しない。

なお **Cloud SQL のインスタンス名は削除後すぐ再利用できる**
(公式ドキュメントで確認)。宿題のやり直しで詰まることはない。

---

## 付録: 本メモの根拠

- 1人あたりの構成は各回の最終スナップショットディレクトリの
  `*.tf` の `resource` 定義の実数から算出
  (lesson2/syukudai2 = 7サブネット / lesson3/syukudai3 = VM2台(zone a/b)・
  証明書1・グローバルIP1 / lesson4/syukudai2 = Redis・Spanner・SQL 各1・
  PSSA用グローバルIP / lesson8/0. before = e2-medium 1台の積み上げ状態)
- ゾーン分布は `*.tf` の `zone = ` の実数
  (`asia-northeast1-a` 42箇所 / `asia-northeast1-b` 4箇所)
- 第10回の問2は `count = 2` で e2-medium × 2台を
  `asia-northeast1-a` に作成する設計(`lesson10/2. question2/instance.tf`)
- 現行値は `gcloud quotas info describe`(Cloud Quotas API)の
  `dimensionsInfos[].details.value` を 2026-09-16 に取得したもの
- 設計書 `2026-08-28-curriculum-design.md` の「確定した制作の型」
  (各回 destroy して終了する運用)に基づき、ピークを「1回分×20人」で計算
