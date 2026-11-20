export type Point = [number, number]
export type Shape = 'square' | 'rectangle' | 'triangle'
export type Line = { from: Point; to: Point }

export const add = (a: Point, b: Point): Point => [a[0] + b[0], a[1] + b[1]]
export const scale = (a: Point, n: number): Point => [a[0] * n, a[1] * n]
export const sub = (a: Point, b: Point): Point => add(a, scale(b, -1))
export const cross = (a: Point, b: Point) => a[0] * b[1] - a[1] * b[0]
const dot = (a: Point, b: Point) => a[0] * b[0] + a[1] * b[1]
export const center = (vertices: Point[]) => scale(vertices.reduce(add, [0, 0]), 1 / vertices.length)
export const polygonEdges = (vertices: Point[]): Line[] =>
  vertices.map((from, i) => ({ from, to: vertices[(i + 1) % vertices.length]! }))

export function snapRotationToAxes(vertices: Point[], angle: number) {
  const step = Math.PI / 2
  let best: { angle: number; edgeIndex: number; axis: 'horizontal' | 'vertical'; error: number } | undefined
  for (const [edgeIndex, { from, to }] of polygonEdges(vertices).entries()) {
    const [x, y] = sub(to, from)
    if (Math.hypot(x, y) < 1e-7) continue
    const heading = Math.atan2(y, x) + angle
    const axisIndex = Math.round(heading / step)
    const correction = axisIndex * step - heading
    const error = Math.abs(correction)
    if (error > Math.PI / 36 || (best && error >= best.error - 1e-10)) continue
    best = { angle: angle + correction, edgeIndex, axis: axisIndex % 2 === 0 ? 'horizontal' : 'vertical', error }
  }
  return best
}

export function findEdgeSnap(vertices: Point[], neighbors: Point[][], tolerance: number) {
  let best: { distance: number; offset: Point; seam: Line } | undefined
  const targets = neighbors.flatMap(polygonEdges)
  for (const edge of polygonEdges(vertices)) {
    const direction = sub(edge.to, edge.from)
    const length = Math.hypot(...direction)
    if (length < 1e-7) continue
    const tangent = scale(direction, 1 / length)
    const normal: Point = [-tangent[1], tangent[0]]
    for (const target of targets) {
      const segment = sub(target.to, target.from)
      const targetLength = Math.hypot(...segment)
      if (targetLength < 1e-7) continue
      const targetDirection = scale(segment, 1 / targetLength)
      // Both polygons use the same winding. Only opposite-facing edges form a seam.
      if (dot(tangent, targetDirection) >= 0 || Math.abs(cross(tangent, targetDirection)) > 1e-6) continue
      const relative = sub(target.from, edge.from)
      const gap = dot(relative, normal)
      const distance = Math.abs(gap)
      if (distance > tolerance || (best && distance >= best.distance)) continue
      const targetEnd = dot(relative, tangent)
      const targetStart = targetEnd - targetLength
      if (Math.min(length, targetEnd) - Math.max(0, targetStart) < tolerance / 4) continue

      const endShift = targetEnd - length
      const nearestEndShift = Math.abs(targetStart) <= Math.abs(endShift) ? targetStart : endShift
      const along = Math.abs(nearestEndShift) <= tolerance ? nearestEndShift : 0
      const start = Math.max(0, targetStart - along)
      const finish = Math.min(length, targetEnd - along)
      const offset = add(scale(normal, gap), scale(tangent, along))
      const origin = add(edge.from, offset)
      best = { distance, offset, seam: { from: add(origin, scale(tangent, start)), to: add(origin, scale(tangent, finish)) } }
    }
  }
  return best
}

export function polygonCentroid(vertices: Point[]): Point {
  const origin = vertices[0]!
  const offsets = vertices.map(point => sub(point, origin))
  let twiceArea = 0
  let weighted: Point = [0, 0]
  for (const { from, to } of polygonEdges(offsets)) {
    const weight = cross(from, to)
    twiceArea += weight
    weighted = add(weighted, scale(add(from, to), weight))
  }
  return twiceArea ? add(origin, scale(weighted, 1 / (3 * twiceArea))) : center(vertices)
}

