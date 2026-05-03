use crate::{config::Config, CliError, Result};
use serde::{de::DeserializeOwned, Serialize};

pub struct Client {
    base_url: String,
    api_key: String,
    http: reqwest::Client,
}

impl Client {
    pub fn from_config() -> Result<Self> {
        let cfg = Config::load()?;
        let ctx = cfg.active()?;
        let api_key = ctx
            .api_key
            .clone()
            .ok_or_else(|| CliError::Config("no api_key — run `obercloud auth login`".into()))?;
        Ok(Self::new_for_test(&ctx.url, &api_key))
    }

    pub fn new_for_test(url: &str, api_key: &str) -> Self {
        Self {
            base_url: url.to_string(),
            api_key: api_key.to_string(),
            http: reqwest::Client::new(),
        }
    }

    pub async fn get<T: DeserializeOwned>(&self, path: &str) -> Result<T> {
        let r = self
            .http
            .get(format!("{}{}", self.base_url, path))
            .bearer_auth(&self.api_key)
            .header("accept", "application/vnd.api+json")
            .send()
            .await?;
        Self::parse(r).await
    }

    pub async fn post<B: Serialize, T: DeserializeOwned>(&self, path: &str, body: &B) -> Result<T> {
        let r = self
            .http
            .post(format!("{}{}", self.base_url, path))
            .bearer_auth(&self.api_key)
            .header("accept", "application/vnd.api+json")
            .header("content-type", "application/vnd.api+json")
            .json(body)
            .send()
            .await?;
        Self::parse(r).await
    }

    pub async fn delete(&self, path: &str) -> Result<()> {
        let r = self
            .http
            .delete(format!("{}{}", self.base_url, path))
            .bearer_auth(&self.api_key)
            .send()
            .await?;
        if !r.status().is_success() {
            let status = r.status().as_u16();
            return Err(CliError::Api {
                status,
                message: r.text().await?,
            });
        }
        Ok(())
    }

    async fn parse<T: DeserializeOwned>(r: reqwest::Response) -> Result<T> {
        if r.status().is_success() {
            Ok(r.json().await?)
        } else {
            let status = r.status().as_u16();
            Err(CliError::Api {
                status,
                message: r.text().await?,
            })
        }
    }
}
