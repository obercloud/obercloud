use colored::Colorize;

pub fn success(msg: &str) {
    println!("{} {}", "✓".green(), msg);
}

pub fn error(msg: &str) {
    eprintln!("{} {}", "✗".red(), msg);
}

pub fn info(msg: &str) {
    println!("{} {}", "→".cyan(), msg);
}
