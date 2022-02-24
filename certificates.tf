# create certificates for the trust anchor and issuer
#
resource "tls_private_key" "linkerd" {
  depends_on = [helm_release.cert-manager]
  for_each    = toset(["trust_anchor", "issuer"])
  algorithm   = "ECDSA"
  ecdsa_curve = "P256"
}

# Control Plane TLS Credentials
resource "tls_self_signed_cert" "linkerd-trust-anchor" {
  depends_on = [helm_release.cert-manager]
  key_algorithm     = tls_private_key.linkerd["trust_anchor"].algorithm
  private_key_pem   = tls_private_key.linkerd["trust_anchor"].private_key_pem
  is_ca_certificate = true

  validity_period_hours = var.trust_anchor_validity_hours

  allowed_uses = ["cert_signing", "crl_signing", "server_auth", "client_auth"]

  subject {
    common_name = "root.linkerd.cluster.local"
  }
}

# Webhook TLS Credentials
resource "tls_self_signed_cert" "linkerd-issuer" {
  depends_on = [helm_release.cert-manager]
  key_algorithm     = tls_private_key.linkerd["issuer"].algorithm
  private_key_pem   = tls_private_key.linkerd["issuer"].private_key_pem
  is_ca_certificate = true

  validity_period_hours = var.issuer_validity_hours

  allowed_uses = ["cert_signing", "crl_signing"]

  subject {
    common_name = "webhook.linkerd.cluster.local"
  }
}

# create namespaces for linkerd and any extensions (linkerd-viz or linkerd-jaeger)
resource "kubernetes_namespace" "namespace" {
  depends_on = [local_file.kubeconfig_EKS_Cluster]
  for_each = var.namespaces
  metadata {
    name        = each.key
    annotations = (each.key != "linkerd") ? { "linkerd.io/inject" = "enabled" } : {}
    labels      = (each.key != "linkerd") ? { "linkerd.io/extension" = trimprefix(each.key, "linkerd-") } : {}
  }
}

# create secret used for the control plane credentials
resource "kubernetes_secret" "linkerd-trust-anchor" {
  depends_on = [kubernetes_namespace.namespace,tls_self_signed_cert.linkerd-trust-anchor]

  type = "kubernetes.io/tls"

  metadata {
    name      = "linkerd-trust-anchor"
    namespace = "linkerd"
  }

  data = {
    "tls.crt" : tls_self_signed_cert.linkerd-trust-anchor.cert_pem
    "tls.key" : tls_private_key.linkerd["trust_anchor"].private_key_pem
  }
}

# create secrets used for the webhook credentials
resource "kubernetes_secret" "linkerd-issuer" {
  depends_on = [kubernetes_namespace.namespace,tls_self_signed_cert.linkerd-issuer]

  type = "kubernetes.io/tls"

  for_each = var.namespaces
  metadata {
    name      = "webhook-issuer-tls"
    namespace = each.key
  }

  data = {
    "tls.crt" : tls_self_signed_cert.linkerd-issuer.cert_pem
    "tls.key" : tls_private_key.linkerd["issuer"].private_key_pem
  }
}
