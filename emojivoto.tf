resource "kubectl_manifest" "emojivoto-ns" {
depends_on = [local_file.kubeconfig_EKS_Cluster]
yaml_body = <<YAML

apiVersion: v1
kind: Namespace
metadata:
  name: emojivoto
  annotations:
    "linkerd.io/inject" : "enabled"
YAML
}
 
resource "kubectl_manifest" "emojivoto-sa1" {
depends_on = [local_file.kubeconfig_EKS_Cluster,kubectl_manifest.emojivoto-ns ]
yaml_body = <<YAML
apiVersion: v1
kind: ServiceAccount
metadata:
  name: emoji
  namespace: emojivoto
YAML
}

resource "kubectl_manifest" "emojivoto-sa2" {
depends_on = [local_file.kubeconfig_EKS_Cluster,kubectl_manifest.emojivoto-ns]
yaml_body = <<YAML
apiVersion: v1
kind: ServiceAccount
metadata:
  name: voting
  namespace: emojivoto
YAML
}

resource "kubectl_manifest" "emojivoto-sa3" {
depends_on = [local_file.kubeconfig_EKS_Cluster,kubectl_manifest.emojivoto-ns]
yaml_body = <<YAML
apiVersion: v1
kind: ServiceAccount
metadata:
  name: web
  namespace: emojivoto

YAML
}

resource "kubectl_manifest" "emojivoto-svc1" {
depends_on = [local_file.kubeconfig_EKS_Cluster,kubectl_manifest.emojivoto-ns] 
yaml_body = <<YAML
apiVersion: v1
kind: Service
metadata:
  name: emoji-svc
  namespace: emojivoto
spec:
  ports:
  - name: grpc
    port: 8080
    targetPort: 8080
  - name: prom
    port: 8801
    targetPort: 8801
  selector:
    app: emoji-svc

YAML
}

resource "kubectl_manifest" "emojivoto-svc2" {
depends_on = [local_file.kubeconfig_EKS_Cluster,kubectl_manifest.emojivoto-ns]
yaml_body = <<YAML
apiVersion: v1
kind: Service
metadata:
  name: voting-svc
  namespace: emojivoto
spec:
  ports:
  - name: grpc
    port: 8080
    targetPort: 8080
  - name: prom
    port: 8801
    targetPort: 8801
  selector:
    app: voting-svc
YAML
}

resource "kubectl_manifest" "emojivoto-svc3" {
depends_on = [local_file.kubeconfig_EKS_Cluster,kubectl_manifest.emojivoto-ns]
yaml_body = <<YAML
apiVersion: v1
kind: Service
metadata:
  name: web-svc
  namespace: emojivoto
spec:
  ports:
  - name: http
    port: 80
    targetPort: 8080
  selector:
    app: web-svc
  type: ClusterIP
YAML
}

resource "kubectl_manifest" "emojivoto-deploy1" {
depends_on = [local_file.kubeconfig_EKS_Cluster,kubectl_manifest.emojivoto-ns,kubectl_manifest.emojivoto-sa1]
yaml_body = <<YAML
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app.kubernetes.io/name: emoji
    app.kubernetes.io/part-of: emojivoto
    app.kubernetes.io/version: v11
  name: emoji
  namespace: emojivoto
  annotations:
    "linkerd.io/inject" : "enabled"
spec:
  replicas: 1
  selector:
    matchLabels:
      app: emoji-svc
      version: v11
  template:
    metadata:
      labels:
        app: emoji-svc
        version: v11
    spec:
      containers:
      - env:
        - name: GRPC_PORT
          value: "8080"
        - name: PROM_PORT
          value: "8801"
        image: docker.l5d.io/buoyantio/emojivoto-emoji-svc:v11
        name: emoji-svc
        ports:
        - containerPort: 8080
          name: grpc
        - containerPort: 8801
          name: prom
        resources:
          requests:
            cpu: 100m
      serviceAccountName: emoji
YAML
}

