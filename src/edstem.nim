import std/httpclient
import std/asyncdispatch
import std/strformat
import std/json
import std/strutils
import common
{.experimental: "codeReordering".}

const 
    baseURL = "https://edstem.org/api"
    userDetails = readFile("details").strip().split(" ")
    username = userDetails[0]
    password = userDetails[1]

     
var token = ""

token = waitFor getToken(username, password)

proc newClient(): AsyncHttpClient =
    ## Creates a new AsyncHttpClient with default settings
    newAsyncHttpClient(headers = newHttpHeaders({
        "x-token": token,
        "Content-Type": "application/json"
    }), userAgent = "Atom Feed")


proc apiRequest(path: string, httpMethod = HttpGet, body = ""): Future[AsyncResponse] {.async.} =
    ## Makes a request to edstem
    let
        url = baseURL & path
        client = newClient()
    let response = await client.request(url, httpMethod, body = body)
    result = response        

proc getToken*(username, password: string): Future[string] {.async.} =
    ## Gets a token from edstem using the specified username and password
    let response = await apiRequest("/token", httpMethod = HttpPost, body = $ %* {
        "login": username,
        "password": password
    })
    if not (response.code == Http200):
        raise newException(ValueError, "Your username or password is incorrect")
    result = (await response.body).parseJson()["token"].getStr()

proc api(path: string, httpMethod = HttpGet, body = ""): Future[string] {.async.} =
    ## Makes an api request to edstem and returns the string return body
    let response = await apiRequest(path, httpMethod, body)
    if response.code == Http401: # Invalid token
        token = await getToken(username, password)
        result = await api(path, httpMethod, body)
    else:
        result = await response.body

        
proc getPosts*(courseID: int, limit: int = 30): Future[seq[ForumPost]] {.async.} =
    ## Fetches the posts from a course using EdStems api (thank you for not having a terrible api)
    let body = await api(fmt"/courses/{courseID}/threads?limit={limit}&sort=new")
    let threads = body.parseJson()["threads"]
    result = newSeq[ForumPost](threads.len)
    for thread in threads:
        result &= thread.to(ForumPost)
        if result[^1].updatedAt == "":
            result[^1].updatedAt = thread["created_at"].getStr()

proc getCourses*(): Future[seq[int]] {.async.} =
    ## Gets all active courses that the user belongs to
    let body = await api("/user")
    let courses = body.parseJson()["courses"]
    for courseJson in courses:
        let course = courseJson["course"].to(ForumCourse) # Get the course, not the role
        if course.status == "active":
            result &= course.id

