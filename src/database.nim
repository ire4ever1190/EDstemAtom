# Why use sql queries when ORM do trick?
import norm/[model, sqlite]
import os
import common

putEnv("DB_HOST", "database.db")

proc getPosts*(courseID: int): seq[Post] =
    ## Gest all posts that belong to a course
    withDB:
        result = @[Post()]
        db.select(result, "Post.courseID = ?", courseID)

proc updatePost*(post: ForumPost) =
    ## Updates a post in the database by finding a post with the same postID (postID is from edStem)
    withDB:
        var oldPost = Post()
        db.select(oldPost, "Post.postID = ?", post.id)
        var newPost = post.toDBPost()
        newPost.id = oldPost.id
        db.update oldPost

proc addPost*(post: Post) =
    ## Inserts a post into the database
    var post = post
    withDB:
        db.insert post

withDB:
    db.createTables(Post())
