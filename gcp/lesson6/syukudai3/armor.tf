variable "company_ip" { type = list(string) }

/**
 * 宿題3: Cloud Armor で静的ファイルにも社内IP制限
 *
 * Cloud Armor は AWS の WAF に相当する。
 * ロードバランサの手前でリクエストを検査して、通す/落とすを決める。
 *
 * ★ どこに効くか ★
 * Firewall Rules は VPC の中の話だったが、
 * Cloud Armor は VPC の外側、Googleのフロントエンドで効く。
 * つまり「LBまで到達する前」に弾ける。
 *
 * ★★ ここがハマりどころ ★★
 *
 * Cloud Armor のポリシーには2種類ある。
 *
 *   type = "CLOUD_ARMOR"       バックエンドサービスに security_policy で付ける
 *                              オリジンへ行く手前で評価される(第3回 宿題3 はこれ)
 *
 *   type = "CLOUD_ARMOR_EDGE"  バックエンドバケット / CDN有効なバックエンドに
 *                              edge_security_policy で付ける
 *                              **キャッシュから返す前**に評価される
 *
 * type を省略すると CLOUD_ARMOR になるので、
 * そのまま edge_security_policy に指定すると失敗する。
 *
 *   Error 400: Security policy ... is not an edge security policy
 *
 * つまり第3回のポリシーをそのまま使い回すことはできない。
 * エッジ用のポリシーを別に作る必要がある。
 *
 * ★ ルールの評価順 ★
 * priority が小さいものから評価され、最初に一致したものが適用される。
 * 一番最後(priority 2147483647)に必ずデフォルトルールが必要。
 *
 * https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_security_policy
 */
resource "google_compute_security_policy" "edge" {
  name        = "${var.user_name}-edge-policy"
  description = "社内IPからのみ静的ファイルの配信を許可する"

  // ★ これが無いと edge_security_policy に指定できない
  type = "CLOUD_ARMOR_EDGE"

  // 社内IPを許可
  rule {
    action   = "allow"
    priority = 1000

    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = var.company_ip
      }
    }

    description = "社内IPを許可"
  }

  // それ以外は拒否(デフォルトルール。省略できない)
  rule {
    action   = "deny(403)"
    priority = 2147483647

    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }

    description = "デフォルト拒否"
  }
}
