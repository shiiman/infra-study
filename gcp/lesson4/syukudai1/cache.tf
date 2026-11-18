/**
 * Memorystore for Valkey
 *
 * AWSのElastiCache(Valkey)に相当する。
 * ValkeyはRedisから派生したオープンソースで、Redisと同じ方法で接続できる。
 *
 * ★ Redis ではなく Valkey を使う理由 ★
 * Memorystore for Redis(クラスタ無しの標準版)の接続方式は、
 * 限定公開サービスアクセスかダイレクトピアリングの2つで、PSCは選べない。
 * PSCで繋げるのは、Memorystore for Valkey と Memorystore for Redis Cluster。
 * Valkey は PSC でしか繋げない(限定公開サービスアクセスは選べない)。
 *
 * ★ AWSとの違い ★
 * ElastiCacheでは以下の4つを作る必要があった。
 *   サブネットグループ / パラメータグループ /
 *   セキュリティグループ / レプリケーショングループ
 *
 * Memorystoreはインスタンス1つで済む。
 *   サブネットグループ   → 不要(PSCのエンドポイントが自動で作られる)
 *   パラメータグループ   → engine_configs で直接指定
 *   セキュリティグループ → 不要(エンドポイント宛の通信になるのでFirewall Rulesも要らない)
 *
 * https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/memorystore_instance
 */
resource "google_memorystore_instance" "cache" {
  instance_id = "${var.user_name}-cache"
  location    = "asia-northeast1"

  // CLUSTER_DISABLED : シャードは1つ。Redis と同じ使い方になる
  // CLUSTER          : データを複数のシャードに分散する(クラスタ対応のクライアントが要る)
  mode        = "CLUSTER_DISABLED"
  shard_count = 1

  // プライマリに付けるレプリカの数
  // 0      : 1ノード。フェイルオーバーなし
  // 1以上  : プライマリ + レプリカ。自動フェイルオーバーあり
  // 宿題1: レプリカを1つ付ける(読み取り専用エンドポイントができる)
  replica_count = 1

  // 勉強会用の最小サイズ(共有CPU)
  node_type      = "SHARED_CORE_NANO"
  engine_version = "VALKEY_9_1"

  // 勉強会用: 通信の暗号化と認証を切る
  // 本番では transit_encryption_mode = SERVER_AUTHENTICATION と authorization_mode = IAM_AUTH を使うこと
  transit_encryption_mode = "TRANSIT_ENCRYPTION_DISABLED"
  authorization_mode      = "AUTH_DISABLED"

  // AWSのパラメータグループに相当
  engine_configs = {
    maxmemory-policy = "allkeys-lru"
  }

  // PSCのエンドポイントを、自分のVPCの中に自動で作る
  desired_auto_created_endpoints {
    network    = google_compute_network.vpc.id
    project_id = var.project_id
  }

  // 勉強会用: destroy できるようにする
  // 本番では true にして誤削除を防ぐこと
  deletion_protection_enabled = false

  // ポリシーが先にないと、エンドポイントを作れずに失敗する
  depends_on = [google_network_connectivity_service_connection_policy.memorystore]
}

/**
 * 自動で作られたエンドポイントのIP
 *
 * エンドポイントは、プライマリ(読み書き)と、レプリカがあるときのリーダー(読み取り専用)の
 * 2種類。connection_type で見分けて、プライマリのIPをアプリに渡す。
 */
locals {
  cache_connections = flatten([
    for e in google_memorystore_instance.cache.endpoints : [
      for c in e.connections : c.psc_auto_connection[0]
    ]
  ])
  cache_host = [
    for c in local.cache_connections : c.ip_address
    if c.connection_type == "CONNECTION_TYPE_PRIMARY"
  ][0]
}

output "cache_host" {
  value = local.cache_host
}

// 宿題1: 読み取り専用エンドポイント
output "cache_read_endpoint" {
  value = [
    for c in local.cache_connections : c.ip_address
    if c.connection_type == "CONNECTION_TYPE_READER"
  ][0]
}
