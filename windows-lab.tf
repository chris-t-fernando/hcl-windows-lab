provider "aws" {
  profile = "default"
  region  = "ap-southeast-2"
}

data "aws_vpc" "landing_zone" {
  filter {
    name   = "tag:landing_zone"
    values = ["true"]
  }
}

data "aws_route_tables" "landing_zone_route" {
  vpc_id = data.aws_vpc.landing_zone.id
}

resource "aws_vpc" "windows_lab" {
  cidr_block = "10.0.0.0/16"

  tags = {
    project = "windows-lab"
  }
}

resource "aws_vpc_peering_connection" "vpc_peering" {
  vpc_id      = aws_vpc.windows_lab.id
  peer_vpc_id = data.aws_vpc.landing_zone.id
  auto_accept = true
}

resource "aws_subnet" "public_subnets" {
  count             = length(var.public_subnet_cidrs)
  vpc_id            = aws_vpc.windows_lab.id
  cidr_block        = element(var.public_subnet_cidrs, count.index)
  availability_zone = element(var.azs, count.index)

  tags = {
    Name = "Public Subnet ${count.index + 1}"
  }
}

resource "aws_subnet" "private_subnets" {
  count             = length(var.private_subnet_cidrs)
  vpc_id            = aws_vpc.windows_lab.id
  cidr_block        = element(var.private_subnet_cidrs, count.index)
  availability_zone = element(var.azs, count.index)

  tags = {
    Name = "Private Subnet ${count.index + 1}"
  }
}

resource "aws_route" "landing_zone_to_windows_lab_routes" {
  count                     = length(data.aws_route_tables.landing_zone_route.ids)
  route_table_id            = data.aws_route_tables.landing_zone_route.ids[count.index]
  destination_cidr_block    = aws_vpc.windows_lab.cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.vpc_peering.id
}


resource "aws_route" "windows_lab_routes_to_landing_zone" {
  route_table_id            = aws_vpc.windows_lab.default_route_table_id
  destination_cidr_block    = data.aws_vpc.landing_zone.cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.vpc_peering.id
}


resource "aws_route" "windows_lab_routes_default_route" {
  route_table_id            = aws_vpc.windows_lab.default_route_table_id
  destination_cidr_block    = "0.0.0.0/0"
  vpc_peering_connection_id = aws_vpc_peering_connection.vpc_peering.id
}

/*
resource "aws_route_tables" "internet_routetable" {
  vpc_id = aws_vpc.windows_lab.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
}
*/


# output

output "vpc_peering_connection_id" {
  description = "Connection Id of VPC Peering"
  value       = aws_vpc_peering_connection.vpc_peering.id
}