export function snapCutLineToPoint(line: Line, point: Point, tolerance: number): Line {
  const distance = distanceToLine(line, point)
  if (Math.abs(distance) > tolerance) return line
  const [x, y] = sub(line.to, line.from)
  const shift = scale([-y, x], distance / Math.hypot(x, y))
  return { from: add(line.from, shift), to: add(line.to, shift) }
}

export function snapCutEndpointToPoint(line: Line, handle: keyof Line, point: Point, tolerance: number): Line | undefined {
  const anchor = line[handle === 'from' ? 'to' : 'from']
  const towardPoint = sub(point, anchor)
  const distance = Math.hypot(...towardPoint)
  if (distance < 1e-7 || Math.abs(distanceToLine(line, point)) > tolerance) return

  const direction = sub(line[handle], anchor)
  const sign = direction[0] * towardPoint[0] + direction[1] * towardPoint[1] < 0 ? -1 : 1
  const endpoint = add(anchor, scale(towardPoint, sign * Math.hypot(...direction) / distance))
  if (Math.hypot(...sub(endpoint, line[handle])) > 2 * tolerance) return
  return { ...line, [handle]: endpoint }
}

export function cutAngleToEdges(direction: Point, vertices: Point[]) {
  const step = Math.PI / 4
  const angle = Math.atan2(direction[1], direction[0])
  return polygonEdges(vertices).reduce<{ target: number; error: number; relative: number } | undefined>((best, edge) => {
    const [x, y] = sub(edge.to, edge.from)
    const heading = Math.atan2(y, x)
    const difference = angle - heading
    const target = heading + Math.round(difference / step) * step
    const error = Math.abs(angle - target)
    const relative = Math.abs(difference - Math.round(difference / Math.PI) * Math.PI)
    if (!best || error < best.error - 1e-10 || (Math.abs(error - best.error) < 1e-10 && relative < best.relative)) {
      return { target, error, relative }
    }
    return best
  }, undefined)
}

export function snapCutDirection(direction: Point, vertices: Point[]): Point {
  const match = cutAngleToEdges(direction, vertices)
  if (!match || match.error > Math.PI / 30) return direction
  const length = Math.hypot(...direction)
  return [Math.cos(match.target) * length, Math.sin(match.target) * length]
}

const epsilon = 1e-7

export function makeShape(shape: Shape): Point[] {
  const w = shape === 'rectangle' ? 1.4 : 1
  const h = shape === 'rectangle' ? 0.7 : 1
  return shape === 'triangle'
    ? [[0, -h], [w, h], [-w, h]]
    : [[-w, -h], [w, -h], [w, h], [-w, h]]
}

export function distanceToLine({ from, to }: Line, point: Point) {
  const direction = sub(to, from)
  return cross(direction, sub(point, from)) / Math.hypot(...direction)
}

export function splitPolygon(vertices: Point[], line: Line) {
  const distances = vertices.map(point => {
    const value = distanceToLine(line, point)
    return Math.abs(value) < epsilon ? 0 : value
  })
  if (!distances.some(value => value > 0) || !distances.some(value => value < 0)) return null

  const positive: Point[] = []
  const negative: Point[] = []
  const intersection: Point[] = []
  polygonEdges(vertices).forEach(({ from, to }, i) => {
    const a = distances[i]!
    const b = distances[(i + 1) % vertices.length]!
    if (a >= 0) positive.push(from)
    if (a <= 0) negative.push(from)
    if (a === 0) intersection.push(from)
    if (a * b < 0) {
      const point = add(from, scale(sub(to, from), a / (a - b)))
      positive.push(point)
      negative.push(point)
      intersection.push(point)
    }
  })
  if (positive.length < 3 || negative.length < 3 || intersection.length < 2) return null
  return { positive, negative, edge: { from: intersection[0]!, to: intersection[1]! } }
}
