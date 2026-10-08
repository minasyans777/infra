# VAULT_ADDR and VAULT_TOKEN are read from the environment (not variables here) so
# neither ever needs to be written to a .tf/.tfvars file. See
# ../documentation/bootstrap-and-unseal.md for what token to use on the first apply
# vs. subsequent ones.
provider "vault" {}
