# 回答例

## カスタムAMI作成

```
aws ec2 create-image --instance-id [EC2インスタンスID] --name [名前]_ami --reboot
```

## 作成したイメージを使用してEC2インスタンスを作成し、ターゲットグループにアタッチ
