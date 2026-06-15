import type { IconName } from "@/components/Icon";

/** Status values used by the interactive product demo nodes. */
export type NodeStatus = "success" | "cached" | "error";

/** Mock trace session metadata shown in the product demo. */
export interface Session {
  id: string;
  title: string;
  trigger: string;
  startedAt: string;
}

/** Mock trace node shape used by the graph, sidebar, and inspector demos. */
export interface TraceNode {
  id: string;
  depth: number;
  step: string;
  status: NodeStatus;
  model: string;
  icon: IconName;
  timestamp: string;
  cost: string;
  latency: string;
  latencyMs: number;
  barPct: number;
  tokensIn: number;
  tokensOut: number;
  requestId: string;
  cacheStatus: string;
  temperature: number | null;
  error?: { code: string; message: string; detail: string };
  prompt: { system: string; user: string };
  response: { lang: "json" | "text"; text: string };
}

/** Demo session shown on the landing page. */
export const SESSION: Session = {
  id: "sess_a91f3c",
  title: "Customer Support Agent · Order #4471",
  trigger: "POST /v1/agent/run",
  startedAt: "14:22:07.184",
};

/** Demo trace graph shown on the landing page. */
export const NODES: TraceNode[] = [
  {
    id: "n1",
    depth: 0,
    step: "1. Intent Classification",
    status: "success",
    model: "gpt-4o",
    icon: "lightbulb",
    timestamp: "14:22:07",
    cost: "$0.0118",
    latency: "842ms",
    latencyMs: 842,
    barPct: 21,
    tokensIn: 412,
    tokensOut: 38,
    requestId: "req_7c1ae4",
    cacheStatus: "MISS",
    temperature: 0.0,
    prompt: {
      system:
        'You are an intent router for a customer-support agent.\nClassify the user\'s message into exactly one intent from:\n[order_status, refund_request, product_question, complaint, other].\nRespond ONLY with strict JSON: { "intent": string, "confidence": number }.',
      user: "Hey, I ordered a pair of trail runners last Tuesday (order 4471) and the tracking hasn't moved in 3 days. Where is my package?",
    },
    response: {
      lang: "json",
      text: `{
  "intent": "order_status",
  "confidence": 0.97,
  "entities": {
    "order_id": "4471",
    "product": "trail runners",
    "sentiment": "frustrated"
  }
}`,
    },
  },
  {
    id: "n2",
    depth: 1,
    step: "2. Vector DB Retrieval",
    status: "cached",
    model: "text-embedding-3-lg",
    icon: "database",
    timestamp: "14:22:08",
    cost: "$0.0000",
    latency: "0ms (cached)",
    latencyMs: 0,
    barPct: 4,
    tokensIn: 24,
    tokensOut: 0,
    requestId: "req_3f88ab",
    cacheStatus: "HIT",
    temperature: null,
    prompt: {
      system:
        "Embed the query and retrieve the top-k support documents from the `kb_support` namespace (k=4, threshold=0.78).",
      user: 'query: "order_status order 4471 shipping delayed tracking not updating"',
    },
    response: {
      lang: "json",
      text: `{
  "cache": "HIT",
  "embedding_hash": "e3b0c44298fc1c14",
  "matches": [
    { "doc": "shipping_delays.md#carrier-scan", "score": 0.913 },
    { "doc": "order_lookup_policy.md",          "score": 0.871 },
    { "doc": "refund_window.md",                "score": 0.804 },
    { "doc": "contact_escalation.md",           "score": 0.781 }
  ],
  "retrieved_from": "local_cache",
  "latency_ms": 0
}`,
    },
  },
  {
    id: "n3",
    depth: 2,
    step: "3. Context Synthesis",
    status: "success",
    model: "claude-3.5-sonnet",
    icon: "link",
    timestamp: "14:22:08",
    cost: "$0.0241",
    latency: "1.21s",
    latencyMs: 1210,
    barPct: 30,
    tokensIn: 1840,
    tokensOut: 256,
    requestId: "req_b20d9f",
    cacheStatus: "MISS",
    temperature: 0.3,
    prompt: {
      system:
        "Synthesize the retrieved knowledge-base passages with the order context into a grounded brief the response agent can use. Cite doc ids. Do not fabricate tracking events.",
      user: "intent=order_status; order=4471; docs=[shipping_delays.md#carrier-scan, order_lookup_policy.md]\nGoal: explain likely cause + next action.",
    },
    response: {
      lang: "json",
      text: `{
  "summary": "Order 4471 shows a carrier label created but no destination scan in 72h — matches the 'stuck in transit' pattern.",
  "grounded_facts": [
    "Policy: re-ship eligible after 5 business days w/o scan [order_lookup_policy.md]",
    "Carrier scans can lag 24-48h during peak [shipping_delays.md#carrier-scan]"
  ],
  "recommended_action": "lookup_order(4471) then offer reship or refund",
  "tone": "empathetic, concise"
}`,
    },
  },
  {
    id: "n4",
    depth: 3,
    step: "4. Tool · lookup_order",
    status: "success",
    model: "function-call",
    icon: "tool",
    timestamp: "14:22:09",
    cost: "$0.0000",
    latency: "318ms",
    latencyMs: 318,
    barPct: 8,
    tokensIn: 96,
    tokensOut: 142,
    requestId: "req_55c7e1",
    cacheStatus: "MISS",
    temperature: null,
    prompt: {
      system:
        "Tool invocation: lookup_order(order_id). Returns live fulfillment record from the internal OMS.",
      user: 'lookup_order(order_id="4471")',
    },
    response: {
      lang: "json",
      text: `{
  "order_id": "4471",
  "status": "in_transit",
  "carrier": "UPS",
  "tracking": "1Z999AA10123456784",
  "last_scan": "2026-05-25T09:11:00Z",
  "last_scan_location": "Hodgkins, IL",
  "expected_delivery": null,
  "reship_eligible": true
}`,
    },
  },
  {
    id: "n5",
    depth: 4,
    step: "5. Response Generation",
    status: "error",
    model: "local-llama-3.1-70b",
    icon: "error",
    timestamp: "14:22:13",
    cost: "$0.0000",
    latency: "4.10s (timeout)",
    latencyMs: 4100,
    barPct: 100,
    tokensIn: 2210,
    tokensOut: 0,
    requestId: "req_e0fa72",
    cacheStatus: "MISS",
    temperature: 0.7,
    error: {
      code: "UPSTREAM_TIMEOUT",
      message: "local runtime did not return within 4000ms deadline",
      detail:
        "POST http://127.0.0.1:11434/api/generate — connection reset after 4.10s (ctx window 8192 exceeded by 142 tokens)",
    },
    prompt: {
      system:
        "You are a warm, concise support agent. Use ONLY grounded_facts. Offer reship OR refund. Max 90 words.",
      user: "context: order 4471 in_transit, last scan 5 days ago in Hodgkins IL, reship_eligible=true. Draft the customer reply.",
    },
    response: {
      lang: "text",
      text: `Error: model runtime unreachable.

  at LocalLlamaProvider.generate (providers/local.ts:214)
  at AgentStep.run (engine/step.ts:88)
  at TraceSession.replay (engine/session.ts:301)

✗ stream aborted — 0 tokens emitted
✗ ctx_window_exceeded: 8334 / 8192
✗ downstream reply NOT delivered to user`,
    },
  },
];
