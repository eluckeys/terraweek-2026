resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  tags = { Name = "tws-vpc" }

  lifecycle {
    prevent_destroy = false
  }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true
  tags = { Name = "tws-public-subnet" }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "tws-igw" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = { Name = "tws-public-rt" }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_security_group" "web" {
  name   = "tws-web-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "tws-web-sg" }
}

# count example — N identical instances
resource "aws_instance" "web" {
  count                  = var.instance_count
  ami                    = data.aws_ami.al2023.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.web.id]
  depends_on              = [aws_route_table_association.public]

  lifecycle {
    create_before_destroy = true
    ignore_changes         = [tags["LastModified"]]
  }

  tags = { Name = "tws-web-${count.index}" }
}

# for_each example — named, stable-identity resources
resource "aws_instance" "named" {
  for_each                = var.named_instances
  ami                     = data.aws_ami.al2023.id
  instance_type           = each.value
  subnet_id               = aws_subnet.public.id
  vpc_security_group_ids  = [aws_security_group.web.id]
  depends_on              = [aws_route_table_association.public]

  tags = { Name = "tws-${each.key}" }
}
