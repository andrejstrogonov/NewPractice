output "namespace" {
  value = kubernetes_namespace_v1.vpn.metadata[0].name
}

output "vpn_proxy_service" {
  value = kubernetes_service_v1.vpn_proxy.metadata[0].name
}

output "openvpn_service" {
  value = kubernetes_service_v1.openvpn.metadata[0].name
}

output "integrity_grpc_service" {
  value = kubernetes_service_v1.integrity_grpc.metadata[0].name
}

output "keycloak_release" {
  value = helm_release.keycloak.name
}
