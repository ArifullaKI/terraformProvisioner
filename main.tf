provider "aws" {
  shared_credentials_file = "~/.aws/credentials"
  profile = "default"
  region = "ap-south-1"
}

resource "aws_vpc" "vpc" {
  cidr_block = "${var.cidr_vpc}"
  enable_dns_hostnames = true
  enable_dns_support = true
  tags = {
      "Environment" = "prod"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = "${aws_vpc.vpc.id}"

  tags = {
      "name" = "prod"
      "Environment" = "prod"
  }
}

resource "aws_subnet" "public_subnet" {
  cidr_block = "${var.cidr_subnet}"
  availability_zone = "${var.availability_zone}"
  vpc_id = "${aws_vpc.vpc.id}"
  map_public_ip_on_launch = "true"
  tags = {
      "Environment" = "prod"
  }
}

resource "aws_route_table" "rtb_public" {
  vpc_id = "${aws_vpc.vpc.id}"

  route {
      cidr_block = "0.0.0.0/0"
      gateway_id = "${aws_internet_gateway.igw.id}"
  }
}

resource "aws_route_table_association" "rta_subnet" {
  subnet_id = "${aws_subnet.public_subnet.id}"
  route_table_id = "${aws_route_table.rtb_public.id}"
}

resource "aws_security_group" "sg_22_80" {
  name = "sg_22"
  vpc_id = "${aws_vpc.vpc.id}"

  ingress {
      from_port = 22
      to_port = 22
      protocol = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
      from_port = 80
      to_port = 80
      protocol = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
      from_port = 0
      to_port = 0
      protocol = "-1"
      cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
      "Environment" = "prod"
  }

}

resource "aws_key_pair" "ec2_key" {
  key_name = "publicKey"
  public_key = "${file(var.public_key_path)}"
}

resource "aws_instance" "ec2_instance" {
  instance_type = "t2.micro"
  ami = "ami-09a7bbd08886aafdf"
  subnet_id = "${aws_subnet.public_subnet.id}"
  vpc_security_group_ids = [ "${aws_security_group.sg_22_80.id}" ]
  key_name = "${aws_key_pair.ec2_key.key_name}"
  tags = {
    "Environment" = "Test"
    "name" = "test ec2"
  }

provisioner "remote-exec" {
    inline = [
        "sudo amazon-linux-extras enable nginx1.12",
        "sudo yum -y install nginx",
        "sudo systemctl start nginx", 
    ] 
}
connection {
    type = "ssh"
    user = "ec2-user"
    password = ""
    private_key = "${file("~/.ssh/new1")}"
    host = "${self.public_ip}"
}
}

output "ip" { 
  value = "${aws_instance.ec2_instance.public_ip}"
}
