use serde::{Serialize, Deserialize};
use serde_json::{Serializer, Deserializer};


#[derive(Serialize, Deserialize)]
pub struct Post<'a> {
    pub id: i64,
    pub title: &'a str,
    pub body: &'a str,
}
