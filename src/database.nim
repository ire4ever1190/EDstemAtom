# Why use sql queries when ORM do trick?
import norm/[model, sqlite]
import os
import common
import times
import sugar

putEnv("DB_HOST", "database.db")

type Models = Post | Comment

using db: DbConn

proc getPosts*(db; courseID: int): seq[Post] =
  ## Gets all posts that belong to a course
  result = @[Post()]
  db.select(result, "Post.courseID = ?", courseID)

proc getComments*(db; parentID: int): seq[Comment] =
  ## Gets all comments that have a parent. Top level comments
  ## have their parent ID be the thread ID
  result = @[Comment()]
  db.select(result, "Comment.parentID = ?", parentID)

proc latest*(posts: seq[Post]): DateTime =
  ## Returns the latest time in a series of posts
  result = dateTime(1970, mJan, 1, 0, 0, 0)
  for post in posts:
    if post.updatedAt > result:
      result = post.updatedAt


proc update*(db; post: Post) =
  ## Updates a post in the database by finding a post with the same postID (postID is from edStem)
  var oldPost = Post()
  db.select(oldPost, "Post.postID = ?", post.postID)
  post.id = oldPost.id
  sqlite.update(db, oldPost)

proc update*(db; comment: Comment) =
  ## Updates a post in the database by finding a post with the same postID (postID is from edStem)
  var oldComment= Comment()
  db.select(oldComment, "Comment.commentID = ?", comment.commentID)
  comment.id = oldComment.id
  sqlite.update(db, oldComment)

template upsert*(db; item: auto) =
  try:
    db &= item
  except DBError as e:
    echo e.msg
    db.update item

proc add*(db; comment: Models) =
  discard comment.dup(db.insert)

withDB:
    db.createTables(Post())
    db.createTables(Comment())
export sqlite
