#![doc = include_str!("../README.md")]
use std::net::SocketAddr;

/// A wrapper type for a closure that returns an [ntex::web::ServiceConfig] so we can implement
/// [shuttle_runtime::Service] for it.
#[derive(Clone)]
pub struct NtexWebService<F>(pub F);

#[shuttle_runtime::async_trait]
impl<F> shuttle_runtime::Service for NtexWebService<F>
where
    F: FnOnce(&mut ntex::web::ServiceConfig) + Send + Clone + 'static,
{
    async fn bind(mut self, addr: SocketAddr) -> Result<(), shuttle_runtime::Error> {
        // Start a worker for each cpu, but no more than 4.
        let worker_count = num_cpus::get().min(4);

        let server =
            ntex::web::HttpServer::new(move || ntex::web::App::new().configure(self.0.clone()))
                .workers(worker_count)
                .bind(addr)?
                .run();

        server.await.map_err(shuttle_runtime::CustomError::new)?;

        Ok(())
    }
}

impl<F> From<F> for NtexWebService<F>
where
    F: FnOnce(&mut ntex::web::ServiceConfig) + Send + Clone + 'static,
{
    fn from(service_config: F) -> Self {
        Self(service_config)
    }
}

#[doc = include_str!("../README.md")]
pub type ShuttleNtexWeb<F> = Result<NtexWebService<F>, shuttle_runtime::Error>;
