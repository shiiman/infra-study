# 回答例

## 課題

Webサーバを再起動しても、アプリが自動で立ち上がるようにする。

VMを止めて起動し直すと `Hello, Infra Study` が返らなくなる。
Dockerデーモンもコンテナも自動起動の設定をしていないため。

## 回答

Terraformのコード変更はなし。VMの中での作業。

### 1. Dockerデーモンをブート時に自動起動する

```
# 現在の状態を確認
systemctl is-enabled docker

# 自動起動を有効化
sudo systemctl enable docker

# 確認
systemctl is-enabled docker
```

```
enabled
```

### 2. コンテナに再起動ポリシーを付ける

```
# 動いているコンテナを止めて消す
sudo docker rm -f $(sudo docker ps -aq)

# --restart always を付けて起動し直す
sudo docker run -d -p 80:8080 --restart always app:0.1

# 確認
sudo docker inspect -f '{{.HostConfig.RestartPolicy.Name}}' $(sudo docker ps -q)
```

```
always
```

## 確認方法

VMを再起動して、何もしなくてもアクセスできることを確認する。

```
gcloud compute instances reset [自分の名前]-web --zone=asia-northeast1-a
```

1〜2分待ってから、ブラウザで `https://[自分の名前].[勉強会のドメイン]` にアクセス。

ロードバランサのバックエンドがHEALTHYに戻っていることも確認する。

```
gcloud compute backend-services get-health [自分の名前]-web-bs --global
```

## 本来はどうするか

手でVMに入って `docker run` するのは、この勉強会の説明用の手順。
実務では次のどれかになる。

- 起動スクリプト(metadata の `startup-script`)に書いておく
- コンテナ最適化OS(Container-Optimized OS)の `gce-container-declaration` を使う
- そもそもVMを使わず **Cloud Run** にする(第5回でやります)

第5回でCloud Runをやると「そもそもこの悩みが消える」ことが分かります。

## 参考

- [コンテナを自動的に起動する](https://docs.docker.jp/config/container/start-containers-automatically.html)
- [起動スクリプトの使用](https://cloud.google.com/compute/docs/instances/startup-scripts/linux)
