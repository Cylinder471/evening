resource "helm_release" "ingress-nginx" {
  name             = "ingress-nginx"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  namespace        = "ingress-nginx"
  create_namespace = true
  version          = "4.10.0"
  values           = [file("./nginx.yaml")]
}
data "kubernetes_service" "ingress_nginx" {
  metadata {
    name      = "ingress-nginx-controller"
    namespace = "ingress-nginx"
  }

  depends_on = [helm_release.ingress-nginx]
}
output "ingress_nginx_load_balancer_hostname" {
  value = data.kubernetes_service.ingress_nginx.status[0].load_balancer[0].ingress[0].hostname
}

resource "helm_release" "my_app" {
  name             = "my-app"
  chart            = "./Chart" # путь к локальному чарту
  namespace        = "default"
  create_namespace = false

  depends_on = [helm_release.ingress-nginx]
}
resource "helm_release" "loki" {
  name       = "loki"  # Имя релиза в Kubernetes
  repository = "https://grafana.github.io/helm-charts"  # Официальный репозиторий
  chart      = "loki"  # Название чарта
  version    = "5.41.0"  # Конкретная версия чарта (рекомендуется фиксировать)
  namespace  = "monitoring"  # Namespace для установки
  create_namespace = true  # Создать namespace если не существует
  atomic     = true  # Откатывать изменения при ошибке
  timeout    = 600  # Таймаут установки (секунды)

  # Используем предварительно созданный файл с базовыми значениями
  values = [
    file("${path.module}/loki-values.yaml")
  ]

  # Динамическая подстановка ARN роли для доступа к S3
  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.loki_irsa.iam_role_arn
  }

  # Передаем полную конфигурацию Loki из отдельного файла
  set {
    name  = "loki.config"
    value = file("${path.module}/loki-config.yaml")
  }

  # Дополнительные параметры можно установить через set
  set {
    name  = "persistence.enabled"
    value = "true"
  }

  set {
    name  = "persistence.size"
    value = "10Gi"
  }

  set {
    name  = "resources.requests.memory"
    value = "512Mi"
  }

  set {
    name  = "resources.requests.cpu"
    value = "500m"
  }

  set {
    name  = "resources.limits.memory"
    value = "1Gi"
  }

  # Зависимости (если есть)
  depends_on = [
    helm_release.ingress-nginx,
    module.loki_irsa
  ]
}
resource "helm_release" "grafana" {
  name       = "grafana"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "grafana"
  version    = "7.3.0" # Проверьте актуальную версию
  namespace  = "monitoring"

  set {
    name  = "service.type"
    value = "ClusterIP"
  }

  set {
    name  = "ingress.enabled"
    value = "true"
  }

  set {
    name  = "ingress.ingressClassName"
    value = "nginx"
  }

  set {
    name  = "ingress.annotations.nginx\\.ingress\\.kubernetes\\.io/rewrite-target"
    value = "/$2"
  }

  set {
    name  = "ingress.path"
    value = "/grafana(/|$)(.*)"
  }

  set {
    name  = "env.GF_SERVER_ROOT_URL"
    value = "/grafana"
  }

  set {
    name  = "env.GF_SERVER_SERVE_FROM_SUB_PATH"
    value = "true"
  }

  set {
    name  = "datasources.datasources\\.yaml\\.apiVersion"
    value = "1"
  }

  set {
    name  = "datasources.datasources\\.yaml\\.datasources[0].name"
    value = "Loki"
  }

  set {
    name  = "datasources.datasources\\.yaml\\.datasources[0].type"
    value = "loki"
  }

  set {
    name  = "datasources.datasources\\.yaml\\.datasources[0].url"
    value = "http://loki:3100"
  }

  set {
    name  = "datasources.datasources\\.yaml\\.datasources[0].access"
    value = "proxy"
  }

  depends_on = [helm_release.loki]
}
