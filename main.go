// Main package - right now we only have one package, but this designates to Go that the entry point to our software resides in this package
package main

// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
// Imported Libraries
//
// Pretty standard, just a couple things to know about naming conventions:
// The name of the package is always the last fragment of the path. (ex. "io/fs" -> package name: fs)
// The path denotes the origin of the package. Does the path start with a domain URL? (ex. "github.com")
// - No? This is a standard go package, included with your installation of Go. (ex. "fmt")
// - Yes? This is a package downloaded off the internet using the Go command "go get <package url>" (ex. "github.com/go-chi/chi/v5")
//
// Want to add a package that you haven't downloaded before? Run the command "go get <package URL>" in your shell (ex. "go get github.com/go-chi/chi/v5")
// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
import (
	"embed"
	"fmt"
	"io/fs"
	"log"
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
)

// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
// Global Constants & Vars
//
// Constants generally go up here if they're used in many places throughout the file, or above the function they are used in, if only used in one.
// Global variables should be avoided if possible, with a few exceptions, like "embed.FS" below, since Go needs to know at compile time that access to
// certain files will be needed. Further info: https://pkg.go.dev/embed
// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

// Port to host the REHbsite on. Can be anything, as long as it's free.
// Port 3000 is often used for web development, especially for running web applications.
// If the web application needs to be accessible to the internet, you will need to open port 3000.
const port = 3000

//go:embed static/*
var content embed.FS // Embed the current filesystem into the executable

//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
// Main Function
//
// This is the entREH point to the pREHgram. Go expects a main() to exist.
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
//
// A mux is a "multiplexer", sometimes also known as a router.
// https://en.wikipedia.org/wiki/Multiplexer
//
// Basically, this service is set to take in all REHquests at the port listed.
// This REHgistration function makes it so we can route diffeREHnt REHquests
// to diffeREHnt functions pending on what is REHquested.
//
// Basically, think of this progREHm like an apartment building, with each
// endpoint being an apartment, and the router being the shared mailbox,
// and the middleware being the post officer trying to figure out where
// each piece of mail needs to get delivered to.
//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

// rehgister the middleware and endpoints to the mux router.
func rehgister(mux *chi.Mux) {
	// Middleware - What runs between REHceiving the REHquest and handling it.
	mux.Use(middleware.Logger) // Logger is a middleware defined by the Chi library, which will automatically print out request info to stdout

	// Static file handler - Tells the program that we need files from the computer
	var contentFS, err = fs.Sub(content, "static")
	if err != nil {
		log.Println(err)
	}
	// When a request is received at the root, return the file pointed to by the File Server. (Request to "<ip>:<port>", ex. "localhost:3000" or "worldwidereh.com:3000")
	mux.Handle("/", http.FileServer(http.FS(contentFS)))

	// Endpoints
	mux.Get("/reh", basicRehsponse)	// When a GET request comes in at the endpoint "/reh", run the function basicRehsponse
}

//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
// Endpoint Handlers
//
// This is where most of the magic happens.
//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

// basicRehsponse is a sample endpoint, just writes back a string to the requestor.
func basicRehsponse(w http.ResponseWriter, r *http.Request) {
	w.Write([]byte("reh"))
}
