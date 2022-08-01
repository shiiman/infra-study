package main

import (
	"database/sql"
	"fmt"
	"net/http"
	"os"

	_ "github.com/go-sql-driver/mysql"
	"github.com/gomodule/redigo/redis"
)

func main() {
	http.HandleFunc("/", handler)
	http.ListenAndServe(":8080", nil)
}

func handler(w http.ResponseWriter, r *http.Request) {
	hostname, _ := os.Hostname()

	// 環境変数から取得.
	DB_USER := os.Getenv("DB_USER")
	DB_PASS := os.Getenv("DB_PASS")
	DB_HOST := os.Getenv("DB_HOST")
	DB_PORT := os.Getenv("DB_PORT")
	DB_NAME := os.Getenv("DB_NAME")
	CACHE_HOST := os.Getenv("CACHE_HOST")
	CACHE_PORT := os.Getenv("CACHE_PORT")

	dbStat := "成功"
	dbconf := DB_USER + ":" + DB_PASS + "@tcp(" + DB_HOST + ":" + DB_PORT + ")/" + DB_NAME + "?charset=utf8mb4"
	db, _ := sql.Open("mysql", dbconf)
	defer db.Close()

	err := db.Ping()
	if err != nil {
		dbStat = "失敗"
		fmt.Println("DB接続失敗")

		_, err = db.Exec("CREATE DATABASE IF NOT EXISTS " + DB_NAME)
		if err != nil {
			fmt.Println("DB作成失敗")
		}
	} else {
		fmt.Println("DB接続成功")
	}

	cacheStat := "成功"
	cacheconf := CACHE_HOST + ":" + CACHE_PORT
	cache, err := redis.Dial("tcp", cacheconf)
	if err != nil {
		cacheStat = "失敗"
		fmt.Println("Cache接続失敗")
	} else {
		defer cache.Close()
		fmt.Println("Cache接続成功")
	}

	fmt.Fprintf(w, "Hello, Infra Study\nhostname: "+hostname+"\nDB接続: "+dbStat+"\nCache接続: "+cacheStat+"\n")
}
