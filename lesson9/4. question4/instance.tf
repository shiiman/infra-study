resource "aws_security_group" "sg_web" {
  name   = "${var.user_name}-web-sg"
  vpc_id = resource.aws_vpc.vpc.id

  tags = {
    Name = "${var.user_name}-web-sg"
  }
}

resource "aws_instance" "private_instance" {
  count                       = 2
  ami                         = "ami-01eccbfa7be1cfaec"
  instance_type               = "t2.micro"
  vpc_security_group_ids      = [resource.aws_security_group.sg_web.id]
  subnet_id                   = resource.aws_subnet.subnet_private.*.id[count.index % length(resource.aws_subnet.subnet_private.*.id)]
  associate_public_ip_address = false

  tags = {
    Name = format("${var.user_name}-web%1d", count.index + 1)
  }

  volume_tags = {
    Name = "${format("${var.user_name}-web%1d", count.index + 1)}-ebs"
  }
}
