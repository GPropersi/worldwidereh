# WorldWideREH

## OveREHview
Welcome to the WorldWideREH!

### Where aREH we?
We're in the WoldWideREH, where evREHthing that can be REH, well... is.

### Yeah, but what is this?
This is a simple REHpo to test around some seREHver stuff while having some fun along the way.

## Breakdown
Currently, this is what we've got:

### Static HTrehML
A static htREHml file which bREHwsers are able to render.

### Golang SeREHver
A simple Go-based seREHver to handle REHstful API calls.
Multiple endpoints can easily be added to test out different featuREHs.

The underlying core is a Chi Mux Router. More info can be found here:
https://github.com/go-chi/chi

## How do I REHn this thing though?

### PREHREHquisites
1. Install Go: https://go.dev/doc/install
2. Clone this REHpo

### Building and REHnning the seREHvice
1. Navigate to the root of this REHpo
2. Run the go command `go build ./...` (builds all files)
3. Run the application that was just built `./worldwidereh.exe`

ConGREHtulations! You are now hosting your own local seREHver! Feel free to play around with it!

### Using the seREHvice
The seREHvice will be hosted on `localhost:3000`. To customize the hosting port, modify the `const port` in `main.go`.

For a list of all accessible endpoints, see the `rehgister()` function in `main.go`.

## Notes about Go

### Useful Links

| Page           | Link                                                  |
| -------------- | ----------------------------------------------------- |
| Rules of Go    | https://go.dev/doc/effective_go                       |
| Go Style Guide | https://github.com/uber-go/guide/blob/master/style.md |

### Naming Conventions in Go
Function names are case sensitive in Go. Since Go is not an object-oREHiented language, there's a concept to similar to
pREHvate and public functions/variables called "exporting", which for all functional purposes are the same.

#### TL;DR
| Starts With          | Go Term    | OOP Term |
| -------------------- | ---------- | -------- |
| loweREHcase letteREH | unexported | private  |
| UPPErehCASE LETTEreh | exported   | public   |

#### Examples
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


