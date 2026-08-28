package main

import (
	"database/sql"
	"fmt"
	"net/http"
	"os"

	_ "github.com/go-sql-driver/mysql"
	_ "github.com/googleapis/go-sql-spanner"
	"github.com/gomodule/redigo/redis"
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

// DB_KIND で接続先の種類を切り替える
//
//	mysql   ローカルのMySQLコンテナ / Cloud SQL
//	spanner Cloud Spanner
//
// Spannerはドライバが違うだけで database/sql の使い方は同じ。
// 接続文字列に IP もポートも出てこないのがポイント。
func openDB() (*sql.DB, string) {
	switch env("DB_KIND", "mysql") {
	case "spanner":
		// projects/<project>/instances/<instance>/databases/<database>
		return openSpanner(env("SPANNER_DATABASE", ""))
	default:
		return openMySQL()
	}
}

func openSpanner(dsn string) (*sql.DB, string) {
	db, err := sql.Open("spanner", dsn)
	if err != nil {
		return nil, "Spanner"
	}
	return db, "Spanner"
}

func openMySQL() (*sql.DB, string) {
	dsn := env("DB_USER", "root") + ":" + env("DB_PASS", "") +
		"@tcp(" + env("DB_HOST", "db") + ":" + env("DB_PORT", "3306") + ")/" +
		env("DB_NAME", "test_db") + "?charset=utf8mb4"
	db, err := sql.Open("mysql", dsn)
	if err != nil {
		return nil, "MySQL"
	}
	return db, "MySQL"
}

func handler(w http.ResponseWriter, r *http.Request) {
	hostname, _ := os.Hostname()

	dbStat := "成功"
	db, kind := openDB()
	if db == nil {
		dbStat = "失敗"
	} else {
		defer db.Close()
		if err := db.Ping(); err != nil {
			dbStat = "失敗"
		}
	}

	cacheStat := "成功"
	cache, err := redis.Dial("tcp",
		env("CACHE_HOST", "cache")+":"+env("CACHE_PORT", "6379"))
	if err != nil {
		cacheStat = "失敗"
	} else {
		defer cache.Close()
	}

	fmt.Fprintf(w, "Hello, Infra Study\nhostname: %s\nDB接続(%s): %s\nCache接続: %s\n",
		hostname, kind, dbStat, cacheStat)
}
