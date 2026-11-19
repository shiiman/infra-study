package main

import (
	"context"
	"database/sql"
	"fmt"
	"net/http"
	"os"
	"time"

	"github.com/gomodule/redigo/redis"
	_ "github.com/googleapis/go-sql-spanner"
	_ "github.com/jackc/pgx/v5/stdlib"
)

// 設定は環境変数から読む
// AWS版はmain.goを直接書き換えてビルドし直していたが、
// 環境変数にしておくと docker run の -e で差し替えられる。
// 第5回のCloud Runでも同じやり方が使える。
func env(key, def string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return def
}

func main() {
	http.HandleFunc("/", handler)
	http.ListenAndServe(":8080", nil)
}

// 接続先は3つあり、それぞれ独立して確かめる(切り替えではなく、全部の結果を出す)
// 接続先の環境変数(DB_HOST・CACHE_HOST・SPANNER_DATABASE)が空のものは、確かめずに「未設定」と出す
//
//	PostgreSQL  ローカルのコンテナ / Cloud SQL
//	Cache       ローカルの Redis コンテナ / Memorystore
//	Spanner     ローカルのエミュレータ / 本物の Cloud Spanner
//
// Spannerはドライバが違うだけで database/sql の使い方は同じ。
// 接続文字列に IP もポートも出てこないのがポイント。
// SPANNER_EMULATOR_HOST があると、ドライバはエミュレータに繋ぐ(コードは変わらない)。

// 接続を確かめるときに待つ時間
const timeout = 5 * time.Second

// 接続できるか確かめる。繋がらないときに、ブラウザを待たせ続けないようにする
// (ドライバによっては、PingContext の時間切れが効かず、リトライし続けるため)
func ping(driver, dsn string) string {
	result := make(chan string, 1)
	go func() {
		db, err := sql.Open(driver, dsn)
		if err != nil {
			result <- "失敗"
			return
		}
		defer db.Close()
		ctx, cancel := context.WithTimeout(context.Background(), timeout)
		defer cancel()
		if err := db.PingContext(ctx); err != nil {
			result <- "失敗"
			return
		}
		result <- "成功"
	}()

	select {
	case r := <-result:
		return r
	case <-time.After(timeout):
		return "失敗"
	}
}

func checkPostgres() string {
	host := env("DB_HOST", "")
	if host == "" {
		return "未設定"
	}
	// sslmode=prefer は、サーバが TLS に対応していれば TLS で、していなければ平文で繋ぐ
	// (ローカルのコンテナは平文、Cloud SQL は TLS)
	dsn := "host=" + host + " port=" + env("DB_PORT", "5432") +
		" user=" + env("DB_USER", "postgres") + " password=" + env("DB_PASS", "") +
		" dbname=" + env("DB_NAME", "test_db") + " sslmode=prefer connect_timeout=5"
	return ping("pgx", dsn)
}

func checkCache() string {
	host := env("CACHE_HOST", "")
	if host == "" {
		return "未設定"
	}
	cache, err := redis.Dial("tcp", host+":"+env("CACHE_PORT", "6379"),
		redis.DialConnectTimeout(timeout))
	if err != nil {
		return "失敗"
	}
	cache.Close()
	return "成功"
}

func checkSpanner() string {
	// projects/<project>/instances/<instance>/databases/<database>
	dsn := env("SPANNER_DATABASE", "")
	if dsn == "" {
		return "未設定"
	}
	return ping("spanner", dsn)
}

func handler(w http.ResponseWriter, r *http.Request) {
	hostname, _ := os.Hostname()

	fmt.Fprintf(w, "Hello, Infra Study\nhostname: %s\nDB接続(PostgreSQL): %s\nCache接続: %s\nSpanner接続: %s\n",
		hostname, checkPostgres(), checkCache(), checkSpanner())
}
