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

// Runs the server, listening for requests until you kill the process.
func main() {
	r := chi.NewRouter()
	rehgister(r)
	http.ListenAndServe(fmt.Sprintf(":%v", port), r)
}

// Mux Registration

// rehgister the middleware and endpoints to the mux router.
func rehgister(mux *chi.Mux) {
	mux.Use(middleware.Logger)
	mux.Get("/", index)
	mux.Get("/reh", basicRehsponse)
}

// Endpoint Handlers

// basicRehsponse is a sample endpoint, just writes back a string to the requestor.
func basicRehsponse(w http.ResponseWriter, r *http.Request) {
	w.Write([]byte("reh"))
}

// index serves the static index.html file
func index(w http.ResponseWriter, r *http.Request) {
	w.Write([]byte("TBD - figuring out how to serve a file"))
}
