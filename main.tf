# https://linkerd.io/2.11/getting-started/
# https://linkerd.io/2.10/tasks/using-ingress/#nginx

resource "time_static" "cert_create_time" {
}

# Create cert-manager
# https://linkerd.io/2.11/tasks/automatically-rotating-control-plane-tls-credentials/
# https://cert-manager.io/docs/installation/helm/
  resource "helm_release" "cert-manager" {
  depends_on = [local_file.kubeconfig_EKS_Cluster]
  name       = "cert-manager"
  chart      = "cert-manager"
  repository = "https://charts.jetstack.io"
  version    = "v1.7.1"
  namespace        = "cert-manager"
  create_namespace = true
  timeout    = var.linkerd_helm_install_timeout_secs
  set {
    name  = "installCRDs"
    value = "true"
  }
}

resource "helm_release" "issuer" {
  depends_on = [kubernetes_secret.linkerd-trust-anchor,kubernetes_secret.linkerd-issuer]
  name       = "linkerd-issuer"
  namespace  = "linkerd"
  chart      = "${path.module}/charts/linkerd-issuers"
  timeout    = var.linkerd_helm_install_timeout_secs
  values = [
    yamlencode({
      installLinkerdViz    = contains(var.namespaces, "linkerd-viz") ? true : false
      installLinkerdJaeger = contains(var.namespaces, "linkerd-jaeger") ? true : false
      certificate = {
        controlplane = {
          duration    = var.certificate_controlplane_duration
          renewbefore = var.certificate_controlplane_renewbefore
        }
        webhook = {
          duration    = var.certificate_webhook_duration
          renewbefore = var.certificate_webhook_renewbefore
        }
      }
    })
  ]
}

resource "helm_release" "linkerd" {
  depends_on = [helm_release.issuer]

  name       = "linkerd"
  chart      = "linkerd2"
  repository = var.chart_repository
  version    = var.chart_version
  namespace        = "linkerd"
  create_namespace = false
  timeout    = var.linkerd_helm_install_timeout_secs

  values = [
    yamlencode({
      installNamespace        = false
      disableHeartBeat        = true
      identityTrustAnchorsPEM = tls_self_signed_cert.linkerd-trust-anchor.cert_pem
      identity = {
        issuer = {
          scheme    = "kubernetes.io/tls"
          crtExpiry = local.cert_expiration_date
        }
      }
      proxyInjector = {
        caBundle       = tls_self_signed_cert.linkerd-issuer.cert_pem
        externalSecret = true
      }
      profileValidator = {
        externalSecret = true
        caBundle       = tls_self_signed_cert.linkerd-issuer.cert_pem
      }
    }),
    var.additional_yaml_config
  ]
}

resource "helm_release" "linkerd-viz" {
  depends_on = [helm_release.issuer, helm_release.linkerd]

  count = contains(var.namespaces, "linkerd-viz") ? 1 : 0

  name       = "linkerd-viz"
  chart      = "linkerd-viz"
  repository = var.chart_repository
  version    = var.chart_version
  namespace        = "linkerd-viz"
  create_namespace = false
  timeout    = var.linkerd_helm_install_timeout_secs

  values = [
    yamlencode({
      installNamespace = false
      tap = {
        caBundle       = tls_self_signed_cert.linkerd-issuer.cert_pem
        externalSecret = true
      }
      tapInjector = {
        externalSecret = true
        caBundle       = tls_self_signed_cert.linkerd-issuer.cert_pem
      }
    }),
    var.viz_additional_yaml_config
  ]
}

resource "helm_release" "linkerd-jaeger" {
  depends_on = [helm_release.issuer]

  count = contains(var.namespaces, "linkerd-jaeger") ? 1 : 0

  name       = "linkerd-jaeger"
  chart      = "linkerd-jaeger"
  repository = var.chart_repository
  version    = var.chart_version
  namespace        = "linkerd-jaeger"
  create_namespace = false
  timeout    = var.linkerd_helm_install_timeout_secs

  values = [
    yamlencode({
      installNamespace = false
      webhook = {
        externalSecret = true
        caBundle       = tls_self_signed_cert.linkerd-issuer.cert_pem
      }
    }),
    var.jaeger_additional_yaml_config
  ]
}

# https://artifacthub.io/packages/helm/oauth2-proxy/oauth2-proxy
# https://linkerd.io/2.10/tasks/exposing-dashboard/
# https://blog.donbowman.ca/2019/02/14/using-single-sign-on-oauth2-across-many-sites-in-kubernetes/

resource "helm_release" "oauth2-proxy" {
  depends_on = [kubernetes_secret.oauth2-proxy]

  count = contains(var.namespaces, "linkerd-viz") ? 1 : 0

  name       = "oauth2-proxy"
  chart      = "oauth2-proxy"
  repository = "https://oauth2-proxy.github.io/manifests"
  version    = "6.0.0"
  namespace        = "linkerd-viz"
  create_namespace = false
  timeout    = var.linkerd_helm_install_timeout_secs

  values = [
    yamlencode({
      installNamespace = false
      webhook = {
        externalSecret = true
        caBundle       = tls_self_signed_cert.linkerd-issuer.cert_pem
      }
    }),
    "${file("./charts/oauth2-proxy/values.yaml")}"
  ]
}