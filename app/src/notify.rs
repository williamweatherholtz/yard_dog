//! Operational visibility: derive health events from container states and
//! deliver them through a pluggable notification channel. Pure event logic +
//! a Notifier trait keep it testable; a stdout notifier is the default channel.

use std::io;

/// A container's current health, as reported by the runtime.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Health {
    Running,
    Exited,
    Unhealthy,
    Restarting,
}

/// One container's observed state.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ContainerState {
    pub name: String,
    pub health: Health,
}

/// A notable operational event about a container.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Event {
    pub container: String,
    pub kind: EventKind,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum EventKind {
    Down,
    Unhealthy,
}

/// Derive events from container states (healthy containers produce none).
pub fn events_from_states(states: &[ContainerState]) -> Vec<Event> {
    states
        .iter()
        .filter_map(|s| {
            let kind = match s.health {
                Health::Exited => EventKind::Down,
                Health::Unhealthy | Health::Restarting => EventKind::Unhealthy,
                Health::Running => return None,
            };
            Some(Event {
                container: s.name.clone(),
                kind,
            })
        })
        .collect()
}

/// Render an event as a human notification message.
pub fn format_event(event: &Event) -> String {
    match event.kind {
        EventKind::Down => format!("container '{}' is DOWN", event.container),
        EventKind::Unhealthy => format!("container '{}' is UNHEALTHY", event.container),
    }
}

/// A channel that delivers a notification message.
pub trait Notifier {
    fn send(&self, message: &str) -> io::Result<()>;
}

/// Send each event through the notifier; returns how many were sent.
pub fn dispatch(events: &[Event], notifier: &dyn Notifier) -> io::Result<usize> {
    for event in events {
        notifier.send(&format_event(event))?;
    }
    Ok(events.len())
}

/// The default channel: prints to stdout.
pub struct StdoutNotifier;
impl Notifier for StdoutNotifier {
    fn send(&self, message: &str) -> io::Result<()> {
        println!("{message}");
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::cell::RefCell;

    fn state(name: &str, health: Health) -> ContainerState {
        ContainerState {
            name: name.into(),
            health,
        }
    }

    #[test]
    fn derives_events_for_unhealthy_containers_only() {
        let states = vec![
            state("web", Health::Running),
            state("db", Health::Exited),
            state("cache", Health::Unhealthy),
            state("worker", Health::Restarting),
        ];
        let events = events_from_states(&states);
        assert_eq!(events.len(), 3);
        assert!(events.contains(&Event {
            container: "db".into(),
            kind: EventKind::Down
        }));
        assert!(events.contains(&Event {
            container: "cache".into(),
            kind: EventKind::Unhealthy
        }));
        assert!(events.contains(&Event {
            container: "worker".into(),
            kind: EventKind::Unhealthy
        }));
    }

    #[test]
    fn dispatch_formats_and_sends_one_message_per_event() {
        #[derive(Default)]
        struct Rec {
            msgs: RefCell<Vec<String>>,
        }
        impl Notifier for Rec {
            fn send(&self, message: &str) -> io::Result<()> {
                self.msgs.borrow_mut().push(message.to_string());
                Ok(())
            }
        }
        let events = vec![
            Event {
                container: "db".into(),
                kind: EventKind::Down,
            },
            Event {
                container: "cache".into(),
                kind: EventKind::Unhealthy,
            },
        ];
        let rec = Rec::default();
        let n = dispatch(&events, &rec).unwrap();
        assert_eq!(n, 2);
        let msgs = rec.msgs.borrow();
        assert!(msgs[0].contains("db") && msgs[0].to_lowercase().contains("down"));
        assert!(msgs[1].contains("cache") && msgs[1].to_lowercase().contains("unhealthy"));
    }
}
