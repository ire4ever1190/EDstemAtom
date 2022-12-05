import mike
import edstem as edstem
import database
import common
import std/strutils
import std/strformat
import std/xmltree
import std/times
import taskman
from ndb/sqlite import DbError
import asyncdispatch

var courseIDs = waitFor getCourses() # Load course IDs from the user

proc getNewPosts(ids: seq[int]) {.async.} =
  withDB:
    for id in ids:
      let posts = await edstem.getPosts(id)
      transaction(db):
        for (post, comments) in posts:
          db.upsert post
          for comment in comments:
            db.upsert comment

let tasks = newAsyncScheduler()

tasks.every(1.hours) do () {.async.}:
  courseIDs = await getCourses()
  await getNewPosts(courseIDs)
  when defined(debug):
    echo "Finished syncing"

asyncCheck tasks.start()

proc newTextTag(tagname: string, content: string, attributes: seq[(string, string)] = @[]): XmlNode =
    ## Creates a new xml tag with text inside it
    result = newElement(tagname)
    if attributes.len() > 0:
        result.attrs = attributes.toXmlAttributes()
    result.add newText(content)

proc newLink(url: string): XmlNode =
    ## Creates a new xml link element
    result = newElement("link")
    result.attrs = {"href": url}.toXmlAttributes()

const dateFormat = "yyyy-MM-dd'T'HH:mm:ssz"

func createEntry(title, content, author, category, url: string, id: int, updated: DateTime): XmlNode =
  result = newElement("entry")

  result &= newTextTag("title", title)
  result &= newTextTag("content", content, @{"type": "html"})

  let authorTag = newElement("author")
  authorTag &= newTextTag("name", author)
  result &= authorTag

  let categoryTag = newElement("category")
  categoryTag.attrs = {"term": category, "label": category}.toXmlAttributes()
  result &= categoryTag

  result &= newLink(url)
  result &= newTextTag("id", url)

  let replies = newElement("link")
  replies.attrs = {
    "rel": "replies",
    "type": "application/atom+xml",
    "href": "/feed/1/comments/2"
  }.toXmlAttributes()
  result &= replies
  result &= newTextTag("updated", updated.format(dateFormat))

proc createFeed(db: DBConn, posts: seq[Post], courseID: int): string =
    ## Creates the Atom feed from all posts in a course
    var feed = newElement("feed")
    feed.attrs = {"xmlns": "http://www.w3.org/2005/Atom"}.toXmlAttributes()
    feed &= newTextTag("title", "ED Stem Forum")
    feed &= newTextTag("subtitle", "Maths stuff")

    let url = fmt"https://edstem.org/courses/{courseID}"
    feed &= newLink(url)
    feed &= newTextTag("id", url)
    feed &= newTextTag("updated", posts.latest.format(dateFormat))

    for post in posts:
        feed.add createEntry(
          post.title,
          post.content,
          post.author,
          post.category,
          fmt"https://edstem.org/courses/{courseID}/discussion/{post.postID}",
          post.postID,
          post.updatedAt
        )

    result = $feed
    
"/feed/:course" -> get(course: int):
  withDB:
    let
      posts = db.getPosts(course)
      latest = posts.latest
    if ctx.beenModified(latest):
      ctx.setHeader("Content-Type", "application/atom+xml")
      ctx.setHeader("Last-Modified", latest.format("ddd',' dd MMM yyyy HH:mm:ss 'GMT'"))
      ctx.send db.createFeed(posts, course)
    else:
      ctx.status = Http304

"/feed/:course/comments/:parentID" -> get(course, parentID: int):
  echo course, " ", parentID

run(8094)

