/**
 * Aplication Loadbalancer
 * https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb
 */
resource "aws_lb" "application_lb" {
  name                       = "${var.user_name}-lb"
  internal                   = false
  load_balancer_type         = "application"
  security_groups            = [resource.aws_security_group.sg_lb.id]
  subnets                    = resource.aws_subnet.subnet_public.*.id

  tags = {
    Name = "${var.user_name}-lb"
  }
}
