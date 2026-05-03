use crate::{CliError, Result};
use std::path::Path;
use std::process::{Command, Stdio};

pub fn run(workdir: &Path, args: &[&str]) -> Result<String> {
    let output = Command::new("tofu")
        .args(args)
        .current_dir(workdir)
        .stdin(Stdio::null())
        .stderr(Stdio::inherit())
        .output()?;

    if !output.status.success() {
        return Err(CliError::Tofu(format!("tofu {:?} failed", args)));
    }
    Ok(String::from_utf8_lossy(&output.stdout).to_string())
}
