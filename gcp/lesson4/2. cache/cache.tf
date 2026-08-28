/**
 * Memorystore for Redis
 *
 * AWSのElastiCacheに相当する。
 *
 * ★ AWSとの違い ★
 * ElastiCacheでは以下の4つを作る必要があった。
 *   サブネットグループ / パラメータグループ /
 *   セキュリティグループ / レプリケーショングループ
 *
 * Memorystoreはインスタンス1つで済む。
 *   サブネットグループ   → 不要(限定公開サービスアクセスで接続)
 *   パラメータグループ   → redis_configs で直接指定
 *   セキュリティグループ → 不要(ピアリング経由なのでFirewall Rulesも要らない)
 *
 * https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/redis_instance
 */
resource "google_redis_instance" "cache" {
  name           = "${var.user_name}-cache"
  region         = "asia-northeast1"
  memory_size_gb = 1

  // BASIC       : 1ノード。フェイルオーバーなし
  // STANDARD_HA : プライマリ + レプリカ。自動フェイルオーバーあり
  tier = "STANDARD_HA"

  redis_version = "REDIS_7_2"

  // 限定公開サービスアクセスで接続する
  authorized_network = module.before.vpc_id
  connect_mode       = "PRIVATE_SERVICE_ACCESS"

  // AWSのパラメータグループに相当
  redis_configs = {
    maxmemory-policy = "allkeys-lru"
  }

  // ピアリングが張られてから作る
  depends_on = [google_service_networking_connection.private_service]
}

output "cache_host" {
  value = google_redis_instance.cache.host
}
