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
    // Flutter owns inspection zoom. The host follows only the window layout;
    // composited magnification never changes these constraints or breakpoints.
    const host = document.getElementById('yorks-app');
    const sizeHost = () => {
      host.style.width = `${window.innerWidth}px`;
      host.style.height = `${window.innerHeight}px`;
    };
    sizeHost();
    window.addEventListener('resize', sizeHost, { passive: true });
    const appRunner = await engineInitializer.initializeEngine({hostElement: host});
    setYorksBootStatus('Opening Yorks…');
    await appRunner.runApp();
  },
}).catch((error) => {
  console.error('Yorks startup failed', error);
  document.documentElement.dataset.yorksBootFailed = 'true';
  setYorksBootStatus('Yorks could not start. Check your connection and retry.');
});
