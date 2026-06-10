type AnalyticsParams = Record<string, string | number | boolean | null | undefined>;

declare global {
  interface Window {
    dataLayer?: Record<string, unknown>[];
    gtag?: (command: "event", eventName: string, params?: AnalyticsParams) => void;
  }
}

export function trackEvent(eventName: string, params: AnalyticsParams = {}) {
  if (typeof window === "undefined") return;

  const cleanParams = Object.fromEntries(
    Object.entries(params).filter(([, value]) => value !== undefined && value !== null),
  );

  window.dataLayer = window.dataLayer ?? [];
  window.dataLayer.push({
    event: eventName,
    ...cleanParams,
  });
}
