use db::Persistence;
use server::{Api};
use std::env;

mod server;
mod dao;
mod db;
mod models;
mod schema;
mod encode;

#[tokio::main]
async fn main(){
    let args: Vec<String> = env::args().collect();
    let addr = [127, 0,0,1];
    let port = 5000;
    println!("running server on port {}", port);
    let handle = server::serve(addr, port, args[1].as_str());
    // just wait till completion
    handle.await 
}
