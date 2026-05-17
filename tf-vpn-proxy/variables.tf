variable "kubeconfig_path" {
  description = "Path to kubeconfig file."
  type        = string
  default     = "~/.kube/config"
}

variable "kube_context" {
  description = "Optional kubeconfig context."
  type        = string
  default     = null
}

variable "namespace" {
  description = "Namespace for the vpn proxy stack."
  type        = string
  default     = "vpn-namespace"
}

variable "domain_name" {
  description = "Public domain used by the nginx gateway."
  type        = string
  default     = "vpn.example.com"
}

variable "keycloak_hostname" {
  description = "Hostname exposed by the Keycloak chart."
  type        = string
  default     = "keycloak.example.com"
}

variable "keycloak_admin_user" {
  description = "Keycloak admin username."
  type        = string
  default     = "admin"
}

variable "keycloak_admin_password" {
  description = "Keycloak admin password."
  type        = string
  sensitive   = true
}

variable "keycloak_realm" {
  description = "Realm used by the VPN client."
  type        = string
  default     = "vpn-realm"
}

variable "keycloak_client_id" {
  description = "OIDC client shown on the nginx redirect."
  type        = string
  default     = "vpn-client"
}

variable "postgres_password" {
  description = "Password for the Keycloak PostgreSQL user."
  type        = string
  sensitive   = true
}

variable "integrity_api_key" {
  description = "Shared bearer token required by the gRPC integrity service."
  type        = string
  sensitive   = true
}

variable "tls_secret_name" {
  description = "Existing kubernetes.io/tls secret used by nginx."
  type        = string
  default     = "vpn-proxy-tls"
}

variable "openvpn_storage_size" {
  description = "PVC size for OpenVPN state."
  type        = string
  default     = "8Gi"
}

variable "storage_class_name" {
  description = "Optional storage class for PVCs."
  type        = string
  default     = null
}
