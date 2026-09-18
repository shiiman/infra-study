# スライド原稿と Google スライド

原稿(`lesson1.md` 〜 `lesson10.md`)から Google スライドに流し込み済み(2026-08-31)。
**共有ドライブ →「インフラ勉強会(GCP)」フォルダ**に置いてある。

| 回 | テーマ | 枚数 | Google スライド |
|---|---|---:|---|
| 第1回 | GCP基礎 / IAM / Terraform | 94 | https://docs.google.com/presentation/d/1LGC9jpgPpKj1ObDw7JFDw1x_OG3sMO_ZdxkUQ4mqU6k/edit |
| 第2回 | ネットワーク | 63 | https://docs.google.com/presentation/d/1p0NGtqsvkGYxFewE8AjoPYqh8kgkvTjyVEjLA6Fmkvs/edit |
| 第3回 | コンピューティング | 56 | https://docs.google.com/presentation/d/1cxkYA6EAxoyUp-iMQILfCvJ_CjR8SuccNb7cRbhMc0s/edit |
| 第4回 | データベース | 55 | https://docs.google.com/presentation/d/1Cn3LTns2BdgXLAwhyPbr-LbEZU1Je_4m3NZLSRkLufM/edit |
| 第5回 | コンテナ | 51 | https://docs.google.com/presentation/d/1ow1DPEjkCakiMKhQ-TknYS3u_9yezEQYnRvaovz_sqs/edit |
| 第6回 | ストレージ + CDN | 46 | https://docs.google.com/presentation/d/1kuYTeNuWkzd8-_Mj1u2RNBKO4-xh8ycWsvlxO0hbXYo/edit |
| 第7回 | CI/CD | 58 | https://docs.google.com/presentation/d/1gRqC2I-lme3uUlA2DX2L3aRYAkpB0DQokDFzI2yKI3I/edit |
| 第8回 | 監視・運用 + その他リソース | 54 | https://docs.google.com/presentation/d/1T5uKWZNngdzsw9JepsK4pJiwgir7dz3mwUgFueaoiDc/edit |
| 第9回 | 試験対策 | 46 | https://docs.google.com/presentation/d/18HRSIFBcPvDAH5Gg19AFevZtYdSj1R2hUVhX-U0vzLg/edit |
| 第10回 | 実践テスト + 総まとめ | 24 | https://docs.google.com/presentation/d/1P4OApYaqHR4UPyu6Se5YiW0lZAORxva7wqCikm1-C_E/edit |

計 547枚(2026-09-16 に Slides API で実測)。

> 第1回は 2026-09-11 に大幅改訂(導入・インフラ基礎の増補、ハンズオンの gcloud 化)。
> ハンズオンの gcloud 化でデッキから3枚(Step1実行 / backend切り替え / state移行)を削除した。

> **★★ S番号でページを特定してはいけない。全10回でズレる ★★**
>
> **第1回も例外ではない(2026-09-18 に判明)。**
> 以前ここに「第1回は S番号とページ番号が1対1」と書いてあったが**誤り**だった。
>
> | 回 | 例 | 原稿 | デッキ |
> |---|---|---|---|
> | 第1回 | Terraform をインストールする | S66 | **p65** |
> | 第6回 | 注意事項 | S43 | **p45** |
> | 第7回 | 注意事項 | S46 | **p57** |
> | 第8回 | 注意事項 | S47 | **p53** |
>
> **第1回のズレは「枚数の違い」ではなく「順序の違い」**なので、
> オフセットを足せば直るわけではない。
> 原稿は S65「Terraform(セクション区切り)」→ S66「インストール」→ S67「作業スペース」の順だが、
> **デッキは p65「インストール」→ p66「作業スペース」→ p67「セクション区切り」**の順。
> 区切りが後ろに移っている。
>
> 原稿94枚・デッキ94枚で**枚数は一致している**ため、
> 総数を見てもズレに気づけない点に注意。
>
> デッキ側を触るときは**必ずタイトルで該当ページを探すこと**。
> Slides API なら次で一覧できる。
>
> ```python
> pres = service.presentations().get(presentationId=PID).execute()
> for i, sl in enumerate(pres["slides"], 1):
>     for el in sl.get("pageElements", []):
>         sh = el.get("shape")
>         if sh and sh.get("placeholder", {}).get("type") == "TITLE":
>             print(i, "".join(e.get("textRun", {}).get("content", "")
>                              for e in sh.get("text", {}).get("textElements", [])))
> ```

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
GCP版は AA の図や長いコマンド行があるため、
一部のスライドは 9〜12pt まで落ちる。

