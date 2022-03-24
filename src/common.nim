import norm/[model, pragmas]
import std/times
import std/strutils
import std/options


type
    Post* = ref object of Model
        courseID*: int
        postID* {.unique.}: int
        title*: string
        content*: string
        category*: string
        updatedAt*: string
        author*: string

type 
    ForumUser* = object
        name*: string
        
    ForumPost* = object
        id*: int
        course_id: int
        title*: string
        content*: string
        document*: string
        category*: string
        updated_at*: string
        user*: Option[ForumUser]

    ForumCourse* = object
        id*: int
        status*: string

const anonUser* = ForumUser(name: "Anonymous")

## 2021-04-18T12:17:40.066362+10:00
proc getUpdateDate*(post: Post): DateTime =
    let parts = post.updatedAt.split('.')
    let secondPart = if parts[1].contains('+'): # code duplication? whats that?
                "+" & parts[1].split("+")[1]
            else:
                "-" & parts[1].split("-")[1]
    let updatedAt = parts[0] & secondPart
    result = updatedAt.parse("yyyy-MM-dd'T'hh:mm:sszzz", utc())

proc convertHTML*(input: string): string =
    ## ED stem doesn't seem to use standard html so this procedure changes it so it works
    ## Maybe I am just dumb tho
    var items: seq[(string, string)]
    let tags = {"paragraph": "p", "list": "ul", "list-item": "li", "bold": "strong"}
    for (i, j) in tags:
        items &= ("<" & i, "<" & j)
        items &= ("</" & i, "</" & j)

    result = input.multiReplace(items)

converter toDBPost*(post: ForumPost): Post =
    result = Post(
        courseID: post.courseID,
        postID: post.id,
        title: post.title,
        content: post.content.convertHTML(),
        category: post.category,
        author: post.user.get(anonUser).name,
        updatedAt: post.updatedAt
    )
