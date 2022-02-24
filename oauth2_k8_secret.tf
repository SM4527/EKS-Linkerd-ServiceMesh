resource "kubernetes_secret" "oauth2-proxy" {
  depends_on = [kubernetes_namespace.namespace]
  metadata {
    name = "oauth2-proxy"
    namespace        = "linkerd-viz"
  }

  data = {
    client-id = var.clientID
    client-secret = var.clientSecret
    cookie-secret = var.cookieSecret
  }

  type = "Opaque"
}