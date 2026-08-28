/**
 * Cloud Storage バケット
 *
 * AWSのS3に相当する。
 *
 * ★ S3との違い ★
 *   S3   バケットはリージョンに属する
 *   GCS  location で リージョン / デュアルリージョン / マルチリージョン を選ぶ
 *
 *   S3   ACLとバケットポリシーの2系統があり、どちらが効くか分かりにくかった
 *   GCS  均一なバケットレベルのアクセス(UBLA)でIAMに一本化できる
 *
 * https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket
 */
resource "google_storage_bucket" "static" {
  name     = "${var.project_id}-static-${var.user_name}"
  location = "ASIA-NORTHEAST1"

  // ストレージクラス
  //   STANDARD  頻繁にアクセスする(既定)
  //   NEARLINE  月1回程度      最低保存30日
  //   COLDLINE  四半期に1回程度 最低保存90日
  //   ARCHIVE   年1回程度      最低保存365日
  storage_class = "STANDARD"

  // 旧来のACLを無効化し、権限管理をIAMに一本化する
  // 第1回のtfstateバケットでも同じ設定をしている
  uniform_bucket_level_access = true

  // 勉強会用: 中身が残っていても destroy できるようにする
  // ★ AWS版では「S3の中身は手動で削除してください」という注意があった
  //   GCPは force_destroy = true で自動的に消せる
  force_destroy = true
}

/**
 * 静的ファイルをアップロードする
 *
 * ★ Terraformでファイルを配置できる ★
 * AWS版では `aws s3 sync` を手で叩いていたが、
 * google_storage_bucket_object でコード管理できる。
 *
 * 大量のファイルには向かない(1ファイル1リソースになる)ので、
 * 実務ではCI/CDから gcloud storage rsync することが多い。
 *
 * https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket_object
 */
resource "google_storage_bucket_object" "index" {
  // ★ オブジェクト名が、そのままURLのパスになる ★
  // バックエンドバケットは /static/index.html のリクエストを
  // オブジェクト "static/index.html" として取りに行く。
  // URLマップの path_rule で振り分けるパスと、
  // オブジェクト名の階層を合わせておくこと。
  name   = "static/index.html"
  bucket = google_storage_bucket.static.name
  source = "${path.module}/static/index.html"

  content_type = "text/html"

  // ★ キャッシュ制御 ★
  // Cloud CDN はこのヘッダを見てキャッシュの寿命を決める
  //   public       CDNにキャッシュしてよい
  //   max-age      ブラウザのキャッシュ時間(秒)
  //   s-maxage     CDNのキャッシュ時間(秒)
  cache_control = "public, max-age=60, s-maxage=300"
}

resource "google_storage_bucket_object" "style" {
  name          = "static/style.css"
  bucket        = google_storage_bucket.static.name
  source        = "${path.module}/static/style.css"
  content_type  = "text/css"
  cache_control = "public, max-age=60, s-maxage=300"
}

output "bucket_name" {
  value = google_storage_bucket.static.name
}
