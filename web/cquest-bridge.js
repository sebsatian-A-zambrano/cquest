/* Compiling and running happen away from the interface, with bounded time. */
(() => {
  let worker;
  let running = false;

  globalThis.cquestGrade = (json, onStatus) => new Promise((resolve) => {
    if (running) {
      resolve(JSON.stringify({diagnostics: 'Ya hay un programa en ejecución.'}));
      return;
    }
    running = true;
    let timer;
    let testIndex = null;
    const stop = (outcome, reset = false) => {
      clearTimeout(timer);
      running = false;
      if (worker) {
        worker.onmessage = null;
        worker.onerror = null;
        if (reset) {
          worker.terminate();
          worker = null;
        }
      }
      resolve(JSON.stringify(outcome));
    };
    const schedule = (time, diagnostics) => {
      clearTimeout(timer);
      timer = setTimeout(() => stop({diagnostics, testIndex}, true), time);
    };
    try {
      worker ??= new Worker(new URL('cquest-worker.js', document.baseURI));
      worker.onerror = () => stop({
        diagnostics: 'El laboratorio no pudo iniciar. Recarga la página y vuelve a probar.',
      }, true);
      worker.onmessage = ({data}) => {
        if (data.phase === 'loading') {
          onStatus('Preparando el compilador…');
          schedule(45000, 'El compilador tardó demasiado en iniciar. Puedes volver a intentarlo.');
        } else if (data.phase === 'compile') {
          onStatus('Compilando tus archivos…');
          schedule(12000, 'El compilador tardó demasiado. Revisa el tamaño del programa e inténtalo de nuevo.');
        } else if (data.phase === 'test') {
          testIndex = data.index;
          onStatus('Ejecutando el caso ' + (testIndex + 1) + '…');
          schedule(2500, 'Este caso excedió el tiempo de ejecución. Comprueba qué hace terminar tus bucles o llamadas.');
        } else {
          stop(data);
        }
      };
      schedule(45000, 'El laboratorio tardó demasiado en iniciar.');
      worker.postMessage(JSON.parse(json));
    } catch (_) {
      stop({diagnostics: 'Este navegador no pudo abrir el laboratorio.'}, true);
    }
  });
})();
