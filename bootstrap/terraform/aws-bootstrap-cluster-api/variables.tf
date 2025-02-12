variable "aws_region" {
  type = string
  default = "us-east-2"
  description = "The region you wish to deploy to"
}

variable "cluster_name" {
  type = string
  default = "plural"
}