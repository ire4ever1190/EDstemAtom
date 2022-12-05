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
        updatedAt*: DateTime
        author*: string

    Comment* = ref object of Model
      parentID*, commentID* {.unique.}: int
      author*: string
      content*: string
      updatedAt*: DateTime

    ForumCourse* = object
        id*: int
        status*: string

const
  anonUser* = "Anonymous"
  dateFormat = "yyyy-MM-dd'T'hh:mm:ss'.'ffffffzzz"

proc parseTime*(x: string): DateTime =
  ## Nims std/times doesn't play with with edstem so we need to do this funky shit
  try:
    let correctTime = x[0..<"2022-10-04T14:40:35".len] & x[^len("+11:00") .. ^1]
    result = correctTime.parse("yyyy-MM-dd'T'hh:mm:sszzz")
  except TimeParseError as e:
    echo e.msg
    result = now()
