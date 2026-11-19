/* Runs Clang and each WebAssembly program in this worker's memory. */
importScripts('compiler/clang-wasm-toolchain.global.js');

const pseudo = '#include <stdio.h>\n' + [
  '#define inicio int main(void)',
  '#define entero int',
  '#define registro struct',
  '#define si if',
  '#define sino else',
  '#define para for',
  '#define mientras while',
  '#define devolver return',
  '#define Y &&',
  '#define O ||',
  '#define leer(variable) do { if (scanf("%d", &(variable)) != 1) return 1; } while (0)',
  '#define mostrar(valor) printf("%d\\n", (int)(valor))',
  '#define texto(valor) puts(valor)',
].join('\n') + '\n';

const toolchainApi = self.clangWasmToolchain;
let toolchain;
let wasiShim;
let busy = false;

async function execute(module, test) {
  wasiShim ??= await import('./compiler/wasi/index.js');
  const { File, OpenFile, ConsoleStdout, PreopenDirectory, WASI } = wasiShim;
  const encoder = new TextEncoder();
  const decoder = new TextDecoder();
  const consoleChunks = [];
  const errorChunks = [];
  let bytes = 0;
  const capture = (chunks) => new ConsoleStdout((data) => {
    bytes += data.length;
    if (bytes > 8192) throw new Error('La salida superó el límite. Revisa tu bucle de impresión.');
    chunks.push(Uint8Array.from(data));
  });
  const read = (chunks) => chunks.map((data, i) =>
    decoder.decode(data, {stream: i < chunks.length - 1})
  ).join('');
  const wasi = new WASI(['faro'], [], [
    new OpenFile(new File(encoder.encode(test.input ? test.input + '\n' : ''))),
    capture(consoleChunks),
    capture(errorChunks),
    new PreopenDirectory('.', Object.entries(test.provided).map(([name, value]) =>
      [name, new File(encoder.encode(value))]
    )),
  ]);
  const instance = await WebAssembly.instantiate(module, {
    wasi_snapshot_preview1: wasi.wasiImport,
  });
  const exit = wasi.start(instance);
  return {output: read(consoleChunks), stderr: read(errorChunks), exit};
}

function normalize(output) {
  return output.replace(/\r\n/g, '\n').split('\n').map(line => line.trim()).join('\n').trim();
}

const message = (error) => {
  if (error instanceof WebAssembly.RuntimeError) {
    return 'El programa se detuvo durante la ejecución. Revisa divisiones por cero, índices y recursión.';
  }
  return String(error?.message ?? error).slice(0, 2500);
};

self.onmessage = async ({data: {lang, files, tests}}) => {
  if (busy) return;
  busy = true;
  try {
    if (!toolchain) {
      self.postMessage({phase: 'loading'});
      toolchain = await toolchainApi.createToolchain({
        baseUrl: new URL('./compiler/', self.location.href).href,
      });
    }
    const pairs = Object.entries(files);
    if (pairs.length > 5 || pairs.some(([name, code]) =>
      !/^[a-z][a-z0-9_]*\.(c|h|algo)$/.test(name) || typeof code !== 'string' || code.length > 16000
    )) {
      throw new Error('Cada archivo admite hasta 16 000 caracteres.');
    }
    const isPseudo = lang === 'alg';
    const main = isPseudo
      ? pseudo + pairs.map(([name, code]) => '#line 1 "' + name + '"\n' + code + '\n').join('')
      : files['main.c'];
    if (typeof main !== 'string') throw new Error('Falta el archivo de entrada.');
    self.postMessage({phase: 'compile'});
    const compiled = await toolchain.lock(() => toolchain.captureCompilerOutput(() =>
      toolchain.runtime.compileArtifact(main, {
        language: 'C', fileName: 'main.c',
        workspaceFiles: isPseudo ? [] : pairs.map(([path, content]) => ({path, content})),
        compileArgs: [
          ...toolchainApi.CLANG_DRIVER_DEFAULT_ARGS,
          '-std=c17', '-Werror=implicit-function-declaration',
          '-Werror=return-type',
        ],
      })
    ));
    if (compiled.error) {
      const diagnostics = toolchainApi.compilerDiagnostics(compiled.raw);
      self.postMessage({diagnostics: diagnostics.slice(0, 14).join('\n') || message(compiled.error)});
      return;
    }
    const module = await WebAssembly.compile(compiled.result.bytes);
    const cases = [];
    for (const [index, test] of tests.entries()) {
      self.postMessage({phase: 'test', index});
      try {
        const result = await execute(module, test);
        cases.push({...result, ok: result.exit === 0 && normalize(result.output) === normalize(test.expected)});
      } catch (error) {
        cases.push({ok: false, error: message(error), output: ''});
      }
    }
    self.postMessage({cases});
  } catch (error) {
    self.postMessage({diagnostics: message(error)});
  } finally {
    busy = false;
  }
};
