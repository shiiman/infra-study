package main

import (
	"database/sql"
	"fmt"
	"net/http"
	"os"

	"github.com/gomodule/redigo/redis"
)

const (
	DB_USER = "root"
	DB_PASS = "root"
	DB_HOST = "127.0.0.1"
	DB_PORT = "3306"
	DB_NAME = "test_db"

	CACHE_HOST = "127.0.0.1"
	CACHE_PORT = "6379"
)

func main() {
	http.HandleFunc("/", handler)
	http.ListenAndServe(":8080", nil)
}

func handler(w http.ResponseWriter, r *http.Request) {
	hostname, _ := os.Hostname()

	dbStat := "成功"
	dbconf := DB_USER + ":" + DB_PASS + "@tcp(" + DB_HOST + ":" + DB_PORT + ")/" + DB_NAME + "?charset=utf8mb4"
	db, err := sql.Open("mysql", dbconf)
	if err != nil {
		dbStat = "失敗"
	}
	defer db.Close()

	cacheStat := "成功"
	cacheconf := CACHE_HOST + ":" + CACHE_PORT
	cache, err := redis.Dial("tcp", cacheconf)
	if err != nil {
		cacheStat = "失敗"
	}
	defer cache.Close()

	fmt.Fprintf(w, "Hello, Infra Study\nhostname: "+hostname+"\nDB接続"+dbStat+"\nCache接続"+cacheStat+"\n")
}
