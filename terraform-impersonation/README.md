# Terraform Impersonation

An example of using service account impersonation with Terraform.

## Structure

- Create a dedicated folder in Google Cloud for the application
  - Google Cloud projects will be created under this folder
- Service Account (SA) for Terraform
  - Use this SA to execute Terraform operations and manage projects under the folder
  - The SA will have the necessary permissions to create and manage resources within the folder hierarchy

## Reference

- Source of Terraform code:
  - [nownabe/google-cloud-examples](https://github.com/nownabe/google-cloud-examples)
