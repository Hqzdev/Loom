import type {
  AgentNode,
  TraceDownstreamResult,
  TraceInvalidationResult,
  TraceReplayResult,
  TraceSnapshot
} from "../domain/trace";
import { invoke } from "@tauri-apps/api/core";

type ProxyBridgeResponse = {
  status: number;
  body: string;
};

export class TetherProxyClient {
  private readonly baseUrl: string;
  private readonly workspaceId: string;

  constructor(baseUrl = "http://127.0.0.1:8080", workspaceId = "local-default") {
    this.baseUrl = baseUrl.replace(/\/$/, "");
    this.workspaceId = workspaceId;
  }

  async health(): Promise<boolean> {
    try {
      const response = await this.request("/api/events/health", "GET");
      return response.status >= 200 && response.status < 300;
    } catch {
      return false;
    }
  }

  async currentTraceSummary(): Promise<TraceSnapshot> {
    return this.read<TraceSnapshot>("/api/traces/current/summary");
  }

  async currentTrace(): Promise<TraceSnapshot> {
    return this.read<TraceSnapshot>("/api/traces/current");
  }

  async traceNodeDetail(nodeId: string): Promise<AgentNode> {
    return this.read<AgentNode>(`/api/traces/${encodeURIComponent(nodeId)}`);
  }

  async downstreamNodes(nodeId: string): Promise<TraceDownstreamResult> {
    return this.read<TraceDownstreamResult>(`/api/traces/${encodeURIComponent(nodeId)}/downstream`);
  }

  async editNodeOutput(nodeId: string, output: string): Promise<TraceInvalidationResult> {
    return this.write<TraceInvalidationResult>(`/api/traces/${encodeURIComponent(nodeId)}/output`, "PATCH", {
      output
    });
  }

  async replayNode(nodeId: string): Promise<TraceReplayResult> {
    return this.write<TraceReplayResult>(`/api/traces/${encodeURIComponent(nodeId)}/replay`, "POST");
  }

  async clearTrace(): Promise<void> {
    await this.write<void>("/api/traces/current", "DELETE");
  }

  async clearCache(): Promise<void> {
    await this.write<void>("/api/cache", "DELETE");
  }

  private async read<Value>(path: string): Promise<Value> {
    const response = await this.request(path, "GET");
    return this.decode<Value>(response);
  }

  private async write<Value>(path: string, method: string, body?: unknown): Promise<Value> {
    const response = await this.request(path, method, body);
    return this.decode<Value>(response);
  }

  private async request(path: string, method: string, body?: unknown): Promise<Response | ProxyBridgeResponse> {
    try {
      return await invoke<ProxyBridgeResponse>("proxy_request", {
        request: {
          method,
          path,
          body: body === undefined ? null : JSON.stringify(body),
          workspace_id: this.workspaceId
        }
      });
    } catch (error) {
      if (!this.isTauriUnavailable(error)) {
        throw error;
      }
    }

    return fetch(`${this.baseUrl}${path}`, {
      method,
      headers: this.headers(body !== undefined),
      body: body === undefined ? undefined : JSON.stringify(body)
    });
  }

  private headers(json = false): HeadersInit {
    const headers: Record<string, string> = {
      "x-tether-workspace": this.workspaceId
    };

    if (json) {
      headers["content-type"] = "application/json";
    }

    return headers;
  }

  private async decode<Value>(response: Response | ProxyBridgeResponse): Promise<Value> {
    if (!this.ok(response.status)) {
      const message = response instanceof Response ? await response.text() : response.body;
      throw new Error(message || `Proxy returned HTTP ${response.status}`);
    }

    if (response.status === 204) {
      return undefined as Value;
    }

    if (response instanceof Response) {
      return response.json() as Promise<Value>;
    }

    return JSON.parse(response.body) as Value;
  }

  private ok(status: number) {
    return status >= 200 && status < 300;
  }

  private isTauriUnavailable(error: unknown): boolean {
    const message = error instanceof Error ? error.message : String(error);
    return message.includes("__TAURI") || message.includes("not a function") || message.includes("undefined");
  }
}
