{{flutter_js}}
{{flutter_build_config}}

// Start Flutter immediately. PostHog is initialized post-frame by the privacy-
// guarded Dart service and never delays Yorks' operational startup path.
const yorksBootStatus = document.querySelector('[data-yorks-boot-status]');
const setYorksBootStatus = (value) => {
  if (yorksBootStatus) yorksBootStatus.textContent = value;
};

_flutter.loader.load({
  onEntrypointLoaded: async (engineInitializer) => {
    setYorksBootStatus('Preparing your workspace…');
    // Size Flutter from the layout viewport, not the magnified visual viewport.
    // VisualViewport.scale distinguishes pinch from a software-keyboard inset,
    // so inspection zoom does not turn a phone layout into a narrower layout.
    const host = document.getElementById('yorks-app');
    const sizeHost = () => {
      const viewport = window.visualViewport;
      const magnification = viewport?.scale ?? 1;
      host.style.width = `${window.innerWidth}px`;
      host.style.height = `${Math.round(Math.min(
        window.innerHeight,
        viewport ? viewport.height * magnification : window.innerHeight,
      ))}px`;
    };
    // Chromium can dispatch the first visual-viewport callback before its new
    // keyboard inset is observable. Repeat on the next frame and also listen
    // for the companion viewport scroll event emitted during focal movement.
    let hostResizePulse = 0;
    const pulseHostSize = () => {
      // Flutter's visual-viewport listener and the custom host ResizeObserver
      // run in different phases. A sub-pixel host change makes the latter
      // reassert the unchanged layout size after each pinch update. clientWidth
      // and clientHeight remain the intended whole logical pixels.
      hostResizePulse = hostResizePulse === 0.0625 ? 0.125 : 0.0625;
      const width = Number.parseFloat(host.style.width);
      const height = Number.parseFloat(host.style.height);
      host.style.width = `${Math.floor(width) + hostResizePulse}px`;
      host.style.height = `${Math.floor(height) + hostResizePulse}px`;
    };
    const scheduleHostSize = () => {
      sizeHost();
      pulseHostSize();
      // Restore the exact CSS size in a later task. The observable pulse has
      // already made the custom-host ResizeObserver reassert Flutter's layout.
      window.setTimeout(sizeHost, 0);
    };
    sizeHost();
    window.addEventListener('resize', scheduleHostSize, { passive: true });
    window.visualViewport?.addEventListener('resize', scheduleHostSize, { passive: true });
    window.visualViewport?.addEventListener('scroll', scheduleHostSize, { passive: true });
    const appRunner = await engineInitializer.initializeEngine({hostElement: host});
    setYorksBootStatus('Opening Yorks…');
    await appRunner.runApp();
  },
}).catch((error) => {
  console.error('Yorks startup failed', error);
  document.documentElement.dataset.yorksBootFailed = 'true';
  setYorksBootStatus('Yorks could not start. Check your connection and retry.');
});
