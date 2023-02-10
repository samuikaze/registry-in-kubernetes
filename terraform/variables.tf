variable "kubernetes_path" {
  type = string
  description = "Kubernetes cluster ip or url"
}

variable "app_name" {
  type = string
  description = "Name of registry"
}

variable "namespace_name" {
  type = string
  description = "Name of namespace"
}

variable "image_name" {
  type = string
  description = "Image name"
}

variable "host_port" {
  type = number
  description = "Specific which port should expose"
}

variable "persistent_volume_size" {
  type = string
  description = "Size of persistent volume"
}

variable "repositories_volume_path" {
  type = string
  description = "The full path of repositories"
}

variable "certificates_volume_path" {
  type = string
  description = "The TLS certificates folder path"
}

variable "authorization_volume_path" {
  type = string
  description = "The authorization information folder path"
}
