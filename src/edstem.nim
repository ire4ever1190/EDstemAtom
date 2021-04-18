import std/httpclient
import std/asyncdispatch
import std/strformat
import std/json
import std/strutils
import common

const 
    token = readFile("token").strip()



proc getPosts*(courseID: int, limit: int = 30): Future[seq[ForumPost]] {.async.} =
    ## Fetches the posts from a course using EdStems api (thank you)
    let 
        url = fmt"https://edstem.org/api/courses/{courseID}/threads?limit={limit}&sort=new"
        client = newAsyncHttpClient(headers = newHttpHeaders({
            "x-token": token
        }), userAgent = "RSS Feed")
    let response = await client.request(url)
    let body = await response.body
    result = body.parseJson()["threads"].to(seq[ForumPost])
