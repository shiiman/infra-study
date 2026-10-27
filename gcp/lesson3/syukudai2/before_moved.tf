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
