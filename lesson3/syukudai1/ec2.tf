/**
 * インスタンス作成
 * https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/instance
 */
resource "aws_instance" "bastion" {
  count         = 1
  ami           = "ami-02c3627b04781eada"
  instance_type = "t2.micro"
  key_name      = "instance_access_key"
  vpc_security_group_ids      = [resource.aws_security_group.sg_bastion.id]
  subnet_id                   = resource.aws_subnet.subnet_public.*.id[count.index % length(resource.aws_subnet.subnet_public.*.id)]
  associate_public_ip_address = true

  tags = {
    Name = format("${var.user_name}-bastion%04d", count.index + 1)
  }

  volume_tags = {
    Name = "${format("${var.user_name}-bastion%04d", count.index + 1)}-ebs"
  }
}

resource "aws_instance" "private_instance" {
  count         = 1
  ami           = "ami-02c3627b04781eada"
  instance_type = "t2.micro"
  key_name      = "instance_access_key"
  vpc_security_group_ids      = [resource.aws_security_group.sg_private_instance.id]
  subnet_id                   = resource.aws_subnet.subnet_private.*.id[count.index % length(resource.aws_subnet.subnet_private.*.id)]
  associate_public_ip_address = false

  tags = {
    Name = format("${var.user_name}-private-instance%04d", count.index + 1)
  }

  volume_tags = {
    Name = "${format("${var.user_name}-private-instance%04d", count.index + 1)}-ebs"
  }
}
