package main

import (
	"fmt"
	"io"
	"net/http"
)

func main() {
	mux := http.NewServeMux()

	mux.HandleFunc("/ping", func(w http.ResponseWriter, r *http.Request) {
		io.WriteString(w, "pong")
	})

	fmt.Println("Работает...")

	err := http.ListenAndServe(":8080", mux)
	if err != nil {
		panic(err)
	}
}
