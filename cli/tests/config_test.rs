use obercloud::config::{Config, Context};

#[test]
fn config_roundtrip() {
    let mut cfg = Config::default();
    cfg.active_context = Some("prod".into());
    cfg.contexts.insert(
        "prod".into(),
        Context {
            url: "https://prod.example.com".into(),
            api_key: Some("obk_test".into()),
        },
    );
    let s = toml::to_string(&cfg).unwrap();
    let parsed: Config = toml::from_str(&s).unwrap();
    assert_eq!(parsed.active_context.as_deref(), Some("prod"));
    assert_eq!(parsed.contexts["prod"].url, "https://prod.example.com");
}
