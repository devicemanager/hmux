import english from "../../messages/en.json";
import japanese from "../../messages/ja.json";

function shellQuote(value: string): string {
  return `'${value.replace(/'/g, "'\\''")}'`;
}

export function guestMessageShell(keys?: readonly string[]): string {
  const cases = Object.entries({ en: english.guestCLI, ja: japanese.guestCLI })
    .map(([locale, messages]) => [locale, Object.fromEntries(Object.entries(messages).filter(([key]) => !keys || keys.includes(key)))] as const)
    .flatMap(([locale, messages]) => Object.entries(messages).map(([key, message]) =>
      `    ${locale}/${key}) printf ${shellQuote(message + "\n")} "$@" ;;`,
    ))
    .join("\n");

  return `hmux_message() {
  case "\${LC_ALL:-\${LC_MESSAGES:-\${LANG:-en}}}" in
    ja*) hmux_message_locale=ja ;;
    *) hmux_message_locale=en ;;
  esac
  hmux_message_key="$1"; shift
  case "$hmux_message_locale/$hmux_message_key" in
${cases}
    *) return 1 ;;
  esac
}`;
}

export const GUEST_HMUX_MESSAGE_SHELL = guestMessageShell();
