use diesel::pg::PgConnection;
use diesel::prelude::*;
use crate::models::{Post, NewPost};

pub struct Persistence {
    conn: PgConnection,
}

impl Persistence {
    pub fn new(conn_str: &str) -> Self {
        Self {
            conn: PgConnection::establish(conn_str).unwrap(),
        }
    }

    pub fn store_post(&mut self, title: &str, body: &str) -> Post {
        use crate::schema::posts;

        let post_to_insert = NewPost { title: title, body: body};
        diesel::insert_into(posts::table)
            .values(&post_to_insert)
            .returning(Post::as_returning())
            .get_result(&mut self.conn)
            .expect("Error saving new post")
    }

    pub fn get_posts_by_title(&mut self, tit: &str) -> Vec<Post> {
        use crate::schema::posts::dsl::*;

        let results = posts 
            .filter(published.eq(true))
            .filter(title.like("%".to_owned() + tit + "%"))
            .select(Post::as_select())
            .load(&mut self.conn)
            .expect("Error loading posts");

        let mut list_of_posts = vec![];
        for result in results {
            list_of_posts.push(result)
        }

        list_of_posts
    }

    pub fn publish_post(&mut self, post_id: i32) -> Post {
        use crate::schema::posts::dsl::*;

        diesel::update(posts.find(post_id))
            .set(published.eq(true))
            .returning(Post::as_returning())
            .get_result(&mut self.conn)
            .unwrap()
    }
}





