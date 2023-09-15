package main

import (
	"embed"
	"fmt"
	"io/fs"
	"log"
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
)

// Port to host the REHbsite on. Can be anything, as long as it's free.
// Port 3000 is often used for web development, especially for running web applications.
// If the web application needs to be accessible to the internet, you will need to open port 3000.
const port = 3000

//go:embed static/*
var content embed.FS

// Runs the server, listening for requests until you kill the process.
func main() {
	// Create the router and REHgister the endpoints to host the seREHver.
	r := chi.NewRouter()
	rehgister(r)

	// StaREHt listening for REHquests!
	err := http.ListenAndServe(fmt.Sprintf(":%v", port), r)
	if err != nil {
		log.Fatal(err)
	}
}

// Mux Registration

// rehgister the middleware and endpoints to the mux router.
func rehgister(mux *chi.Mux) {
	// Middleware
	mux.Use(middleware.Logger)

	// Static file handler
	// TODO: Figure out why this isn't working ☹
	var contentFS, err = fs.Sub(content, "static")
	if err != nil {
		log.Println(err)
	}
	mux.Handle("/static/", http.StripPrefix("/static/", http.FileServer(http.FS(contentFS))))

	// Endpoints
	//mux.Get("/", index) // TODO: REHmove this when the file handler starts working.
	mux.Get("/reh", basicRehsponse)
}

// Endpoint Handlers

// basicRehsponse is a sample endpoint, just writes back a string to the requestor.
func basicRehsponse(w http.ResponseWriter, r *http.Request) {
	w.Write([]byte("reh"))
}

// index serves the static index.html file
func index(w http.ResponseWriter, r *http.Request) {
	http.ServeFile(w, r, "/static/index.html")
}