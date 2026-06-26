//! Authentication service: local credentials, JWTs, and Google OAuth wiring.

mod context;
pub(crate) mod extractor;
mod google;
mod jwt;
mod oauth;
mod password;
mod routes;
mod types;

pub(crate) use context::{AuthContext, require_auth};
pub(crate) use routes::router;
pub(crate) use types::{AuthResponse, LoginRequest, RegisterRequest};
pub(crate) use types::{auth_response, normalize_email, row_to_user};
