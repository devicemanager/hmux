import type { HmuxCommand } from "./generated/commands.js";
import type { HmuxAuthority } from "./generated/metadata.js";

export class HmuxError extends Error {
  constructor(message: string) {
    super(message);
    this.name = new.target.name;
  }
}

export class HmuxCommandError extends HmuxError {
  readonly commandId: unknown;
  readonly response: unknown;

  constructor(message: string, commandId?: unknown, response?: unknown) {
    super(message);
    this.commandId = commandId;
    this.response = response;
  }
}

export class HmuxConnectionError extends HmuxError {}
/** The server rejected the WebSocket credential before routing requests. */
export class HmuxAuthenticationRejectedError extends HmuxConnectionError {}
export class HmuxProtocolError extends HmuxError {}
export class HmuxTimeoutError extends HmuxError {}
export class HmuxAbortError extends HmuxError {}

/** A command was blocked locally because its authority was not enabled. */
export class HmuxAuthorityError extends HmuxError {
  readonly command: HmuxCommand;
  readonly requiredAuthority: HmuxAuthority;
  readonly grantedAuthorities: readonly HmuxAuthority[];

  constructor(
    command: HmuxCommand,
    requiredAuthority: HmuxAuthority,
    grantedAuthorities: readonly HmuxAuthority[],
  ) {
    super(`${command} requires ${requiredAuthority} authority`);
    this.command = command;
    this.requiredAuthority = requiredAuthority;
    this.grantedAuthorities = Object.freeze([...grantedAuthorities]);
  }
}
