use crate::error::ApiError;

pub(super) fn theme(value: &str) -> Result<String, ApiError> {
    match value {
        "system" | "light" | "dark" => Ok(value.to_string()),
        _ => Err(ApiError::bad_request(
            "theme must be system, light, or dark",
        )),
    }
}

pub(super) fn proxy_port(value: i32) -> Result<i32, ApiError> {
    if !(1..=65535).contains(&value) {
        return Err(ApiError::bad_request(
            "proxy_port must be between 1 and 65535",
        ));
    }
    Ok(value)
}

pub(super) fn profile_name(value: &str) -> Result<String, ApiError> {
    let value = value.trim();
    if value.is_empty() || value.len() > 120 {
        return Err(ApiError::bad_request(
            "name must be between 1 and 120 characters",
        ));
    }
    Ok(value.to_string())
}

pub(super) fn provider_key(value: &str, label: &str) -> Result<Option<String>, ApiError> {
    let value = value.trim();
    if value.is_empty() {
        return Ok(None);
    }
    if value.len() > 4096 || value.chars().any(char::is_control) {
        return Err(ApiError::bad_request(format!("{label} is invalid")));
    }
    Ok(Some(value.to_string()))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn accepts_supported_themes() {
        assert_eq!(theme("system").unwrap(), "system");
        assert_eq!(theme("light").unwrap(), "light");
        assert_eq!(theme("dark").unwrap(), "dark");
    }

    #[test]
    fn rejects_unknown_theme() {
        let error = theme("midnight").unwrap_err();
        assert_eq!(error.status, axum::http::StatusCode::BAD_REQUEST);
    }

    #[test]
    fn validates_proxy_port_range() {
        assert_eq!(proxy_port(1).unwrap(), 1);
        assert_eq!(proxy_port(65535).unwrap(), 65535);
        assert!(proxy_port(0).is_err());
        assert!(proxy_port(65536).is_err());
    }

    #[test]
    fn trims_profile_names_and_rejects_empty_values() {
        assert_eq!(profile_name(" Ada ").unwrap(), "Ada");
        assert!(profile_name(" ").is_err());
    }

    #[test]
    fn rejects_oversized_profile_names() {
        assert!(profile_name(&"x".repeat(121)).is_err());
    }

    #[test]
    fn normalizes_provider_keys_without_exposing_values() {
        assert_eq!(
            provider_key(" sk-test ", "OpenAI API key").unwrap(),
            Some("sk-test".to_string())
        );
        assert_eq!(provider_key(" ", "OpenAI API key").unwrap(), None);
    }

    #[test]
    fn rejects_control_characters_and_oversized_provider_keys() {
        assert!(provider_key("abc\n123", "OpenAI API key").is_err());
        assert!(provider_key(&"x".repeat(4097), "OpenAI API key").is_err());
    }
}
