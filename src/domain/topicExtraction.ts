export function extractTopicsFromText(input: string): string[] {
  // TODO(real-nlp): Replace keyword parsing with proper topic extraction model.
  return input
    .split(/[,\s]+/)
    .map((topic) => topic.trim().toLowerCase())
    .filter((topic) => topic.length >= 3)
    .slice(0, 8);
}
