data "terraform_remote_state" "template" {
  backend = "s3"
  config = {
    key    = "<filename>.tfstate"
    bucket = "<aws-account-number>-terraform-state"
    region = "eu-west-1"
  }
}
