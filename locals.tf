locals {
  # Helper: convert region to short form
  # eu-west-1a -> euw1a | eu-west-2 -> euw2
  short_region    = replace(var.primary_region, "/^([a-z]{2})-([a-z])[a-z]+-([0-9]+)([a-z]?)$/", "$1$2$3$4")
  short_dr_region = replace(var.secondary_region, "/^([a-z]{2})-([a-z])[a-z]+-([0-9]+)([a-z]?)$/", "$1$2$3$4")

  # Common tags applied to all resources
  common_tags = merge(
    var.tags,
    {
      Environment   = var.environment
      ManagedBy     = "terraform"
      Module        = "transit-gateway"
      ModuleVersion = local.module_version
    }
  )

  # Resolve Transit Gateway IDs
  create_tgw         = var.create_transit_gateway
  transit_gateway_id = local.create_tgw ? aws_ec2_transit_gateway.this[0].id : var.transit_gateway_id

  # DR Transit Gateway ID resolution
  dr_create_tgw         = var.dr_enabled && var.create_transit_gateway
  dr_transit_gateway_id = var.dr_enabled ? (var.create_transit_gateway ? aws_ec2_transit_gateway.dr[0].id : var.dr_transit_gateway_id) : ""
}
