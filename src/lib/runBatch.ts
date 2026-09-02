// Wait for every worker before returning, including after an individual failure.
export async function runBatch<T>(
  items: T[],
  execute: (item: T) => Promise<void>,
  onProgress?: (completed: number, total: number) => void,
) {
  const succeeded: T[] = []
  const failed: { item: T; error: unknown }[] = []
  let next = 0
  let completed = 0
  async function worker() {
    while (next < items.length) {
      const item = items[next++]!
      try {
        await execute(item)
        succeeded.push(item)
      } catch (error) {
        failed.push({ item, error })
      }
      completed++
      onProgress?.(completed, items.length)
    }
  }
  await Promise.all(Array.from({ length: Math.min(5, items.length) }, worker))
  return { succeeded, failed }
}
