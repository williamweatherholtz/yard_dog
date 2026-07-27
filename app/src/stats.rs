//! Per-container resource usage from `docker stats`. The parse is pure (unit-
//! tested); the docker shell-out is a thin adapter.

use std::collections::HashMap;

/// CPU% and memory-usage strings for one container, as docker reports them.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ContainerStat {
    pub cpu: String,
    pub mem: String,
}

/// Parse tab-separated `docker stats` output into a container-name -> stat map.
/// Expected line format: `NAME\tCPU%\tMEMUSAGE` (a stopped/absent container has
/// no line). Blank lines are skipped.
pub fn parse_container_stats(text: &str) -> HashMap<String, ContainerStat> {
    let mut out = HashMap::new();
    for line in text.lines() {
        let line = line.trim_end();
        if line.is_empty() {
            continue;
        }
        let mut parts = line.split('\t');
        if let (Some(name), Some(cpu), Some(mem)) = (parts.next(), parts.next(), parts.next()) {
            out.insert(name.trim().to_string(), ContainerStat { cpu: cpu.trim().to_string(), mem: mem.trim().to_string() });
        }
    }
    out
}

/// Live CPU/mem for the given container names via `docker stats --no-stream`.
/// Returns an empty map on any failure (nothing running / docker down).
pub fn stats_via_docker(names: &[String]) -> HashMap<String, ContainerStat> {
    if names.is_empty() {
        return HashMap::new();
    }
    let mut args: Vec<String> = vec![
        "stats".into(),
        "--no-stream".into(),
        "--format".into(),
        "{{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}".into(),
    ];
    args.extend(names.iter().cloned());
    match std::process::Command::new("docker").args(&args).output() {
        Ok(o) if o.status.success() => parse_container_stats(&String::from_utf8_lossy(&o.stdout)),
        _ => HashMap::new(),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_tab_separated_stats() {
        let text = "webapp-web-1\t0.03%\t3.4MiB / 256MiB\ndb-1\t1.20%\t42MiB / 512MiB\n\n";
        let m = parse_container_stats(text);
        assert_eq!(m.len(), 2);
        assert_eq!(m["webapp-web-1"].cpu, "0.03%");
        assert_eq!(m["webapp-web-1"].mem, "3.4MiB / 256MiB");
        assert_eq!(m["db-1"].cpu, "1.20%");
        // malformed / empty input is safe
        assert!(parse_container_stats("").is_empty());
        assert!(parse_container_stats("garbage-no-tabs").is_empty());
    }
}
