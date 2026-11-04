/**
 * Feasible flow with lower bounds (Dinic). Used for two small combinatorial
 * problems: controlled rounding of the topic × difficulty matrix, and picking
 * per-cell counts during variant assembly. Graphs have < 100 nodes.
 */

export interface BoundedEdge {
  from: string;
  to: string;
  lo: number;
  hi: number;
}

interface Arc {
  to: number;
  cap: number;
  rev: number;
}

class Dinic {
  private readonly graph: Arc[][];
  private level: number[] = [];
  private iter: number[] = [];

  constructor(n: number) {
    this.graph = Array.from({ length: n }, () => []);
  }

  addEdge(u: number, v: number, cap: number): [number, number] {
    const a: Arc = { to: v, cap, rev: this.graph[v]!.length };
    const b: Arc = { to: u, cap: 0, rev: this.graph[u]!.length };
    this.graph[u]!.push(a);
    this.graph[v]!.push(b);
    return [u, this.graph[u]!.length - 1];
  }

  arc(u: number, i: number): Arc {
    return this.graph[u]![i]!;
  }

  private bfs(s: number): void {
    this.level = new Array(this.graph.length).fill(-1);
    this.level[s] = 0;
    const q = [s];
    while (q.length) {
      const u = q.shift()!;
      for (const e of this.graph[u]!) {
        if (e.cap > 0 && this.level[e.to]! < 0) {
          this.level[e.to] = this.level[u]! + 1;
          q.push(e.to);
        }
      }
    }
  }

  private dfs(u: number, t: number, f: number): number {
    if (u === t) return f;
    const edges = this.graph[u]!;
    for (; this.iter[u]! < edges.length; this.iter[u]!++) {
      const e = edges[this.iter[u]!]!;
      if (e.cap > 0 && this.level[u]! < this.level[e.to]!) {
        const d = this.dfs(e.to, t, Math.min(f, e.cap));
        if (d > 0) {
          e.cap -= d;
          this.graph[e.to]![e.rev]!.cap += d;
          return d;
        }
      }
    }
    return 0;
  }

  maxFlow(s: number, t: number): number {
    let flow = 0;
    for (;;) {
      this.bfs(s);
      if (this.level[t]! < 0) return flow;
      this.iter = new Array(this.graph.length).fill(0);
      let f: number;
      while ((f = this.dfs(s, t, Number.MAX_SAFE_INTEGER)) > 0) flow += f;
    }
  }
}

/**
 * Finds integer flows f(e) with lo ≤ f ≤ hi on every edge and conservation at
 * every node (a circulation), or returns null when none exists. Put a
 * source→…→sink network in `edges` plus one edge sink→source with a wide
 * range to model an s–t flow.
 */
export function feasibleCirculation(edges: BoundedEdge[]): number[] | null {
  const names = new Map<string, number>();
  const id = (n: string): number => {
    let v = names.get(n);
    if (v === undefined) {
      v = names.size;
      names.set(n, v);
    }
    return v;
  };
  for (const e of edges) {
    if (e.lo > e.hi || e.lo < 0) return null;
    id(e.from);
    id(e.to);
  }
  const n = names.size;
  const S = n;
  const T = n + 1;
  const dinic = new Dinic(n + 2);
  const demand = new Array<number>(n).fill(0);
  const handles: Array<[number, number]> = [];
  for (const e of edges) {
    const u = id(e.from);
    const v = id(e.to);
    handles.push(dinic.addEdge(u, v, e.hi - e.lo));
    demand[v]! += e.lo;
    demand[u]! -= e.lo;
  }
  let need = 0;
  for (let v = 0; v < n; v++) {
    const d = demand[v]!;
    if (d > 0) {
      dinic.addEdge(S, v, d);
      need += d;
    } else if (d < 0) {
      dinic.addEdge(v, T, -d);
    }
  }
  const got = dinic.maxFlow(S, T);
  if (got !== need) return null;
  return edges.map((e, i) => {
    const [u, idx] = handles[i]!;
    const arc = dinic.arc(u, idx);
    return e.lo + (e.hi - e.lo - arc.cap);
  });
}

/**
 * Integer matrix x[r][c] with row sums == rowTargets, column sums ==
 * colTargets and cellLo ≤ x ≤ cellHi. Returns null if infeasible.
 */
export function boundedMatrix(
  rowTargets: Array<{ lo: number; hi: number }>,
  colTargets: Array<{ lo: number; hi: number }>,
  cellLo: number[][],
  cellHi: number[][],
  exactTotal?: number,
): number[][] | null {
  const edges: BoundedEdge[] = [];
  const total = colTargets.reduce((a, c) => a + c.hi, 0) + rowTargets.reduce((a, r) => a + r.hi, 0);
  colTargets.forEach((c, j) => edges.push({ from: 'S', to: `c${j}`, lo: c.lo, hi: c.hi }));
  rowTargets.forEach((r, i) => edges.push({ from: `r${i}`, to: 'T', lo: r.lo, hi: r.hi }));
  const cellIndex: Array<[number, number, number]> = [];
  for (let i = 0; i < rowTargets.length; i++) {
    for (let j = 0; j < colTargets.length; j++) {
      const lo = cellLo[i]?.[j] ?? 0;
      const hi = cellHi[i]?.[j] ?? 0;
      if (hi <= 0 && lo <= 0) continue;
      cellIndex.push([i, j, edges.length]);
      edges.push({ from: `c${j}`, to: `r${i}`, lo, hi });
    }
  }
  edges.push(exactTotal === undefined ? { from: 'T', to: 'S', lo: 0, hi: total } : { from: 'T', to: 'S', lo: exactTotal, hi: exactTotal });
  const flow = feasibleCirculation(edges);
  if (!flow) return null;
  const x = rowTargets.map(() => colTargets.map(() => 0));
  for (const [i, j, k] of cellIndex) x[i]![j] = flow[k]!;
  return x;
}

/** Largest-remainder apportionment of `total` by `weights` (ties → larger weight, then earlier index). */
export function apportion(total: number, weights: number[]): number[] {
  const sum = weights.reduce((a, b) => a + b, 0);
  if (sum <= 0) return weights.map(() => 0);
  const raw = weights.map((w) => (w / sum) * total);
  const out = raw.map((r) => Math.floor(r));
  let left = total - out.reduce((a, b) => a + b, 0);
  const order = raw
    .map((r, i) => ({ i, frac: r - Math.floor(r), w: weights[i]! }))
    .sort((a, b) => b.frac - a.frac || b.w - a.w || a.i - b.i);
  for (let k = 0; left > 0 && k < order.length; k++, left--) out[order[k]!.i]!++;
  return out;
}
