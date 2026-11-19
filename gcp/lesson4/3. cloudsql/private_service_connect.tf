/**
 * Private Service Connect (PSC) とサービス接続ポリシー
 *
 * ★ AWSには無い、GCP独自の前提 ★
 *
 * Memorystore や Cloud SQL は「Googleが管理するVPC」の中で動いている。
 * 自分のVPCとは別のネットワークなので、そのままでは繋がらない。
 *
 * PSC は、自分のVPCの中に「エンドポイント」(内部IPを1つ)を立てて、
 * そのIPに向かって接続すると、Google側のサービスに届く仕組み。
 *
 *   自分のVPC 172.16.0.0/16
 *     ├ public  172.16.0.0/24
 *     └ private 172.16.10.0/24
 *         └ 172.16.10.4  ← エンドポイント。このIP宛に接続する
 *                ↕ PSC
 *   Googleが管理するVPC(Memorystore がいる)
 *
 * 貸し出すのはIP 1つ分だけで、IPレンジの設計は要らない。
 * (限定公開サービスアクセスは、IPレンジを丸ごとGoogleに貸し出してピアリングを張っていた)
 *
 * AWSではRDSやElastiCacheが自分のVPCのサブネットに直接ENIを作っていたので、
 * この手順は存在しなかった。代わりにサブネットグループを作っていた。
 *
 * ★ サービス接続ポリシー ★
 * 「このVPCの、このサブネットに、この種類のサービスのエンドポイントを
 *  自動で作ってよい」という許可。サービスの種類(サービスクラス)ごとに1つ作る。
 *
 *   Memorystore → gcp-memorystore
 *   Cloud SQL   → google-cloud-sql
 *
 * ポリシーがあると、インスタンスを作るときにエンドポイントが自動で作られる。
 * エンドポイントのIPは、subnetworks に指定したサブネットから払い出される。
 *
 * https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/network_connectivity_service_connection_policy
 */
resource "google_network_connectivity_service_connection_policy" "memorystore" {
  name          = "${var.user_name}-memorystore"
  location      = "asia-northeast1"
  service_class = "gcp-memorystore"
  network       = google_compute_network.vpc.id

  psc_config {
    // エンドポイントのIPを払い出すサブネット
    subnetworks = [google_compute_subnetwork.private.id]
  }
}
