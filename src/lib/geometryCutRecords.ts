import type { Line, Point } from './geometryGame'

export interface GeometryCutRecord {
  id: string
  timestamp: number
  color: string
  before: Point[]
  pieces: [Point[], Point[]]
  edge: Line
}

export const cutRecordLimit = 30

function isPoint(value: unknown): value is Point {
  return Array.isArray(value) && value.length === 2 && value.every(Number.isFinite)
}

function isPolygon(value: unknown): value is Point[] {
  return Array.isArray(value) && value.length >= 3 && value.every(isPoint)
}

function isCutRecord(value: unknown): value is GeometryCutRecord {
  if (typeof value !== 'object' || !value) return false
  const record = value as Partial<GeometryCutRecord>
  return typeof record.id === 'string' && typeof record.timestamp === 'number' &&
    Number.isFinite(record.timestamp) && Math.abs(record.timestamp) <= 8.64e15 &&
    typeof record.color === 'string' && /^#[\da-f]{6}$/i.test(record.color) &&
    isPolygon(record.before) && Array.isArray(record.pieces) && record.pieces.length === 2 &&
    record.pieces.every(isPolygon) && !!record.edge &&
    isPoint(record.edge.from) && isPoint(record.edge.to)
}

export function readCutRecords(storageKey: string): GeometryCutRecord[] {
  try {
    const data: unknown = JSON.parse(localStorage.getItem(storageKey) ?? '[]')
    return Array.isArray(data) ? data.filter(isCutRecord).slice(0, cutRecordLimit) : []
  } catch {
    return []
  }
}

export function saveCutRecords(storageKey: string, records: GeometryCutRecord[]) {
  try {
    localStorage.setItem(storageKey, JSON.stringify(records.slice(0, cutRecordLimit)))
    return true
  } catch {
    return false
  }
}

export function geometryShapeName(vertices: Point[]) {
  return ({ 3: '三角形', 4: '四边形', 5: '五边形', 6: '六边形' }[vertices.length] ?? `${vertices.length} 边形`)
}
