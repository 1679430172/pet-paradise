import ts from 'typescript'
import { readFile, mkdir, writeFile, unlink } from 'node:fs/promises'
import path from 'node:path'
const folder = path.resolve('node_modules/.checkin-test')
await mkdir(folder, { recursive: true })
const file = path.join(folder, 'edge-check.ts')
const source = (await readFile('supabase/functions/photo-checkins/index.ts', 'utf8')).replace('npm:@supabase/supabase-js@2.105.4', '@supabase/supabase-js')
await writeFile(file, 'declare const Deno: { env: { get(key: string): string | undefined }; serve(handler: (req: Request) => Promise<Response>): void };\n' + source)
try {
  const program = ts.createProgram([file], { noEmit: true, strict: true, skipLibCheck: true, target: ts.ScriptTarget.ES2022, module: ts.ModuleKind.ESNext, moduleResolution: ts.ModuleResolutionKind.Bundler, types: [] })
  const diagnostics = ts.getPreEmitDiagnostics(program)
  if (diagnostics.length) {
    console.error(ts.formatDiagnosticsWithColorAndContext(diagnostics, { getCanonicalFileName: x => x, getCurrentDirectory: () => process.cwd(), getNewLine: () => '\n' }))
    process.exitCode = 1
  } else console.log('PASS: Edge Function TypeScript and Supabase client types (Deno runtime shim)')
} finally { await unlink(file) }
