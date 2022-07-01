/**
 * インスタンス作成
 * https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/instance
 */
resource "aws_instance" "web_instance" {
  count                       = 1
  ami                         = "ami-02c3627b04781eada"
  instance_type               = "t2.micro"
  vpc_security_group_ids      = [resource.aws_security_group.sg_web_instance.id]
  subnet_id                   = resource.aws_subnet.subnet_web.*.id[count.index % length(resource.aws_subnet.subnet_web.*.id)]
  associate_public_ip_address = false

  tags = {
    Name = format("${var.user_name}-web-instance%04d", count.index + 1)
  }

  volume_tags = {
    Name = "${format("${var.user_name}-web-instance%04d", count.index + 1)}-ebs"
  }
}
