resource "aws_secretsmanager_secret" "control_plane_secrets" {
  name        = "control-plane-secrets"
  description = "This secret is created by Terraform, but the value is managed via the bootstrap scripts."

  lifecycle {
    ignore_changes = all
  }
}
