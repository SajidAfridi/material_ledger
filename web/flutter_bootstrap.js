{{flutter_js}}
{{flutter_build_config}}

// Start Flutter immediately. Push is deliberately registered by the signed-in
// application after first paint; it must never hold the application entrypoint
// behind a service-worker install or update cycle.
const yorksBootStatus = document.querySelector('[data-yorks-boot-status]');
const setYorksBootStatus = (value) => {
  if (yorksBootStatus) yorksBootStatus.textContent = value;
};

_flutter.loader.load({
  onEntrypointLoaded: async (engineInitializer) => {
    setYorksBootStatus('Preparing your workspace…');
    const appRunner = await engineInitializer.initializeEngine();
    setYorksBootStatus('Opening Yorks…');
    await appRunner.runApp();
  },
}).catch((error) => {
  console.error('Yorks startup failed', error);
  document.documentElement.dataset.yorksBootFailed = 'true';
  setYorksBootStatus('Yorks could not start. Check your connection and retry.');
});
