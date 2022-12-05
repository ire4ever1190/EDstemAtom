import std/httpclient
import std/asyncdispatch
import std/strformat
import std/json
import std/strutils
import std/tables
import std/sugar
import std/times
import common
{.experimental: "codeReordering".}

const 
    baseURL = "https://edstem.org/api"

let
  userDetails = readFile("details").strip().split(" ")
  username = userDetails[0]
  password = userDetails[1]
     
var token = ""

proc newClient(): AsyncHttpClient =
    ## Creates a new AsyncHttpClient with default settings
    newAsyncHttpClient(headers = newHttpHeaders({
        "x-token": token,
        "Content-Type": "application/json"
    }), userAgent = "Atom Feed")

token = waitFor getToken(username, password)

proc apiRequest(client: AsyncHttpClient, path: string, httpMethod = HttpGet, body = ""): Future[AsyncResponse] {.async.} =
    ## Makes a request to edstem
    let
      url = baseURL & path
      response = await client.request(url, httpMethod, body = body)
    result = response        

proc getToken*(username, password: string): Future[string] {.async.} =
    ## Gets a token from edstem using the specified username and password
    let client = newClient()
    defer: client.close()
    let response = await client.apiRequest("/token", httpMethod = HttpPost, body = $ %* {
        "login": username,
        "password": password
    })
    if not (response.code == Http200):
        raise newException(ValueError, "Your username or password is incorrect")
    result = response.body.await().parseJson()["token"].getStr()

proc api(path: string, httpMethod = HttpGet, body = ""): Future[string] {.async.} =
    ## Makes an api request to edstem and returns the string return body
    let client = newClient()
    defer: client.close()
    let response = await client.apiRequest(path, httpMethod, body)
    if response.code == Http401: # Invalid token
        token = await getToken(username, password)
        result = await api(path, httpMethod, body)
    else:
        result = await response.body


func convertHTML*(input: string): string {.raises: [].} =
    ## ED stem doesn't seem to use standard html so this procedure changes it so it works
    ## Maybe I am just dumb tho
    var items: seq[(string, string)]
    let tags = {"paragraph": "p", "list": "ul", "list-item": "li", "bold": "strong"}
    for (a, b) in tags:
        items &= ("<" & a, "<" & b)
        items &= ("</" & a, "</" & b)
    result = input.multiReplace(items)

proc updatedAt(j: JsonNode): DateTime =
  ## Returns the date stored in the updated_at field in j.
  ## If that is null then created_at is used
  result = j["updated_at"].getStr(j["created_at"].getStr()).parseTime()

proc getComments*(postID: int): Future[seq[Comment]] {.async.} =
  ## Fetches the comments for a post
  let
    body = api(fmt"/threads/{postID}").await().parseJson()
    thread = body["thread"]
  # Create lookup table for users
  var users = collect:
    for user in body["users"]:
      {user["id"].getInt(): user["name"].getStr()}
  users[0] = anonUser
  for comment in thread["answers"].elems & thread["comments"].elems:
    result &= Comment(
      commentID: comment["id"].getInt(),
      parentID: comment["parent_id"].getInt(postID),
      author: users[comment["user_id"].getInt(0)],
      content: comment["content"].getStr().convertHTML(),
      updatedAt: comment.updatedAt()
    )

proc getPosts*(courseID: int, limit: int = 30): Future[seq[(Post, seq[Comment])]] {.async.} =
  ## Fetches the posts from a course using EdStems api (thank you for not having a terrible api)
  let body = await api(fmt"/courses/{courseID}/threads?limit={limit}&sort=new")
  let threads = body.parseJson()["threads"]
  for thread in threads:
    var post = Post()
    post.courseID = courseID
    post.title = thread["title"].getStr()
    post.postID = thread["id"].getInt()
    post.content = thread["content"].getStr().convertHTML()
    if thread.hasKey("user") and thread["user"].kind != JNull:
      post.author = thread["user"]["name"].getStr(anonUser)
    else:
      post.author = anonUser

    post.updatedAt = thread.updatedAt()
    result &= (post, await post.postID.getComments())

proc getCourses*(): Future[seq[int]] {.async.} =
    ## Gets all active courses that the user belongs to
    let body = await api("/user")
    let courses = body.parseJson()["courses"]
    for courseJson in courses:
        let course = courseJson["course"].to(ForumCourse) # Get the course, not the role
        if course.status == "active":
            result &= course.id









