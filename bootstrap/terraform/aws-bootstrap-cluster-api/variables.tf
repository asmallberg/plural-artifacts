variable "aws_region" {
  type = string
  default = "us-east-2"
  description = "The region you wish to deploy to"
}

variable "cluster_name" {
  type = string
  default = "plural"
}

variable "capa_serviceaccount" {
  type = string
  default = "capa-controller-manager"
}
