package main

import (
	"fmt"
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
)

// Port to host the REHbsite on. Can be anything, as long as it's free.
// Port 3000 is often used for web development, especially for running web applications.
// If the web application needs to be accessible to the internet, you will need to open port 3000.
const port = 3000

// Runs the server until you kill the process.
func main() {
	r := chi.NewRouter()
	r.Use(middleware.Logger)
	r.Get("/", func(w http.ResponseWriter, r *http.Request) {
		w.Write([]byte("reh"))
	})
	http.ListenAndServe(fmt.Sprintf(":%v", port), r)
}
