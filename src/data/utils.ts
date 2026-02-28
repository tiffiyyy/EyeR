export function generateId(prefix: string): string {
  const entropy = Math.random().toString(36).slice(2, 10);
  return `${prefix}_${Date.now()}_${entropy}`;
}

export function nowIso(): string {
  return new Date().toISOString();
}
