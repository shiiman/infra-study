# 実践テスト 試験1(選択式)

**制限時間 25分 / 15問 / 各1点(15点満点)**

- Google Form で提出します
- **部分点はありません。**「2つ選べ」の問題は完答のみ得点
- 出題範囲は第1回〜第8回の全範囲
- 何も見ずに解いてください

> **★ 出題していない範囲 ★**
> GKE / 課金管理 / 組織・フォルダ・Cloud Identity は
> この勉強会で扱っていないので出題しません(第9回 S19 参照)。

---

## 問1(第1回・IAM)

Google Cloud のリソース階層として正しい順序はどれですか。

- A. プロジェクト → フォルダ → 組織
- B. 組織 → フォルダ → プロジェクト
- C. 組織 → プロジェクト → フォルダ
- D. フォルダ → 組織 → プロジェクト

---

## 問2(第1回・IAM)

サービスアカウントに、あるバケットの読み取り権限だけを与えたい。
最小権限の原則に従う方法はどれですか。

- A. プロジェクトに `roles/owner` を付与する
- B. プロジェクトに `roles/storage.admin` を付与する
- C. そのバケットに `roles/storage.objectViewer` を付与する
- D. `allUsers` に `roles/storage.objectViewer` を付与する

---

## 問3(第2回・ネットワーク)

GCP の VPC とサブネットについて、正しいものを **2つ** 選んでください。

- A. VPC はリージョンに属する
- B. VPC はグローバルなリソースである
- C. サブネットはリージョンに属する
- D. サブネットはゾーンに属する
- E. VPC を作ると必ず全リージョンにサブネットができる

---

## 問4(第2回・ネットワーク)

外部IPを持たない VM から、インターネット上のパッケージリポジトリに
アクセスしたい。必要なものはどれですか。

- A. Private Google Access を有効にする
- B. Cloud Router と Cloud NAT を作る
- C. VMに外部IPを付ける
- D. Firewall ルールで egress を許可する

---

## 問5(第2回・ネットワーク)

AWS のセキュリティグループと GCP の Firewall Rules の違いとして
正しいものはどれですか。

- A. GCP では他の Firewall ルールを送信元として指定できる
- B. GCP ではネットワークタグまたはサービスアカウントで対象を指定する
- C. GCP の Firewall ルールはサブネット単位で適用される
- D. GCP には egress ルールが存在しない

---

## 問6(第2回・IAP)

外部IPを持たない VM に IAP 経由で SSH したい。
必要なものを **2つ** 選んでください。

- A. `35.235.240.0/20` からの22番を許可する Firewall ルール
- B. `0.0.0.0/0` からの22番を許可する Firewall ルール
- C. `roles/iap.tunnelResourceAccessor` の付与
- D. 踏み台サーバの構築
- E. VMへの外部IPの付与

---

## 問7(第3回・ロードバランサ)

グローバル外部アプリケーションロードバランサを作ったが、
ブラウザで開くと **503** が返る。最初に疑うべきものはどれですか。

- A. アプリケーションのエラー
- B. Firewall ルールで `130.211.0.0/22` と `35.191.0.0/16` を許可していない
- C. DNS レコードの設定ミス
- D. SSL 証明書がまだ発行されていない

---

## 問8(第4回・データベース)

Cloud Run から Spanner には繋がるが、Memorystore には繋がらない。
理由として正しいものはどれですか。

- A. Spanner は Google API 経由、Memorystore は VPC 内にあるため
- B. Memorystore が起動していないため
- C. Spanner のほうが新しいサービスだから
- D. Memorystore は Cloud Run から使えない

---

## 問9(第4回・データベース)

Cloud SQL や Memorystore を VPC から使うために必要な仕組みはどれですか。

- A. Private Google Access
- B. Cloud NAT
- C. 限定公開サービスアクセス(VPCピアリング)
- D. Cloud VPN

---

## 問10(第5回・Cloud Run)

Cloud Run で、リクエストが無い時間帯の課金をゼロにしたい。
どうしますか。

- A. `min_instance_count` を 0 にする
- B. `max_instance_count` を 0 にする
- C. `timeout` を短くする
- D. Cloud Run では課金をゼロにできない

---

## 問11(第6回・ストレージとCDN)

Cloud CDN について正しいものはどれですか。

- A. CloudFront と同じく独立したサービスである
- B. ロードバランサのバックエンドに付ける機能である
- C. Cloud Storage の設定項目である
- D. Cloud Run でしか使えない

---

## 問12(第6回・ストレージ)

バックエンドバケットで配信するために、Cloud Storage のオブジェクトに
必要な設定はどれですか。

- A. CloudFront の OAI に相当する仕組みを設定する
- B. `allUsers` に `roles/storage.objectViewer` を付与する
- C. バケットを非公開のままにする
- D. 署名付きURLを発行する

---

## 問13(第7回・CI/CD)

Cloud Build から Cloud Run にデプロイするために必要な権限を
**2つ** 選んでください。

- A. `roles/run.developer`
- B. `roles/iam.serviceAccountUser`
- C. `roles/storage.admin`
- D. `roles/artifactregistry.reader`
- E. `roles/cloudbuild.builds.editor`

---

## 問14(第7回・CI/CD)

CI/CD が Cloud Run のイメージを差し替えたあと、
`terraform apply` すると古いイメージに戻ってしまう。
どうすればよいですか。

- A. Terraform の管理から Cloud Run を外す
- B. `lifecycle { ignore_changes = [template[0].containers[0].image] }` を書く
- C. CI/CD 側で Terraform を実行する
- D. `terraform apply` をしない運用にする

---

## 問15(第8回・監視)

アラートにすべきものはどれですか。

- A. CPU 使用率が 80% を超えた
- B. リクエスト数が普段より多い
- C. サイトが外から見えなくなった
- D. ディスクの読み取り回数が増えた
