/**
 * Step4: GitHub Actions から GCP を操作できるようにする
 *
 * ★ サービスアカウントの鍵ファイル(JSON)は作りません ★
 *
 * 昔は「SAの鍵を作って GitHub Secrets に貼る」というやり方でした。
 * これには問題があります。
 *
 *   - 鍵に有効期限がない
 *   - 漏れたら、取り消すまで誰でもGCPを触れる
 *   - 誰がコピーを持っているか分からない
 *
 * 代わりに使うのが Workload Identity 連携 (WIF) です。
 *
 * ★ 仕組み ★
 *
 * GitHub Actions は実行のたびに OIDC トークンを発行できます。
 * そのトークンには、こういう情報が入っています。
 *
 *   repository : sumzap/infra-study-app
 *   ref        : refs/heads/shiiman
 *
 *   1. Actions がこのトークンを持って GCP に来る
 *   2. GCP は GitHub の公開鍵でトークンを検証する
 *   3. 下に書いた条件に合えば、SAの短命なトークン(1時間)を渡す
 *
 * 鍵ファイルは1つも増えません。
 *
 * ★ AWSでいうと ★
 *   GitHub OIDC プロバイダを作って、IAMロールの信頼ポリシーに
 *   リポジトリの条件を書き、AssumeRole する形と同じです。
 */

/**
 * 講師が用意した Workload Identity プールの情報
 *
 * ★ プールとプロバイダは、プロジェクトに1つあれば足ります ★
 *
 * 作成はプロジェクト単位の操作になるので、
 * Cloud Build の GitHub 接続(cloudbuild_repository)と同じ扱いで
 * 講師が事前に用意してあります。
 *
 * 確認:
 *   gcloud iam workload-identity-pools list --location=global
 */
variable "workload_identity_pool_id" {
  description = "Workload Identity プールのフルリソース名(講師から渡される)"
  type        = string
}

variable "github_repository" {
  description = "アプリ用リポジトリ(owner/repo)"
  type        = string
  default     = "sumzap/infra-study-app"
}

/**
 * 自分のビルド用SAに「GitHub Actions から使ってよい」と書く
 *
 * ★ 付ける先は プロジェクト ではなく サービスアカウント ★
 *
 * Step3 で使った google_service_account_iam_member と同じリソースです。
 * 違うのは member の書き方だけ。
 *
 *   通常          serviceAccount:xxx@yyy.iam.gserviceaccount.com
 *   外部ID(WIF)   principal://iam.googleapis.com/<プール>/subject/<sub の値>
 *
 * ★ なぜ attribute.repo_ref という属性を使うのか ★
 *
 * 外部IDの指定には2つの書き方があります。
 *
 *   principal://.../subject/<sub の値>
 *     → トークンの sub を完全一致で見る
 *
 *   principalSet://.../attribute.<名前>/<値>
 *     → プロバイダで定義した属性で「集合」を指す
 *
 * 一見、sub の完全一致(principal://)が素直に見えます。
 * GitHub の sub は通常 repo:OWNER/REPO:ref:refs/heads/BRANCH の形なので、
 * リポジトリとブランチの両方を1つの文字列で縛れるからです。
 *
 * ★ しかし、この org ではそれが使えません ★
 *
 * 実際に発行されたトークンの sub を見ると、こうなっていました。
 *
 *   repo:sumzap@45473687/infra-study-app@1351899519:ref:refs/heads/shiiman
 *             ^^^^^^^^^                ^^^^^^^^^^^
 *
 * GitHub の組織設定で
 * 「OIDC の subject に不変ID(数値)を含める」が有効になっているためです。
 * 組織やリポジトリの名前を変えても同じ主体を指せるようにする設定で、
 * セキュリティ的にはこちらのほうが堅牢です。
 *
 * この数値IDをコードに書くと、読めないうえに調べないと分かりません。
 * 一方 repository / ref クレームは名前のまま素直に入っています。
 *
 * そこでプロバイダ側でこの2つを連結した属性を作ってあります。
 *
 *   attribute.repo_ref = assertion.repository + "@" + assertion.ref
 *
 * これで「リポジトリ名 @ ブランチ」という読める文字列で縛れます。
 *
 * ★ repository だけで絞ってはいけません ★
 *
 * 全員で1つのリポジトリを共有しているので、
 * attribute.repository だけだと **他の人のブランチから自分のSAが使えて**
 * しまいます。必ず ref まで含めた repo_ref を使ってください。
 *
 * ★ @refs/heads/${var.user_name} を消さないこと ★
 *
 * https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/google_service_account_iam
 */
resource "google_service_account_iam_member" "github_actions" {
  service_account_id = data.google_service_account.build.name
  role               = "roles/iam.workloadIdentityUser"

  member = join("", [
    "principalSet://iam.googleapis.com/",
    var.workload_identity_pool_id,
    "/attribute.repo_ref/",
    var.github_repository,
    "@refs/heads/",
    var.user_name,
  ])
}

/**
 * ワークフローに貼る値
 *
 * GitHub のリポジトリ変数(Variables)に入れて使います。
 * Secrets ではなく Variables で構いません。
 * ここに秘密の情報は1つもないからです(鍵を作っていないので)。
 *
 * ★ リポジトリは全員共通なので、Variables も全員で共有されます ★
 *
 * だから受講者ごとに違う値(リポジトリ名 / サービス名 / SA)は
 * ここに入れず、ワークフロー側でブランチ名から組み立てます。
 * Cloud Build のトリガーで substitutions に user_name を渡したのと同じ発想です。
 *
 * 講師が1回だけ設定すればよいのは、次の2つだけです。
 */
output "github_actions_variables" {
  description = "GitHub の Variables に設定する値(全員共通。講師が1回設定する)"
  value = {
    WIF_PROVIDER = "${var.workload_identity_pool_id}/providers/github"
    PROJECT_ID   = var.project_id
  }
}

/**
 * 自分のワークフローが使う値(確認用)
 *
 * ブランチ名から組み立てられるので設定は要りません。
 * 想定と合っているかの確認に使ってください。
 */
output "github_actions_derived" {
  description = "ワークフローがブランチ名から組み立てる値"
  value = {
    branch   = var.user_name
    repo_ref = "${var.github_repository}@refs/heads/${var.user_name}"
    sa       = data.google_service_account.build.email
    repo     = google_artifact_registry_repository.app.repository_id
    service  = module.before.cloud_run_name
  }
}
