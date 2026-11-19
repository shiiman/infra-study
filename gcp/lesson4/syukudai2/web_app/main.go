package main

import (
	"database/sql"
	"fmt"
	"net/http"
	"os"

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

// DB_KIND で接続先の種類を切り替える
//
//	postgres ローカルのPostgreSQLコンテナ / Cloud SQL
//	spanner  Cloud Spanner
//
// Spannerはドライバが違うだけで database/sql の使い方は同じ。
// 接続文字列に IP もポートも出てこないのがポイント。
func openDB() (*sql.DB, string) {
	switch env("DB_KIND", "postgres") {
	case "spanner":
		// projects/<project>/instances/<instance>/databases/<database>
		return openSpanner(env("SPANNER_DATABASE", ""))
	default:
		return openPostgres()
	}
}

func openSpanner(dsn string) (*sql.DB, string) {
	db, err := sql.Open("spanner", dsn)
	if err != nil {
		return nil, "Spanner"
	}
	return db, "Spanner"
}

func openPostgres() (*sql.DB, string) {
	// sslmode=prefer は、サーバが TLS に対応していれば TLS で、していなければ平文で繋ぐ
	// (ローカルのコンテナは平文、Cloud SQL は TLS)
	dsn := "host=" + env("DB_HOST", "db") + " port=" + env("DB_PORT", "5432") +
		" user=" + env("DB_USER", "postgres") + " password=" + env("DB_PASS", "") +
		" dbname=" + env("DB_NAME", "test_db") + " sslmode=prefer connect_timeout=5"
	db, err := sql.Open("pgx", dsn)
	if err != nil {
		return nil, "PostgreSQL"
	}
	return db, "PostgreSQL"
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
