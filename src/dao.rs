use serde::{Serialize, Deserialize};
use serde_json::{Serializer, Deserializer};



#[derive(Serialize, Deserialize)]
pub struct Post<'a> {
    pub id: i64,
    pub title: &'a str,
    pub body: &'a str,
}

impl<'a> Post<'a> {
    pub fn new(id: i64, title: &'a str, body: &'a str) -> Self {
        Self {
            id: id, 
            title: title,            
            body: body,
        }
    }
}