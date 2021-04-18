import std/httpclient
import std/asyncdispatch
import std/strformat
import std/json
import std/strutils
import common

const 
    token = readFile("token").strip()
    baseURL = "https://edstem.org/api"

proc newClient(): AsyncHttpClient =
    newAsyncHttpClient(headers = newHttpHeaders({
        "x-token": token
    }), userAgent = "Atom Feed")

proc apiRequest(path: string): Future[string] {.async.} =
    let
        url = baseURL & path
        client = newClient()
    let response = await client.request(url)
    result = await response.body

proc getPosts*(courseID: int, limit: int = 30): Future[seq[ForumPost]] {.async.} =
    ## Fetches the posts from a course using EdStems api (thank you for not having a terrible api)
    let body = await apiRequest(fmt"/courses/{courseID}/threads?limit={limit}&sort=new")
    result = body.parseJson()["threads"].to(seq[ForumPost])

proc getCourses*(): Future[seq[int]] {.async.} =
    ## Gets all active courses that the user belongs to
    let body = await apiRequest("/user")
    let courses = body.parseJson()["courses"]
    for courseJson in courses:
        let course = courseJson["course"].to(ForumCourse) # Get the course, not the role
        if course.status == "active":
            result &= course.id