## 作図(2026-08-31 完了)

原稿で **`**[図版]** **新規作成**`** と指示していた **57枚**を、
Google スライドの**ネイティブ図形**(矩形・矢印・線・テキストボックス)で描いた。
画像を貼っていないので、**位置も色も文字もスライド上で直接編集できる**。

| 回 | 枚数 | 主な図 |
|---:|---:|---|
| 第1回 | 3 | リソース階層のツリー / サービスアカウントの2つの顔 / 3ステップのフロー |
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

### 1枚だけ直したいとき(再生成しない方法)

デッキ全体を作り直さず、**該当ページの BODY プレースホルダだけ差し替えられる**。
他のページの手調整は一切触らないので安全。

```python
requests = [
    {"deleteText": {"objectId": body_id, "textRange": {"type": "ALL"}}},
    {"insertText": {"objectId": body_id, "insertionIndex": 0, "text": new_text}},
    {"updateTextStyle": {"objectId": body_id, "textRange": {"type": "ALL"},
                         "style": {"fontSize": {"magnitude": fit, "unit": "PT"}},
                         "fields": "fontSize"}},
]
service.presentations().batchUpdate(presentationId=PID, body={"requests": requests}).execute()
```

- `deleteText` + `insertText` だけなら**フォントサイズは引き継がれる**(実測で確認)。
  文字数が増えて枠からはみ出すときだけ `updateTextStyle` でサイズを下げる。

> **★ 収まりは計算で判定しないこと。サムネイルを見ること(2026-09-18)★**
>
> 以前ここに「`行数 x サイズ x 1.2` が枠高の95%以内なら収まる」と書いていたが、
> **この式は過剰に保守的で使えない。**
> 実際には**手を加えていないページでも「はみ出す」と判定される**。
> 式を信じてフォントを下げると、手調整済みのレイアウトを無駄に壊す。
>
> **`getThumbnail` で画像を取って目で見るのが唯一確実。**
>
> ```python
> r = service.presentations().pages().getThumbnail(
>         presentationId=PID, pageObjectId=oid,
>         thumbnailProperties_thumbnailSize="LARGE").execute()
> urllib.request.urlretrieve(r["contentUrl"], "page.png")
> ```
>
> 2026-09-18 に第1回 p65(24行/14pt)と p85(22行/14pt)で試したところ、
> **式は両方「はみ出す」と出たが、実際は下に余白が残っていた。**
- 認証は `shiiman-google` プラグインの `lib/google_utils.py` の
  `load_credentials(get_token_path("<プロファイル名>"), SCOPES)` を使う。

**2026-09-16 にこの方法で4枚を差し替えた**
(第5回 p50 / 第6回 p45 / 第7回 p57 / 第8回 p53 の「注意事項」)。
片付け手順を「受講者は1回だけ、2回目は講師がまとめて」に変えたため。
フォントサイズは 8→7 / 7→6 / 16→14 / 16→12 pt に調整している。

**2026-09-18 に第1回の2枚を差し替えた。**

| ページ | 何を |
|---|---|
| p65 Terraform をインストールする | バージョンを `1.16.0` → `1.16.3` に |
| p85 Step3 実行 → 成功 | 「apply 直後は IAM 反映待ちで失敗する」の1行を追加 |

どちらも**フォントは 14pt のまま触っていない**。サムネイルで収まりを確認済み。
