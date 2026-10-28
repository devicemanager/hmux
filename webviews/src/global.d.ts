import type { DiffResponse } from "./diff/generated/protocol";

export {};

type AgentSessionNativeReply =
  | { ok: true; value: unknown }
  | { ok: false; error?: { code?: string; userMessage?: string } };

declare global {
  /// Opaque sanitizer policy built by `Resources/markdown-viewer/markdown-sanitizer.js`.
  type HmuxMarkdownSanitizerProfile = { readonly __hmuxMarkdownSanitizerProfile?: never };

  type HmuxMarkdownSanitizerURLContext = {
    namespace: string;
    tag: string;
    name: string;
    value: string;
  };

  var HmuxMarkdownSanitizer: {
    markdownProfile(options?: {
      removeElements?: string[];
      extraAttributes?: Record<string, string[]>;
      url?: (context: HmuxMarkdownSanitizerURLContext) => string | null;
      element?: (source: Element, clean: Element) => boolean;
    }): HmuxMarkdownSanitizerProfile;
    diagramProfile(): HmuxMarkdownSanitizerProfile;
    sanitizeToFragment(
      html: string,
      options: { document: Document; profile: HmuxMarkdownSanitizerProfile },
    ): DocumentFragment;
    serializeFragment(fragment: DocumentFragment, targetDocument: Document): string;
    sanitizeCSS(text: string): string | null;
  };

  var HmuxViewerNavigation: {
    install(options: {
      target: Document | HTMLElement;
      getScroller: () => HTMLElement;
      shortcuts: Record<string, unknown>;
    }): () => void;
    installManualInputReset(options: {
      target: Document | HTMLElement;
      getScroller: () => HTMLElement;
    }): () => void;
    performAction(action: string, scroller: HTMLElement): boolean;
    resetSmoothTarget(scroller: HTMLElement): void;
  };

  interface Window {
    __hmuxPerformDiffViewerNavigationAction?: (action: string) => boolean;
    __hmuxDiffViewer?: {
      codeView?: unknown;
      codeViewItems?: unknown[];
      items?: unknown[];
      state?: unknown;
      streamMetrics?: unknown;
      workerPool?: unknown;
    };
    webkit?: {
      messageHandlers?: {
        agentSession?: {
          postMessage(message: unknown): Promise<AgentSessionNativeReply>;
        };
        hmuxDiff?: {
          postMessage(message: unknown): Promise<DiffResponse>;
        };
      };
    };
  }
}
