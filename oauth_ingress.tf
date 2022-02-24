resource "kubectl_manifest" "linkerd_ingress" {

depends_on = [kubernetes_namespace.namespace]
  
yaml_body = <<YAML
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: web
  namespace: linkerd-viz
  annotations:
    nginx.ingress.kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/upstream-vhost: $service_name.$namespace.svc.cluster.local:8084   
    nginx.ingress.kubernetes.io/configuration-snippet: |
      proxy_set_header Origin "";
      proxy_hide_header l5d-remote-ip;
      proxy_hide_header l5d-server-id;    
    #nginx.ingress.kubernetes.io/auth-url: https://$host/oauth2/auth  
    #nginx.ingress.kubernetes.io/auth-signin: "https://$host/oauth2/start?rd=$escaped_request_uri"
    #nginx.ingress.kubernetes.io/auth-signin: https://$host/oauth2/start?rd=https%3A%2F%2F$host$request_uri
    #nginx.ingress.kubernetes.io/auth-url: http://oauth2-proxy.linkerd-viz.svc.cluster.local:4180/oauth2/auth
spec:
  ingressClassName: nginx
  rules:
  - host: linkerd.devopsdemos.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: web
            port:
              number: 8084
YAML
}


resource "kubectl_manifest" "oauth2_ingress" {

depends_on = [kubernetes_namespace.namespace]
  
yaml_body = <<YAML
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: oauth2-proxy
  namespace: linkerd-viz
  annotations:
    nginx.ingress.kubernetes.io/ingress.class: nginx
spec:
  ingressClassName: nginx
  rules:
  - host: linkerd.devopsdemos.com
    http:
      paths:
      - path: /oauth2
        pathType: Prefix
        backend:
          service:
            name: oauth2-proxy
            port:
              number: 80
YAML
}