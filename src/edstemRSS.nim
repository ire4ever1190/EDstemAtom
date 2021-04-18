import mike
import edstem as edstem
import database as db
import common
import std/strutils
import std/strformat
import std/xmltree
import std/times
from ndb/sqlite import DbError
import asyncdispatch

const forumIDs = @[5609] # Maybe make this configurable? 

proc getNewPosts(ids: seq[int]) {.async.}=
    for id in ids:
        let posts = await edstem.getPosts(id)
        for post in posts:
            try:
                db.addPost(post)
            except DbError: # Handle unique key if a post is already in the db
                # Update incase the teacher changed something
                db.updatePost(post)
                
proc getPostsTask(ids: seq[int]) {.async.} =
    while true:
        await getNewPosts(ids)
        await sleepAsync((60 * 60 * 60) * 3 * 1000) # 3 hours in milliseconds

asyncCheck getPostsTask(forumIDs)

proc newTextTag(tagname: string, content: string, attributes: seq[(string, string)] = @[]): XmlNode =
    result = newElement(tagname)
    if attributes.len() > 0:
        result.attrs = attributes.toXmlAttributes()
    result.add newText(content)

proc newLink(url: string): XmlNode =
    result = newElement("link")
    result.attrs = {"href": url}.toXmlAttributes()

proc createFeed(courseID: int): string =
    let posts = db.getPosts(courseID)
    var feed = newElement("feed")
    const siteURL = "http://127.0.0.1:8094" # Move this into a config file also
    feed.attrs = {"xmlns": "http://www.w3.org/2005/Atom"}.toXmlAttributes()
    let dateFormat = "yyyy-MM-dd'T'HH:mm:ssz"
    block:
        feed.add newTextTag("title", "ED Stem Forum")
        feed.add newTextTag("subtitle", "Maths stuff")
        let url = fmt"{siteURL}/feed/{courseID}"
        feed.add newLink(url)
        feed.add newTextTag("id", fmt"https://edstem.org/courses/{courseID}")

    var latestTime = initDateTime(1, mJan, 1970, 00, 00, 00, 00, utc())
    for post in posts:
        var item = newElement("entry")
        item.add newTextTag("title", post.title)
        item.add newTextTag("content", post.content, @{"type": "html"})

        let author = newElement("author")
        author.add newTextTag("name", post.author)
        item.add author
        let url = fmt"https://edstem.org/courses/{courseID}/discussion/{post.postID}"
        item.add newLink(url)
        item.add newTextTag("id", url)
        let time = post.getUpdateDate()
        item.add newTextTag("updated", time.format(dateFormat))
        if time > latestTime:
            latestTime = time
        feed.add item
    echo feed.len() - 2
    feed.insert(newTextTag("updated", latestTime.format(dateFormat)), feed.len() - len(posts) - 2)
    result = $feed
    
"/feed/:course" -> get:
    let courseID = ctx.pathParams["course"].parseInt()
    return createFeed(courseID)

discard createFeed(5609)
run(8094)
