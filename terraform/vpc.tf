
# Create a VPC

resource "aws_vpc" "main" {
    cidr_block = var.vpc_cidr
    enable_dns_hostnames = true
    enable_dns_support = true
    tags = {
        Name = "${var.project_name}-vpc"
    }
}
#=======================================================================
# create internet gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "${var.project_name}-igw"
  }
}

#=======================================================================

#create subnets
resource "aws_subnet" "public-1" {
    vpc_id = aws_vpc.main.id
    cidr_block = "10.0.1.0/24"
    availability_zone = var.availability_zones[0]
    map_public_ip_on_launch = true

    tags = {
        Name = "${var.project_name}-public-1"
        Tier = "Public"
    }
}
resource "aws_subnet" "public-2" {
    vpc_id = aws_vpc.main.id
    cidr_block = "10.0.2.0/24"
    availability_zone = var.availability_zones[1]
    map_public_ip_on_launch = true
    tags = {
        Name = "${var.project_name}-public-2"
        Tier = "Public"
    }
}

#--------------------this is private subnet 
resource "aws_subnet" "private-app-1" {
    vpc_id = aws_vpc.main.id
    cidr_block = "10.0.11.0/24"
    availability_zone = var.availability_zones[0]
    tags = {
        Name = "${var.project_name}-private-1"
        Tier = "Private-app"
    }
}

resource "aws_subnet" "private-app-2" {
    vpc_id = aws_vpc.main.id
    cidr_block = "10.0.12.0/24"
    availability_zone = var.availability_zones[1]
    tags = {
        Name = "${var.project_name}-private-2"
        Tier = "Private-app"
    }
}

#--------------------this is private DB
resource "aws_subnet" "private-db-1" {
    vpc_id = aws_vpc.main.id
    cidr_block = "10.0.21.0/24"
    availability_zone = var.availability_zones[0]
    tags = {
        Name = "${var.project_name}-private-db-1"
        Tier = "Private-db"
    }
}

resource "aws_subnet" "private-db-2" {
    vpc_id = aws_vpc.main.id
    cidr_block = "10.0.22.0/24"
    availability_zone = var.availability_zones[1]
    tags = {
        Name = "${var.project_name}-private-db-2"
        Tier = "Private-db"
    }
}
#==============================================================================

# creating elactic ip for NAT gateway
resource "aws_eip" "nat-1" {
    #domain = "vpc"
    tags = {
        Name = "${var.project_name}-nat-eip-1"
    }
}
resource "aws_eip" "nat-2" {
    #domain = "vpc"
    tags = {
        Name = "${var.project_name}-nat-eip-2"
    }
}
#==============================================================================
resource "aws_nat_gateway" "nat-1" {
    allocation_id = aws_eip.nat-1.id
    subnet_id = aws_subnet.public-1.id

    tags = {
        Name = "${var.project_name}-nat-1"
    }

    depends_on = [
        aws_internet_gateway.main
    ]
}

resource "aws_nat_gateway" "nat-2" {
    allocation_id = aws_eip.nat-2.id
    subnet_id = aws_subnet.public-2.id

    tags = {
        Name = "${var.project_name}-nat-2"
    }
    depends_on = [
        aws_internet_gateway.main
    ]
}
#==============================================================================
#create route table for public subnet
resource "aws_route_table" "public" {
    vpc_id = aws_vpc.main.id
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.main.id
    }
    tags = {
        Name = "${var.project_name}-public-1"
    }
}

resource "aws_route_table_association" "public-1" {
    subnet_id = aws_subnet.public-1.id
    route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public-2" {
    subnet_id = aws_subnet.public-2.id
    route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private-1" {
    vpc_id = aws_vpc.main.id
    route {
        cidr_block = "0.0.0.0/0"
        nat_gateway_id = aws_nat_gateway.nat-1.id
    }
    tags = {
        Name = "${var.project_name}-private-1"
    }
}

resource "aws_route_table" "private-2" {
    vpc_id = aws_vpc.main.id
    route {
        cidr_block = "0.0.0.0/0"
        nat_gateway_id = aws_nat_gateway.nat-2.id
    }
    tags = {
        Name = "${var.project_name}-private-2"
    }
}

resource "aws_route_table_association" "private-app-1" {
    subnet_id = aws_subnet.private-app-1.id
    route_table_id = aws_route_table.private-1.id
}

resource "aws_route_table_association" "private-app-2" {
    subnet_id = aws_subnet.private-app-2.id
    route_table_id = aws_route_table.private-2.id
}

resource "aws_route_table_association" "private-db-1" {
    subnet_id = aws_subnet.private-db-1.id
    route_table_id = aws_route_table.private-1.id
}

resource "aws_route_table_association" "private-db-2" {
    subnet_id = aws_subnet.private-db-2.id
    route_table_id = aws_route_table.private-2.id
}   
