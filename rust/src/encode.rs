

pub fn encode_post<'a>(post: &'a crate::models::Post) -> crate::dao::Post<'a> {
    crate::dao::Post {
        id: post.id as i64, 
        title: post.title.as_str(),
        body: post.body.as_str(),
    }
}

pub fn encode_posts<'a>(posts: &'a Vec<crate::models::Post>) -> Vec<crate::dao::Post<'a>> {
    let mut v = vec![];
    for post in posts {
        v.push(encode_post(post))
    }
    v
}

