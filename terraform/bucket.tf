resource "scaleway_object_bucket" "tfstate" {
  name   = "gpu-mig-presentation-tfstate"
  region = var.region
}

import {
  id = "fr-par/gpu-mig-presentation-tfstate"
  to = scaleway_object_bucket.tfstate
}
