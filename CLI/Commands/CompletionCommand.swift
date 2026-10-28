import ArgumentParser
import Foundation

struct Completion: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "completion",
        abstract: String(
            localized: "cli.command.completion.abstract",
            defaultValue: "Print a shell completion script for hmux."
        ),
        discussion: String(
            localized: "cli.command.completion.discussion",
            defaultValue: """
            Add the matching line to your shell startup file:
              zsh:  eval "$(hmux completion zsh)"
              bash: eval "$(hmux completion bash)"
              fish: hmux completion fish | source
            """
        )
    )

    @Argument(
        help: ArgumentHelp(
            String(
                localized: "cli.command.completion.shell.help",
                defaultValue: "Shell to generate a script for."
            )
        ),
        completion: .list(["bash", "zsh", "fish"])
    )
    var shell: String

    func run() throws {
        guard let kind = CompletionShell(rawValue: shell) else {
            throw CLIError(
                message: String.localizedStringWithFormat(
                    String(
                        localized: "cli.command.completion.unsupportedShell",
                        defaultValue: "Unsupported shell '%@'. Supported: bash, zsh, fish."
                    ),
                    shell
                ),
                exitCode: 2
            )
        }
        print(HmuxCommand.completionScript(for: kind))
    }
}
