/**
 * バックエンドバケット + Cloud CDN
 *
 * ★ AWSとの一番大きな違い ★
 *
 * CloudFront は独立したサービスで、ディストリビューションを作り、
 * オリジン・キャッシュ動作・証明書・ドメインを全部その中に設定していた。
 *
 * Cloud CDN は独立したサービスではなく、
 * **ロードバランサのバックエンドに付ける機能**。
 * `enable_cdn = true` を書くだけで有効になる。
 *
 *   AWS  [Route53] → [CloudFront] → [S3]
 *                     独立したサービス
 *
 *   GCP  [Cloud DNS] → [ロードバランサ] → [バックエンドバケット] → [GCS]
 *                        第3回で作ったもの      enable_cdn = true
 *
 * つまり第3回で作ったロードバランサに、配信先を1つ足すだけ。
 * ドメインも証明書もそのまま使える。
 *
 * https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_backend_bucket
 */
resource "google_compute_backend_bucket" "static" {
  name        = "${var.user_name}-static-bb"
  bucket_name = google_storage_bucket.static.name

  // これだけでCDNが有効になる
  enable_cdn = true

  // 宿題3: Cloud Armor のポリシーを紐づける
  // ★ バックエンドバケットには edge_security_policy を使う
  //   security_policy という属性は存在しない
  //   指定するポリシーは type = "CLOUD_ARMOR_EDGE" である必要がある
  edge_security_policy = google_compute_security_policy.edge.id

  cdn_policy {
    // キャッシュの判断方法
    //   CACHE_ALL_STATIC    静的コンテンツを自動でキャッシュ(既定)
    //   USE_ORIGIN_HEADERS  オリジンのCache-Controlに従う
    //   FORCE_CACHE_ALL     全部キャッシュ(Cache-Controlを無視)
    //
    // 既定のままだと Cache-Control が無くてもキャッシュされてしまい、
    // 「なぜキャッシュされているか」がコードから読めない。
    // オブジェクトに付けた Cache-Control で寿命を決めたいので明示する。
    cache_mode = "USE_ORIGIN_HEADERS"

    // オリジンが落ちている間、期限切れのキャッシュを返し続ける秒数
    serve_while_stale = 86400

    // 同じURLへの同時リクエストをまとめてオリジンに1回だけ問い合わせる
    // (キャッシュミス時にオリジンへ殺到するのを防ぐ)
    request_coalescing = true
  }
}
