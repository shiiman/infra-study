# スライド原稿と Google スライド

原稿(`lesson1.md` 〜 `lesson10.md`)から Google スライドに流し込み済み(2026-08-31)。
**共有ドライブ →「インフラ勉強会(GCP)」フォルダ**に置いてある。

| 回 | テーマ | 枚数 | Google スライド |
|---|---|---:|---|
| 第1回 | GCP基礎 / IAM / Terraform | 69 | https://docs.google.com/presentation/d/1LGC9jpgPpKj1ObDw7JFDw1x_OG3sMO_ZdxkUQ4mqU6k/edit |
| 第2回 | ネットワーク | 63 | https://docs.google.com/presentation/d/1p0NGtqsvkGYxFewE8AjoPYqh8kgkvTjyVEjLA6Fmkvs/edit |
| 第3回 | コンピューティング | 56 | https://docs.google.com/presentation/d/1cxkYA6EAxoyUp-iMQILfCvJ_CjR8SuccNb7cRbhMc0s/edit |
| 第4回 | データベース | 53 | https://docs.google.com/presentation/d/1Cn3LTns2BdgXLAwhyPbr-LbEZU1Je_4m3NZLSRkLufM/edit |
| 第5回 | コンテナ | 51 | https://docs.google.com/presentation/d/1ow1DPEjkCakiMKhQ-TknYS3u_9yezEQYnRvaovz_sqs/edit |
| 第6回 | ストレージ + CDN | 46 | https://docs.google.com/presentation/d/1kuYTeNuWkzd8-_Mj1u2RNBKO4-xh8ycWsvlxO0hbXYo/edit |
| 第7回 | CI/CD | 48 | https://docs.google.com/presentation/d/1gRqC2I-lme3uUlA2DX2L3aRYAkpB0DQokDFzI2yKI3I/edit |
| 第8回 | 監視・運用 + その他リソース | 48 | https://docs.google.com/presentation/d/1T5uKWZNngdzsw9JepsK4pJiwgir7dz3mwUgFueaoiDc/edit |
| 第9回 | 試験対策 | 46 | https://docs.google.com/presentation/d/18HRSIFBcPvDAH5Gg19AFevZtYdSj1R2hUVhX-U0vzLg/edit |
| 第10回 | 実践テスト + 総まとめ | 24 | https://docs.google.com/presentation/d/1P4OApYaqHR4UPyu6Se5YiW0lZAORxva7wqCikm1-C_E/edit |

計 504枚。

## 流し込みの方式

**AWS版 第1回のデッキを複製**してテーマ・レイアウト・マスタをそのまま引き継ぎ、
中身のスライドを入れ替えている。自前でテキストボックスを置くのではなく、
**レイアウト `p24` の TITLE / BODY プレースホルダに割り当てている**ので、
Google スライドの「レイアウト」機能や一括書式変更がそのまま効く。

黒帯はマスタではなく**各スライドの背景画像**(`stretchedPictureFill`)なので、
生成した全スライドにコピーしている。

### AWS版から実測した配置(第1回・第2回の98ボックス)

| | x | y | 幅 | 高さ | 書式 |
|---|---|---|---|---|---|
| タイトル枠 | 530448 | 287817 | 9039900 | 361500 | Kosugi 32pt 太字 / 白 |
| 本文枠 | 369738 | 1290975 | 10515600 | 4553550 | 14〜24pt(最頻20pt) |

単位は EMU。プレースホルダの基準サイズは 3000000 x 3000000 なので、
`updatePageElementTransform` の scale で上の実寸に合わせている。

**本文の文字サイズは 20pt を基準に、枠に収まる最大値を自動で選んでいる。**
全角を2、半角を1として行幅を数え、`幅 x サイズ x 0.6` が枠幅に収まるまで下げる。
GCP版は AA の図や `terraform destroy -target=...` の長い行があるため、
一部のスライドは 9〜12pt まで落ちる。

## 作図(2026-08-31 完了)

原稿で **`**[図版]** **新規作成**`** と指示していた **57枚**を、
Google スライドの**ネイティブ図形**(矩形・矢印・線・テキストボックス)で描いた。
画像を貼っていないので、**位置も色も文字もスライド上で直接編集できる**。

| 回 | 枚数 | 主な図 |
|---:|---:|---|
| 第1回 | 3 | リソース階層のツリー / サービスアカウントの2つの顔 / 4ステップのフロー |
| 第2回 | 9 | AWS-GCP対応表 / Firewall Rules vs SG / 踏み台不要 / SG→SAの書き換え / IAPの3つのゲート |
| 第3回 | 3 | ゴール構成図 / LBの6リソース / なぜ繋がらないのか(503) |
| 第4回 | 6 | DBサービス一覧 / 3種類の接続方式 / レンジの貸し出し / Spanner比較 / ホットスポット |
| 第5回 | 7 | VM→Cloud Run の移行 / コンテナサービスの選び方 / Cloud Runの構成 / Direct VPC egress |
| 第6回 | 5 | パス振り分け / S3との違い / Cloud CDN は LB の機能 / バックエンドバケット / URLマップ |
| 第7回 | 7 | pushからデプロイまで / AWS4 vs GCP1 / IAMの階層 / 権限が2つ要る / 責務の分界 |
| 第8回 | 7 | ログ・メトリクス・アラートの流れ / 監視サービス対応 / 何を鳴らすか / ダッシュボードのタイル |
| 第9回 | 6 | 資格のピラミッド / AWS対応表 / 選び方 / ACEの配点 / カバー率 |
| 第10回 | 4 | 4問の構成図 / 10回の全体像 / AWSとの違い / 何度も出てきた3つの考え方 |

### 描き方の決めごと

配色は AWS 版が白地・黒枠だったのに合わせ、**対比が要るところだけ**色を使う。

| 色 | 使う場面 |
|---|---|
| 薄いオレンジ | AWS 側 |
| 薄い青 | GCP 側 |
| 薄い黄 | 今日の主役・ここが変わる、の強調 |
| 薄い緑 | うまくいく / 楽になった |
| 薄い赤 | 失敗する / 詰まる / 注意 |

図に内容を載せきったスライドは**本文枠を空にしてある**。
図の下に本文を残したスライドは、本文枠を図の下端まで下げてある。

## 直したいとき

**Google スライド上で直接編集するのが前提。**
図形はグループ化していないので1つずつ動かせるし、
本文はプレースホルダなのでレイアウト変更や一括書式変更がそのまま効く。

生成スクリプトは会話用の一時ディレクトリに置いたので残っていない。
上の実測値と方式が分かれば Slides API で作り直せるが、
**手で調整したあとに再生成すると、その調整は消える。**
