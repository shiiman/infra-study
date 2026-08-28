# 回答例

## 課題

ライフサイクルルールを設定し、古いファイルが自動削除されることを確認する。

## 回答

`storage.tf` を参照。3つのルールを入れている。

```hcl
// 3世代より古い版を削除
lifecycle_rule {
  condition {
    num_newer_versions = 3
    with_state         = "ARCHIVED"
  }
  action {
    type = "Delete"
  }
}

// 7日より古い版を削除
lifecycle_rule {
  condition {
    days_since_noncurrent_time = 7
    with_state                 = "ARCHIVED"
  }
  action {
    type = "Delete"
  }
}

// 30日経った現行版を NEARLINE に移す
lifecycle_rule {
  condition {
    age        = 30
    with_state = "LIVE"
  }
  action {
    type          = "SetStorageClass"
    storage_class = "NEARLINE"
  }
}
```

## ポイント: with_state

| 値 | 意味 |
|---|---|
| `LIVE` | 現行版 |
| `ARCHIVED` | バージョニングで残った古い版 |
| `ANY` | 両方 |

**指定を間違えると現行版が消える。** バージョニングと組で使うときは
`ARCHIVED` を明示すること。

## ポイント: アクションの種類

| type | 内容 |
|---|---|
| `Delete` | 削除する |
| `SetStorageClass` | ストレージクラスを変える(安いクラスへ移す) |
| `AbortIncompleteMultipartUpload` | 中断したアップロードを片付ける |

「30日でNEARLINE、90日でCOLDLINE、365日で削除」のように
段階的にコストを下げるのが定番。

## 確認方法

```
terraform apply

gcloud storage buckets describe gs://[バケット名] --format="yaml(lifecycle_config)"
```

★ フィールド名は `lifecycle_config`。`lifecycle` を指定すると null になる。

```yaml
lifecycle_config:
  rule:
  - action: {type: Delete}
    condition: {isLive: false, numNewerVersions: 3}
  - action: {type: Delete}
    condition: {daysSinceNoncurrentTime: 7, isLive: false}
  - action: {storageClass: NEARLINE, type: SetStorageClass}
    condition: {age: 30, isLive: true}
```

Terraform の `with_state = "ARCHIVED"` は、APIでは `isLive: false` になる。

### 動作を確認する

**ライフサイクルは即時に実行されない。** Google側が1日1回程度まとめて処理する。

講義中に確認したい場合は `num_newer_versions = 1` にして、
index.html を3回ほど上書きしてから翌日確認する。

```
# 何度か上書き
terraform apply    # version を書き換えるたびに

# 世代を確認
gcloud storage ls --all-versions gs://[バケット名]/static/index.html | wc -l

# 翌日、古い版が消えていることを確認
```

## AWSとの違い

考え方はほぼ同じ。書き方が少し違う。

| | S3 | Cloud Storage |
|---|---|---|
| リソース | `aws_s3_bucket_lifecycle_configuration`(別リソース) | `lifecycle_rule`(バケットの属性) |
| 現行/非現行 | `noncurrent_version_expiration` など別ブロック | `with_state` で指定 |
| ストレージクラス移行 | `transition` | `SetStorageClass` |

## 参考

- [オブジェクトのライフサイクル管理](https://cloud.google.com/storage/docs/lifecycle)
- [ストレージクラス](https://cloud.google.com/storage/docs/storage-classes)
