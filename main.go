// Main package - right now we only have one package, but this designates to Go that the entry point to our software resides in this package
package main

// ~~~~~~~~~~~~~~~~~~~~~
// Imported Libraries
// ~~~~~~~~~~~~~~~~~~~~~
import (
	"embed"
	"fmt"
	"io/fs"
	"log"
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
)

// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
// Global Constants & Vars
// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

// Port to host the REHbsite on. Can be anything, as long as it's free.
// Port 3000 is often used for web development, especially for running web applications.
// If the web application needs to be accessible to the internet, you will need to open port 3000.
const port = 3000

//go:embed static/*
var content embed.FS // Embed the current filesystem into the executable

//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
// Main Function
//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

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

//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
// Mux REHgistration - Where APIs are defined
//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

// rehgister the middleware and endpoints to the mux router.
func rehgister(mux *chi.Mux) {
	// Middleware - What runs between REHceiving the REHquest and handling it.
	mux.Use(middleware.Logger) // Log all incoming REHquests (If including, it is REHquired to REHgister this first)

	// Static file handler - Tells the program that we need files from the computer
	var contentFS, err = fs.Sub(content, "static")
	if err != nil {
		log.Println(err)
	}
	// When a request is received at the root, return the file pointed to by the File Server. (Request to "<ip>:<port>", ex. "localhost:3000" or "worldwidereh.com:3000")
	mux.Handle("/", http.FileServer(http.FS(contentFS)))

	// Endpoints
	mux.Get("/reh", basicRehsponse) // When a GET request comes in at the endpoint "/reh", run the function basicRehsponse
}

//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
// Endpoint Handlers
//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

// basicRehsponse is a sample endpoint, just writes back a string to the requestor.
func basicRehsponse(w http.ResponseWriter, r *http.Request) {
	w.Write([]byte("reh"))
}
