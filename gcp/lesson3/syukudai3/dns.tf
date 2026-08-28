variable "dns_zone_name" {}

/**
 * Cloud DNS のマネージドゾーンを参照する
 *
 * ★ ゾーンはTerraformで作らない ★
 * 全員で1つのプロジェクトを共有しているため、
 * ゾーンをresourceで書くと誰かのdestroyで全員のドメインが消える。
 * 事前に用意されたゾーンをdataで参照するだけにする。
 *
 * https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/dns_managed_zone
 */
data "google_dns_managed_zone" "public" {
  name = var.dns_zone_name
}

/**
 * Aレコード作成
 *
 * <自分の名前>.<勉強会のドメイン> を
 * ロードバランサのグローバルIPに向ける。
 *
 * AWSではALBへの alias レコードだったが、
 * GCPはLBが固定IPを持つので普通のAレコードでよい。
 *
 * dns_name は末尾にドットが付く形("example.jp.")で返る。
 *
 * https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/dns_record_set
 */
resource "google_dns_record_set" "web" {
  name         = "${var.user_name}.${data.google_dns_managed_zone.public.dns_name}"
  managed_zone = data.google_dns_managed_zone.public.name
  type         = "A"
  ttl          = 300

  rrdatas = [google_compute_global_address.web.address]
}

output "web_url" {
  value = "http://${var.user_name}.${trimsuffix(data.google_dns_managed_zone.public.dns_name, ".")}"
}
