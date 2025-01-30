resource "aws_vpc" "tg-test-VPC" {
  tags                 = merge(var.tags, { Name = "tg-test-VPC" })
  enable_dns_support   = true
  enable_dns_hostnames = true
  cidr_block           = "10.0.0.0/16"
}

resource "aws_internet_gateway" "alb-test-IGW" {
  vpc_id = aws_vpc.tg-test-VPC.id
  tags   = merge(var.tags, { Name = "alb-test-IGW" })
}

resource "aws_route_table" "public-rt" {
  vpc_id = aws_vpc.tg-test-VPC.id
  tags   = merge(var.tags, { Name = "public-rt" })

  route {
    gateway_id = aws_internet_gateway.alb-test-IGW.id
    cidr_block = "0.0.0.0/0"
  }
}

resource "aws_subnet" "public_snet" {
  vpc_id            = aws_vpc.tg-test-VPC.id
  tags              = merge(var.tags, { Name = "public_snet" })
  cidr_block        = "10.0.1.0/24"
  availability_zone = "eu-west-1a"
}

resource "aws_route_table_association" "public_rt_association" {
  subnet_id      = aws_subnet.public_snet.id
  route_table_id = aws_route_table.public-rt.id
}

resource "aws_instance" "web-1a" {
  user_data                   = <<EOT
#!/bin/bash
# Use this for your user data (script from top to bottom)
# install httpd (Linux 2 version) 
yum update -y
yum install -y httpd
systemctl start httpd
systemctl enable httpd
echo "<h1>Hello World from $(hostname -f)</h1>" > /var/www/html/index.html
EOT
  tags                        = merge(var.tags, { Name = "web-1a" })
  subnet_id                   = aws_subnet.public_snet.id
  key_name                    = "MyKeyPair"
  instance_type               = "t2.micro"
  associate_public_ip_address = true
  ami                         = "ami-0a094c309b87cc107"

  vpc_security_group_ids = [
    aws_security_group.web-sg.id,
  ]
}

resource "aws_security_group" "web-sg" {
  vpc_id = aws_vpc.tg-test-VPC.id
  tags   = merge(var.tags, { Name = "Web-sg" })

  egress {
    to_port     = 0
    protocol    = "-1"
    from_port   = 0
    description = "Allow all out"
    cidr_blocks = [
      "0.0.0.0/0",
    ]
  }

  ingress {
    to_port     = 22
    protocol    = "tcp"
    from_port   = 22
    description = "Allow SSH"
    cidr_blocks = [
      "0.0.0.0/0",
    ]
  }
  ingress {
    to_port     = -1
    protocol    = "icmp"
    from_port   = -1
    description = "Allow ICMP"
    cidr_blocks = [
      "0.0.0.0/0",
    ]
  }
  ingress {
    to_port     = 80
    protocol    = "tcp"
    from_port   = 80
    description = "Allow HTTP"
    cidr_blocks = [
      "0.0.0.0/0",
    ]
  }
}

resource "aws_subnet" "public_snet2" {
  vpc_id            = aws_vpc.tg-test-VPC.id
  tags              = merge(var.tags, { Name = "public_snet" })
  cidr_block        = "10.0.2.0/24"
  availability_zone = "eu-west-1b"
}

resource "aws_route_table_association" "public_rt_association2" {
  subnet_id      = aws_subnet.public_snet2.id
  route_table_id = aws_route_table.public-rt2.id
}

resource "aws_instance" "web-1b" {
  user_data                   = <<EOT
#!/bin/bash
# Use this for your user data (script from top to bottom)
# install httpd (Linux 2 version) 
yum update -y
yum install -y httpd
systemctl start httpd
systemctl enable httpd
echo "<h1>Hello World from $(hostname -f)</h1>" > /var/www/html/index.html
EOT
  tags                        = merge(var.tags, { Name = "web-1b" })
  subnet_id                   = aws_subnet.public_snet2.id
  key_name                    = "MyKeyPair"
  instance_type               = "t2.micro"
  associate_public_ip_address = true
  ami                         = "ami-0a094c309b87cc107"

  vpc_security_group_ids = [
    aws_security_group.web-sg.id,
  ]
}

resource "aws_route_table" "public-rt2" {
  vpc_id = aws_vpc.tg-test-VPC.id
  tags   = merge(var.tags, { Name = "public-rt" })

  route {
    gateway_id = aws_internet_gateway.alb-test-IGW.id
    cidr_block = "0.0.0.0/0"
  }
}

resource "aws_lb" "test-alb" {
  tags               = merge(var.tags, { Name = "test-alb" })
  load_balancer_type = "application"

  security_groups = [
    aws_security_group.alb-sg.id,
  ]

  subnets = [
    aws_subnet.public_snet.id,
    aws_subnet.public_snet2.id,
  ]
}

resource "aws_lb_target_group" "alb_target_group" {
  vpc_id           = aws_vpc.tg-test-VPC.id
  target_type      = "instance"
  tags             = merge(var.tags, {})
  protocol_version = "HTTP1"
  protocol         = "HTTP"
  port             = 80

  health_check {
    port = "80"
    path = "/"
  }
}

resource "aws_lb_listener" "alb_listener" {
  tags              = merge(var.tags, {})
  port              = 80
  load_balancer_arn = aws_lb.test-alb.arn

  default_action {
    type = "forward"
    forward {
      target_group {
        arn = aws_lb_target_group.alb_target_group.arn
      }
    }
  }
}

resource "aws_security_group" "alb-sg" {
  vpc_id = aws_vpc.tg-test-VPC.id
  tags   = merge(var.tags, { Name = "alb-sg" })

  egress {
    to_port     = 0
    protocol    = "-1"
    from_port   = 0
    description = "Allow all out"
    cidr_blocks = [
      "0.0.0.0/0",
    ]
  }

  ingress {
    to_port     = 80
    protocol    = "tcp"
    from_port   = 80
    description = "Allow HTTP"
    cidr_blocks = [
      "0.0.0.0/0",
    ]
  }
}

resource "aws_lb_target_group_attachment" "lb_target_group_attachment" {
  target_id        = aws_instance.web-1a.id
  target_group_arn = aws_lb_target_group.alb_target_group.arn
}

resource "aws_lb_target_group_attachment" "lb_target_group_attachment2" {
  target_id        = aws_instance.web-1b.id
  target_group_arn = aws_lb_target_group.alb_target_group.arn
}

