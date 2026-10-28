use hmux::{Config, Error, ReadScreenOptions, Result, RunCommand};
use std::env;
use std::thread;
use std::time::{Duration, Instant};

fn main() -> Result<()> {
    let socket = env::var("HMUX_TUI_SOCKET")
        .map_err(|_| Error::Connection("HMUX_TUI_SOCKET is required".to_string()))?;
    let client = hmux::Client::connect(Config::from_socket_path(socket))?;
    let session = client.current_session();
    let workspace = session.create_workspace(Some("rust-sdk-e2e".to_string()))?;
    let marker = format!("HMUX_RUST_RESOURCE_E2E_{}", std::process::id());
    let terminal =
        workspace.resource.run(RunCommand::argv(["printf", &format!("{marker}\\n")])?)?;

    let deadline = Instant::now() + Duration::from_secs(5);
    loop {
        let screen = terminal.resource.read_screen(ReadScreenOptions)?;
        if screen.text.contains(&marker) {
            break;
        }
        if Instant::now() >= deadline {
            return Err(Error::Timeout("marker did not reach terminal screen".to_string()));
        }
        thread::sleep(Duration::from_millis(50));
    }

    workspace.resource.close()?;
    client.close()
}
