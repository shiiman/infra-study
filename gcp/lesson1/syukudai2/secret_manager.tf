/**
 * シークレットの値を受け取る変数
 *
 * ephemeral = true にすると、この値は tfstate にも plan にも保存されず、
 * apply を実行している間だけメモリ上に存在する。
 *
 *   - terraform.tfvars には書かない(リポジトリに残ってしまうため)
 *   - 環境変数 TF_VAR_secret_value で渡す(README の手順を参照)
 *
 * sensitive = true は、画面に値が表示されないようにするためのもの。
 * ephemeral(保存されない)とは別の話で、両方付けるのが普通。
 *
 * https://developer.hashicorp.com/terraform/language/values/variables#exclude-values-from-state
 */
variable "secret_value" {
  type      = string
  sensitive = true
  ephemeral = true

  // destroy のときは値が要らないので、空文字を既定にしている。
  // (既定を付けないと、destroy のたびに値を聞かれる)
  // 渡し忘れて apply しても、空のシークレットは作られない。
  // Secret Manager が「Field [payload] is required」と拒否する
  default = ""
}

/**
 * Secret Manager のシークレット作成(入れ物)
 *
 * https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/secret_manager_secret
 */
resource "google_secret_manager_secret" "app" {
  secret_id = "${var.user_name}-app-secret"

  replication {
    user_managed {
      replicas {
        location = "asia-northeast1"
      }
    }
  }
}

/**
 * シークレットの値(バージョン)
 *
 * 値は secret_data ではなく secret_data_wo(write-only)に渡す。
 *
 *   secret_data     : tfstate に平文で保存される
 *   secret_data_wo  : tfstate に保存されない(書き込み専用。APIから読み戻さない)
 *
 * 注意すること:
 *   - 値を変えても Terraform は変更を検知できない(値を持っていないため)。
 *     更新するときは secret_data_wo_version の数字を上げる
 *   - 数字を上げると新しいバージョンが作られ、古いバージョンは既定で破棄される
 *     (ロールバック用に残したいなら deletion_policy を見直す)
 *
 * https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/secret_manager_secret_version
 */
resource "google_secret_manager_secret_version" "app" {
  secret                 = google_secret_manager_secret.app.id
  secret_data_wo         = var.secret_value
  secret_data_wo_version = 1
}

/**
 * シークレット単位のIAM
 *
 * プロジェクト全体に roles/secretmanager.secretAccessor を付けると
 * プロジェクト内の全シークレットが読めてしまう。
 * このシークレットだけを読ませたいので、リソース単位で付与する。
 *
 * https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/secret_manager_secret_iam
 */
resource "google_secret_manager_secret_iam_member" "app_accessor" {
  secret_id = google_secret_manager_secret.app.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.app.email}"
}
