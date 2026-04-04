// This repository is public.
//
// This Terraform configuration is intentionally reduced to a public-safe template.
// Concrete infrastructure definitions and any project-specific identifiers are
// maintained outside git (see https://linear.app/conxian-labs/issue/CON-256).

terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

variable "project_id" {
  description = "GCP project ID (kept outside this public repo)"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "us-central1"
}

provider "google" {
  project = var.project_id
  region  = var.region
}
