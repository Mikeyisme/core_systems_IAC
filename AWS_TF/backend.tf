terraform {
  backend "s3" {
    bucket       = "my-dev-terraform-bucket1"
    key          = "dev/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
    encrypt      = true
  }
}