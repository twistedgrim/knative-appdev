import { useEffect, useState } from "react";
import { Button } from "@/components/ui/button";

type ApiPayload = {
  message: string;
  timestamp: string;
};

export default function App() {
  const [data, setData] = useState<ApiPayload | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  const load = async () => {
    try {
      setLoading(true);
      setError(null);
      const res = await fetch("/api/message");
      if (!res.ok) {
        throw new Error(`request failed (${res.status})`);
      }
      const payload = (await res.json()) as ApiPayload;
      setData(payload);
    } catch (err) {
      setError(err instanceof Error ? err.message : "request failed");
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    void load();
  }, []);

  return (
    <main className="mx-auto flex min-h-screen max-w-4xl items-center px-6 py-16">
      <section className="w-full rounded-lg border bg-card p-8 shadow-sm">
        <p className="mb-2 text-xs uppercase tracking-wide text-muted-foreground">Knative Sample</p>
        <h1 className="text-3xl font-semibold tracking-tight">TypeScript React + Node.js</h1>
        <p className="mt-2 text-sm text-muted-foreground">
          Vite frontend with Tailwind and shadcn-style component structure.
        </p>

        <div className="mt-6 flex items-center gap-3">
          <Button onClick={load} disabled={loading}>
            {loading ? "Refreshing..." : "Refresh API"}
          </Button>
          <Button variant="outline" size="sm" onClick={() => setData(null)}>
            Clear
          </Button>
        </div>

        <div className="mt-6 rounded-md border bg-muted p-4 text-sm">
          {error && <p className="text-red-600">Error: {error}</p>}
          {!error && !data && <p className="text-muted-foreground">No API response yet.</p>}
          {data && (
            <>
              <p className="font-medium">{data.message}</p>
              <p className="mt-1 text-xs text-muted-foreground">{data.timestamp}</p>
            </>
          )}
        </div>
      </section>
    </main>
  );
}