resource "kubectl_manifest" "emojivoto-deploy2" {
depends_on = [local_file.kubeconfig_EKS_Cluster,kubectl_manifest.emojivoto-ns]
yaml_body = <<YAML
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app.kubernetes.io/name: vote-bot
    app.kubernetes.io/part-of: emojivoto
    app.kubernetes.io/version: v11
  name: vote-bot
  namespace: emojivoto
  annotations:
    "linkerd.io/inject" : "enabled"
spec:
  replicas: 1
  selector:
    matchLabels:
      app: vote-bot
      version: v11
  template:
    metadata:
      labels:
        app: vote-bot
        version: v11
    spec:
      containers:
      - command:
        - emojivoto-vote-bot
        env:
        - name: WEB_HOST
          value: web-svc.emojivoto:80
        image: docker.l5d.io/buoyantio/emojivoto-web:v11
        name: vote-bot
        resources:
          requests:
            cpu: 10m
YAML
}

resource "kubectl_manifest" "emojivoto-deploy3" {
depends_on = [local_file.kubeconfig_EKS_Cluster,kubectl_manifest.emojivoto-ns,kubectl_manifest.emojivoto-sa2]
yaml_body = <<YAML
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app.kubernetes.io/name: voting
    app.kubernetes.io/part-of: emojivoto
    app.kubernetes.io/version: v11
  name: voting
  namespace: emojivoto
  annotations:
    "linkerd.io/inject" : "enabled"
spec:
  replicas: 1
  selector:
    matchLabels:
      app: voting-svc
      version: v11
  template:
    metadata:
      labels:
        app: voting-svc
        version: v11
    spec:
      containers:
      - env:
        - name: GRPC_PORT
          value: "8080"
        - name: PROM_PORT
          value: "8801"
        image: docker.l5d.io/buoyantio/emojivoto-voting-svc:v11
        name: voting-svc
        ports:
        - containerPort: 8080
          name: grpc
        - containerPort: 8801
          name: prom
        resources:
          requests:
            cpu: 100m
      serviceAccountName: voting
YAML
}

resource "kubectl_manifest" "emojivoto-deploy4" {
depends_on = [local_file.kubeconfig_EKS_Cluster,kubectl_manifest.emojivoto-ns,kubectl_manifest.emojivoto-sa3]
yaml_body = <<YAML
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app.kubernetes.io/name: web
    app.kubernetes.io/part-of: emojivoto
    app.kubernetes.io/version: v11
  name: web
  namespace: emojivoto
  annotations:
    "linkerd.io/inject" : "enabled"
spec:
  replicas: 1
  selector:
    matchLabels:
      app: web-svc
      version: v11
  template:
    metadata:
      labels:
        app: web-svc
        version: v11
    spec:
      containers:
      - env:
        - name: WEB_PORT
          value: "8080"
        - name: EMOJISVC_HOST
          value: emoji-svc.emojivoto:8080
        - name: VOTINGSVC_HOST
          value: voting-svc.emojivoto:8080
        - name: INDEX_BUNDLE
          value: dist/index_bundle.js
        image: docker.l5d.io/buoyantio/emojivoto-web:v11
        name: web-svc
        ports:
        - containerPort: 8080
          name: http
        resources:
          requests:
            cpu: 100m
      serviceAccountName: web
    
YAML
}

    # https://linkerd.io/2.10/tasks/using-ingress/
    # apiVersion: networking.k8s.io/v1beta1 # for k8s < v1.19
resource "kubectl_manifest" "emojivoto-ingress" {
depends_on = [local_file.kubeconfig_EKS_Cluster,kubectl_manifest.emojivoto-ns,kubectl_manifest.emojivoto-svc3]
yaml_body = <<YAML
    apiVersion: networking.k8s.io/v1
    kind: Ingress
    metadata:
      name: emojivoto-web-ingress
      namespace: emojivoto
      annotations:
        nginx.ingress.kubernetes.io/service-upstream: "true"
    spec:
      ingressClassName: nginx
      rules:
      - host: emojivoto.devopsdemos.com
        http:
          paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: web-svc
                port:
                  number: 80

YAML
}