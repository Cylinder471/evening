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