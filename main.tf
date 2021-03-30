
provider "aws" {
  region     = "us-east-1"
  access_key = var.access_key
  secret_key = var.secret_key
}

resource "random_id" "server" {
  keepers = {
    # Generate a new id each time we switch to a new AMI id
    ami_id = var.ami_id
  }

  byte_length = 8
}

resource "aws_vpc" "main" {
  cidr_block = "10.1.0.0/16"
  tags = merge(
	local.common_tags,

	tomap(
	  {"Zoo" = "AWS Zoofarm"
          "RESOURCE" = "aws_vpc"
	  }
	)
	)
  enable_dns_hostnames = true 
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags = merge(
        local.common_tags,

        tomap(
          {"Zoo" = "AWS Zoofarm"
          "RESOURCE" = "internet gateway"
          }
        )
        )
}
resource "aws_subnet" "main" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.1.1.0/24"
  availability_zone = "us-east-1a"
  tags = merge(
        local.common_tags,

        tomap(
          {"Zoo" = "AWS Zoofarm"
          "RESOURCE" = "subnet"
          }
        )
        )
}

resource "aws_route_table" "default" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
  tags = merge(
        local.common_tags,

        tomap(
          {"Zoo" = "AWS Zoofarm"
          "RESOURCE" = "routing table"
          }
        )
        )
}

resource "aws_route_table_association" "main" {
  subnet_id      = aws_subnet.main.id
  route_table_id = aws_route_table.default.id

}

resource "aws_eip" "webserver" {
  instance   = aws_instance.webserver.id
  vpc        = true
  depends_on = [aws_internet_gateway.main]
  tags = merge(
        local.common_tags,

        tomap(
          {"Zoo" = "AWS Zoofarm"
          "RESOURCE" = "eip"
          }
        )
        )
}

resource "aws_key_pair" "terraform_pub_key" {
  key_name   = "craigums-${random_id.server.hex}" 
  public_key = file("~/.ssh/surfkey.pub")
  tags = merge(
        local.common_tags,

        tomap(
          {"Zoo" = "AWS Zoofarm"
          "RESOURCE" = "keypair"
          }
        )
        )
}

data "aws_ami" "ubuntu" {
  most_recent = true
  tags = merge(
        local.common_tags,

        tomap(
          {"Zoo" = "AWS Zoofarm"
          "RESOURCE" = "ubuntu server"
          }
        )
        )
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical

}


resource "aws_instance" "webserver" {
  tags = merge(
        local.common_tags,

        tomap(
          {"Zoo" = "AWS Zoofarm"
          "RESOURCE" = "webserver AMI"
          }
        )
        )
  ami                         = data.aws_ami.ubuntu.id
  availability_zone           = "us-east-1a"
  instance_type               = "t2.micro"
  key_name                    = aws_key_pair.terraform_pub_key.key_name
  vpc_security_group_ids      = [aws_security_group.allowall.id]
  subnet_id                   = aws_subnet.main.id
  associate_public_ip_address = true
  user_data = "${file("install_userdata_ubuntu.sh")}"
#  provisioner "remote-exec" {
#    inline = [
#      "sudo apt update",
#      "sudo apt-get -y install python",
#      "sudo apt-get -y install software-properties-common",
#      "sudo apt-add-repository --yes --update ppa:ansible/ansible",
#      "sudo apt-get -y install ansible",
#      "cd ansible; ansible-playbook -vvv -c local -i \"localhost,\" armor.yml",
#      "sudo apt-get install curl unzip",
#      "sudo apt-get jq"
#    ]

    connection {
      host        = self.public_ip
      type        = "ssh"
      user        = var.ssh_user
      private_key = file(var.private_key_path)
    }
  #}
  #Don't comment out this next line.
}
