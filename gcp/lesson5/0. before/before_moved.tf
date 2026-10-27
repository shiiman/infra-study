// 旧教材の module.before で作成済みの場合も、同じリソースを引き継ぐ。
moved {
  from = module.before.google_compute_network.vpc
  to   = google_compute_network.vpc
}

moved {
  from = module.before.google_compute_subnetwork.public
  to   = google_compute_subnetwork.public
}

moved {
  from = module.before.google_compute_subnetwork.private
  to   = google_compute_subnetwork.private
}

moved {
  from = module.before.google_compute_router.router
  to   = google_compute_router.router
}

moved {
  from = module.before.google_compute_router_nat.nat
  to   = google_compute_router_nat.nat
}

moved {
  from = module.before.google_service_account.web
  to   = google_service_account.web
}

moved {
  from = module.before.google_compute_instance.web
  to   = google_compute_instance.web
}

moved {
  from = module.before.google_compute_firewall.allow_iap_ssh
  to   = google_compute_firewall.allow_iap_ssh
}

moved {
  from = module.before.google_compute_firewall.allow_lb_to_web
  to   = google_compute_firewall.allow_lb_to_web
}

moved {
  from = module.before.google_iap_tunnel_instance_iam_member.web
  to   = google_iap_tunnel_instance_iam_member.web
}

moved {
  from = module.before.google_compute_instance_iam_member.web_os_login
  to   = google_compute_instance_iam_member.web_os_login
}

moved {
  from = module.before.google_service_account_iam_member.web_sa_user
  to   = google_service_account_iam_member.web_sa_user
}

moved {
  from = module.before.google_compute_instance_group.web
  to   = google_compute_instance_group.web
}

moved {
  from = module.before.google_compute_health_check.web
  to   = google_compute_health_check.web
}

moved {
  from = module.before.google_compute_backend_service.web
  to   = google_compute_backend_service.web
}

moved {
  from = module.before.google_compute_global_address.web
  to   = google_compute_global_address.web
}

moved {
  from = module.before.google_dns_record_set.web
  to   = google_dns_record_set.web
}

moved {
  from = module.before.google_compute_managed_ssl_certificate.web
  to   = google_compute_managed_ssl_certificate.web
}

moved {
  from = module.before.google_compute_global_address.private_service
  to   = google_compute_global_address.private_service
}

moved {
  from = module.before.google_service_networking_connection.private_service
  to   = google_service_networking_connection.private_service
}

moved {
  from = module.before.google_redis_instance.cache
  to   = google_redis_instance.cache
}

moved {
  from = module.before.google_spanner_instance.main
  to   = google_spanner_instance.main
}

moved {
  from = module.before.google_spanner_database.app
  to   = google_spanner_database.app
}

moved {
  from = module.before.google_spanner_database_iam_member.web
  to   = google_spanner_database_iam_member.web
}
