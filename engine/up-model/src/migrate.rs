//! Schema versioning and migrations.
//!
//! Every document stores `schemaVersion`. Loading goes through a
//! [`Migrator`], which upgrades the raw JSON step by step (`v → v+1`)
//! before deserializing into the current Rust type. Adding a schema change:
//! bump the constant, register a step that rewrites the previous shape.

use serde::de::DeserializeOwned;
use serde_json::Value;
use up_core::{UpError, UpResult};

pub const KIT_SCHEMA_VERSION: u32 = 1;
pub const PROJECT_SCHEMA_VERSION: u32 = 1;

/// Migration step: transforms a document at version `from` into `from + 1`.
pub type MigrationFn = fn(&mut Value) -> UpResult<()>;

pub struct Migrator<T> {
    current: u32,
    steps: Vec<(u32, MigrationFn)>,
    _t: std::marker::PhantomData<fn() -> T>,
}

impl<T: DeserializeOwned> Migrator<T> {
    pub fn new(current: u32) -> Self {
        Self {
            current,
            steps: Vec::new(),
            _t: std::marker::PhantomData,
        }
    }

    /// Register a step `from → from + 1`.
    pub fn step(mut self, from: u32, f: MigrationFn) -> Self {
        self.steps.push((from, f));
        self
    }

    /// Upgrade raw JSON in place to the current version.
    pub fn upgrade(&self, doc: &mut Value) -> UpResult<()> {
        let obj = doc
            .as_object_mut()
            .ok_or_else(|| UpError::format("document must be a JSON object"))?;
        // Documents written before versioning count as version 0.
        let mut v = obj
            .get("schemaVersion")
            .and_then(Value::as_u64)
            .unwrap_or(0) as u32;
        if v > self.current {
            return Err(UpError::format(format!(
                "document schema v{v} is newer than supported v{}",
                self.current
            )));
        }
        while v < self.current {
            let step = self
                .steps
                .iter()
                .find(|(from, _)| *from == v)
                .map(|(_, f)| *f);
            // Without a registered step only the version number changes.
            if let Some(f) = step {
                f(doc)?;
            }
            v += 1;
            if let Some(o) = doc.as_object_mut() {
                o.insert("schemaVersion".into(), Value::from(v));
            }
        }
        Ok(())
    }

    pub fn load_value(&self, mut doc: Value) -> UpResult<T> {
        self.upgrade(&mut doc)?;
        serde_json::from_value(doc).map_err(|e| UpError::format(e.to_string()))
    }

    pub fn load(&self, json: &str) -> UpResult<T> {
        let v: Value = serde_json::from_str(json).map_err(|e| UpError::format(e.to_string()))?;
        self.load_value(v)
    }
}

/// v0 kits (pre-versioning drafts) stored pads as `{"pads": {"A0": {...}}}`;
/// v1 uses a list with explicit `pad` ids.
fn kit_v0_to_v1(doc: &mut Value) -> UpResult<()> {
    let Some(obj) = doc.as_object_mut() else {
        return Ok(());
    };
    if let Some(Value::Object(map)) = obj.get("pads").cloned() {
        let mut list = Vec::new();
        for (label, mut pad) in map {
            let id = up_core::PadId::parse(&label)?;
            if let Some(p) = pad.as_object_mut() {
                p.insert(
                    "pad".into(),
                    serde_json::to_value(id).map_err(|e| UpError::format(e.to_string()))?,
                );
            }
            list.push(pad);
        }
        obj.insert("pads".into(), Value::Array(list));
    }
    Ok(())
}

pub fn kit_migrator() -> Migrator<crate::KitDoc> {
    Migrator::new(KIT_SCHEMA_VERSION).step(0, kit_v0_to_v1)
}

pub fn project_migrator() -> Migrator<crate::Project> {
    Migrator::new(PROJECT_SCHEMA_VERSION)
}

impl crate::KitDoc {
    pub fn to_json(&self) -> UpResult<String> {
        serde_json::to_string_pretty(self).map_err(|e| UpError::format(e.to_string()))
    }

    /// Parse and migrate to the current schema.
    pub fn from_json(s: &str) -> UpResult<Self> {
        let k = kit_migrator().load(s)?;
        k.validate()?;
        Ok(k)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use up_core::PadId;

    #[test]
    fn kit_v0_is_migrated() {
        let v0 = r#"{"name":"Old","pads":{"B1":{"name":"x","mode":"Loop"}}}"#;
        let k = crate::KitDoc::from_json(v0).unwrap();
        assert_eq!(k.schema_version, 1);
        assert_eq!(k.pads[0].pad, PadId { bank: 1, index: 1 });
        assert_eq!(k.pads[0].mode, up_core::PadMode::Loop);
    }

    #[test]
    fn newer_schema_rejected() {
        let err = crate::KitDoc::from_json(r#"{"schemaVersion":99}"#).unwrap_err();
        assert_eq!(err.code, up_core::ErrorCode::Format);
    }

    #[test]
    fn custom_steps_run_in_order() {
        fn add_a(v: &mut Value) -> UpResult<()> {
            v["log"] = Value::from("a");
            Ok(())
        }
        fn add_b(v: &mut Value) -> UpResult<()> {
            let s = v["log"].as_str().unwrap_or("").to_owned();
            v["log"] = Value::from(s + "b");
            Ok(())
        }
        let m = Migrator::<Value>::new(3).step(1, add_b).step(0, add_a);
        let out = m.load("{}").unwrap();
        assert_eq!(out["log"], "ab");
        assert_eq!(out["schemaVersion"], 3);
    }
}
