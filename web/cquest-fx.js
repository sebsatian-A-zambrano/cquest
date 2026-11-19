/* Small synthesized sound cues for the expedition. Nothing is played before interaction. */
(() => {
  let audio;
  const cues = {
    talk: [392, 523],
    memory: [440, 660, 784],
    pickup: [329, 440, 659],
    repair: [261, 392, 523, 659, 784],
    cross: [392, 587, 784, 1046],
  };
  globalThis.cquestFx = (event) => {
    try {
      const Context = globalThis.AudioContext || globalThis.webkitAudioContext;
      if (!Context || !cues[event]) return;
      audio ??= new Context();
      if (audio.state === 'suspended') void audio.resume().catch(() => {});
      const start = audio.currentTime;
      cues[event].forEach((frequency, index) => {
        const ping = audio.createOscillator();
        const gain = audio.createGain();
        const at = start + index * 0.064;
        ping.type = 'triangle';
        ping.frequency.setValueAtTime(frequency, at);
        gain.gain.setValueAtTime(0.0001, at);
        gain.gain.exponentialRampToValueAtTime(0.036, at + 0.015);
        gain.gain.exponentialRampToValueAtTime(0.0001, at + 0.22);
        ping.connect(gain);
        gain.connect(audio.destination);
        ping.start(at);
        ping.stop(at + 0.23);
      });
    } catch (_) {}
  };
})();
