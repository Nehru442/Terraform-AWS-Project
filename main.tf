variable "cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

resource "aws_vpc" "myvpc" {
  cidr_block = var.cidr
}

resource "aws_subnet" "subnet1" {
    vpc_id = aws_vpc.myvpc.id
    cidr_block = "10.0.0.0/24"
    availability_zone = "ap-south-1a"
    map_public_ip_on_launch = true
}

resource "aws_subnet" "subnet2" {
    vpc_id = aws_vpc.myvpc.id
    cidr_block = "10.0.1.0/24"
    availability_zone = "ap-south-1b"
    map_public_ip_on_launch = true
}

resource "aws_internet_gateway" "myigw" {
    vpc_id = aws_vpc.myvpc.id
}

resource "aws_route_table" "myroute" {
    vpc_id = aws_vpc.myvpc.id

    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.myigw.id
    }
}

resource "aws_route_table_association" "a" {
    subnet_id = aws_subnet.subnet1.id
    route_table_id = aws_route_table.myroute.id
}

resource "aws_route_table_association" "b" {
    subnet_id = aws_subnet.subnet2.id
    route_table_id = aws_route_table.myroute.id
}

resource aws_security_group "mysecuritygroup" {
    name        = "my-security-group"
    vpc_id      = aws_vpc.myvpc.id

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
     
     tags = {
        Name = "my-security-group"
    }
}   

resource "aws_s3_bucket" "mybucket" {
  bucket = "my-terraform-venkat-bucket-project"
}

resource "aws_s3_bucket_public_access_block" "mybucket_public_access_block" {
  bucket = aws_s3_bucket.mybucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_instance" "myec2" {
  ami           = "ami-006f82a1d5a27da54"
  instance_type = "t3.micro"
  vpc_security_group_ids = [aws_security_group.mysecuritygroup.id]
  subnet_id = aws_subnet.subnet1.id
  user_data = base64encode(file("userdata.sh"))
}

resource "aws_instance" "myec2_2" {
  ami           = "ami-006f82a1d5a27da54"
  instance_type = "t3.micro"
  vpc_security_group_ids = [aws_security_group.mysecuritygroup.id]
  subnet_id = aws_subnet.subnet2.id
  user_data = base64encode(file("userdata1.sh"))
}

resource aws_lb "myloadbalancer" {
  name               = "my-load-balancer"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.mysecuritygroup.id]
  subnets            = [aws_subnet.subnet1.id, aws_subnet.subnet2.id]

  tags = {
    Name = "my-load-balancer"
  }
}

resource "aws_lb_target_group" "mytargetgroup" {
  name     = "my-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.myvpc.id

  health_check {
    path  = "/"
    port  = "traffic-port"
  }
}

resource "aws_lb_target_group_attachment" "mytargetgroupattachment1" {
  target_group_arn = aws_lb_target_group.mytargetgroup.arn
  target_id        = aws_instance.myec2.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "mytargetgroupattachment2" {
  target_group_arn = aws_lb_target_group.mytargetgroup.arn
  target_id        = aws_instance.myec2_2.id
  port             = 80
}

resource "aws_lb_listener" "mylistener" {
  load_balancer_arn = aws_lb.myloadbalancer.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.mytargetgroup.arn
  }
}

output "load_balancer_dns_name" {
  value = aws_lb.myloadbalancer.dns_name
}