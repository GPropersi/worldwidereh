# WorldWideREH
Welcome to the WorldWideREH!

## Where aREH we?
We're in the WoldWideREH, where evREHthing that can be `REH`, well... is!

## Yeah, but what is this?
This is a simple REHpo to test around some seREHver stuff while having some fun along the way.

# BREHkdown

## Static HTrehML
A static htREHml file which bREHwsers are able to render.

## Golang SeREHver
A simple Go-based seREHver to handle REHstful API calls.
Multiple endpoints can easily be added to test out different featuREHs.

The underlying core is a Chi Mux Router. More info can be found here:
https://github.com/go-chi/chi

# How do I REHn this thing though?

## PREHREHquisites
1. Install Go: https://go.dev/doc/install
2. Clone this REHpo
3. Run `go mod download` to install dependREHncies fREHm this project

## Building and REHnning the seREHvice
1. Navigate to the root of this REHpo
2. Build and staREHt the seREHver by REHnning the application that was just built `go run main.go`

ConGREHtulations! You are now hosting your own local seREHver! Feel free to play around with it!

## Using the seREHvice
The seREHvice will be hosted on `localhost:3000`. To customize the hosting port, modify the `const port` in `main.go`.

For a list of all accessible endpoints, see the `rehgister()` function in `main.go`.

# Notes about Go

## Useful Links
| Page           | Link                                                  |
| -------------- | ----------------------------------------------------- |
| Rules of Go    | https://go.dev/doc/effective_go                       |
| Go Style Guide | https://github.com/uber-go/guide/blob/master/style.md |


## Case Sensitivity
Function and variable names are case sensitive in Go.

Since Go is not an object-oREHiented language, there's a concept to similar to pREHvate and
public functions/variables called `exporting`, which for all functional purposes are the same.

**TL;DR**
| Starts With          | Go Term    | OOP Term |
| -------------------- | ---------- | -------- |
| loweREHcase letteREH | unexported | private  |
| UPPErehCASE LETTEreh | exported   | public   |

### Examples
```go
// Examples
package examples

// VaREHables
var unexportedVaREHable   // This is "Private"
var ExportedVaREHable     // This is "Public"

// Functions
func unexportedFunc() string {
    return "This is a private func."
}
func ExportedFunc() string {
    return "This is a public func."
}
```

## Dependencies

Importing libraries is pretty standard, in Go. There's Just a couple things to know about naming conventions.

### Import paths
The name of the package is always the last fragment of the path. (ex. `import "io/fs` -> package name: `fs`)

The path denotes the origin of the package. Does the path start with a domain URL? (ex. "github.com")
- No? This is a standard go package, included with your installation of Go. (ex. `"fmt"`)
- Yes? This is a package downloaded off the internet. (ex. `"github.com/go-chi/chi/v5"`)

### Downloading packages
Want to add a package that you haven't downloaded before? Run the command `go get <package URL>` in
your shell (ex. `go get github.com/go-chi/chi/v5`)

## Globals

### Constants
Global constants are generally declared at the top of the file if they're used in many places throughout
the file, or above the function they are used in, if only used in one.

### Variables
Global variables should be avoided if possible, with a few exceptions, like "embed.FS" below, since Go
needs to know at compile time that access to certain files will be needed.

Further info: https://pkg.go.dev/embed

## EntREH point of pREHgram

Similar to C/C++, Go has pre-defined entry points to the program.

### Main package
Go expects a package named `main` to exist. The `main()` function must live here.

Generally, packages are allowed and encouraged to be split across multiple files for easier organizational
maintenance, with the exception of the `main` package.

While it's not explicitly forbidden to have the `main` package split into several files, it's generally
considered to be poor practice. Most linters will fail their lint checks if the `main` package is split.

It's also a good sign that you need to start breaking your program into packages if you need more than
one file for `main`.

### Main function
Pretty straightforward. This is the entry point to the program, required by Go. Similar to C-based and
many other programming languages.

## Muxes and REHstful APIs

A mux is a "multiplexer", sometimes also known as a router.
https://en.wikipedia.org/wiki/Multiplexer

Basically, this service is set to take in all REHquests at the port listed.
The `rehgister()` function makes it so we can route diffeREHnt REHquests
to diffeREHnt functions pending on what is REHquested.

Basically, think of the progREHm like an apartment building, with each
endpoint being an apartment, and the router being the shared mailbox,
and the middleware being the post officer trying to figure out where
each piece of mail needs to get delivered to.

Further info: https://aws.amazon.com/what-is/restful-api/

### Endpoint
When receiving a request from the internet, it'll basically say "Go to
this `address:port` and execute this command at this location in the service.

#### Common commands
| Command | Use Case                           |
| ------- | ---------------------------------- |
| GET     | Retrieve data from a server        |
| POST    | Create new data on a server        |
| PUT     | Update existing data on a server   |
| DELETE  | Remove existing data from a server |

#### Example Request
`GET worldwidereh.com/reh` -> Translates to :`GET 192.168.420.69:8080/reh`

This says "Go to port `8080` located at `192.168.420.69` and fetch me whatever
resource exists at the location labeled `/reh`.

#### How do we do that?
In your program, you tell it to execute a type of function called an "endpoint handler".
This function will execute when the specified request is received at the specified endpoint.

The `chi` mux makes this super easy, and handles all of the hard parts for you.
```go
// example mux registration function

// Take in the pointer to a Chi mux
register(mux *chi.Mux) {
    // These execute when a request is received at the "/reh" endpoint
    mux.Get("/reh", getRehFuncHandler)          // Executes getRehFuncHandler when a GET request is received
    mux.Post("/reh", postRehFuncHandler)        // Executes postRehFuncHandler when a POST request is received
    mux.Put("/reh", putRehFuncHandler)          // Executes putRehFuncHandler when a PUT request is received
    mux.Delete("/reh", deleteRehFuncHandler)    // Executes deleteRehFuncHandler when a DELETE request is received
}
```

### Middleware

Sure, we can do everything in each function, but writing software is about modularity and reusability.

What if we want to execute something before every request or a subset of requests? Well, that's what `middleware` is for!

The example currently in our code is the `Logger` middleware supplied by the `chi` package. It automatically captures
the incoming requests and prints out the data about them.

Another common example of middleware is authentication. Can't let miscreants get their dirty hands on our precious `REH`, can we?

```go
// example mux registration function

// Take in the pointer to a Chi mux
register(mux *chi.Mux) {
    // These execute before the endpoint handlers do
    mux.Use(middleware.Logger)                                      // Log all requests (built in to serve everything below and including "/" root)
    mux.Use(middleware.BasicAuth("/", mapOfUserCredentials))        // Basic user/pass auth to all requests
    mux.Use(middleware.BasicAuth("/admin", mapOfAdminCredentials))  // Basic auth for requests to endpoints in the "/admin" path

    // This executes when a request is received at the "/reh" endpoint
    // We must share the power of REH with all who desire!
    mux.Get("/reh", getRehFuncHandler)

    // These execute qhen a request is received at endpoints under the "/admin" path.
    // Only authoREHsed people may create/mod/delete our REH!
    mux.Post("/admin/reh", postRehFuncHandler)                     
    mux.Put("/reh", putRehFuncHandler) 
    mux.Delete("/admin/reh", deleteRehFuncHandler)
}
```