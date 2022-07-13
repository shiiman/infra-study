# 回答例

## Dockerをブート時に自動起動にする

```
# 確認
systemctl list-unit-files --type=service

# 自動起動on
sudo systemctl enable docker

# 確認
systemctl list-unit-files --type=service
```

## Dockerコンテナの自動起動ポリシーを指定してアプリケーションを再起動

```
docker run -d -p 80:8080 --restart always app:0.1
```

## 参考

ドキュメント[https://docs.docker.jp/v19.03/config/container/start-containers-automatically.html]
