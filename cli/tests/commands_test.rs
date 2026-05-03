use assert_cmd::Command;
use predicates::prelude::*;

#[test]
fn help_lists_subcommands() {
    let mut cmd = Command::cargo_bin("obercloud").unwrap();
    cmd.arg("--help");
    cmd.assert()
        .success()
        .stdout(predicate::str::contains("init"))
        .stdout(predicate::str::contains("context"))
        .stdout(predicate::str::contains("orgs"));
}
