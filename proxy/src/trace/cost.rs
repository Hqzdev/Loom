//! Token cost estimation for captured trace rows.
//!
//! Rates are first-party USD prices per million tokens checked on 2026-06-14.
//! Unknown models intentionally return zero rather than showing a bad estimate.

/// Estimates the request cost in USD using provider/model token pricing.
pub(super) fn estimate_cost(
    provider: &str,
    model: &str,
    tokens_in: i64,
    tokens_out: i64,
) -> String {
    let Some(rate) = rate_for(provider, model) else {
        return "$0.0000".to_string();
    };
    let input = tokens_in.max(0) as f64 * rate.input_per_mtok / 1_000_000.0;
    let output = tokens_out.max(0) as f64 * rate.output_per_mtok / 1_000_000.0;
    format!("${:.4}", input + output)
}

/// Returns the best local price match for a known provider/model family.
fn rate_for(provider: &str, model: &str) -> Option<Rate> {
    let provider = provider.to_ascii_lowercase();
    let model = model.to_ascii_lowercase();

    if provider == "openai" || model.starts_with("gpt-") {
        return openai_rate(&model);
    }
    if provider == "anthropic" || model.contains("claude") {
        return anthropic_rate(&model);
    }
    None
}

/// Matches current OpenAI flagship text models at standard short-context rates.
fn openai_rate(model: &str) -> Option<Rate> {
    if model.contains("gpt-5.5-pro") || model.contains("gpt-5.4-pro") {
        Some(Rate::new(30.0, 180.0))
    } else if model.contains("gpt-5.5") {
        Some(Rate::new(5.0, 30.0))
    } else if model.contains("gpt-5.4-mini") {
        Some(Rate::new(0.75, 4.50))
    } else if model.contains("gpt-5.4-nano") {
        Some(Rate::new(0.20, 1.25))
    } else if model.contains("gpt-5.4") {
        Some(Rate::new(2.50, 15.0))
    } else if model.starts_with("gpt-4o-mini") {
        Some(Rate::new(0.15, 0.60))
    } else if model.starts_with("gpt-4o") {
        Some(Rate::new(2.50, 10.0))
    } else if model.starts_with("gpt-4.1-mini") {
        Some(Rate::new(0.40, 1.60))
    } else if model.starts_with("gpt-4.1-nano") {
        Some(Rate::new(0.10, 0.40))
    } else if model.starts_with("gpt-4.1") {
        Some(Rate::new(2.0, 8.0))
    } else if model.starts_with("o4-mini") || model.starts_with("o3-mini") {
        Some(Rate::new(1.10, 4.40))
    } else if model.starts_with("o3") {
        Some(Rate::new(2.0, 8.0))
    } else if model.starts_with("o1-mini") {
        Some(Rate::new(1.10, 4.40))
    } else if model.starts_with("o1") {
        Some(Rate::new(15.0, 60.0))
    } else if model.starts_with("gpt-4-turbo") {
        Some(Rate::new(10.0, 30.0))
    } else if model.starts_with("gpt-4") {
        Some(Rate::new(30.0, 60.0))
    } else if model.starts_with("gpt-3.5") {
        Some(Rate::new(0.50, 1.50))
    } else {
        None
    }
}

/// Matches current Anthropic Claude API base token rates.
fn anthropic_rate(model: &str) -> Option<Rate> {
    if model.contains("opus-4-8")
        || model.contains("opus-4.8")
        || model.contains("opus-4-7")
        || model.contains("opus-4.7")
        || model.contains("opus-4-6")
        || model.contains("opus-4.6")
        || model.contains("opus-4-5")
        || model.contains("opus-4.5")
    {
        Some(Rate::new(5.0, 25.0))
    } else if model.contains("opus-4-1") || model.contains("opus-4.1") || model.contains("opus-4") {
        Some(Rate::new(15.0, 75.0))
    } else if model.contains("sonnet-4") {
        Some(Rate::new(3.0, 15.0))
    } else if model.contains("haiku-4-5") || model.contains("haiku-4.5") {
        Some(Rate::new(1.0, 5.0))
    } else if model.contains("sonnet-3-5") || model.contains("sonnet-3.5") {
        Some(Rate::new(3.0, 15.0))
    } else if model.contains("haiku-3-5") || model.contains("haiku-3.5") {
        Some(Rate::new(0.80, 4.0))
    } else if model.contains("opus-3") {
        Some(Rate::new(15.0, 75.0))
    } else if model.contains("haiku-3") {
        Some(Rate::new(0.25, 1.25))
    } else {
        None
    }
}

/// A model's input/output prices per one million tokens.
struct Rate {
    input_per_mtok: f64,
    output_per_mtok: f64,
}

impl Rate {
    /// Creates a rate from provider-published dollars-per-million-token values.
    fn new(input_per_mtok: f64, output_per_mtok: f64) -> Self {
        Self {
            input_per_mtok,
            output_per_mtok,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    /// Verifies current OpenAI standard short-context token pricing.
    #[test]
    fn estimates_openai_standard_short_context_cost() {
        let cost = estimate_cost("openai", "gpt-5.5", 1_000, 2_000);
        assert_eq!(cost, "$0.0650");
    }

    /// Verifies current Anthropic Sonnet base token pricing.
    #[test]
    fn estimates_anthropic_sonnet_cost() {
        let cost = estimate_cost("anthropic", "claude-sonnet-4-6", 1_000_000, 1_000_000);
        assert_eq!(cost, "$18.0000");
    }

    /// Verifies unknown models do not receive speculative prices.
    #[test]
    fn unknown_models_get_zero_cost_instead_of_guessing() {
        let cost = estimate_cost("openai", "gpt-unknown", 1_000_000, 1_000_000);
        assert_eq!(cost, "$0.0000");
    }
}
