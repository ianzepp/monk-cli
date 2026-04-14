use std::{
    env, fs,
    path::{Path, PathBuf},
};

use serde::{Deserialize, Serialize};

use crate::error::MonkError;

const CONFIG_DIR_NAME: &str = "monk";
const CONFIG_FILE_NAME: &str = "config.json";

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct MonkConfig {
    #[serde(default = "MonkConfig::default_base_url")]
    pub base_url: String,
    #[serde(default)]
    pub token: Option<String>,
    #[serde(default = "MonkConfig::default_output_format")]
    pub output_format: OutputFormat,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq, Default)]
#[serde(rename_all = "lowercase")]
pub enum OutputFormat {
    #[default]
    Json,
    Toon,
    Yaml,
}

impl MonkConfig {
    pub fn new(base_url: impl Into<String>) -> Self {
        Self {
            base_url: base_url.into(),
            token: None,
            output_format: OutputFormat::Json,
        }
    }

    pub fn from_env() -> Self {
        let mut config = Self::default();
        config.apply_env_overrides();
        config
    }

    pub fn load_effective() -> Result<Self, MonkError> {
        let mut config = Self::load().unwrap_or_default();
        config.apply_env_overrides();
        Ok(config)
    }

    pub fn apply_env_overrides(&mut self) {
        if let Ok(base_url) = env::var("MONK_API_BASE_URL") {
            self.base_url = base_url;
        }

        if let Ok(token) = env::var("MONK_API_TOKEN") {
            self.token = Some(token);
        }

        if let Ok(format) = env::var("MONK_API_FORMAT") {
            self.output_format = format.parse().unwrap_or_default();
        }
    }

    pub fn config_path() -> Result<PathBuf, MonkError> {
        let base = dirs::config_dir().ok_or(MonkError::ConfigPathUnavailable)?;
        Ok(base.join(CONFIG_DIR_NAME).join(CONFIG_FILE_NAME))
    }

    pub fn load() -> Result<Self, MonkError> {
        let path = Self::config_path()?;
        Self::load_from_path(&path)
    }

    pub fn load_from_path(path: impl AsRef<Path>) -> Result<Self, MonkError> {
        let path = path.as_ref();
        let raw = fs::read_to_string(path).map_err(|source| MonkError::ConfigRead {
            path: path.display().to_string(),
            source,
        })?;
        serde_json::from_str(&raw).map_err(MonkError::ConfigDeserialize)
    }

    pub fn save(&self) -> Result<(), MonkError> {
        let path = Self::config_path()?;
        self.save_to_path(&path)
    }

    pub fn save_to_path(&self, path: impl AsRef<Path>) -> Result<(), MonkError> {
        let path = path.as_ref();
        if let Some(parent) = path.parent() {
            fs::create_dir_all(parent).map_err(|source| MonkError::ConfigWrite {
                path: parent.display().to_string(),
                source,
            })?;
        }

        let json = serde_json::to_string_pretty(self).map_err(MonkError::ConfigSerialize)?;
        fs::write(path, json).map_err(|source| MonkError::ConfigWrite {
            path: path.display().to_string(),
            source,
        })
    }

    pub fn with_token(mut self, token: impl Into<String>) -> Self {
        self.token = Some(token.into());
        self
    }

    pub fn clear_token(&mut self) {
        self.token = None;
    }

    pub fn token(&self) -> Option<&str> {
        self.token.as_deref()
    }

    pub fn set_token(&mut self, token: impl Into<String>) {
        self.token = Some(token.into());
    }

    pub fn base_url(&self) -> Result<url::Url, MonkError> {
        url::Url::parse(&self.base_url)
            .map_err(|_| MonkError::InvalidBaseUrl(self.base_url.clone()))
    }
}

impl Default for MonkConfig {
    fn default() -> Self {
        Self {
            base_url: Self::default_base_url(),
            token: None,
            output_format: Self::default_output_format(),
        }
    }
}

impl MonkConfig {
    fn default_base_url() -> String {
        "https://monk-api.com".to_string()
    }

    fn default_output_format() -> OutputFormat {
        OutputFormat::Json
    }
}

#[cfg(test)]
mod tests {
    use std::time::{SystemTime, UNIX_EPOCH};

    use super::{MonkConfig, OutputFormat};

    #[test]
    fn default_base_url_points_to_public_api() {
        assert_eq!(MonkConfig::default().base_url, "https://monk-api.com");
    }

    #[test]
    fn save_and_load_round_trips_token_state() {
        let stamp = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .expect("system clock should be after unix epoch")
            .as_nanos();
        let path = std::env::temp_dir().join(format!("monk-config-{stamp}.json"));

        let config = MonkConfig {
            base_url: "https://example.com".to_string(),
            token: Some("jwt-one".to_string()),
            output_format: OutputFormat::Yaml,
        };

        config.save_to_path(&path).expect("config should save");
        let loaded = MonkConfig::load_from_path(&path).expect("config should load");

        assert_eq!(loaded.base_url, "https://example.com");
        assert_eq!(loaded.token.as_deref(), Some("jwt-one"));
        assert_eq!(loaded.output_format, OutputFormat::Yaml);

        let _ = std::fs::remove_file(&path);
    }

    #[test]
    fn token_set_and_clear_behaves_like_logout() {
        let mut config = MonkConfig::default();

        config.set_token("jwt-two");
        assert_eq!(config.token.as_deref(), Some("jwt-two"));

        config.clear_token();
        assert_eq!(config.token, None);
    }
}

impl OutputFormat {
    pub fn as_str(&self) -> &'static str {
        match self {
            OutputFormat::Json => "json",
            OutputFormat::Toon => "toon",
            OutputFormat::Yaml => "yaml",
        }
    }
}

impl std::str::FromStr for OutputFormat {
    type Err = ();

    fn from_str(value: &str) -> Result<Self, Self::Err> {
        match value.to_ascii_lowercase().as_str() {
            "json" => Ok(OutputFormat::Json),
            "toon" => Ok(OutputFormat::Toon),
            "yaml" => Ok(OutputFormat::Yaml),
            _ => Err(()),
        }
    }
}
