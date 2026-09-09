{{flutter_js}}
{{flutter_build_config}}

// Flutter's PostHog plugin delegates web capture to posthog-js. The Dart
// Posthog().setup() call does not initialize that browser SDK, so the R35
// launcher writes a gitignored posthog_config.js and this bootstrap loads it
// before Flutter starts. With no generated config (or telemetry disabled), the
// app simply continues with analytics off.
const loadYorksPostHogConfig = () => new Promise((resolve) => {
  const script = document.createElement('script');
  script.src = 'posthog_config.js';
  script.async = false;
  script.onload = resolve;
  script.onerror = resolve;
  document.head.appendChild(script);
});

const initializeYorksPostHogWeb = async () => {
  await loadYorksPostHogConfig();
  const config = window.__YORKS_POSTHOG__;
  if (!config?.enabled || !config.projectToken) return;

  // Official PostHog web loader. It creates a synchronous queue immediately,
  // then loads posthog-js asynchronously, so Flutter capture/identify calls are
  // safe even if the network library has not finished downloading yet.
  !function(t,e){var o,n,p,r;e.__SV||(window.posthog&&window.posthog.__loaded)||(window.posthog=e,e._i=[],e.init=function(i,s,a){function g(t,e){var o=e.split('.');2==o.length&&(t=t[o[0]],e=o[1]),t[e]=function(){t.push([e].concat(Array.prototype.slice.call(arguments,0)))}}p||((p=t.createElement('script')).type='text/javascript',p.crossOrigin='anonymous',p.async=!0,p.src=s.api_host.replace('.i.posthog.com','-assets.i.posthog.com')+'/static/array.js',p.onerror=function(){p=null},(r=t.getElementsByTagName('script')[0]).parentNode.insertBefore(p,r));var u=e;for(void 0!==a?u=e[a]=[]:a='posthog',u.people=u.people||[],Object.defineProperty(u,'toString',{configurable:!0,enumerable:!0,writable:!0,value:function(t){var e='posthog';return'posthog'!==a&&(e+='.'+a),t||(e+=' (stub)'),e}}),Object.defineProperty(u.people,'toString',{configurable:!0,enumerable:!0,writable:!0,value:function(){return u.toString(1)+'.people (stub)'}}),o='init capture register register_once register_for_session unregister opt_out_capturing has_opted_out_capturing opt_in_capturing reset isFeatureEnabled getFeatureFlag getFeatureFlagPayload reloadFeatureFlags group identify setPersonProperties setPersonPropertiesForFlags resetPersonPropertiesForFlags setGroupPropertiesForFlags resetGroupPropertiesForFlags resetGroups onFeatureFlags addFeatureFlagsHandler onSessionId getSurveys getActiveMatchingSurveys renderSurvey canRenderSurvey getNextSurveyStep'.split(' '),n=0;n<o.length;n++)g(u,o[n]);e._i.push([i,s,a])},e.__SV=1)}(document,window.posthog||[]);

  window.posthog.init(config.projectToken, {
    api_host: config.host || 'https://us.i.posthog.com',
    defaults: '2026-05-30',
    debug: Boolean(config.debug),
    // Yorks captures deliberate semantic events from Dart. Browser DOM
    // autocapture is intentionally disabled because Flutter renders primarily
    // to canvas and Yorks contains sensitive operational data.
    autocapture: false,
    capture_pageview: false,
    capture_pageleave: false,
    // Session replay remains explicitly off until masked staging recordings
    // have been reviewed and approved.
    disable_session_recording: true,
  });

  if (config.debug) {
    console.info('[analytics] PostHog web bridge initialized');
  }
};

// Start Flutter after the PostHog browser queue exists. Push is deliberately
// registered by the signed-in application after first paint; it must never
// hold the application entrypoint behind a service-worker install/update cycle.
const yorksBootStatus = document.querySelector('[data-yorks-boot-status]');
const setYorksBootStatus = (value) => {
  if (yorksBootStatus) yorksBootStatus.textContent = value;
};

initializeYorksPostHogWeb()
  .catch((error) => console.warn('[analytics] PostHog web bootstrap skipped', error))
  .finally(() => {
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
  });
