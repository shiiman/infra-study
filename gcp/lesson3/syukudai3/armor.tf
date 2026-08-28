variable "company_ip" { type = list(string) }

/**
 * 宿題3: Cloud Armor で社内IP制限
 *
 * Cloud Armor は AWS の WAF に相当する。
 * ロードバランサの手前でリクエストを検査して、通す/落とすを決める。
 *
 * ★ どこに効くか ★
 * Firewall Rules は VPC の中の話だったが、
 * Cloud Armor は VPC の外側、Googleのフロントエンドで効く。
 * つまり「LBまで到達する前」に弾ける。
 *
 * ★ ルールの評価順 ★
 * priority が小さいものから評価され、最初に一致したものが適用される。
 * 一番最後(priority 2147483647)に必ずデフォルトルールが必要。
 *
 * https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_security_policy
 */
resource "google_compute_security_policy" "web" {
  name        = "${var.user_name}-web-policy"
  description = "社内IPからのみアクセスを許可する"

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
