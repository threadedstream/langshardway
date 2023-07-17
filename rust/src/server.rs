use std::convert::Infallible;
use std::net::{SocketAddr};
use futures_util::TryFutureExt;
use hyper::body;
use hyper::http::HeaderValue;
use std::sync::{Arc};
use hyper::{Body, Request, Response, Server};
use hyper::service::{make_service_fn, service_fn};
use hyper::{Method, StatusCode};
use std::collections::HashMap;
use tokio::sync::Mutex;
use crate::db::Persistence;

use crate::dao::Post;
use crate::encode::{encode_post, encode_posts};

pub struct Api {
    db: Persistence
}

unsafe impl Send for Api {}
unsafe impl Sync for Api {}

impl Api {
    pub fn new(db: Persistence) -> Self {
        Self{
            db: db,
        }
    }

    async fn store_post(&mut self, req: Request<Body>) -> Result<Response<Body>, Infallible> {
        let mut response = Response::new(Body::empty());
        if let Ok(bytes) = body::to_bytes(req.into_body()).await {
            let p: Post = serde_json::from_slice(&bytes).unwrap();
            let post = self.db.store_post(p.title, p.body);
            
            let v = serde_json::to_string(&encode_post(&post)).unwrap();

            *response.body_mut() = Body::from(v);
            *response.status_mut() = StatusCode::OK;
        } else {
            *response.status_mut() = StatusCode::BAD_REQUEST;
            *response.body_mut() = Body::from("post some data please");
        }
        
        Ok(response)
    }   

    fn publish_post(&mut self, _: Request<Body>, query_params: HashMap<String, String>) -> Result<Response<Body>, Infallible> {
        let response = {
            let mut response = Response::new(Body::empty());
            if let Some(post_id) = query_params.get(&"id".to_owned()) {
                let post = self.db.publish_post(post_id.parse::<i32>().unwrap());
                let v = serde_json::to_string(&encode_post(&post)).unwrap();
                *response.body_mut() = Body::from(v);
                *response.status_mut() = StatusCode::OK;
            } else {
                *response.status_mut() = StatusCode::BAD_REQUEST;
                *response.body_mut() = Body::from("post some data please");
            }
            response 
        };
        Ok(response)
    }

    fn get_posts_by_title(&mut self, _: Request<Body>, query_params: HashMap<String, String>) -> Result<Response<Body>, Infallible> {
        let mut response = Response::new(Body::empty());
        if let Some(post_title) = query_params.get(&"title".to_owned()) {
            let posts = self.db.get_posts_by_title(post_title.as_str());
            let api_posts = encode_posts(&posts);
            let v = serde_json::to_string(&api_posts).unwrap();
            *response.body_mut() = Body::from(v);
            *response.status_mut() = StatusCode::OK;
        } else {
            *response.status_mut() = StatusCode::BAD_REQUEST;
            *response.body_mut() = Body::from("post some data please");
        }

        Ok(response)
    }


    fn handle_dumb(&self) -> Result<Response<Body>,Infallible> {
        let mut response = Response::new(Body::empty());
        *response.body_mut() = Body::from("your rust code actually worked damn it");
        *response.status_mut() = StatusCode::NOT_FOUND;
        Ok(response)
    }

    fn handler_not_found() -> Result<Response<Body>, Infallible> {
        let mut response = Response::new(Body::empty());
        *response.body_mut() = Body::from("look somewhere else");
        *response.status_mut() = StatusCode::NOT_FOUND;
        Ok(response)
    }
}

pub async fn serve(addr: [u8; 4], port: u16, conn_str: &str) {
    let addr = SocketAddr::from((addr, port));

    let db = Persistence::new(conn_str);
    let api = Arc::new(Mutex::new(Api::new(db)));
    let make_svc = make_service_fn(move |_|{
        let api = api.clone();
        
        async {
            Ok::<_, hyper::Error>(service_fn(move |req| {
                let api = api.clone();
                
                async move {
                    let mut query_params: HashMap<String, String> = HashMap::new();
                    if let Some(query) = req.uri().query() {
                        query_params = parse_query_params(query); 
                    }
                    
                    let mut response = match (req.method(), req.uri().path()) {
                        (&Method::POST, "/post") => api.lock().await.store_post(req).await.unwrap(),
                        (&Method::GET, "/publish") => api.lock().await.publish_post(req, query_params).unwrap(),
                        (&Method::GET, "/posts") => api.lock().await.get_posts_by_title(req, query_params).unwrap(),
                        (&Method::GET, "/dumb") => api.lock().await.handle_dumb().unwrap(),
                        _ => Api::handler_not_found().unwrap()
                    };
                    response.headers_mut().append("Content-Type", HeaderValue::from_str("application/json").unwrap());
                    Ok::<Response<Body>, hyper::Error>(response)
                }
            }))
        }
    });

    let server = Server::bind(&addr).serve(make_svc);

    let graceful = server.with_graceful_shutdown(shutdown_callback());

    if let Err(e) = graceful.await {
        eprintln!("server error: {}", e);
    }
}

async fn shutdown_callback() {
    tokio::signal::ctrl_c()
        .await
        .expect("failed to install ctrl-c signal handler")
}

fn parse_query_params(query: &str) -> HashMap<String,String> {
    let mut hm = HashMap::new();
    let v: Vec<&str> = query.split("&").collect();
    v.iter().for_each(|element| {
        let v: Vec<&str> = element.split("=").collect();
        hm.insert(v[0].to_string(), v[1].to_string());
    });
    hm 
}

