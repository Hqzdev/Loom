use serde_json::{Map, Value, json};

pub(crate) fn info(event: &str, fields: Value) {
    emit("info", event, fields);
}

pub(crate) fn warn(event: &str, fields: Value) {
    emit("warn", event, fields);
}

pub(crate) fn error(event: &str, fields: Value) {
    emit("error", event, fields);
}

fn emit(level: &str, event: &str, fields: Value) {
    let mut object = match fields {
        Value::Object(object) => object,
        _ => Map::new(),
    };
    object.insert("level".to_string(), Value::String(level.to_string()));
    object.insert("event".to_string(), Value::String(event.to_string()));
    object.insert("timestamp".to_string(), json!(chrono::Utc::now()));
    eprintln!("{}", Value::Object(object));
}
