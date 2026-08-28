# 回答例

## 課題

Cloud Storage にバージョニングを設定し、上書きしても前の版が残ることを確認する。

## 回答

`storage.tf` を参照。

```hcl
resource "google_storage_bucket" "static" {
  versioning {
    enabled = true
  }
}
```

## 確認方法

```
terraform apply
```

### 現在の版を確認

```
gcloud storage ls --all-versions --long gs://[バケット名]/static/index.html
```

### ファイルを更新する

`static/index.html` の `version: 1` を `version: 2` に書き換えて apply。

```
terraform apply
```

### 世代が2つになっていることを確認

```
gcloud storage ls --all-versions --long gs://[バケット名]/static/index.html
```

```
  341  2026-01-18T10:00:00Z  gs://.../static/index.html#1768730400000000
  341  2026-01-18T10:05:00Z  gs://.../static/index.html#1768730700000000
```

`#` のあとの数字が**世代番号(generation)**。

### 古い版を取り出す

```
gcloud storage cp gs://[バケット名]/static/index.html#1768730400000000 ./old.html
cat old.html
```

`version: 1` のままの内容が取れる。

### 古い版に戻す

```
gcloud storage cp gs://[バケット名]/static/index.html#1768730400000000 \
  gs://[バケット名]/static/index.html
```

## AWSとの違い

| | S3 | Cloud Storage |
|---|---|---|
| 有効化 | バケットのバージョニング設定 | `versioning { enabled = true }` |
| 版の識別 | バージョンID(文字列) | 世代番号(数値のタイムスタンプ) |
| 指定方法 | `--version-id xxx` | `オブジェクト名#世代番号` |
| 古い版の状態 | 非現行バージョン | ARCHIVED |

AWS版の宿題では「クエリストリングにバージョン情報を付与してアクセス」となっていたが、
これは CloudFront にクエリストリングを転送する設定が別途必要で手順が複雑だった。

GCPは `gcloud storage` から世代番号で直接取れるので、そこは簡単。

## 注意

**バージョニングを有効にすると、古い版も課金対象になる。**
放っておくと増え続けるので、ライフサイクルルールとセットで使う(宿題2)。

## 参考

- [オブジェクトのバージョニング](https://cloud.google.com/storage/docs/object-versioning)
