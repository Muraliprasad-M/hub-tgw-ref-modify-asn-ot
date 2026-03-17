################################################################################
# DR Region Provider
################################################################################

provider "aws" {
  alias  = "dr"
  region = var.secondary_region
}

################################################################################
# DR Transit Gateway
################################################################################

resource "aws_ec2_transit_gateway" "dr" {
  count    = local.dr_create_tgw ? 1 : 0
  provider = aws.dr

  amazon_side_asn                 = var.amazon_side_asn
  auto_accept_shared_attachments  = var.auto_accept_shared_attachments
  default_route_table_association = var.default_route_table_association
  default_route_table_propagation = var.default_route_table_propagation
  dns_support                     = var.dns_support
  vpn_ecmp_support                = var.vpn_ecmp_support
  multicast_support               = var.multicast_support

  tags = merge(
    local.common_tags,
    {
      Name   = "${var.name}-${local.short_dr_region}-tgw"
      Region = "dr"
    }
  )
}

resource "aws_ec2_transit_gateway_route_table" "dr_hub" {
  count    = local.dr_create_tgw ? 1 : 0
  provider = aws.dr

  transit_gateway_id = local.dr_transit_gateway_id

  tags = merge(
    local.common_tags,
    {
      Name   = "${var.name}-${local.short_dr_region}-hub-tgw-rt"
      Region = "dr"
    }
  )
}

resource "aws_ec2_transit_gateway_route_table" "dr_spoke" {
  count    = local.dr_create_tgw ? 1 : 0
  provider = aws.dr

  transit_gateway_id = aws_ec2_transit_gateway.dr[0].id

  tags = merge(
    local.common_tags,
    {
      Name   = "${var.name}-${local.short_dr_region}-spoke-tgw-rt"
      Region = "dr"
    }
  )
}

resource "aws_ec2_transit_gateway_route_table_association" "dr_hub" {
  count    = local.dr_create_tgw ? 1 : 0
  provider = aws.dr

  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.dr[0].id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.dr_hub[0].id
}

resource "aws_ec2_transit_gateway_route" "dr_spoke_default" {
  count    = local.dr_create_tgw ? 1 : 0
  provider = aws.dr

  destination_cidr_block         = "0.0.0.0/0"
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.dr[0].id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.dr_spoke[0].id
}

################################################################################
# DR Transit Gateway VPC Attachment (DR Hub VPC)
################################################################################

resource "aws_ec2_transit_gateway_vpc_attachment" "dr" {
  count    = var.dr_enabled ? 1 : 0
  provider = aws.dr

  transit_gateway_id = local.dr_transit_gateway_id
  vpc_id             = var.dr_vpc_id
  subnet_ids         = var.dr_subnet_ids

  appliance_mode_support                          = var.appliance_mode_support
  transit_gateway_default_route_table_association = false
  transit_gateway_default_route_table_propagation = false

  tags = merge(
    local.common_tags,
    {
      Name   = "${var.name}-vpc-${local.short_dr_region}-tgw-attachment"
      Region = "dr"
    }
  )
}

################################################################################
# DR RAM Resource Share
################################################################################

resource "aws_ram_resource_share" "dr_tgw" {
  count    = var.dr_enabled && var.share_transit_gateway ? 1 : 0
  provider = aws.dr

  name                      = "${var.name}-${local.short_dr_region}-tgw-share"
  allow_external_principals = var.ram_allow_external_principals

  tags = merge(
    local.common_tags,
    {
      Name   = "${var.name}-${local.short_dr_region}-tgw-share"
      Region = "dr"
    }
  )
}

resource "aws_ram_resource_association" "dr_tgw" {
  count    = var.dr_enabled && var.share_transit_gateway ? 1 : 0
  provider = aws.dr

  resource_arn       = local.dr_create_tgw ? aws_ec2_transit_gateway.dr[0].arn : "arn:aws:ec2:${var.secondary_region}:${data.aws_caller_identity.current.account_id}:transit-gateway/${var.dr_transit_gateway_id}"
  resource_share_arn = aws_ram_resource_share.dr_tgw[0].arn
}

resource "aws_ram_principal_association" "dr_tgw" {
  count    = var.dr_enabled && var.share_transit_gateway ? length(var.ram_principals) : 0
  provider = aws.dr

  principal          = var.ram_principals[count.index]
  resource_share_arn = aws_ram_resource_share.dr_tgw[0].arn
}
