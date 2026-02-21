resource "scaleway_object_bucket" "tfstate" {
  name   = "gpu-mig-presentation-tfstate"
  region = var.region
}
