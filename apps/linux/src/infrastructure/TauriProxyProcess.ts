import { invoke } from "@tauri-apps/api/core";

type ProxyStartResult = {
  started: boolean;
  already_running: boolean;
  binary_path?: string | null;
};

export class TauriProxyProcess {
  isAvailable(): boolean {
    return typeof window !== "undefined";
  }

  async health(port = 8080): Promise<boolean> {
    try {
      return await invoke<boolean>("proxy_health", { port });
    } catch {
      return false;
    }
  }

  async start(port = 8080): Promise<ProxyStartResult> {
    this.ensureAvailable();
    return this.invokeDesktop<ProxyStartResult>("start_proxy", { port });
  }

  async stop(): Promise<boolean> {
    this.ensureAvailable();
    return this.invokeDesktop<boolean>("stop_proxy");
  }

  private ensureAvailable() {
    if (typeof window === "undefined") {
      throw new Error("Open the Tether desktop window to start the local proxy. Browser preview cannot run Tauri commands.");
    }
  }

  private async invokeDesktop<Value>(command: string, payload?: Record<string, unknown>): Promise<Value> {
    try {
      return await invoke<Value>(command, payload);
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      if (message.includes("__TAURI") || message.includes("not a function") || message.includes("undefined")) {
        throw new Error("Open the Tether desktop window to run proxy commands. Safari preview is visual only.");
      }
      throw error;
    }
  }
}
