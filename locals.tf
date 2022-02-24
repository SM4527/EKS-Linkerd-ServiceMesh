locals {
  env = "${terraform.workspace}"

  # set certification expiration date for the number of hours specified
  cert_expiration_date = timeadd(time_static.cert_create_time.rfc3339, "${var.ca_cert_expiration_hours}h")

  region_map = {
    default = "us-east-1"
  }
 
  region = "${lookup(local.region_map, local.env)}"

  kubeconfig = yamlencode({
    apiVersion      = "v1"
    kind            = "Config"
    current-context = "${var.AWS_PROFILE}"
    clusters = [{
      name = data.terraform_remote_state.eks.outputs.EKS_cluster_id
      cluster = {
        certificate-authority-data = data.terraform_remote_state.eks.outputs.EKS_cluster_CA_data
        server                     = data.terraform_remote_state.eks.outputs.EKS_cluster_endpoint
      }
    }]
    contexts = [{
      name = "${var.AWS_PROFILE}"
      context = {
        cluster = data.terraform_remote_state.eks.outputs.EKS_cluster_id
        user    = "${var.AWS_PROFILE}"
      }
    }]
    users = [{
      name = "${var.AWS_PROFILE}"
      user = {
        exec = {
          apiVersion = "client.authentication.k8s.io/v1alpha1"
          args        = ["--region","${local.region}","eks", "get-token", "--cluster-name", data.terraform_remote_state.eks.outputs.EKS_cluster_name ]
          command     = "aws"
          env = [{
            "name" = "AWS_PROFILE"
            "value" = "${var.AWS_PROFILE}"
          }]
        }
      }
    }]
  })
  
}