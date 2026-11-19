(() => {
  let installPrompt;
  window.addEventListener('beforeinstallprompt', event => {
    event.preventDefault();
    installPrompt = event;
    document.dispatchEvent(new Event('cquest-installable'));
  });
  window.cquestOpenInstall = () => {
    location.assign(new URL('instalar.html', document.baseURI));
  };
  window.cquestInstall = async () => {
    if (!installPrompt) return false;
    await installPrompt.prompt();
    await installPrompt.userChoice;
    installPrompt = null;
    return true;
  };
  window.cquestCanInstall = () => Boolean(installPrompt);

  window.cquestOfflineReady = (async () => {
    if (!('serviceWorker' in navigator) || !window.isSecureContext) return false;
    try {
      const manifest = await fetch(new URL('offline-files.json', document.baseURI), {cache:'no-store'});
      if (!manifest.ok) return false;
      await navigator.serviceWorker.register(new URL('cquest-sw.js', document.baseURI));
      await navigator.serviceWorker.ready;
      return true;
    } catch (_) {
      return false;
    }
  })();
})();
